import AppKit
import Combine
import Foundation

/// One engine event line from `<video>.session/events.jsonl` (engine/CONTRACT.md).
struct EngineEvent: Identifiable, Hashable {
    let id: String
    let type: String
    let fStart: Int
    let fEnd: Int
    let confidence: Double
    let detail: String          // "from → to" / entity, human readable
    let evidenceFrame: Int?
    let evidenceCrop: String?
}

struct EngineBox: Hashable {
    let id: String
    let label: String
    let type: String
    let bbox: [Double]      // normalized x,y,w,h of the analyzed (full) video frame
    let visible: Bool
    let source: String      // observed | propagated | inferred
    let conf: Double
}

struct AskEvidence: Identifiable, Hashable {
    var id: String { "\(f)|\(crop ?? "")" }
    let f: Int
    let crop: String?
}

/// Engine-side state for a review window: region modes per frame, events, and the Ask box.
/// Files are (re)parsed in the background whenever their mtime changes (engine may still be running).
@MainActor
final class EngineSessionModel: ObservableObject {
    private(set) var sessionDir: URL
    private let sessionCandidates: [URL]
    /// Per-frame engine boxes (replayed from snapshot + merge-patch deltas).
    @Published private(set) var boxes: [[EngineBox]] = []
    @Published private(set) var fps: Double = 60
    @Published private(set) var modes: [String] = []        // index = frame f, 48 chars (8×6 row-major), "" if missing
    @Published private(set) var modeCounts: [Character: Int] = [:]
    @Published private(set) var events: [EngineEvent] = []
    @Published private(set) var hasSession = false
    @Published var showRegions = true

    // Ask box
    @Published var question = ""
    @Published private(set) var isAsking = false
    @Published private(set) var answer: String?
    @Published private(set) var contextTokens: Int?
    @Published private(set) var askEvidence: [AskEvidence] = []
    @Published private(set) var askError: String?
    @Published var shownCrop: String?          // resolved path of the crop being previewed

    private var timer: Timer?
    private var streamStamp: String = ""
    private var eventsStamp: String = ""
    private var metaStamp: String = ""
    private var parsing = false
    private var autoAsked = false
    /// Set by ReviewModel: seek the player to a frame.
    var onSeekFrame: ((Int) -> Void)?

    init(video: URL) {
        // CONTRACT says `<video>.session/`; the engine writes `x.mp4.session` or `x.session` — accept both.
        sessionCandidates = [EnginePaths.sessionDir(for: video),
                             URL(fileURLWithPath: video.deletingPathExtension().path + ".session", isDirectory: true)]
        sessionDir = sessionCandidates[0]
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    var streamURL: URL { sessionDir.appendingPathComponent("stream.jsonl") }
    var eventsURL: URL { sessionDir.appendingPathComponent("events.jsonl") }
    var metaURL: URL { sessionDir.appendingPathComponent("meta.json") }

    func frame(forMs ms: Int) -> Int { Int((Double(ms) * fps / 1000.0).rounded(.down)) }
    func ms(forFrame f: Int) -> Int { Int((Double(f) * 1000.0 / fps).rounded()) }

    func modes(atMs ms: Int) -> String? {
        guard !modes.isEmpty else { return nil }
        let f = max(0, min(modes.count - 1, frame(forMs: ms)))
        let m = modes[f]
        return m.isEmpty ? nil : m
    }

    var totalRegions: Int { modeCounts.values.reduce(0, +) }

    func resolve(_ crop: String?) -> String? {
        guard let c = crop, !c.isEmpty else { return nil }
        return c.hasPrefix("/") ? c : sessionDir.appendingPathComponent(c).path
    }

    // MARK: Loading

    private static func stamp(_ u: URL) -> String {
        guard let a = try? FileManager.default.attributesOfItem(atPath: u.path) else { return "" }
        return "\((a[.size] as? NSNumber)?.intValue ?? 0)-\((a[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)"
    }

    func refresh() {
        let fm = FileManager.default
        if !hasSession, let found = sessionCandidates.first(where: { fm.fileExists(atPath: $0.appendingPathComponent("stream.jsonl").path) || fm.fileExists(atPath: $0.appendingPathComponent("events.jsonl").path) }) {
            sessionDir = found
            hasSession = true
        }
        // Automation hook for scripted proofs: GR_AUTO_ASK="question" asks once, after the engine has finished (meta.json exists).
        if hasSession, !autoAsked, let q = ProcessInfo.processInfo.environment["GR_AUTO_ASK"], !q.isEmpty,
           fm.fileExists(atPath: metaURL.path) {
            autoAsked = true; question = q
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in MainActor.assumeIsolated { self?.ask() } }
        }
        guard hasSession, !parsing else { return }
        let ms = Self.stamp(metaURL), ss = Self.stamp(streamURL), es = Self.stamp(eventsURL)
        guard ms != metaStamp || ss != streamStamp || es != eventsStamp else { return }
        let doStream = ss != streamStamp, doEvents = es != eventsStamp, doMeta = ms != metaStamp
        metaStamp = ms; streamStamp = ss; eventsStamp = es
        parsing = true
        let (su, eu, mu) = (streamURL, eventsURL, metaURL)
        Task.detached(priority: .utility) {
            let fps = doMeta ? Self.parseFps(mu) : nil
            let stream = doStream ? Self.parseStream(su) : nil
            let evs = doEvents ? Self.parseEvents(eu) : nil
            await MainActor.run { [weak self] in
                guard let self else { return }
                if let fps { self.fps = fps }
                if let stream {
                    self.modes = stream.0; self.modeCounts = stream.1; self.boxes = stream.2
                    AppLog.log("engine_stage", ["name": "review_regions", "frames": stream.0.count, "box_frames": stream.2.filter { !$0.isEmpty }.count, "session": self.sessionDir.path])
                }
                if let evs {
                    self.events = evs
                    AppLog.log("engine_stage", ["name": "review_events", "count": evs.count, "session": self.sessionDir.path])
                }
                self.parsing = false
            }
        }
    }

