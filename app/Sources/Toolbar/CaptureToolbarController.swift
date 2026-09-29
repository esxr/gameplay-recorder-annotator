import AppKit

/// Borderless floating panel hosting the toolbar. Can become key so Esc works.
final class ToolbarPanel: NSPanel {
    var onEscape: (() -> Void)?
    init() {
        super.init(contentRect: NSRect(origin: .zero, size: ToolbarMetrics.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        appearance = NSAppearance(named: .darkAqua)
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

/// Clone of the macOS Screenshot toolbar (Cmd+Shift+5).
@MainActor final class CaptureToolbarController: NSObject {
    private let onRecord: (RecordingRequest) -> Void
    private let panel = ToolbarPanel()
    private var modeButtons: [ModeButton] = []
    private let primary = PrimaryButton()
    private let optionsButton = NSButton()
    private var overlays: [OverlayWindow] = []
    private var keyMonitor: Any?

    private let defaults = UserDefaults.standard
    private var mode: CaptureMode {
        didSet { defaults.set(mode.rawValue, forKey: "toolbar.mode"); refresh() }
    }
    private enum SaveTo: String, CaseIterable { case Desktop, Documents, Movies }
    private var saveTo: SaveTo { didSet { defaults.set(saveTo.rawValue, forKey: "toolbar.saveTo") } }
    private var timerSeconds: Int { didSet { defaults.set(timerSeconds, forKey: "toolbar.timer") } }
    private var showMouseClicks: Bool { didSet { defaults.set(showMouseClicks, forKey: "toolbar.clicks") } }
    private var microphone: Bool { didSet { defaults.set(microphone, forKey: "toolbar.mic") } }
    /// Last portion selection, global AppKit coords.
    private var lastRect: CGRect? {
        didSet { if let r = lastRect { defaults.set(NSStringFromRect(r), forKey: "toolbar.rect") } }
    }

    init(onRecord: @escaping (RecordingRequest) -> Void) {
        self.onRecord = onRecord
        mode = CaptureMode(rawValue: defaults.string(forKey: "toolbar.mode") ?? "") ?? .recordEntireScreen
        saveTo = SaveTo(rawValue: defaults.string(forKey: "toolbar.saveTo") ?? "") ?? .Desktop
        timerSeconds = defaults.integer(forKey: "toolbar.timer")
        showMouseClicks = defaults.object(forKey: "toolbar.clicks") as? Bool ?? true
        microphone = defaults.bool(forKey: "toolbar.mic")
        if let s = defaults.string(forKey: "toolbar.rect") { let r = NSRectFromString(s); lastRect = r.isEmpty ? nil : r }
        super.init()
        panel.onEscape = { [weak self] in self?.cancel() }
        buildUI()
        refresh()
    }

    // MARK: Public API

    func show() {
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        installKeyMonitor()
        showOverlayForMode()
        panel.orderFrontRegardless()
        AppLog.log("toolbar_shown", ["mode": mode.rawValue, "frame": NSStringFromRect(panel.frame).replacingOccurrences(of: " ", with: "")])
    }

    func hide() {
        removeOverlays()
        panel.orderOut(nil)
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    // MARK: UI

    private func buildUI() {
        let bg = ToolbarBackgroundView(frame: NSRect(origin: .zero, size: ToolbarMetrics.size))
        bg.autoresizingMask = [.width, .height]
        panel.contentView = bg
        let midY = ToolbarMetrics.size.height / 2

        let close = NSButton(frame: NSRect(x: ToolbarMetrics.closeCenterX - 11, y: midY - 11, width: 22, height: 22))
        close.isBordered = false
        close.bezelStyle = .regularSquare
        close.imagePosition = .imageOnly
        let closeCfg = NSImage.SymbolConfiguration(pointSize: 17, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(white: 0.13, alpha: 1), NSColor(white: 0.62, alpha: 1)]))
        close.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")?.withSymbolConfiguration(closeCfg)
        close.target = self
        close.action = #selector(closeClicked)
        close.setAccessibilityLabel("Close")
        bg.addSubview(close)

        let modes: [(CaptureMode, CGFloat)] = [
            (.captureEntireScreen, ToolbarMetrics.captureCentersX[0]),
            (.captureSelectedWindow, ToolbarMetrics.captureCentersX[1]),
            (.captureSelectedPortion, ToolbarMetrics.captureCentersX[2]),
            (.recordEntireScreen, ToolbarMetrics.recordCentersX[0]),
            (.recordSelectedPortion, ToolbarMetrics.recordCentersX[1]),
        ]
        let bs = ToolbarMetrics.modeButtonSize
        for (m, cx) in modes {
            let b = ModeButton(mode: m)
            b.frame = NSRect(x: cx - bs.width / 2, y: midY - bs.height / 2, width: bs.width, height: bs.height)
            b.target = self
            b.action = #selector(modeClicked(_:))
            modeButtons.append(b)
            bg.addSubview(b)
        }
        for x in [ToolbarMetrics.divider1X, ToolbarMetrics.divider2X] {
            let d = DividerView(frame: NSRect(x: x, y: midY - 12, width: 1, height: 24))
            bg.addSubview(d)
        }

        optionsButton.frame = NSRect(x: ToolbarMetrics.optionsCenterX - 36, y: midY - 12, width: 72, height: 24)
        optionsButton.isBordered = false
        optionsButton.bezelStyle = .regularSquare
        optionsButton.attributedTitle = NSAttributedString(string: "Options", attributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor(white: 1, alpha: 0.66)])
        optionsButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold))
        optionsButton.imagePosition = .imageTrailing
        optionsButton.contentTintColor = NSColor(white: 1, alpha: 0.66)
        optionsButton.target = self
        optionsButton.action = #selector(optionsClicked(_:))
        bg.addSubview(optionsButton)

        primary.target = self
        primary.action = #selector(primaryClicked)
        bg.addSubview(primary)
    }

