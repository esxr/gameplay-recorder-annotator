import AppKit
import ScreenCaptureKit

/// Still captures via ScreenCaptureKit's SCScreenshotManager, saved as PNG.
enum ScreenshotSaver {
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }

    /// Global AppKit rect (bottom-left origin) -> CG global rect (top-left origin of primary display).
    static func cgRect(fromAppKit r: CGRect) -> CGRect {
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }

    static func fileName(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        return "Screenshot \(f.string(from: date)).png"
    }

    /// Captures `screen` (optionally cropped to `rect`, global AppKit coords) and writes a PNG into `folder`.
    static func captureScreen(_ screen: NSScreen, rect: CGRect?, to folder: URL) async throws -> URL {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let id = displayID(of: screen)
        guard let display = content.displays.first(where: { $0.displayID == id }) ?? content.displays.first else {
            throw NSError(domain: "Toolbar", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display"])
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        cfg.showsCursor = false
        if let r = rect {
            // display-local, top-left origin, points
            let local = CGRect(x: r.minX - screen.frame.minX, y: screen.frame.maxY - r.maxY, width: r.width, height: r.height)
            cfg.sourceRect = local
            cfg.width = Int(local.width * scale)
            cfg.height = Int(local.height * scale)
        } else {
            cfg.width = Int(screen.frame.width * scale)
            cfg.height = Int(screen.frame.height * scale)
        }
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
        return try write(image, to: folder)
    }

    /// Captures the topmost normal window under `point` (global AppKit coords), ignoring our own windows.
    static func captureWindow(at point: NSPoint, to folder: URL) async throws -> URL? {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let win = topWindow(at: point, in: content.windows) else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: win)
        let cfg = SCStreamConfiguration()
        let scale = NSScreen.screens.first(where: { $0.frame.contains(point) })?.backingScaleFactor ?? 2
        cfg.width = Int(win.frame.width * scale)
        cfg.height = Int(win.frame.height * scale)
        cfg.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
        return try write(image, to: folder)
    }

    /// Frame (global AppKit coords) of the window under the point, using CGWindowList (fast, synchronous; for hover highlight).
    static func windowFrame(at point: NSPoint) -> NSRect? {
        let cgPoint = cgRect(fromAppKit: CGRect(origin: point, size: .zero)).origin
        let me = ProcessInfo.processInfo.processIdentifier
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? Int32) != me,
                  let b = info[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b), r.contains(cgPoint) else { continue }
            let h = NSScreen.screens.first?.frame.height ?? 0
            return NSRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
        }
        return nil
    }

    private static func topWindow(at point: NSPoint, in windows: [SCWindow]) -> SCWindow? {
        let cgPoint = cgRect(fromAppKit: CGRect(origin: point, size: .zero)).origin
        let me = ProcessInfo.processInfo.processIdentifier
        // SCShareableContent windows are front-to-back ordered
        return windows.first { w in
            w.windowLayer == 0 && w.isOnScreen && w.frame.contains(cgPoint) && w.owningApplication?.processID != me && w.frame.width > 1
        }
    }

    private static func write(_ image: CGImage, to folder: URL) throws -> URL {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "Toolbar", code: 2, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
        }
        let url = folder.appendingPathComponent(fileName())
        try data.write(to: url)
        return url
    }
}
