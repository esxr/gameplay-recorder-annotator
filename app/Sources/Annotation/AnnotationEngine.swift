import AVFoundation
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum AnnotationError: Error, LocalizedError {
    case noAPIKey
    case noVideoTrack
    case http(Int, String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Anthropic API key found (env ANTHROPIC_API_KEY or anthropic.env)"
        case .noVideoTrack: return "Video has no readable duration/track"
        case .http(let c, let m): return "Claude API HTTP \(c): \(m)"
        case .badResponse(let m): return "Bad Claude response: \(m)"
        }
    }
}

/// A frame chosen for annotation.
struct FrameSample: Sendable {
    let t: Double          // seconds
    let trigger: String    // "sample_1fps" | "scene_change"
    var frameIndex: Int { Int((t * 60).rounded()) }
    var tMs: Int { Int((t * 1000).rounded()) }
}

/// Holds completed records and appends JSONL lines as they complete.
actor AnnotationSink {
    private var records: [AnnotationRecord] = []
    private let url: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return e
    }()

    init(url: URL) {
        self.url = url
        try? FileManager.default.removeItem(at: url)
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }

    func append(_ r: AnnotationRecord) {
        records.append(r)
        guard var data = try? encoder.encode(r) else { return }
        data.append(0x0A)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        }
    }

    /// Latest completed record strictly before time t (used as persistent-state context).
    func context(before tMs: Int) -> AnnotationRecord? {
        records.filter { $0.t_ms < tMs }.max { $0.t_ms < $1.t_ms }
    }

    var count: Int { records.count }

    /// Rewrite the file sorted by t_ms.
    func finalizeSorted() -> Int {
        let sorted = records.sorted { $0.t_ms < $1.t_ms }
        var out = Data()
        for r in sorted {
            if let d = try? encoder.encode(r) { out.append(d); out.append(0x0A) }
        }
        try? out.write(to: url, options: .atomic)
        return sorted.count
    }
}

final class AnnotationEngine: VideoAnnotating, @unchecked Sendable {
    let model: String
    let maxConcurrent: Int
    let sceneThreshold: Double
    let scanFPS: Double

    init(model: String? = nil, maxConcurrent: Int = 6, sceneThreshold: Double = 0.18, scanFPS: Double = 4) {
        self.model = model ?? ProcessInfo.processInfo.environment["GR_MODEL"] ?? "claude-haiku-4-5-20251001"
        self.maxConcurrent = maxConcurrent
        self.sceneThreshold = sceneThreshold
        self.scanFPS = scanFPS
    }

    // MARK: - API key

    static func loadAPIKey() -> String? {
        if let k = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines), !k.isEmpty {
            return k
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let files = [
            home.appendingPathComponent("Library/Application Support/GameplayRecorder/anthropic.env"),
            URL(fileURLWithPath: "/Users/pranav/Desktop/gameplay_recorder_annotator/.secrets/anthropic.env"),
        ]
        for f in files {
            guard let s = try? String(contentsOf: f, encoding: .utf8) else { continue }
            for raw in s.split(whereSeparator: \.isNewline) {
                var line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("export ") { line = String(line.dropFirst(7)) }
                guard line.hasPrefix("ANTHROPIC_API_KEY") , let eq = line.firstIndex(of: "=") else { continue }
                var v = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                v = v.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !v.isEmpty { return v }
            }
        }
        return nil
    }

    // MARK: - VideoAnnotating

