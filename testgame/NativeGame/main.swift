// Native port of testgame/index.html: same deterministic game (state is a pure function of gf), drawn with
// CoreGraphics/AppKit into a 1280x720 content view at 60 Hz, independent of browser/Low-Power throttling.
//
// Build: swiftc -O testgame/NativeGame/main.swift -o scratch/testgame/nativegame
// Run:   nativegame [--delay 3] [--duration 70] [--out testgame/out/truth.jsonl] [--x 100 --y 100]
//   --delay     seconds to show frame 0 before the game clock starts (default 3)
//   --duration  stop after this many seconds of game time (smoke tests; default: full 70 s run)
//   --x/--y     content top-left on the main (menu-bar) screen, top-left origin points (default 100,100)
// Window rules: ordinary titled/closable/miniaturizable NSWindow, level .normal, activation policy .accessory,
// never activates, orderBack after showing. Prints "WINDOW_ID <CGWindowID>" at start. Exits 2 s after GAME OVER.
// Truth: one JSON line per gf written directly to --out (truncated at game start). If a display tick is late and a
// gf is never drawn, its line is still written with "rendered": false.
import AppKit
import QuartzCore

// ---------------- args ----------------
var argDelay = 3.0, argDuration = -1.0, argX = 100.0, argY = 100.0
var argOut = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("../../testgame/out/truth.jsonl").standardized.path
do {
    let a = CommandLine.arguments; var i = 1
    while i < a.count {
        let v = i + 1 < a.count ? a[i + 1] : ""
        switch a[i] {
        case "--delay": argDelay = Double(v) ?? 3; i += 1
        case "--duration": argDuration = Double(v) ?? -1; i += 1
        case "--out": argOut = v; i += 1
        case "--x": argX = Double(v) ?? 100; i += 1
        case "--y": argY = Double(v) ?? 100; i += 1
        default: break
        }
        i += 1
    }
}

// ---------------- game logic (mirrors index.html exactly) ----------------
let W = 1280.0, H = 720.0, FPS = 60, GAME_FRAMES = 70 * 60

struct Mulberry32 {
    var a: UInt32
    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296.0
    }
}
var rng = Mulberry32(a: 12345)
struct Star { let x, y, r: Double }
var stars: [Star] = []
for _ in 0..<80 { let x = rng.next() * W, y = 90 + rng.next() * 480, r = 1 + rng.next() * 2; stars.append(Star(x: x, y: y, r: r)) }
var shots: [Int] = []
do { var g = 90; while g < GAME_FRAMES - 30 { shots.append(g); g += 100 + Int(floor(rng.next() * 60)) } }
let FLASHES: [(Int, Int)] = [(317, 1), (611, 2), (953, 1), (1277, 2), (1589, 1), (2213, 2), (2531, 1), (2867, 2), (3391, 1), (3713, 2)]
var flashSet = Set<Int>(); for (s, l) in FLASHES { for k in 0..<l { flashSet.insert(s + k) } }
let LOAD_START = 3000, LOAD_END = 3060, OBJ_CHANGE = 2100
let COVER = CGRect(x: 580, y: 140, width: 130, height: 420)
struct Enemy { let id: Int; let color: NSColor; let spawn: Int; let die: Int; let path: (Double) -> (Double, Double) }
func hex(_ v: Int) -> NSColor { NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1) }
let ENEMIES: [Enemy] = [
    Enemy(id: 1, color: hex(0xe53935), spawn: 0, die: Int(1e9), path: { t in (640 + 420 * sin(t * 0.55), 250 + 40 * sin(t * 1.3)) }),
    Enemy(id: 2, color: hex(0x43a047), spawn: 0, die: Int(1e9), path: { t in (640 + 360 * sin(t * 0.37 + 1.0), 420 + 50 * sin(t * 0.9)) }),
    Enemy(id: 3, color: hex(0x1e88e5), spawn: 0, die: 2400, path: { t in (290 + 150 * sin(t * 0.6), 330 + 110 * cos(t * 0.45)) }),
    Enemy(id: 4, color: hex(0xfdd835), spawn: 1500, die: Int(1e9), path: { t in (880 + 300 * sin(t * 0.3 + 2.0), 480 + 60 * cos(t * 0.7)) }),
]
let ESZ = 64.0

