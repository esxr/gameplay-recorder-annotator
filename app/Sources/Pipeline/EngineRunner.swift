import Foundation

/// Runs the Python engine (`engine/run.py <video>`) and keeps the query server (`engine/server.py`, port 8765) alive.
/// Every `STAGE <name> k=v…` line on stdout is forwarded to AppLog as `engine_stage name=<name> k=v…`.
enum EnginePaths {
    static var repo: URL {
        let p = ProcessInfo.processInfo.environment["GR_REPO"] ?? "/Users/pranav/Desktop/gameplay_recorder_annotator"
        return URL(fileURLWithPath: p, isDirectory: true)
    }
    static var python: URL { repo.appendingPathComponent(".venv/bin/python") }
    static var runScript: URL { repo.appendingPathComponent("engine/run.py") }
    static var serverScript: URL { repo.appendingPathComponent("engine/server.py") }
    static var serverBase: URL { URL(string: "http://127.0.0.1:\(ProcessInfo.processInfo.environment["GR_ENGINE_PORT"] ?? "8765")")! }
    /// Session dir per CONTRACT: `<video>.session/` (e.g. `x.mp4.session/`).
    static func sessionDir(for video: URL) -> URL { URL(fileURLWithPath: video.path + ".session", isDirectory: true) }
}

final class EngineRunner: @unchecked Sendable {
    static let shared = EngineRunner()

    private let lock = NSLock()
    private var serverProcess: Process?
    private var serverStartAttempted = false
    private var running: [String: Process] = [:]

    /// Starts `run.py <video>` in the background (no-op if already running for this video). Also ensures the server.
    func run(video: URL, extraArgs: [String] = []) {
        ensureServer()
        let key = video.path
        lock.lock()
        if running[key] != nil { lock.unlock(); return }
        let p = Process()
        running[key] = p
        lock.unlock()

        let session = EnginePaths.sessionDir(for: video).path
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            p.executableURL = EnginePaths.python
            p.arguments = [EnginePaths.runScript.path, video.path] + extraArgs
            p.currentDirectoryURL = EnginePaths.repo
            var env = ProcessInfo.processInfo.environment
            env["PYTHONUNBUFFERED"] = "1"
            p.environment = env
            let out = Pipe(), err = Pipe()
            p.standardOutput = out
            p.standardError = err
            let stdoutBuf = LineBuffer { line in EngineRunner.handleStdout(line, session: session) }
            let stderrTail = TailBuffer(limit: 20)
            out.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { h.readabilityHandler = nil } else { stdoutBuf.feed(d) }
            }
            err.fileHandleForReading.readabilityHandler = { h in
                let d = h.availableData
                if d.isEmpty { h.readabilityHandler = nil } else { stderrTail.feed(d) }
            }
            AppLog.log("engine_started", ["video": video.path, "session": session, "python": EnginePaths.python.path])
            do {
                try p.run()
                p.waitUntilExit()
            } catch {
                AppLog.log("engine_error", ["error": "\(error)", "session": session])
            }
            out.fileHandleForReading.readabilityHandler = nil
            err.fileHandleForReading.readabilityHandler = nil
            if let rest = try? out.fileHandleForReading.readToEnd() { stdoutBuf.feed(rest) }
            stdoutBuf.flush()
            let code = p.isRunning ? -1 : Int(p.terminationStatus)
            var fields: [String: Any] = ["session": session, "exit": code]
            if code != 0 {
                if let rest = try? err.fileHandleForReading.readToEnd() { stderrTail.feed(rest) }
                fields["stderr_tail"] = stderrTail.text.replacingOccurrences(of: "\n", with: " | ")
            }
            AppLog.log("engine_finished", fields)
            self?.lock.lock(); self?.running[key] = nil; self?.lock.unlock()
            NotificationCenter.default.post(name: .engineFinished, object: session)
        }
    }

    private static func handleStdout(_ line: String, session: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("STAGE ") else { return }
        let parts = trimmed.dropFirst(6).split(separator: " ", omittingEmptySubsequences: true)
        guard let name = parts.first else { return }
        var fields: [String: Any] = ["name": String(name)]
        for kv in parts.dropFirst() {
            if let eq = kv.firstIndex(of: "=") {
                fields[String(kv[..<eq])] = String(kv[kv.index(after: eq)...])
            }
        }
        if fields["session"] == nil { fields["session"] = session }
        AppLog.log("engine_stage", fields)
    }

    // MARK: Query server

    /// Starts `engine/server.py` once per app launch if nothing answers on port 8765.
    func ensureServer() {
        lock.lock()
        if serverStartAttempted { lock.unlock(); return }
        serverStartAttempted = true
        lock.unlock()
        Task.detached { [weak self] in
            if await EngineRunner.serverAlive() {
                AppLog.log("engine_server", ["status": "already_running"])
                return
            }
            self?.startServer()
        }
    }

    static func serverAlive() async -> Bool {
        var req = URLRequest(url: EnginePaths.serverBase.appendingPathComponent("health"))
        req.timeoutInterval = 1.5
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return resp is HTTPURLResponse   // any HTTP answer (even 404) means the server is up
        } catch {
            return false
        }
    }

    private func startServer() {
        guard FileManager.default.fileExists(atPath: EnginePaths.serverScript.path) else {
            AppLog.log("engine_server", ["status": "missing", "path": EnginePaths.serverScript.path])
            lock.lock(); serverStartAttempted = false; lock.unlock()   // retry on next run
            return
        }
        let p = Process()
        p.executableURL = EnginePaths.python
        p.arguments = [EnginePaths.serverScript.path]
        p.currentDirectoryURL = EnginePaths.repo
        let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/GameplayRecorder/engine_server.log")
        if !FileManager.default.fileExists(atPath: logURL.path) { FileManager.default.createFile(atPath: logURL.path, contents: Data()) }
        if let h = try? FileHandle(forWritingTo: logURL) { h.seekToEndOfFile(); p.standardOutput = h; p.standardError = h }
        do {
            try p.run()
            lock.lock(); serverProcess = p; lock.unlock()
            AppLog.log("engine_server", ["status": "started", "pid": p.processIdentifier])
        } catch {
            AppLog.log("engine_server", ["status": "error", "error": "\(error)"])
        }
    }

    func shutdown() {
        lock.lock(); let s = serverProcess; let rs = Array(running.values); lock.unlock()
        s?.terminate()
        rs.forEach { if $0.isRunning { $0.terminate() } }
    }
}

