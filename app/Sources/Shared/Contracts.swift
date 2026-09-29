import AppKit
import Foundation

// Shared interfaces between Toolbar, Recording, Annotation and Review modules.
// Owned by the orchestrator. Do not change signatures without updating every module.

enum CaptureMode: String, CaseIterable {
    case captureEntireScreen, captureSelectedWindow, captureSelectedPortion
    case recordEntireScreen, recordSelectedPortion

    var isRecording: Bool { self == .recordEntireScreen || self == .recordSelectedPortion }
}

/// What the user asked to record. `rect` is in global AppKit screen coordinates (points), nil = whole display.
struct RecordingRequest {
    var mode: CaptureMode
    var screen: NSScreen
    var rect: CGRect?
    var captureMicrophone: Bool = false
    var showMouseClicks: Bool = true
}

/// One annotation line in `<video>.annotations.jsonl`. Fields follow knowledge/wiki/concepts/semantic-annotation-taxonomy.md.
struct AnnotationEntity: Codable, Hashable {
    var id: String
    var type: String
    var label: String
    var bbox: [Double]?        // normalized [x, y, w, h] in 0...1
    var confidence: Double
}

struct AnnotationEvent: Codable, Hashable {
    var type: String
    var description: String
    var confidence: Double
}

struct AnnotationRecord: Codable, Hashable, Identifiable {
    var id: Int { frame }
    var t_ms: Int
    var frame: Int               // frame index at 60 fps
    var scene: String
    var entities: [AnnotationEntity]
    var hud: [String: String]
    var text: [String]
    var events: [AnnotationEvent]
    var confidence: Double
    var evidence_frame: String   // path to the extracted JPEG
    var model: String
    var trigger: String          // "sample_1fps" or "scene_change"
}

enum AppPaths {
    static var moviesDir: URL {
        let u = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies/GameplayRecorder", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static func annotationsURL(for video: URL) -> URL {
        video.deletingPathExtension().appendingPathExtension("annotations.jsonl")
    }
    static func framesDir(for video: URL) -> URL {
        let u = video.deletingPathExtension().appendingPathExtension("frames")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
}

/// Append-only app log at ~/Library/Logs/GameplayRecorder/app.log. Format: ISO8601 timestamp, space, event, space, key=value...
enum AppLog {
    static let url: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/GameplayRecorder", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("app.log")
    }()
    private static let queue = DispatchQueue(label: "applog")
    static func log(_ event: String, _ fields: [String: Any] = [:]) {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let kv = fields.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let line = "\(f.string(from: Date())) \(event) \(kv)\n"
        queue.async {
            if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
            else { try? line.data(using: .utf8)!.write(to: url) }
        }
        print(line, terminator: "")
    }
}

// MARK: - Module interfaces (implemented by each module)

/// Recording module (Recording/ScreenRecorder.swift) implements this.
@MainActor protocol ScreenRecording: AnyObject {
    var isRecording: Bool { get }
    /// Starts SCStream -> AVAssetWriter H.264 60 fps. Logs `recording_started path=...`.
    func start(_ request: RecordingRequest) async throws
    /// Stops and finalizes the file. Logs `recording_stopped path=... duration_s=...`. Returns the .mp4 URL.
    func stop() async throws -> URL
}

/// Annotation module (Annotation/AnnotationEngine.swift) implements this.
protocol VideoAnnotating: AnyObject {
    /// Logs `annotation_started`, extracts frames (1 fps + scene changes), calls Claude vision, appends JSONL
    /// lines as they complete, logs `annotation_finished records=N`. progress: 0...1 on any thread.
    func annotate(video: URL, progress: @escaping @Sendable (Double, Int) -> Void) async throws -> URL
}

/// Review module (Review/ReviewWindowController.swift) implements this.
@MainActor protocol ReviewPresenting: AnyObject {
    /// Opens the review window for a video + its JSONL (JSONL may still be growing; reload on a 1 s timer).
    func present(video: URL, annotations: URL)
}
