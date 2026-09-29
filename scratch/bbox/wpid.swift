import CoreGraphics
let pid = Int(CommandLine.arguments[1])!
let l = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in l where (w["kCGWindowOwnerPID"] as? Int) == pid && (w["kCGWindowLayer"] as? Int) == 0 && ((w["kCGWindowName"] as? String) ?? "").hasSuffix(".mp4") { print(w["kCGWindowNumber"]!) }