extension Notification.Name {
    static let engineFinished = Notification.Name("GameplayRecorder.engineFinished")
}

/// Splits a byte stream into lines.
private final class LineBuffer: @unchecked Sendable {
    private var buf = Data()
    private let lock = NSLock()
    private let onLine: (String) -> Void
    init(_ onLine: @escaping (String) -> Void) { self.onLine = onLine }
    func feed(_ d: Data) {
        lock.lock()
        buf.append(d)
        var lines: [String] = []
        while let nl = buf.firstIndex(of: 0x0A) {
            lines.append(String(decoding: buf[buf.startIndex..<nl], as: UTF8.self))
            buf.removeSubrange(buf.startIndex...nl)
        }
        lock.unlock()
        lines.forEach(onLine)
    }
    func flush() {
        lock.lock(); let rest = buf; buf = Data(); lock.unlock()
        if !rest.isEmpty { onLine(String(decoding: rest, as: UTF8.self)) }
    }
}

private final class TailBuffer: @unchecked Sendable {
    private var lines: [String] = []
    private let limit: Int
    private let lock = NSLock()
    init(limit: Int) { self.limit = limit }
    func feed(_ d: Data) {
        lock.lock(); defer { lock.unlock() }
        lines += String(decoding: d, as: UTF8.self).split(separator: "\n").map(String.init)
        if lines.count > limit { lines.removeFirst(lines.count - limit) }
    }
    var text: String { lock.lock(); defer { lock.unlock() }; return lines.joined(separator: "\n") }
}