    nonisolated private static func parseFps(_ u: URL) -> Double? {
        guard let d = try? Data(contentsOf: u), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        if let f = o["fps"] as? Double, f > 0 { return f }
        if let f = o["fps"] as? Int, f > 0 { return Double(f) }
        return nil
    }

    /// Keeps f → modes and f → entity boxes (replaying snapshot + JSON-merge-patch deltas once).
    nonisolated private static func parseStream(_ u: URL) -> ([String], [Character: Int], [[EngineBox]])? {
        guard let d = try? Data(contentsOf: u) else { return nil }
        var rows: [(Int, String, [EngineBox])] = []
        var counts: [Character: Int] = [:]
        var state: [String: Any] = [:]
        var maxF = -1
        for line in d.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard let o = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let f = (o["f"] as? NSNumber)?.intValue else { continue }
            let m = (o["modes"] as? String) ?? ""
            for c in m { counts[c, default: 0] += 1 }
            if let st = o["state"] as? [String: Any] { state = st }
            else if let dl = o["delta"] as? [String: Any], !dl.isEmpty { state = mergePatch(state, dl) }
            rows.append((f, m, entityBoxes(state)))
            maxF = max(maxF, f)
        }
        guard maxF >= 0 else { return ([], [:], []) }
        var arr = [String](repeating: "", count: maxF + 1)
        var bx = [[EngineBox]](repeating: [], count: maxF + 1)
        var have = [Bool](repeating: false, count: maxF + 1)
        for (f, m, b) in rows { arr[f] = m; bx[f] = b; have[f] = true }
        var last = "", lastB: [EngineBox] = []
        for i in arr.indices {
            if have[i] { last = arr[i]; lastB = bx[i] } else { arr[i] = last; bx[i] = lastB }
        }
        return (arr, counts, bx)
    }

    /// RFC 7386 merge patch.
    nonisolated private static func mergePatch(_ target: [String: Any], _ patch: [String: Any]) -> [String: Any] {
        var t = target
        for (k, v) in patch {
            if v is NSNull { t.removeValue(forKey: k) }
            else if let pv = v as? [String: Any] { t[k] = mergePatch((t[k] as? [String: Any]) ?? [:], pv) }
            else { t[k] = v }
        }
        return t
    }

    nonisolated private static func entityBoxes(_ state: [String: Any]) -> [EngineBox] {
        guard let ents = state["entities"] as? [String: Any] else { return [] }
        var out: [EngineBox] = []
        for (id, raw) in ents {
            guard let e = raw as? [String: Any], let bf = e["bbox"] as? [String: Any],
                  let v = bf["v"] as? [Any], v.count == 4 else { continue }
            let b = v.compactMap { ($0 as? NSNumber)?.doubleValue }
            guard b.count == 4 else { continue }
            let vis = ((e["visible"] as? [String: Any])?["v"] as? Bool) ?? true
            let label = ((e["label"] as? [String: Any])?["v"]).map { "\($0)" } ?? ""
            let type = ((e["type"] as? [String: Any])?["v"]).map { "\($0)" } ?? ""
            var source = (bf["source"] as? String) ?? "observed"
            if !vis { source = "inferred" }
            out.append(EngineBox(id: id, label: label, type: type, bbox: b, visible: vis, source: source,
                                 conf: (bf["conf"] as? NSNumber)?.doubleValue ?? 0))
        }
        return out.sorted { $0.id < $1.id }
    }

    func boxes(atMs ms: Int) -> [EngineBox]? {
        guard !boxes.isEmpty else { return nil }
        return boxes[max(0, min(boxes.count - 1, frame(forMs: ms)))]
    }

    nonisolated private static func valueStart(_ line: Substring, _ key: String) -> Substring.Index? {
        guard let r = line.range(of: key) else { return nil }
        var i = r.upperBound
        while i < line.endIndex, line[i] == " " || line[i] == ":" { i = line.index(after: i) }
        return i
    }

    nonisolated private static func intField(_ line: Substring, _ key: String) -> Int? {
        guard var i = valueStart(line, key) else { return nil }
        var s = ""
        while i < line.endIndex, line[i].isNumber || line[i] == "-" { s.append(line[i]); i = line.index(after: i) }
        return Int(s)
    }

    nonisolated private static func stringField(_ line: Substring, _ key: String) -> String? {
        guard let i0 = valueStart(line, key), i0 < line.endIndex, line[i0] == "\"" else { return nil }
        let start = line.index(after: i0)
        guard let end = line[start...].firstIndex(of: "\"") else { return nil }
        return String(line[start..<end])
    }

    nonisolated private static func parseEvents(_ u: URL) -> [EngineEvent]? {
        guard let d = try? Data(contentsOf: u) else { return nil }
        var out: [EngineEvent] = []
        for (n, line) in String(decoding: d, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: true).enumerated() {
            guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            let fs = (o["f_start"] as? NSNumber)?.intValue ?? (o["f"] as? NSNumber)?.intValue ?? 0
            let fe = (o["f_end"] as? NSNumber)?.intValue ?? fs
            let ev = o["evidence"] as? [String: Any]
            var detail: [String] = []
            if let e = o["entity"] { detail.append("\(e)") }
            if o["from"] != nil || o["to"] != nil { detail.append("\(o["from"].map { "\($0)" } ?? "∅") → \(o["to"].map { "\($0)" } ?? "∅")") }
            out.append(EngineEvent(
                id: (o["id"] as? String) ?? "\(n)",
                type: (o["type"] as? String) ?? "event",
                fStart: fs, fEnd: fe,
                confidence: (o["confidence"] as? NSNumber)?.doubleValue ?? 0,
                detail: detail.joined(separator: " "),
                evidenceFrame: (ev?["f"] as? NSNumber)?.intValue,
                evidenceCrop: ev?["crop"] as? String))
        }
        return out.sorted { $0.fStart < $1.fStart }
    }

    // MARK: Ask

    func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !isAsking else { return }
        isAsking = true; askError = nil; answer = nil; contextTokens = nil; askEvidence = []
        let session = sessionDir.path
        AppLog.log("engine_stage", ["name": "ask_ui", "phase": "submit", "session": session, "question": "\"\(q)\""])
        EngineRunner.shared.ensureServer()
        Task { @MainActor [weak self] in
            var req = URLRequest(url: EnginePaths.serverBase.appendingPathComponent("ask"))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 180
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["session": session, "question": q])
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(domain: "ask", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code): \(String(decoding: data.prefix(300), as: UTF8.self))"])
                }
                guard let self else { return }
                self.answer = (o["answer"] as? String) ?? (o["error"] as? String).map { "Error: \($0)" } ?? "(no answer)"
                self.contextTokens = (o["context_tokens"] as? NSNumber)?.intValue
                self.askEvidence = ((o["evidence"] as? [[String: Any]]) ?? []).compactMap { e in
                    guard let f = (e["f"] as? NSNumber)?.intValue else { return nil }
                    return AskEvidence(f: f, crop: e["crop"] as? String)
                }
                self.isAsking = false
                if let first = self.askEvidence.first { self.shownCrop = self.resolve(first.crop); self.onSeekFrame?(first.f) }
                AppLog.log("engine_stage", ["name": "compile", "session": session, "context_tokens": self.contextTokens ?? -1,
                                            "evidence": self.askEvidence.count])
                AppLog.log("engine_stage", ["name": "answer", "session": session, "answer_chars": self.answer?.count ?? 0,
                                            "model": (o["model"] as? String) ?? "server-default"])
                AppLog.log("engine_stage", ["name": "ask_ui", "phase": "answer", "http": code, "session": session,
                                            "context_tokens": self.contextTokens ?? -1, "evidence": self.askEvidence.count,
                                            "answer_chars": self.answer?.count ?? 0])
            } catch {
                guard let self else { return }
                self.askError = error.localizedDescription
                self.isAsking = false
                AppLog.log("engine_stage", ["name": "ask_ui", "phase": "error", "session": session, "error": "\"\(error.localizedDescription)\""])
            }
        }
    }
}

enum RegionMode {
    static let order: [Character] = ["C", "P", "V", "R", "F"]
    static func name(_ c: Character) -> String {
        switch c {
        case "C": return "COPY"
        case "P": return "PROPAGATE"
        case "V": return "REVALIDATE"
        case "R": return "RE-INFER"
        case "F": return "FULL REFRESH"
        default: return "?"
        }
    }
    static func color(_ c: Character) -> NSColor {
        switch c {
        case "C": return NSColor.gray
        case "P": return NSColor.systemBlue
        case "V": return NSColor.systemYellow
        case "R": return NSColor.systemOrange
        case "F": return NSColor.systemRed
        default: return NSColor.clear
        }
    }
    static func fillOpacity(_ c: Character) -> Double { c == "C" ? 0.06 : 0.35 }
}
