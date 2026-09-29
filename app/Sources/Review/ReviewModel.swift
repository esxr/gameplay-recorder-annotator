import AVFoundation
import AppKit
import Combine
import Foundation

/// State for one review window: the player, the (possibly still growing) JSONL records and the selection.
@MainActor
final class ReviewModel: ObservableObject {
    let videoURL: URL
    let annotationsURL: URL
    let player: AVPlayer
    let engine: EngineSessionModel

    @Published private(set) var records: [AnnotationRecord] = []
    @Published private(set) var jsonlLineCount: Int = 0
    @Published private(set) var malformedLineCount: Int = 0
    @Published var selectedFrame: Int?          // AnnotationRecord.id
    @Published var showBoxes: Bool = true
    @Published var showList: Bool = true
    @Published private(set) var currentMs: Int = 0
    @Published private(set) var assetDurationMs: Int = 0
    @Published private(set) var videoSize: CGSize = CGSize(width: 16, height: 9)
    @Published private(set) var isGrowing: Bool = true
    @Published private(set) var isPlaying: Bool = false

    private var reloadTimer: Timer?
    private var timeObserver: Any?
    private var lastFileSize: Int = -1
    private var lastModDate: Date?
    private var unchangedReloads = 0
    private var engineSub: AnyCancellable?

    init(video: URL, annotations: URL) {
        videoURL = video
        annotationsURL = annotations
        player = AVPlayer(url: video)
        engine = EngineSessionModel(video: video)
        player.actionAtItemEnd = .pause
        engineSub = engine.$hasSession.removeDuplicates().sink { [weak self] _ in self?.objectWillChange.send() }
        engine.onSeekFrame = { [weak self] f in guard let self else { return }; self.seek(toMs: self.engine.ms(forFrame: f)) }
        loadAssetInfo()
        reload()
        start()
    }

    /// Duration used by the timeline: the asset duration, or the last record time if the asset isn't loaded yet.
    var durationMs: Int { max(assetDurationMs, (records.last?.t_ms ?? 0) + 1, 1) }

    var selectedRecord: AnnotationRecord? {
        guard let f = selectedFrame else { return nil }
        return records.first { $0.frame == f }
    }

    var selectedIndex: Int? {
        guard let f = selectedFrame else { return nil }
        return records.firstIndex { $0.frame == f }
    }

    /// Annotation writer may drop `<video>.annotations.done` (either `x.mp4.annotations.done` or `x.annotations.done`).
    private var annotationDoneExists: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: videoURL.path + ".annotations.done")
            || fm.fileExists(atPath: videoURL.deletingPathExtension().path + ".annotations.done")
    }

    // MARK: Lifecycle

    private func start() {
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { [weak self] t in
            MainActor.assumeIsolated { self?.tick(t) }
        }
    }

    func stop() {
        reloadTimer?.invalidate(); reloadTimer = nil
        if let o = timeObserver { player.removeTimeObserver(o); timeObserver = nil }
        player.pause()
        engine.stop()
    }

    private func loadAssetInfo() {
        let asset = AVURLAsset(url: videoURL)
        Task { @MainActor [weak self] in
            if let d = try? await asset.load(.duration), d.isNumeric {
                self?.assetDurationMs = Int(d.seconds * 1000)
            }
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let (size, tf) = try? await track.load(.naturalSize, .preferredTransform) {
                let r = CGRect(origin: .zero, size: size).applying(tf)
                if abs(r.width) > 0, abs(r.height) > 0 {
                    self?.videoSize = CGSize(width: abs(r.width), height: abs(r.height))
                }
            }
        }
    }

    private func tick(_ t: CMTime) {
        guard t.isNumeric else { return }
        currentMs = Int(t.seconds * 1000)
        let playing = player.rate != 0
        if playing != isPlaying { isPlaying = playing }
        if playing, let r = latestRecord(atOrBefore: currentMs), r.frame != selectedFrame {
            selectedFrame = r.frame
        }
    }

    func latestRecord(atOrBefore ms: Int) -> AnnotationRecord? {
        // records sorted by t_ms; binary search for the last element with t_ms <= ms
        var lo = 0, hi = records.count - 1, ans: Int? = nil
        while lo <= hi {
            let mid = (lo + hi) / 2
            if records[mid].t_ms <= ms { ans = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return ans.map { records[$0] }
    }

    // MARK: JSONL loading

    func reload() {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: annotationsURL.path)
        let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        let mod = attrs?[.modificationDate] as? Date
        if size == lastFileSize && mod == lastModDate {
            unchangedReloads += 1
            if isGrowing && unchangedReloads >= 2 && annotationDoneExists { isGrowing = false }
            return
        }
        unchangedReloads = 0
        lastFileSize = size; lastModDate = mod
        isGrowing = true

        guard let data = try? Data(contentsOf: annotationsURL), let text = String(data: data, encoding: .utf8) else {
            return
        }
        let decoder = JSONDecoder()
        var parsed: [AnnotationRecord] = []
        var lines = 0, bad = 0
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            lines += 1
            if let d = line.data(using: .utf8), let r = try? decoder.decode(AnnotationRecord.self, from: d) {
                parsed.append(r)
            } else {
                bad += 1
            }
        }
        parsed.sort { ($0.t_ms, $0.frame) < ($1.t_ms, $1.frame) }
        jsonlLineCount = lines
        malformedLineCount = bad
        if parsed != records { records = parsed }
        if selectedFrame == nil, let first = records.first { selectedFrame = first.frame }
    }

    // MARK: Navigation

    func seek(toMs ms: Int) {
        let clamped = max(0, min(ms, durationMs))
        currentMs = clamped
        player.seek(to: CMTime(value: CMTimeValue(clamped), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func select(_ r: AnnotationRecord, seek doSeek: Bool = true) {
        selectedFrame = r.frame
        if doSeek { seek(toMs: r.t_ms) }
    }

    func step(_ delta: Int) {
        guard !records.isEmpty else { return }
        let idx: Int
        if let i = selectedIndex {
            idx = max(0, min(records.count - 1, i + delta))
        } else {
            idx = delta > 0 ? 0 : records.count - 1
        }
        select(records[idx])
    }

    func togglePlay() {
        if player.rate != 0 { player.pause() } else { player.play() }
    }
}
