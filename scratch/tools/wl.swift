import CoreGraphics
let l = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in l where (w["kCGWindowOwnerName"] as? String ?? "").contains("Gameplay") { print(w["kCGWindowNumber"]!, w["kCGWindowLayer"]!, w["kCGWindowName"] ?? "-", w["kCGWindowIsOnscreen"] ?? "-", w["kCGWindowBounds"]!) }