    func annotate(video: URL, progress: @escaping @Sendable (Double, Int) -> Void) async throws -> URL {
        AppLog.log("annotation_started", ["video": video.path, "model": model])
        let started = Date()
        let outURL = AppPaths.annotationsURL(for: video)
        do {
            guard let apiKey = Self.loadAPIKey() else { throw AnnotationError.noAPIKey }
            let asset = AVURLAsset(url: video)
            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration > 0 else { throw AnnotationError.noVideoTrack }

            let samples = try await selectSamples(asset: asset, duration: duration)
            AppLog.log("annotation_samples", ["count": samples.count,
                                               "scene_changes": samples.filter { $0.trigger == "scene_change" }.count,
                                               "duration_s": String(format: "%.2f", duration)])
            progress(0.02, 0)

            let framesDir = AppPaths.framesDir(for: video)
            let sink = AnnotationSink(url: outURL)
            let total = samples.count
            let limit = max(1, maxConcurrent)

            // Full-resolution generator for evidence frames.
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = .zero
            gen.maximumSize = CGSize(width: 1280, height: 1280)

            await withTaskGroup(of: Void.self) { group in
                var next = 0
                var done = 0
                func launch(_ s: FrameSample) {
                    group.addTask { [self] in
                        await self.process(sample: s, generator: gen, framesDir: framesDir, apiKey: apiKey, sink: sink)
                    }
                }
                // First frame alone so later frames have persistent-state context.
                if next < total { launch(samples[next]); next += 1 }
                if next < total {
                    await group.next(); done += 1
                    progress(0.02 + 0.98 * Double(done) / Double(total), await sink.count)
                }
                while next < total && next - done < limit { launch(samples[next]); next += 1 }
                while await group.next() != nil {
                    done += 1
                    progress(0.02 + 0.98 * Double(done) / Double(max(total, 1)), await sink.count)
                    if next < total { launch(samples[next]); next += 1 }
                }
            }

            let n = await sink.finalizeSorted()
            progress(1.0, n)
            AppLog.log("annotation_finished", ["records": n, "samples": total, "path": outURL.path,
                                                "elapsed_s": String(format: "%.1f", Date().timeIntervalSince(started))])
            return outURL
        } catch {
            AppLog.log("annotation_error", ["stage": "annotate", "error": "\(error.localizedDescription)"])
            throw error
        }
    }

    // MARK: - Sampling (1 fps + scene changes)

    func selectSamples(asset: AVAsset, duration: Double) async throws -> [FrameSample] {
        var samples: [FrameSample] = []
        let lastT = max(0, duration - 0.05)
        var t = 0.0
        while t <= lastT + 1e-6 { samples.append(FrameSample(t: t, trigger: "sample_1fps")); t += 1.0 }

        let scan = AVAssetImageGenerator(asset: asset)
        scan.appliesPreferredTrackTransform = true
        scan.requestedTimeToleranceBefore = .zero
        scan.requestedTimeToleranceAfter = .zero
        scan.maximumSize = CGSize(width: 64, height: 64)

        var prev: [UInt8]? = nil
        let step = 1.0 / scanFPS
        var st = 0.0
        while st <= lastT + 1e-6 {
            let time = CMTime(seconds: st, preferredTimescale: 600)
            if let (cg, _) = try? await scan.image(at: time), let g = Self.grayThumb(cg) {
                if let p = prev, p.count == g.count {
                    var sum = 0
                    for i in 0..<g.count { sum += abs(Int(g[i]) - Int(p[i])) }
                    let diff = Double(sum) / Double(g.count) / 255.0
                    if diff > sceneThreshold, !samples.contains(where: { abs($0.t - st) < 0.5 }) {
                        samples.append(FrameSample(t: st, trigger: "scene_change"))
                        AppLog.log("annotation_scene_change", ["t_ms": Int(st * 1000), "diff": String(format: "%.3f", diff)])
                    }
                }
                prev = g
            }
            st += step
        }
        return samples.sorted { $0.t < $1.t }
    }

