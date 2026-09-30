import AppKit
import SwiftUI

/// Opens a titled review window: AVPlayerView + annotation sidebar + marker timeline.
/// Each `present` call opens its own window; windows are retained until closed.
@MainActor
final class ReviewWindowController: NSObject, ReviewPresenting, NSWindowDelegate {
    private final class Entry {
        let window: NSWindow
        let model: ReviewModel
        var keyMonitor: Any?
        init(window: NSWindow, model: ReviewModel) { self.window = window; self.model = model }
    }
    private var entries: [ObjectIdentifier: Entry] = [:]

    /// Most recently opened window (useful for screenshots / tests).
    private(set) var lastWindow: NSWindow?

    func present(video: URL, annotations: URL) {
        AppLog.log("review_opened", ["video": video.path, "annotations": annotations.path])
        let model = ReviewModel(video: video, annotations: annotations)
        let host = NSHostingController(rootView: ReviewRootView(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.contentViewController = host
        window.setContentSize(NSSize(width: 1280, height: 800))
        window.contentMinSize = NSSize(width: 900, height: 560)
        window.title = video.lastPathComponent
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let entry = Entry(window: window, model: model)
        entry.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak window, weak model] ev in
            guard let window, let model, ev.window === window else { return ev }
            // Don't hijack arrows while typing in a text field.
            if window.firstResponder is NSText { return ev }
            switch ev.keyCode {
            case 123: model.step(-1); return nil   // ←
            case 124: model.step(1); return nil    // →
            case 49: model.togglePlay(); return nil // space
            default: return ev
            }
        }
        entries[ObjectIdentifier(window)] = entry
        lastWindow = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// Automation hook (`grctl play`): restart playback from 0 in every open review window, without taking focus.
    func playFromStart() {
        for e in entries.values { e.model.seek(toMs: 0); e.model.player.play() }
        AppLog.log("review_play", ["windows": entries.count])
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow, let e = entries.removeValue(forKey: ObjectIdentifier(w)) else { return }
        if let m = e.keyMonitor { NSEvent.removeMonitor(m) }
        e.model.stop()
        AppLog.log("review_closed", ["video": e.model.videoURL.path])
    }
}
