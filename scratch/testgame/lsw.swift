import CoreGraphics
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in l where (w["kCGWindowLayer"] as? Int ?? 1) == 0 { print(w["kCGWindowNumber"]!, w["kCGWindowOwnerName"] ?? "-", w["kCGWindowName"] ?? "-", w["kCGWindowBounds"]!) }
