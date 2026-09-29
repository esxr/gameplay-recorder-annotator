import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit

enum ScreenRecorderError: LocalizedError {
    case alreadyRecording
    case notRecording
    case displayNotFound
    case writerSetupFailed(String)
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording: return "A recording is already in progress."
        case .notRecording: return "No recording is in progress."
        case .displayNotFound: return "Could not find the display to record (check Screen Recording permission)."
        case .writerSetupFailed(let s): return "Could not set up the video writer: \(s)"
        case .writerFailed(let s): return "Video writer failed: \(s)"
        }
    }
}

/// ScreenCaptureKit SCStream -> AVAssetWriter, H.264, constant 60 fps.
///
/// SCStream only delivers new frames when screen content changes, so frames are re-timed:
/// the latest complete pixel buffer is appended on a strict 60 Hz grid (pts = n/60, session starts at 0).
/// This yields ffprobe r_frame_rate = 60/1 and avg_frame_rate = 60/1.
@MainActor
final class ScreenRecorder: ScreenRecording {
    private(set) var isRecording = false
    private var stream: SCStream?
    private var sink: CaptureSink?
    private var outputURL: URL?

    init() {}

    func start(_ request: RecordingRequest) async throws {
        guard !isRecording else { throw ScreenRecorderError.alreadyRecording }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let screenNumber = (request.screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        guard let display = content.displays.first(where: { $0.displayID == screenNumber }) ?? content.displays.first else {
            throw ScreenRecorderError.displayNotFound
        }

        // Exclude this app's own windows (toolbar, selection overlay, menu bar item windows).
        let pid = ProcessInfo.processInfo.processIdentifier
        let ownApps = content.applications.filter { $0.processID == pid }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

        let scale = request.screen.backingScaleFactor
        let config = SCStreamConfiguration()
        var pixelW: Int
        var pixelH: Int
        if let rect = request.rect, request.mode == .recordSelectedPortion || rect.width > 0 {
            // Global AppKit coords (bottom-left origin) -> display-local top-left points.
            let sf = request.screen.frame
            var local = CGRect(x: rect.minX - sf.minX,
                               y: sf.maxY - rect.maxY,
                               width: rect.width,
                               height: rect.height)
            local = local.intersection(CGRect(x: 0, y: 0, width: sf.width, height: sf.height))
            if !local.isNull {
                local = CGRect(x: local.minX.rounded(), y: local.minY.rounded(),
                               width: local.width.rounded(), height: local.height.rounded())
            }
            if local.isNull || local.width < 2 || local.height < 2 {
                local = CGRect(x: 0, y: 0, width: sf.width, height: sf.height)
            }
            config.sourceRect = local
            pixelW = Int((local.width * scale).rounded())
            pixelH = Int((local.height * scale).rounded())
        } else {
            pixelW = Int((CGFloat(display.width) * scale).rounded())
            pixelH = Int((CGFloat(display.height) * scale).rounded())
        }
        // H.264 hardware encoder limit: keep within 4096 px on the long side.
        let maxSide = 4096
        if max(pixelW, pixelH) > maxSide {
            let f = Double(maxSide) / Double(max(pixelW, pixelH))
            pixelW = Int(Double(pixelW) * f)
            pixelH = Int(Double(pixelH) * f)
        }
        pixelW = max(2, pixelW & ~1)
        pixelH = max(2, pixelH & ~1)

        config.width = pixelW
        config.height = pixelH
        config.scalesToFit = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 6
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.capturesAudio = false

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let url = AppPaths.moviesDir.appendingPathComponent("Recording \(df.string(from: Date())).mp4")
        try? FileManager.default.removeItem(at: url)

        let sink = try CaptureSink(url: url, width: pixelW, height: pixelH)
        let stream = SCStream(filter: filter, configuration: config, delegate: sink)
        try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: sink.captureQueue)
        try await stream.startCapture()
        sink.startTimer()

        self.stream = stream
        self.sink = sink
        self.outputURL = url
        self.isRecording = true
        AppLog.log("recording_started", ["path": url.path, "width": pixelW, "height": pixelH, "fps": 60,
                                         "mode": request.mode.rawValue])
    }

