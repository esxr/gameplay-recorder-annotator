import Foundation
let video = URL(fileURLWithPath: CommandLine.arguments[1])
let t0 = Date()
let engine = AnnotationEngine()
let sem = DispatchSemaphore(value: 0)
Task {
    do {
        let out = try await engine.annotate(video: video) { f, n in print(String(format: "progress %.2f records=%d", f, n)) }
        print("OUT \(out.path) total_s=\(Date().timeIntervalSince(t0))")
    } catch { print("FAILED \(error)") }
    sem.signal()
}
sem.wait()
