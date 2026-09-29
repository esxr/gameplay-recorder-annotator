import Foundation
// grctl stop | show [mode] | primary  — posts automation notifications to GameplayRecorder.app
let a = CommandLine.arguments
let cmd = a.count > 1 ? a[1] : "stop"
DistributedNotificationCenter.default().postNotificationName(.init("com.operantlabs.GameplayRecorder.\(cmd)"), object: a.count > 2 ? a[2] : nil, userInfo: nil, deliverImmediately: true)
