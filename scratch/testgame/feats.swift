import WebKit
if let feats = (WKPreferences.self as AnyObject).perform(NSSelectorFromString("_features"))?.takeUnretainedValue() as? [NSObject] {
  for f in feats { let k = (f.value(forKey: "key") as? String) ?? ""; if k.lowercased().contains("throttl") || k.lowercased().contains("power") || k.contains("60") || k.lowercased().contains("frame") { print(k) } }
}
