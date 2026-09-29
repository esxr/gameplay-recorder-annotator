import AppKit
import WebKit
// gamehost <url> <x> <y> — shows the game in an ORDINARY titled, closable, movable window (level .normal)
// whose 1280x720 content rect sits at global AppKit point (x,y). The window is ordered BEHIND other windows
// (orderBack) and the app never activates. Prints "window_id=<CGWindowID>" to stdout. Cmd+W / close ends it.
let a = CommandLine.arguments
let url = URL(string: a.count > 1 ? a[1] : "http://127.0.0.1:8777/")!
let x = a.count > 2 ? Double(a[2])! : 100, y = a.count > 3 ? Double(a[3])! : 297
final class Del: NSObject, NSApplicationDelegate, NSWindowDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, never activates
let del = Del(); app.delegate = del
let win = NSWindow(contentRect: NSRect(x: x, y: y, width: 1280, height: 720),
                   styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
win.title = "Test Game"
win.level = .normal
win.isReleasedWhenClosed = false
win.delegate = del
let cfg = WKWebViewConfiguration()
// macOS Low Power Mode makes WebKit throttle rendering updates (rAF) to 30 fps. Disable that throttling via
// WebKit's (private) feature flags so the game renders every 60 fps frame.
if let feats = (WKPreferences.self as AnyObject).perform(NSSelectorFromString("_features"))?.takeUnretainedValue() as? [NSObject] {
  for f in feats {
    let key = (f.value(forKey: "key") as? String) ?? ""
    if key.contains("RenderingUpdateThrottling") || key.contains("PreferPageRenderingUpdatesNear60FPS") {
      let on = key.contains("Near60FPS")
      let sel = NSSelectorFromString("_setEnabled:forFeature:")
      typealias Fn = @convention(c) (AnyObject, Selector, Bool, AnyObject) -> Void
      if let m = class_getInstanceMethod(WKPreferences.self, sel) {
        unsafeBitCast(method_getImplementation(m), to: Fn.self)(cfg.preferences, sel, on, f)
      }
      print("feature", key, "->", on)
    }
  }
}
let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720), configuration: cfg)
win.contentView = wv
wv.load(URLRequest(url: url))
win.orderBack(nil)                    // behind other windows; no makeKey, no activate
print("window_id=\(win.windowNumber)"); print("content_rect", NSStringFromRect(win.contentRect(forFrameRect: win.frame))); fflush(stdout)
app.run()
