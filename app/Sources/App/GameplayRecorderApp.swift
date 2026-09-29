import AppKit
import Carbon.HIToolbox

// Entry point + coordinator. Owned by the orchestrator (integration). Modules plug in via Shared/Contracts.swift.
// Flow: toolbar (Cmd+Shift+5 clone) → ScreenRecorder → menu-bar stop → AnnotationEngine → ReviewWindowController.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let d = AppDelegate()
        app.delegate = d
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private var statusItem: NSStatusItem!
    private var toolbar: CaptureToolbarController!
    private let recorder = ScreenRecorder()
    private let annotator = AnnotationEngine()
    private var reviews: [ReviewWindowController] = []
    private var hotKeyRef: EventHotKeyRef?
    private var recordingStart: Date?
    private var elapsedTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.log("app_launched")
        toolbar = CaptureToolbarController(onRecord: { [weak self] req in
            Task { @MainActor in await self?.startRecording(req) }
        })
        setupStatusItem()
        registerHotKey()
        // Automation hook for scripted proofs: `notifyutil`-style distributed notification stops a recording.
        DistributedNotificationCenter.default().addObserver(forName: .init("com.operantlabs.GameplayRecorder.stop"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.recorder.isRecording == true { self?.stopRecording() } }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("com.operantlabs.GameplayRecorder.show"), object: nil, queue: .main) { [weak self] n in
            MainActor.assumeIsolated {
                guard let self, !self.recorder.isRecording else { return }
                if let m = (n.object as? String).flatMap(CaptureMode.init(rawValue:)) { self.toolbar.show(mode: m) } else { self.toolbar.show() }
            }
        }
        // `grctl record "x,y,w,h"` (global AppKit points) records a region without showing the toolbar or taking focus.
        DistributedNotificationCenter.default().addObserver(forName: .init("com.operantlabs.GameplayRecorder.record"), object: nil, queue: .main) { [weak self] n in
            MainActor.assumeIsolated {
                guard let self, !self.recorder.isRecording, let screen = NSScreen.main else { return }
                let p = ((n.object as? String) ?? "").split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                let rect = p.count == 4 ? CGRect(x: p[0], y: p[1], width: p[2], height: p[3]) : nil
                let req = RecordingRequest(mode: rect == nil ? .recordEntireScreen : .recordSelectedPortion, screen: screen, rect: rect)
                AppLog.log("record_requested", ["mode": "\(req.mode)", "rect": rect.map { NSStringFromRect($0) } ?? "nil", "via": "automation"])
                Task { @MainActor in await self.startRecording(req) }
            }
        }
        // `grctl recordwin <CGWindowID>` records one window without focus or toolbar.
        DistributedNotificationCenter.default().addObserver(forName: .init("com.operantlabs.GameplayRecorder.recordwin"), object: nil, queue: .main) { [weak self] n in
            MainActor.assumeIsolated {
                guard let self, !self.recorder.isRecording, let screen = NSScreen.main,
                      let wid = (n.object as? String).flatMap({ UInt32($0) }) else { return }
                var req = RecordingRequest(mode: .recordSelectedWindow, screen: screen, rect: nil)
                req.windowID = wid
                AppLog.log("record_requested", ["mode": "recordSelectedWindow", "window_id": wid, "via": "automation"])
                Task { @MainActor in await self.startRecording(req) }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("com.operantlabs.GameplayRecorder.primary"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.toolbar.triggerPrimary() }
        }
        // `--review <video.mp4>` opens an existing recording without recording.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--review"), i + 1 < args.count {
            let v = URL(fileURLWithPath: args[i + 1])
            openReview(video: v)
        } else if let i = args.firstIndex(of: "--annotate"), i + 1 < args.count {
            annotateThenReview(URL(fileURLWithPath: args[i + 1]))
        } else {
            toolbar.show()
        }
    }

    // MARK: Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIdleIcon()
    }

    private func setIdleIcon() {
        statusItem.button?.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Gameplay Recorder")
        statusItem.button?.title = ""
        statusItem.button?.action = nil
        let menu = NSMenu()
        menu.addItem(withTitle: "New Recording…  (⌥⌘5)", action: #selector(showToolbar), keyEquivalent: "")
        menu.addItem(withTitle: "Open Recording…", action: #selector(openRecording), keyEquivalent: "")
        menu.addItem(withTitle: "Show Recordings Folder", action: #selector(showFolder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Gameplay Recorder", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    /// While recording, the status item becomes the native-style stop button (click = stop), with elapsed time.
    private func setRecordingIcon() {
        statusItem.menu = nil
        statusItem.button?.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop Recording")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.target = self
        statusItem.button?.action = #selector(stopRecording)
        recordingStart = Date()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let s = self.recordingStart else { return }
                let e = Int(Date().timeIntervalSince(s))
                self.statusItem.button?.title = String(format: " %d:%02d", e / 60, e % 60)
            }
        }
    }

    @objc private func showToolbar() {
        if recorder.isRecording { return }
        toolbar.show()
    }

    @objc private func showFolder() { NSWorkspace.shared.open(AppPaths.moviesDir) }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openRecording() {
        let p = NSOpenPanel()
        p.directoryURL = AppPaths.moviesDir
        p.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        NSApp.activate(ignoringOtherApps: true)
        guard p.runModal() == .OK, let v = p.url else { return }
        if FileManager.default.fileExists(atPath: AppPaths.annotationsURL(for: v).path) { openReview(video: v) }
        else { annotateThenReview(v) }
    }

    // MARK: Record → annotate → review

    private func startRecording(_ req: RecordingRequest) async {
        do {
            try await recorder.start(req)
            setRecordingIcon()
        } catch {
            AppLog.log("recording_error", ["error": "\(error)"])
            alert("Could not start recording", "\(error.localizedDescription)\n\nGrant Screen Recording permission in System Settings → Privacy & Security, then try again.")
        }
    }

    @objc private func stopRecording() {
        Task { @MainActor in
            elapsedTimer?.invalidate(); elapsedTimer = nil
            do {
                let url = try await recorder.stop()
                setIdleIcon()
                annotateThenReview(url)
            } catch {
                AppLog.log("recording_error", ["error": "\(error)"])
                setIdleIcon()
            }
        }
    }

    private func annotateThenReview(_ video: URL) {
        let jsonl = AppPaths.annotationsURL(for: video)
        statusItem.button?.title = " Annotating…"
        // Semantic video state engine (engine/run.py) runs alongside the 1 fps Claude annotation; logs engine_stage lines.
        EngineRunner.shared.run(video: video)
        // Open the review immediately; it polls the growing JSONL.
        Task.detached { [annotator] in
            do {
                _ = try await annotator.annotate(video: video) { frac, n in
                    Task { @MainActor [weak self] in
                        self?.statusItem.button?.title = String(format: " Annotating %d%% (%d)", Int(frac * 100), n)
                    }
                }
                // Marker file tells the review window annotation is complete.
                FileManager.default.createFile(atPath: video.deletingPathExtension().appendingPathExtension("annotations.done").path, contents: Data())
                await MainActor.run { [weak self] in self?.statusItem.button?.title = "" }
            } catch {
                AppLog.log("annotation_error", ["error": "\(error)"])
                await MainActor.run { [weak self] in self?.statusItem.button?.title = " Annotation failed" }
            }
        }
        if !FileManager.default.fileExists(atPath: jsonl.path) {
            FileManager.default.createFile(atPath: jsonl.path, contents: Data())
        }
        openReview(video: video)
    }

    private func openReview(video: URL) {
        let r = ReviewWindowController()
        reviews.append(r)
        NSApp.activate(ignoringOtherApps: true)
        r.present(video: video, annotations: AppPaths.annotationsURL(for: video))
    }

    private func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = title; a.informativeText = text; a.runModal()
    }

    // MARK: Global hotkey ⌥⌘5 (⇧⌘5 is reserved by the system screenshot tool)

    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            let me = Unmanaged<AppDelegate>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { MainActor.assumeIsolated { me.showToolbar() } }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        let id = EventHotKeyID(signature: OSType(0x47524543), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_5), UInt32(cmdKey | optionKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
