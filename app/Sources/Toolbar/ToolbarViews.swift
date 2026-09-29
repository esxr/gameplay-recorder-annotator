import AppKit

// Visual building blocks of the Cmd+Shift+5 clone. Measurements (points) come from
// proofs/G1-native.png: toolbar 547 x 50, corner radius 14, fill ~#222222.
// Native macOS 26 has a 6th slot (Record Selected Window) that the 5-mode contract lacks, so the
// toolbar is one 56 pt slot narrower (491 pt); everything left of that slot sits at native x offsets.

enum ToolbarMetrics {
    static let size = NSSize(width: 491, height: 50)
    static let cornerRadius: CGFloat = 14
    static let bottomOffset: CGFloat = 102           // native toolbarOrigin.y
    static let closeCenterX: CGFloat = 22
    static let captureCentersX: [CGFloat] = [63, 111, 160]
    static let divider1X: CGFloat = 191
    static let recordCentersX: [CGFloat] = [226, 282]
    static let divider2X: CGFloat = 320
    static let optionsCenterX: CGFloat = 365
    static let primaryFrame = NSRect(x: 408, y: 7, width: 76, height: 36)
    static let modeButtonSize = NSSize(width: 44, height: 38)
}

/// Icon for a mode, composed from SF Symbols to look like the native glyphs.
@MainActor enum ToolbarIcons {
    static func image(for mode: CaptureMode) -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: 24, weight: .light)
        func sym(_ name: String, _ fallback: String) -> NSImage {
            let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: fallback, accessibilityDescription: nil) ?? NSImage()
            return img.withSymbolConfiguration(cfg) ?? img
        }
        switch mode {
        case .captureEntireScreen: return sym("dock.rectangle", "rectangle.inset.filled")
        case .captureSelectedWindow: return sym("macwindow", "rectangle")
        case .captureSelectedPortion: return sym("rectangle.dashed", "rectangle")
        case .recordEntireScreen: return badged(sym("dock.rectangle", "rectangle.inset.filled"))
        case .recordSelectedPortion: return badged(sym("rectangle.dashed", "rectangle"))
        }
    }

    /// Native record glyphs are the capture glyph with a small "record" dot badge at the bottom-right.
    static func badged(_ base: NSImage) -> NSImage {
        let bs = base.size
        let badge: CGFloat = 11
        let size = NSSize(width: bs.width + badge * 0.45, height: bs.height + badge * 0.35)
        let img = NSImage(size: size, flipped: false) { _ in
            base.draw(in: NSRect(x: 0, y: size.height - bs.height, width: bs.width, height: bs.height))
            let r = NSRect(x: size.width - badge, y: 0, width: badge, height: badge)
            // punch out a ring so the badge reads on top of the frame
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: r.insetBy(dx: -1.5, dy: -1.5)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.black.setStroke()
            let ring = NSBezierPath(ovalIn: r.insetBy(dx: 0.75, dy: 0.75)); ring.lineWidth = 1.5; ring.stroke()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: r.insetBy(dx: 3, dy: 3)).fill()
            return true
        }
        img.isTemplate = true
        return img
    }
}

/// Square-ish icon button that shows a rounded highlight when selected (like the native toolbar).
final class ModeButton: NSButton {
    let mode: CaptureMode
    var isSelectedMode = false { didSet { needsDisplay = true; updateTint() } }
    private var hovering = false { didSet { needsDisplay = true } }

    init(mode: CaptureMode) {
        self.mode = mode
        super.init(frame: NSRect(origin: .zero, size: ToolbarMetrics.modeButtonSize))
        isBordered = false
        bezelStyle = .regularSquare
        imagePosition = .imageOnly
        image = ToolbarIcons.image(for: mode)
        imageScaling = .scaleNone
        toolTip = Self.title(mode)
        setAccessibilityLabel(Self.title(mode))
        updateTint()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }

    static func title(_ m: CaptureMode) -> String {
        switch m {
        case .captureEntireScreen: return "Capture Entire Screen"
        case .captureSelectedWindow: return "Capture Selected Window"
        case .captureSelectedPortion: return "Capture Selected Portion"
        case .recordEntireScreen: return "Record Entire Screen"
        case .recordSelectedPortion: return "Record Selected Portion"
        }
    }

    private func updateTint() { contentTintColor = NSColor(white: 1, alpha: isSelectedMode ? 0.85 : 0.66) }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func draw(_ dirtyRect: NSRect) {
        if isSelectedMode || hovering {
            NSColor(white: 1, alpha: isSelectedMode ? 0.11 : 0.05).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8).fill()
        }
        super.draw(dirtyRect)
    }
}

/// The blue "Capture"/"Record" button.
final class PrimaryButton: NSButton {
    init() {
        super.init(frame: ToolbarMetrics.primaryFrame)
        isBordered = false
        bezelStyle = .regularSquare
        focusRingType = .none
    }
    required init?(coder: NSCoder) { fatalError() }
    override var title: String { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let pressed = isHighlighted
        (pressed ? NSColor(displayP3Red: 22/255, green: 137/255, blue: 204/255, alpha: 1) : NSColor(displayP3Red: 27/255, green: 171/255, blue: 1, alpha: 1)).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 9, yRadius: 9).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.white]
        let s = NSAttributedString(string: title, attributes: attrs)
        let sz = s.size()
        s.draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2))
    }
}

final class DividerView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 1, alpha: 0.16).setFill()
        bounds.fill()
    }
}

/// Rounded dark HUD background. Native Tahoe toolbar is ~#222 nearly opaque over vibrancy.
final class ToolbarBackgroundView: NSVisualEffectView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = ToolbarMetrics.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        maskImage = Self.mask(radius: ToolbarMetrics.cornerRadius)
        let tint = NSView(frame: bounds)
        tint.autoresizingMask = [.width, .height]
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(srgbRed: 34/255, green: 34/255, blue: 34/255, alpha: 0.82).cgColor
        addSubview(tint)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var mouseDownCanMoveWindow: Bool { true }

    static func mask(radius: CGFloat) -> NSImage {
        let d = radius * 2 + 1
        let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { r in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        img.resizingMode = .stretch
        return img
    }
}
