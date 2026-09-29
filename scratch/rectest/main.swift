import AppKit
import Foundation

@main
struct RecTest {
    static func main() async {
        _ = NSApplication.shared
        let secs = Double(CommandLine.arguments.dropFirst().first ?? "6") ?? 6
        await run(secs)
        exit(0)
    }
    @MainActor static func run(_ secs: Double) async {
        let rec = ScreenRecorder()
        let screen = NSScreen.main!
        do {
            try await rec.start(RecordingRequest(mode: .recordEntireScreen, screen: screen, rect: nil))
            try await Task.sleep(nanoseconds: UInt64(secs * 1e9))
            let a = try await rec.stop()
            print("FULL", a.path)
            let f = screen.frame
            let r = CGRect(x: f.midX - 400, y: f.midY - 300, width: 800, height: 600)
            try await rec.start(RecordingRequest(mode: .recordSelectedPortion, screen: screen, rect: r))
            try await Task.sleep(nanoseconds: UInt64(secs * 1e9))
            let b = try await rec.stop()
            print("PORTION", b.path)
        } catch { print("ERROR", error) }
    }
}
