import AppKit
import WebKit
// gamehost <url> <x> <y>  — shows the game in a borderless, NON-activating floating panel (1280x720 content)
// at global AppKit point (x,y) (bottom-left origin). Never activates / steals focus.
let a = CommandLine.arguments
let url = URL(string: a.count > 1 ? a[1] : "http://127.0.0.1:8777/")!
let x = a.count > 2 ? Double(a[2])! : 100, y = a.count > 3 ? Double(a[3])! : 297
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let panel = NSPanel(contentRect: NSRect(x: x, y: y, width: 1280, height: 720),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.level = .floating
panel.hidesOnDeactivate = false
panel.isReleasedWhenClosed = false
panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
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
panel.contentView = wv
wv.load(URLRequest(url: url))
panel.orderFrontRegardless()
print("panel frame", NSStringFromRect(panel.frame)); fflush(stdout)
app.run()
