import CoreGraphics
// winrect <ownerSubstring> <titleSubstring> : prints "x y w h" (top-left origin points) of first on-screen matching window
let a = CommandLine.arguments
let owner = a.count > 1 ? a[1] : "Chrome", title = a.count > 2 ? a[2] : "Test Game"
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in l {
  let o = w["kCGWindowOwnerName"] as? String ?? "", n = w["kCGWindowName"] as? String ?? ""
  guard o.contains(owner), n.contains(title), (w["kCGWindowLayer"] as? Int ?? 1) == 0 else { continue }
  let b = w["kCGWindowBounds"] as! [String: Any]
  print(b["X"]!, b["Y"]!, b["Width"]!, b["Height"]!); break
}