    static func grayThumb(_ img: CGImage, w: Int = 64, h: Int = 36) -> [UInt8]? {
        var buf = [UInt8](repeating: 0, count: w * h)
        let ok = buf.withUnsafeMutableBytes { ptr -> Bool in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .low
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? buf : nil
    }

    // MARK: - Per-frame processing

    private func process(sample s: FrameSample, generator: AVAssetImageGenerator, framesDir: URL, apiKey: String, sink: AnnotationSink) async {
        let frameURL = framesDir.appendingPathComponent("frame_\(s.frameIndex).jpg")
        do {
            let (cg, _) = try await generator.image(at: CMTime(seconds: s.t, preferredTimescale: 600))
            guard let jpeg = Self.jpegData(cg, quality: 0.7) else { throw AnnotationError.badResponse("jpeg encode failed") }
            try jpeg.write(to: frameURL, options: .atomic)
            let ctx = await sink.context(before: s.tMs)
            let parsed = try await callClaude(jpeg: jpeg, sample: s, context: ctx, apiKey: apiKey)
            let rec = AnnotationRecord(t_ms: s.tMs, frame: s.frameIndex, scene: parsed.scene, entities: parsed.entities,
                                       hud: parsed.hud, text: parsed.text, events: parsed.events, confidence: parsed.confidence,
                                       evidence_frame: frameURL.path, model: model, trigger: s.trigger)
            await sink.append(rec)
            AppLog.log("annotation_frame", ["t_ms": s.tMs, "trigger": s.trigger, "entities": rec.entities.count, "hud": rec.hud.count])
        } catch {
            AppLog.log("annotation_error", ["t_ms": s.tMs, "trigger": s.trigger, "error": "\(error.localizedDescription)"])
        }
    }

    static func jpegData(_ img: CGImage, quality: Double) -> Data? {
        // Ensure max 1280 px long edge.
        var image = img
        let longEdge = max(img.width, img.height)
        if longEdge > 1280 {
            let scale = 1280.0 / Double(longEdge)
            let w = Int(Double(img.width) * scale), h = Int(Double(img.height) * scale)
            if let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
                ctx.interpolationQuality = .high
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
                if let s = ctx.makeImage() { image = s }
            }
        }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    // MARK: - Claude

    struct Parsed {
        var scene: String
        var entities: [AnnotationEntity]
        var hud: [String: String]
        var text: [String]
        var events: [AnnotationEvent]
        var confidence: Double
    }

    static let toolSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "scene": ["type": "string", "description": "Short description of the current scene/screen state"],
            "entities": ["type": "array", "items": [
                "type": "object",
                "properties": [
                    "id": ["type": "string", "description": "Stable id like player_1, enemy_3, window_editor; reuse ids from previous frame for the same object"],
                    "type": ["type": "string"],
                    "label": ["type": "string"],
                    "bbox": ["type": "array", "items": ["type": "number"], "description": "normalized [x, y, w, h], origin top-left, 0..1"],
                    "confidence": ["type": "number"],
                ],
                "required": ["id", "type", "label", "bbox", "confidence"],
            ]],
            "hud": ["type": "object", "additionalProperties": ["type": "string"], "description": "HUD/status elements: name -> value string (health, score, ammo, timer, menu title, status bar values...)"],
            "text": ["type": "array", "items": ["type": "string"], "description": "Visible text strings (most salient, max ~20)"],
            "events": ["type": "array", "items": [
                "type": "object",
                "properties": ["type": ["type": "string"], "description": ["type": "string"], "confidence": ["type": "number"]],
                "required": ["type", "description", "confidence"],
            ]],
            "confidence": ["type": "number", "description": "Overall confidence 0..1"],
        ],
        "required": ["scene", "entities", "hud", "text", "events", "confidence"],
    ]

    private func prompt(sample s: FrameSample, context: AnnotationRecord?) -> String {
        var p = """
        You are annotating one frame of a screen/gameplay recording at t=\(String(format: "%.2f", s.t))s (trigger: \(s.trigger)).
        Describe the semantic state of the frame by calling the record_annotation tool. Rules:
        - scene: one short sentence naming the game/app and the current screen/state.
        - entities: the salient objects (characters, enemies, items, projectiles, UI windows/panels, buttons, cursor). Give each a stable id (type_n), type, label, normalized bbox [x,y,w,h] with origin top-left, and confidence 0..1. List 3-15 entities.
        - hud: HUD/status readouts as name -> value strings (health, score, ammo, timer, level, menu/tab title, clock, battery...). Use visible values only.
        - text: the most salient visible text strings (max 20, verbatim).
        - events: what is happening or has changed (e.g. scene_change, menu_opened, damage_taken, scrolling); empty if nothing.
        - Never invent values you cannot see; lower confidence when unsure.
        """
        if let c = context {
            let ents = c.entities.prefix(15).map { "\($0.id)(\($0.type): \($0.label))" }.joined(separator: ", ")
            p += "\n\nPrevious frame (t=\(c.t_ms) ms) state, for id continuity — reuse these ids for the same objects, create new ids for new ones:\nscene: \(c.scene)\nentities: \(ents)"
        }
        return p
    }

    private func callClaude(jpeg: Data, sample: FrameSample, context: AnnotationRecord?, apiKey: String) async throws -> Parsed {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "tools": [["name": "record_annotation", "description": "Record the structured annotation for this frame.",
                       "input_schema": Self.toolSchema]],
            "tool_choice": ["type": "tool", "name": "record_annotation"],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": prompt(sample: sample, context: context)],
                ],
            ]],
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 90
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = bodyData

        var attempt = 0
        while true {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 { return try Self.parseResponse(data) }
                let msg = String(data: data.prefix(300), encoding: .utf8) ?? ""
                if (code == 429 || code >= 500) && attempt < 3 {
                    attempt += 1
                    var delay = pow(2.0, Double(attempt)) // 2,4,8
                    if let ra = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "retry-after"), let d = Double(ra) { delay = max(delay, d) }
                    AppLog.log("annotation_retry", ["t_ms": sample.tMs, "status": code, "attempt": attempt])
                    try await Task.sleep(nanoseconds: UInt64(delay * 1e9))
                    continue
                }
                throw AnnotationError.http(code, msg)
            } catch let e as URLError where attempt < 3 {
                attempt += 1
                AppLog.log("annotation_retry", ["t_ms": sample.tMs, "error": e.code.rawValue, "attempt": attempt])
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1e9))
            }
        }
    }

    static func parseResponse(_ data: Data) throws -> Parsed {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else { throw AnnotationError.badResponse("no content") }
        if let tool = content.first(where: { ($0["type"] as? String) == "tool_use" }), let input = tool["input"] as? [String: Any] {
            return parseAnnotation(input)
        }
        // Fallback: text block with JSON (possibly fenced).
        let text = content.compactMap { $0["text"] as? String }.joined(separator: "\n")
        if let j = extractJSONObject(text) { return parseAnnotation(j) }
        throw AnnotationError.badResponse("no tool_use or JSON")
    }

    static func extractJSONObject(_ s: String) -> [String: Any]? {
        var t = s.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        guard let a = t.firstIndex(of: "{"), let b = t.lastIndex(of: "}"), a < b else { return nil }
        t = String(t[a...b])
        return (try? JSONSerialization.jsonObject(with: Data(t.utf8))) as? [String: Any]
    }

    static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }

    static func str(_ v: Any?) -> String {
        if let s = v as? String { return s }
        if let v = v, !(v is NSNull) { return "\(v)" }
        return ""
    }

    static func parseAnnotation(_ j: [String: Any]) -> Parsed {
        let clamp: (Double) -> Double = { min(1, max(0, $0)) }
        var ents: [AnnotationEntity] = []
        for (i, e) in ((j["entities"] as? [[String: Any]]) ?? []).enumerated() {
            var bbox: [Double]? = nil
            if let b = e["bbox"] as? [Any] {
                let v = b.compactMap { num($0) }.map(clamp)
                if v.count == 4 { bbox = v }
            }
            let id = str(e["id"])
            ents.append(AnnotationEntity(id: id.isEmpty ? "entity_\(i + 1)" : id, type: str(e["type"]), label: str(e["label"]),
                                         bbox: bbox, confidence: clamp(num(e["confidence"]) ?? 0.5)))
        }
        var hud: [String: String] = [:]
        if let h = j["hud"] as? [String: Any] { for (k, v) in h { hud[k] = str(v) } }
        let text = ((j["text"] as? [Any]) ?? []).map { str($0) }.filter { !$0.isEmpty }
        let events = ((j["events"] as? [[String: Any]]) ?? []).map {
            AnnotationEvent(type: str($0["type"]), description: str($0["description"]), confidence: clamp(num($0["confidence"]) ?? 0.5))
        }
        return Parsed(scene: str(j["scene"]), entities: ents, hud: hud, text: text, events: events,
                      confidence: clamp(num(j["confidence"]) ?? 0.5))
    }
}