    func stop() async throws -> URL {
        guard isRecording, let stream, let sink, let url = outputURL else { throw ScreenRecorderError.notRecording }
        isRecording = false
        self.stream = nil
        self.sink = nil
        self.outputURL = nil
        try? await stream.stopCapture()
        let frames = try await sink.finish()
        let duration = Double(frames) / 60.0
        AppLog.log("recording_stopped", ["path": url.path, "duration_s": String(format: "%.2f", duration), "frames": frames])
        return url
    }
}

/// Receives SCStream samples on `captureQueue`, writes on a 60 Hz grid on `writeQueue`.
private final class CaptureSink: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let captureQueue = DispatchQueue(label: "recorder.capture", qos: .userInteractive)
    private let writeQueue = DispatchQueue(label: "recorder.write", qos: .userInteractive)

    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor

    private let lock = NSLock()
    private var latest: CVPixelBuffer?          // guarded by lock
    private var startHostTime: CFTimeInterval?  // write queue only
    private var framesWritten: Int64 = 0        // write queue only
    private var timer: DispatchSourceTimer?
    private var finished = false

    init(url: URL, width: Int, height: Int) throws {
        do { writer = try AVAssetWriter(outputURL: url, fileType: .mp4) }
        catch { throw ScreenRecorderError.writerSetupFailed(error.localizedDescription) }
        let bitrate = max(8_000_000, min(60_000_000, width * height * 60 / 8))
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoMaxKeyFrameIntervalKey: 120,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
            ] as [String: Any],
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        input.mediaTimeScale = 600
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw ScreenRecorderError.writerSetupFailed("cannot add video input") }
        writer.add(input)
        writer.movieTimeScale = 600
        super.init()
        guard writer.startWriting() else {
            throw ScreenRecorderError.writerSetupFailed(writer.error?.localizedDescription ?? "startWriting failed")
        }
        writer.startSession(atSourceTime: .zero)
    }

    func startTimer() {
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: writeQueue)
        t.schedule(deadline: .now(), repeating: .nanoseconds(1_000_000_000 / 120), leeway: .microseconds(500))
        t.setEventHandler { [weak self] in self?.tick(final: false) }
        timer = t
        t.resume()
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw), status == .complete,
              let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock(); latest = pb; lock.unlock()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        AppLog.log("recording_stream_error", ["error": error.localizedDescription])
    }

    // MARK: 60 Hz grid writer (write queue)

    /// Timer fires at 120 Hz; appends frames so that framesWritten tracks elapsed*60 since the first frame.
    private func tick(final: Bool) {
        guard !finished else { return }
        lock.lock(); let pb = latest; lock.unlock()
        guard let pb else { return }
        let now = CACurrentMediaTime()
        if startHostTime == nil { startHostTime = now }
        let target = Int64(((now - startHostTime!) * 60.0).rounded(.down)) + 1
        var budget = 8 // avoid long catch-up bursts
        while framesWritten < target && budget > 0 {
            guard input.isReadyForMoreMediaData else { break }
            let pts = CMTime(value: framesWritten, timescale: 60)
            if !adaptor.append(pb, withPresentationTime: pts) {
                AppLog.log("recording_append_failed", ["error": writer.error?.localizedDescription ?? "unknown"])
                return
            }
            framesWritten += 1
            budget -= 1
        }
    }

    func finish() async throws -> Int64 {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int64, Error>) in
            writeQueue.async {
                self.timer?.cancel()
                self.timer = nil
                // Flush any remaining grid frames up to now.
                self.tick(final: true)
                self.finished = true
                let frames = self.framesWritten
                if frames == 0 {
                    // No frame ever arrived; still produce a valid (empty) file.
                    self.writer.cancelWriting()
                    cont.resume(throwing: ScreenRecorderError.writerFailed("no frames captured"))
                    return
                }
                self.input.markAsFinished()
                self.writer.endSession(atSourceTime: CMTime(value: frames, timescale: 60))
                self.writer.finishWriting {
                    if self.writer.status == .completed { cont.resume(returning: frames) }
                    else { cont.resume(throwing: ScreenRecorderError.writerFailed(self.writer.error?.localizedDescription ?? "status \(self.writer.status.rawValue)")) }
                }
            }
        }
    }
}