func sceneAt(_ gf: Int) -> String {
    if gf >= GAME_FRAMES { return "gameover" }
    if gf >= LOAD_START && gf < LOAD_END { return "loading" }
    return gf < LOAD_START ? "level1" : "level2"
}
func hudAt(_ gf: Int) -> (health: Int, ammo: Int, score: Int) {
    var ammo = 30, health = 100, score = 0
    for s in shots { if s > gf { break }; ammo -= 1; if ammo <= 0 { ammo = 30 }; score += 50 }
    for (s, _) in FLASHES { if s > gf { break }; health -= 7 }
    if gf >= 2400 { score += 500 }
    return (health, ammo, score)
}
func objectiveAt(_ gf: Int) -> String { gf < OBJ_CHANGE ? "Reach the gate" : "Defend the core" }
func enemiesAt(_ gf: Int) -> [(Enemy, CGRect)] {
    let sc = sceneAt(gf); if sc == "loading" || sc == "gameover" { return [] }
    let t = Double(gf) / Double(FPS); var out: [(Enemy, CGRect)] = []
    for e in ENEMIES where gf >= e.spawn && gf < e.die {
        let (cx, cy) = e.path(t - Double(e.spawn) / Double(FPS))
        out.append((e, CGRect(x: cx - ESZ / 2, y: cy - ESZ / 2, width: ESZ, height: ESZ)))
    }
    return out
}
func visibleBox(_ b: CGRect) -> CGRect? {
    let cx0 = COVER.minX, cx1 = COVER.maxX
    let vcov = b.minY >= COVER.minY && b.maxY <= COVER.maxY
    var x0 = b.minX, x1 = b.maxX
    if vcov && x1 > cx0 && x0 < cx1 {
        if x0 >= cx0 && x1 <= cx1 { return nil }
        if x0 < cx0 && x1 > cx1 { /* spans cover: keep full box */ } else if x0 < cx0 { x1 = cx0 } else { x0 = cx1 }
    }
    if x1 - x0 < 2 { return nil }
    return CGRect(x: x0, y: b.minY, width: x1 - x0, height: b.height)
}
func r4(_ v: Double) -> String { let d = (v * 10000).rounded() / 10000; return d == d.rounded() ? String(Int(d)) : "\(d)" }
func jsonStr(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
func truthLine(_ gf: Int, rendered: Bool) -> String {
    let h = hudAt(gf)
    var es: [String] = []
    for (e, b) in enemiesAt(gf) {
        if let v = visibleBox(b) {
            es.append("{\"id\": \(e.id), \"x\": \(r4(v.minX / W)), \"y\": \(r4(v.minY / H)), \"w\": \(r4(v.width / W)), \"h\": \(r4(v.height / H))}")
        }
    }
    return "{\"gf\": \(gf), \"sync\": \(gf & 0xffff), \"hud\": {\"health\": \(h.health), \"ammo\": \(h.ammo), \"score\": \(h.score)}, "
        + "\"objective\": \(jsonStr(objectiveAt(gf))), \"enemies\": [\(es.joined(separator: ", "))], "
        + "\"flash\": \(flashSet.contains(gf)), \"scene\": \(jsonStr(sceneAt(gf))), \"rendered\": \(rendered)}"
}

// ---------------- rendering ----------------
func fill(_ c: CGContext, _ col: NSColor, _ r: CGRect) { c.setFillColor(col.cgColor); c.fill(r) }
func gray(_ v: Int, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: CGFloat(v) / 255, green: CGFloat(v) / 255, blue: CGFloat(v) / 255, alpha: a) }
let hudFont = NSFont.monospacedSystemFont(ofSize: 40, weight: .bold)
let objFont = NSFont.monospacedSystemFont(ofSize: 32, weight: .bold)
let bigFont = NSFont.monospacedSystemFont(ofSize: 72, weight: .bold)
let goFont = NSFont.monospacedSystemFont(ofSize: 96, weight: .bold)
enum Align { case left, center, right }
func textMiddle(_ s: String, _ font: NSFont, _ col: NSColor, _ x: Double, middle y: Double) {
    let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: col])
    let sz = str.size()
    str.draw(at: NSPoint(x: x - sz.width / 2, y: y - sz.height / 2))
}
/// baseline-positioned draw: in a flipped view, draw(at:) places the line's top at y, so shift by ascender.
func textBL(_ s: String, _ font: NSFont, _ col: NSColor, _ x: Double, _ y: Double, _ al: Align) {
    let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: col])
    let w = str.size().width
    let px = al == .left ? x : (al == .center ? x - w / 2 : x - w)
    str.draw(at: NSPoint(x: px, y: y - font.ascender))
}