    private func refresh() {
        for b in modeButtons { b.isSelectedMode = (b.mode == mode) }
        primary.title = mode.isRecording ? "Record" : "Capture"
    }

    private func positionPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        var origin = NSPoint(x: screen.frame.midX - ToolbarMetrics.size.width / 2, y: screen.frame.minY + ToolbarMetrics.bottomOffset)
        // Match wherever the native toolbar was last placed (it remembers a user-dragged origin).
        if let s = UserDefaults(suiteName: "com.apple.screencaptureui")?.string(forKey: "toolbarOrigin") {
            let p = NSPointFromString(s)
            let f = NSRect(origin: p, size: ToolbarMetrics.size)
            if NSScreen.screens.contains(where: { $0.frame.contains(f) }) { origin = p }
        }
        panel.setFrameOrigin(origin)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            if e.keyCode == 53 { self.cancel(); return nil }
            if e.keyCode == 36 || e.keyCode == 76 { self.primaryClicked(); return nil }   // Return triggers, like native
            return e
        }
    }

    // MARK: Overlays

    private var toolbarScreen: NSScreen {
        NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func removeOverlays() {
        overlays.forEach { $0.orderOut(nil) }
        overlays.removeAll()
    }

    private func showOverlayForMode() {
        removeOverlays()
        switch mode {
        case .captureSelectedPortion, .recordSelectedPortion:
            let screen = lastRect.flatMap { r in NSScreen.screens.first(where: { $0.frame.intersects(r) }) } ?? toolbarScreen
            let w = OverlayWindow(screen: screen)
            let f = screen.frame
            var sel = lastRect?.intersection(f) ?? .null
            if sel.isNull || sel.width < 20 || sel.height < 20 {
                sel = NSRect(x: f.midX - f.width * 0.25, y: f.midY - f.height * 0.25, width: f.width * 0.5, height: f.height * 0.5)
            }
            let local = sel.offsetBy(dx: -f.minX, dy: -f.minY)
            let v = SelectionOverlayView(frame: NSRect(origin: .zero, size: f.size), selection: local)
            v.onChange = { [weak self] r in self?.lastRect = r.offsetBy(dx: f.minX, dy: f.minY) }
            lastRect = sel
            w.contentView = v
            overlays.append(w)
        case .captureEntireScreen, .recordEntireScreen, .captureSelectedWindow:
            for screen in NSScreen.screens {
                let w = OverlayWindow(screen: screen)
                let v = ClickCatcherView(frame: NSRect(origin: .zero, size: screen.frame.size))
                v.screenHint = mode != .captureSelectedWindow
                if mode == .captureSelectedWindow {
                    v.highlightProvider = { p in ScreenshotSaver.windowFrame(at: p) }
                    v.onClick = { [weak self] p in self?.perform(clickPoint: p) }
                } else {
                    v.onClick = { [weak self] p in
                        guard let self else { return }
                        let s = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? screen
                        self.perform(screen: s)
                    }
                }
                w.contentView = v
                overlays.append(w)
            }
        }
        overlays.forEach { $0.orderFrontRegardless() }
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    // MARK: Actions

    @objc private func closeClicked() { cancel() }

    private func cancel() {
        AppLog.log("toolbar_closed")
        hide()
    }

    @objc private func modeClicked(_ sender: ModeButton) {
        mode = sender.mode
        showOverlayForMode()
    }

    @objc private func primaryClicked() {
        switch mode {
        case .captureSelectedWindow:
            // Native: Capture in window mode captures the window under the pointer when clicked; the button
            // falls back to the frontmost window at the screen center.
            let f = toolbarScreen.frame
            perform(clickPoint: NSPoint(x: f.midX, y: f.midY))
        case .captureSelectedPortion, .recordSelectedPortion:
            perform(screen: lastRect.flatMap { r in NSScreen.screens.first(where: { $0.frame.intersects(r) }) } ?? toolbarScreen)
        default:
            perform(screen: toolbarScreen)
        }
    }

    private var saveFolder: URL {
        let fm = FileManager.default
        switch saveTo {
        case .Desktop: return fm.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        case .Documents: return fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        case .Movies: return fm.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        }
    }

    private func perform(screen: NSScreen) {
        let rect: CGRect? = (mode == .captureSelectedPortion || mode == .recordSelectedPortion) ? lastRect?.intersection(screen.frame) : nil
        let m = mode, delay = timerSeconds, folder = saveFolder
        hide()
        Task { @MainActor in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000) }
            if m.isRecording {
                let req = RecordingRequest(mode: m, screen: screen, rect: rect, captureMicrophone: self.microphone, showMouseClicks: self.showMouseClicks)
                AppLog.log("record_requested", ["mode": m.rawValue, "rect": rect.map { NSStringFromRect($0).replacingOccurrences(of: " ", with: "") } ?? "nil",
                                                "screen": ScreenshotSaver.displayID(of: screen)])
                self.onRecord(req)
            } else {
                try? await Task.sleep(nanoseconds: 150_000_000)   // let our windows leave the screen
                do {
                    let url = try await ScreenshotSaver.captureScreen(screen, rect: rect, to: folder)
                    AppLog.log("screenshot_saved", ["mode": m.rawValue, "path": url.path.replacingOccurrences(of: " ", with: "\\ ")])
                } catch {
                    AppLog.log("screenshot_failed", ["error": error.localizedDescription])
                }
            }
        }
    }

    private func perform(clickPoint p: NSPoint) {
        let folder = saveFolder, delay = timerSeconds
        hide()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000 + 150_000_000)
            do {
                if let url = try await ScreenshotSaver.captureWindow(at: p, to: folder) {
                    AppLog.log("screenshot_saved", ["mode": CaptureMode.captureSelectedWindow.rawValue, "path": url.path.replacingOccurrences(of: " ", with: "\\ ")])
                } else {
                    AppLog.log("screenshot_failed", ["error": "no_window_at_point"])
                }
            } catch {
                AppLog.log("screenshot_failed", ["error": error.localizedDescription])
            }
        }
    }

    // MARK: Options menu

    @objc private func optionsClicked(_ sender: NSButton) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        func header(_ t: String) {
            if #available(macOS 14.0, *) { menu.addItem(.sectionHeader(title: t)) }
            else { let i = NSMenuItem(title: t, action: nil, keyEquivalent: ""); i.isEnabled = false; menu.addItem(i) }
        }
        func item(_ t: String, _ on: Bool, _ tag: Int, _ rep: Any? = nil) {
            let i = NSMenuItem(title: t, action: #selector(optionPicked(_:)), keyEquivalent: "")
            i.target = self; i.state = on ? .on : .off; i.tag = tag; i.representedObject = rep
            menu.addItem(i)
        }
        header("Save to")
        for s in SaveTo.allCases { item(s.rawValue, saveTo == s, 1, s.rawValue) }
        menu.addItem(.separator())
        header("Timer")
        item("None", timerSeconds == 0, 2, 0)
        item("5 Seconds", timerSeconds == 5, 2, 5)
        item("10 Seconds", timerSeconds == 10, 2, 10)
        menu.addItem(.separator())
        header("Microphone")
        item("None", !microphone, 4, false)
        item("Built-in Microphone", microphone, 4, true)
        menu.addItem(.separator())
        header("Options")
        item("Show Mouse Clicks", showMouseClicks, 3)
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func optionPicked(_ item: NSMenuItem) {
        switch item.tag {
        case 1: if let s = item.representedObject as? String, let v = SaveTo(rawValue: s) { saveTo = v }
        case 2: timerSeconds = item.representedObject as? Int ?? 0
        case 3: showMouseClicks.toggle()
        case 4: microphone = item.representedObject as? Bool ?? false
        default: break
        }
        AppLog.log("toolbar_option", ["saveTo": saveTo.rawValue, "timer": timerSeconds, "clicks": showMouseClicks, "mic": microphone])
    }
}
