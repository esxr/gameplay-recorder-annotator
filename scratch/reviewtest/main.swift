import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let rc = MainActor.assumeIsolated { () -> ReviewWindowController in
    let rc = ReviewWindowController()
    rc.present(video: dir.appendingPathComponent("sample.mp4"), annotations: dir.appendingPathComponent("sample.annotations.jsonl"))
    return rc
}
app.run()
_ = rc