func drawEnemy(_ c: CGContext, _ b: CGRect, _ color: NSColor) {
    fill(c, color, b)
    fill(c, gray(0x11), CGRect(x: b.minX + 6, y: b.minY + 6, width: b.width - 12, height: 10))
    fill(c, .white, CGRect(x: b.minX + 14, y: b.minY + 24, width: 12, height: 12)); fill(c, .white, CGRect(x: b.maxX - 26, y: b.minY + 24, width: 12, height: 12))
    fill(c, .black, CGRect(x: b.minX + 18, y: b.minY + 28, width: 5, height: 5)); fill(c, .black, CGRect(x: b.maxX - 22, y: b.minY + 28, width: 5, height: 5))
    fill(c, .black, CGRect(x: b.minX + 16, y: b.minY + 46, width: b.width - 32, height: 6))
}
func drawBarcode(_ c: CGContext, _ gf: Int) {
    fill(c, gray(0x80), CGRect(x: 0, y: 0, width: 16 * 12 + 8, height: 20))
    for i in 0..<16 { let bit = (gf >> (15 - i)) & 1; fill(c, bit == 1 ? .white : .black, CGRect(x: 4 + Double(i) * 12, y: 4, width: 12, height: 12)) }
}
func render(_ c: CGContext, _ gf: Int) {
    let sc = sceneAt(gf)
    if sc == "loading" {
        fill(c, .black, CGRect(x: 0, y: 0, width: W, height: H))
        textMiddle("LOADING", bigFont, gray(0xdd), W / 2, middle: H / 2)
    } else {
        fill(c, sc == "level1" ? hex(0x26324a) : hex(0x4a2a2a), CGRect(x: 0, y: 0, width: W, height: H))
        fill(c, sc == "level1" ? hex(0x3d4d6b) : hex(0x6b3d33), CGRect(x: 0, y: 560, width: W, height: 160))
        for s in stars { fill(c, NSColor(white: 1, alpha: 0.35), CGRect(x: s.x, y: s.y, width: s.r, height: s.r)) }
        for (e, b) in enemiesAt(gf) { drawEnemy(c, b, e.color) }
        fill(c, hex(0x8d8d8d), COVER)
        c.setStrokeColor(hex(0x5a5a5a).cgColor); c.setLineWidth(4); c.stroke(COVER.insetBy(dx: 2, dy: 2))
        for s in shots where gf >= s && gf < s + 4 {
            c.setStrokeColor(hex(0xffeb3b).cgColor); c.setLineWidth(3)
            c.move(to: CGPoint(x: W / 2, y: H - 30)); c.addLine(to: CGPoint(x: W / 2 + 40, y: H - 200)); c.strokePath()
        }
    }
    let hud = hudAt(gf)
    let panel = NSColor(srgbRed: 10 / 255, green: 10 / 255, blue: 14 / 255, alpha: 0.88)
    fill(c, panel, CGRect(x: 20, y: 590, width: 330, height: 110))
    textBL("HEALTH \(hud.health)", hudFont, .white, 36, 638, .left)
    textBL("AMMO \(hud.ammo)", hudFont, .white, 36, 684, .left)
    fill(c, panel, CGRect(x: W - 330, y: 20, width: 310, height: 60))
    textBL("SCORE \(hud.score)", hudFont, .white, W - 36, 64, .right)
    fill(c, panel, CGRect(x: W / 2 - 220, y: 20, width: 440, height: 50))
    textBL(objectiveAt(gf), objFont, hex(0xffd54f), W / 2, 56, .center)
    if sc == "gameover" {
        fill(c, NSColor(white: 0, alpha: 0.6), CGRect(x: 0, y: 0, width: W, height: H))
        textMiddle("GAME OVER", goFont, hex(0xff5252), W / 2, middle: H / 2)
    }
    if flashSet.contains(gf) { fill(c, NSColor(white: 1, alpha: 0.6), CGRect(x: 0, y: 0, width: W, height: H)) }
    drawBarcode(c, gf)
}

