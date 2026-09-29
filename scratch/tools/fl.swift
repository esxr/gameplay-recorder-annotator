import CoreGraphics
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in l { let layer = w["kCGWindowLayer"] as! Int; let b = w["kCGWindowBounds"] as! [String: Any]; let wd = b["Width"] as! Double
  if layer > 0 && layer < 20 || wd >= 1000 && layer == 0 && (w["kCGWindowOwnerName"] as? String ?? "") != "" { print(layer, w["kCGWindowOwnerPID"]!, w["kCGWindowOwnerName"] ?? "-", Int(wd), b["Height"]!) } }
