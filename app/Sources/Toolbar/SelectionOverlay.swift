import AppKit

/// Full-screen borderless overlay window placed below the toolbar.
final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Dimmed overlay with a draggable / resizable dashed selection rectangle and a size label (Selected Portion modes).
final class SelectionOverlayView: NSView {
    /// Selection in this view's coordinates.
    var selection: NSRect { didSet { needsDisplay = true; onChange?(selection) } }
    var onChange: ((NSRect) -> Void)?

    private enum Drag { case none, move(NSPoint, NSRect), resize(Int, NSRect, NSPoint), create(NSPoint) }
    private var drag: Drag = .none
    private let handle: CGFloat = 7

    init(frame: NSRect, selection: NSRect) {
        self.selection = selection
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // handle order: 0 BL, 1 B, 2 BR, 3 R, 4 TR, 5 T, 6 TL, 7 L
    private func handlePoints(_ r: NSRect) -> [NSPoint] {
        [NSPoint(x: r.minX, y: r.minY), NSPoint(x: r.midX, y: r.minY), NSPoint(x: r.maxX, y: r.minY),
         NSPoint(x: r.maxX, y: r.midY), NSPoint(x: r.maxX, y: r.maxY), NSPoint(x: r.midX, y: r.maxY),
         NSPoint(x: r.minX, y: r.maxY), NSPoint(x: r.minX, y: r.midY)]
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        dim.append(NSBezierPath(rect: selection))
        dim.windingRule = .evenOdd
        NSColor(white: 0, alpha: 0.35).setFill()
        dim.fill()

        let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        NSColor(white: 0, alpha: 0.6).setStroke(); border.stroke()
        border.setLineDash([4, 4], count: 2, phase: 0)
        NSColor.white.setStroke(); border.stroke()

        for p in handlePoints(selection) {
            let r = NSRect(x: p.x - handle / 2 - 1, y: p.y - handle / 2 - 1, width: handle + 2, height: handle + 2)
            let c = NSBezierPath(ovalIn: r)
            NSColor.white.setFill(); c.fill()
            NSColor(white: 0, alpha: 0.35).setStroke(); c.lineWidth = 0.5; c.stroke()
        }

        // size label: native shows "W × H" in a dark rounded pill below the rect
        let scale = window?.backingScaleFactor ?? 2
        let text = "\(Int(selection.width * scale)) × \(Int(selection.height * scale))"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white]
        let s = NSAttributedString(string: text, attributes: attrs)
        let sz = s.size()
        var pill = NSRect(x: selection.midX - sz.width / 2 - 8, y: selection.minY - sz.height - 16, width: sz.width + 16, height: sz.height + 6)
        if pill.minY < bounds.minY + 4 { pill.origin.y = selection.minY + 8 }
        NSColor(white: 0.1, alpha: 0.8).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 6, yRadius: 6).fill()
        s.draw(at: NSPoint(x: pill.minX + 8, y: pill.minY + 3))
    }

    override func resetCursorRects() {
        addCursorRect(selection, cursor: .openHand)
        for p in handlePoints(selection) {
            addCursorRect(NSRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16), cursor: .crosshair)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        for (i, h) in handlePoints(selection).enumerated() where abs(h.x - p.x) <= 10 && abs(h.y - p.y) <= 10 {
            drag = .resize(i, selection, p); return
        }
        if selection.contains(p) { drag = .move(p, selection); NSCursor.closedHand.set() }
        else { drag = .create(p); selection = NSRect(origin: p, size: .zero) }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        switch drag {
        case .none: break
        case .create(let start):
            selection = NSRect(x: min(start.x, p.x), y: min(start.y, p.y), width: abs(p.x - start.x), height: abs(p.y - start.y))
        case .move(let start, let orig):
            var r = orig.offsetBy(dx: p.x - start.x, dy: p.y - start.y)
            r.origin.x = max(bounds.minX, min(r.origin.x, bounds.maxX - r.width))
            r.origin.y = max(bounds.minY, min(r.origin.y, bounds.maxY - r.height))
            selection = r
        case .resize(let i, let orig, let start):
            let dx = p.x - start.x, dy = p.y - start.y
            var minX = orig.minX, maxX = orig.maxX, minY = orig.minY, maxY = orig.maxY
            if [0, 6, 7].contains(i) { minX += dx }
            if [2, 3, 4].contains(i) { maxX += dx }
            if [0, 1, 2].contains(i) { minY += dy }
            if [4, 5, 6].contains(i) { maxY += dy }
            selection = NSRect(x: min(minX, maxX), y: min(minY, maxY), width: abs(maxX - minX), height: abs(maxY - minY))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if case .create = drag, selection.width < 4 || selection.height < 4 {
            // a click without drag: keep a sensible default size around the point
            selection = NSRect(x: selection.minX - 200, y: selection.minY - 125, width: 400, height: 250).intersection(bounds)
        }
        drag = .none
        window?.invalidateCursorRects(for: self)
    }
}

/// Transparent click-catcher for Entire Screen / Selected Window modes. Window mode highlights the window under the mouse.
final class ClickCatcherView: NSView {
    var onClick: ((NSPoint) -> Void)?          // global AppKit coords
    var highlightProvider: ((NSPoint) -> NSRect?)?  // global point -> global window frame
    var screenHint = false
    private var highlight: NSRect?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: screenHint ? .arrow : NSCursor.pointingHand) }

    override func mouseMoved(with event: NSEvent) {
        guard let w = window, let provider = highlightProvider else { return }
        let g = w.convertPoint(toScreen: event.locationInWindow)
        let new = provider(g).map { w.convertFromScreen($0) }
        if new != highlight { highlight = new; needsDisplay = true }
    }

    override func mouseDown(with event: NSEvent) {
        guard let w = window else { return }
        onClick?(w.convertPoint(toScreen: event.locationInWindow))
    }

    override func draw(_ dirtyRect: NSRect) {
        // almost-clear fill so the window receives clicks everywhere
        NSColor(white: 0, alpha: 0.004).setFill(); bounds.fill()
        if let h = highlight {
            NSColor(srgbRed: 0.2, green: 0.55, blue: 1, alpha: 0.28).setFill()
            h.fill()
        }
    }
}