// ---------------- app / view / clock ----------------
final class GameView: NSView {
    var gf = 0
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        render(c, gf)
    }
}

final class Game: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var win: NSWindow!
    var view: GameView!
    var link: CADisplayLink?
    var out: FileHandle?
    var t0: CFTimeInterval = 0
    var lastGf = -1, skipped = 0, started = false, finishedAt: CFTimeInterval = 0
    let maxGf = argDuration > 0 ? min(GAME_FRAMES, Int(argDuration * Double(FPS))) : GAME_FRAMES

    func applicationDidFinishLaunching(_ n: Notification) {
        let screen = NSScreen.screens.first!   // menu-bar (main laptop) screen, independent of focus
        let top = screen.frame.maxY - argY
        let rect = NSRect(x: screen.frame.minX + argX, y: top - H, width: W, height: H)
        win = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        win.title = "Native Test Game"
        win.level = .normal
        win.isReleasedWhenClosed = false
        win.delegate = self
        view = GameView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        win.contentView = view
        win.orderBack(nil)                     // visible, behind other windows; never key, never activates
        print("WINDOW_ID \(win.windowNumber)")
        print("CONTENT_RECT_APPKIT \(Int(rect.minX)),\(Int(rect.minY)),\(Int(W)),\(Int(H)) screen=\(NSStringFromRect(screen.frame))")
        fflush(stdout)
        let l = view.displayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
        DispatchQueue.main.asyncAfter(deadline: .now() + argDelay) { self.start() }
    }
    func start() {
        FileManager.default.createFile(atPath: argOut, contents: nil)   // truncate
        out = FileHandle(forWritingAtPath: argOut)
        t0 = CACurrentMediaTime(); started = true
        print("GAME_START t=\(t0) out=\(argOut)"); fflush(stdout)
    }
    func emit(_ g: Int, _ rendered: Bool) { out?.write((truthLine(g, rendered: rendered) + "\n").data(using: .utf8)!) }
    @objc func tick(_ l: CADisplayLink) {
        guard started else { return }
        let now = CACurrentMediaTime()
        if finishedAt > 0 {
            if now - finishedAt > 2 { finish() }
            return
        }
        let gf = min(maxGf, Int(floor((now - t0) * Double(FPS) + 1e-6)))
        guard gf != lastGf else { return }
        if lastGf + 1 < gf { for g in (lastGf + 1)..<gf { emit(g, false); skipped += 1 } }
        view.gf = gf
        view.display()                          // draw this gf now (synchronous)
        emit(gf, true)
        lastGf = gf
        if gf >= maxGf { finishedAt = now; print("GAME_OVER gf=\(gf) skipped=\(skipped)"); fflush(stdout) }
    }
    func finish() {
        link?.invalidate(); try? out?.synchronize(); try? out?.close()
        print("EXIT lines=\(lastGf + 1) skipped=\(skipped)"); fflush(stdout)
        exit(0)
    }
    func windowWillClose(_ n: Notification) { finish() }
}

let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "test game 60 Hz")
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let game = Game()
app.delegate = game
app.run()
_ = activity
