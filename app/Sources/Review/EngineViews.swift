import AVFoundation
import AppKit
import SwiftUI

// MARK: - Region grid overlay (8×6) on the video

struct RegionOverlay: View {
    @ObservedObject var model: ReviewModel
    @ObservedObject var engine: EngineSessionModel

    var body: some View {
        GeometryReader { geo in
            if engine.showRegions, let m = engine.modes(atMs: model.currentMs), m.count >= 48 {
                let fit = AVMakeRect(aspectRatio: model.videoSize, insideRect: CGRect(origin: .zero, size: geo.size))
                let chars = Array(m)
                let cw = fit.width / 8, ch = fit.height / 6
                Canvas { ctx, _ in
                    for r in 0..<6 {
                        for c in 0..<8 {
                            let mode = chars[r * 8 + c]
                            let rect = CGRect(x: fit.minX + CGFloat(c) * cw, y: fit.minY + CGFloat(r) * ch, width: cw, height: ch)
                            let col = Color(nsColor: RegionMode.color(mode))
                            ctx.fill(Path(rect), with: .color(col.opacity(RegionMode.fillOpacity(mode))))
                            ctx.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(mode == "C" ? Color.white.opacity(0.15) : col.opacity(0.9)), lineWidth: mode == "C" ? 0.5 : 1.5)
                            if mode != "C" {
                                ctx.draw(Text(String(mode)).font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                                         at: CGPoint(x: rect.minX + 8, y: rect.minY + 8))
                            }
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Toggle + legend with session-wide mode percentages + current frame number.
struct RegionLegend: View {
    @ObservedObject var model: ReviewModel
    @ObservedObject var engine: EngineSessionModel

    var body: some View {
        if engine.hasSession {
            HStack(spacing: 8) {
                Toggle("Show regions", isOn: $engine.showRegions).toggleStyle(.checkbox)
                let total = max(engine.totalRegions, 1)
                ForEach(RegionMode.order, id: \.self) { c in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: RegionMode.color(c)).opacity(c == "C" ? 0.5 : 0.9))
                            .frame(width: 10, height: 10)
                        Text("\(String(c)) \(String(format: "%.1f", 100.0 * Double(engine.modeCounts[c] ?? 0) / Double(total)))%")
                            .monospacedDigit()
                    }
                    .help(RegionMode.name(c))
                }
                Text("f \(engine.frame(forMs: model.currentMs)) / \(max(engine.modes.count - 1, 0))")
                    .monospacedDigit().foregroundColor(.secondary)
            }
            .font(.caption)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.55)))
        }
    }
}

// MARK: - Events lane under the timeline

struct EventsLane: View {
    @ObservedObject var model: ReviewModel
    @ObservedObject var engine: EngineSessionModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Events \(engine.events.count)").font(.caption).foregroundColor(.secondary).frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let dur = Double(model.durationMs)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)).frame(width: w, height: h)
                    ForEach(engine.events) { e in
                        let x = w * CGFloat(Double(engine.ms(forFrame: e.fStart)) / dur)
                        let row = CGFloat(Self.row(e.type))
                        Rectangle().fill(Self.color(e.type))
                            .frame(width: 3, height: h / 4 - 1)
                            .frame(width: 9, height: h / 4)
                            .contentShape(Rectangle())
                            .position(x: x, y: row * h / 4 + h / 8)
                            .onTapGesture {
                                model.seek(toMs: engine.ms(forFrame: e.fStart))
                                engine.shownCrop = engine.resolve(e.evidenceCrop)
                                AppLog.log("engine_stage", ["name": "review_event_click", "type": e.type, "f": e.fStart])
                            }
                            .help("f\(e.fStart)–\(e.fEnd) · \(e.type) \(e.detail) · conf \(String(format: "%.2f", e.confidence))")
                    }
                    Rectangle().fill(Color.red).frame(width: 1, height: h)
                        .position(x: w * CGFloat(Double(model.currentMs) / dur), y: h / 2)
                        .allowsHitTesting(false)
                }
            }
            HStack(spacing: 6) {
                ForEach(["flash", "ui_value_changed", "text_changed", "entity", "scene"], id: \.self) { t in
                    HStack(spacing: 2) { Circle().fill(Self.color(t)).frame(width: 6, height: 6); Text(t) }
                }
            }
            .font(.system(size: 9)).foregroundColor(.secondary)
        }
    }

    static func row(_ type: String) -> Int {
        switch type {
        case "flash": return 0
        case "ui_value_changed": return 1
        case "text_changed": return 2
        default: return 3
        }
    }

    static func color(_ type: String) -> Color {
        switch type {
        case "flash": return .red
        case "ui_value_changed": return .cyan
        case "text_changed": return .yellow
        case "scene_changed", "scene": return .purple
        case "confidence_warning": return .orange
        default: return .green
        }
    }
}

// MARK: - Ask box (POST /ask)

struct AskPanel: View {
    @ObservedObject var model: ReviewModel
    @ObservedObject var engine: EngineSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Ask the engine").font(.headline)
                Spacer()
                if !engine.events.isEmpty || !engine.modes.isEmpty {
                    Text("\(engine.modes.count) frames · \(engine.events.count) events").font(.caption).foregroundColor(.secondary)
                }
            }
            HStack(spacing: 6) {
                TextField("e.g. When did health first drop?", text: $engine.question)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { engine.ask() }
                Button(engine.isAsking ? "…" : "Ask") { engine.ask() }
                    .disabled(engine.isAsking || engine.question.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if engine.isAsking { ProgressView().controlSize(.small) }
                    if let err = engine.askError { Text(err).font(.caption).foregroundColor(.red).textSelection(.enabled) }
                    if let a = engine.answer {
                        Text(a).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        if let t = engine.contextTokens {
                            Text("context_tokens: \(t)").font(.caption.monospacedDigit()).foregroundColor(.secondary)
                        }
                    }
                    if !engine.askEvidence.isEmpty {
                        Text("Evidence").font(.caption.weight(.semibold))
                        FlowRow(items: engine.askEvidence) { ev in
                            Button("f\(ev.f)") {
                                model.seek(toMs: engine.ms(forFrame: ev.f))
                                engine.shownCrop = engine.resolve(ev.crop)
                                AppLog.log("engine_stage", ["name": "ask_ui", "phase": "evidence_click", "f": ev.f])
                            }
                            .buttonStyle(.link)
                            .font(.caption.monospacedDigit())
                        }
                    }
                    if let p = engine.shownCrop, let img = NSImage(contentsOfFile: p) {
                        Image(nsImage: img).resizable().interpolation(.none).aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 140).cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 1))
                        Text((p as NSString).lastPathComponent).font(.caption2).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
    }
}

/// Simple wrapping row of small buttons.
struct FlowRow<Item: Identifiable & Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) { self.items = items; self.content = content }
    var body: some View {
        let rows = stride(from: 0, to: items.count, by: 6).map { Array(items[$0..<min($0 + 6, items.count)]) }
        VStack(alignment: .leading, spacing: 2) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 8) { ForEach(rows[i]) { content($0) } }
            }
        }
    }
}

// MARK: - Bounding boxes at the exact playhead frame

/// Engine session → per-frame replayed state (solid = observed, dashed = propagated, dotted+faded = inferred/occluded).
/// No session → 1 fps Claude records, linearly interpolated by entity id so boxes still move.
struct BoxOverlay: View {
    @ObservedObject var model: ReviewModel
    @ObservedObject var engine: EngineSessionModel

    var body: some View {
        GeometryReader { geo in
            if model.showBoxes {
                let fit = AVMakeRect(aspectRatio: model.videoSize, insideRect: CGRect(origin: .zero, size: geo.size))
                if let eb = engine.boxes(atMs: model.currentMs) {
                    ForEach(eb, id: \.id) { b in
                        let r = rect(b.bbox, fit)
                        let style: StrokeStyle = b.source == "observed" ? StrokeStyle(lineWidth: 2)
                            : b.source == "propagated" ? StrokeStyle(lineWidth: 2, dash: [6, 4])
                            : StrokeStyle(lineWidth: 1.5, dash: [1.5, 3])
                        let col = entityColor(b.type == "object" ? "enemy" : b.type)
                        boxView(r: r, color: col, style: style, text: "\(b.id) \(b.label) \(Int(b.conf * 100))%")
                            .opacity(b.source == "inferred" || !b.visible ? 0.45 : 1)
                    }
                } else {
                    ForEach(Array(model.interpolatedEntities(atMs: model.currentMs).enumerated()), id: \.offset) { _, e in
                        if let bb = e.bbox, bb.count == 4 {
                            boxView(r: rect(bb, fit), color: entityColor(e.type), style: StrokeStyle(lineWidth: 2),
                                    text: "\(e.label) \(Int(e.confidence * 100))%")
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func rect(_ b: [Double], _ fit: CGRect) -> CGRect {
        CGRect(x: fit.minX + b[0] * fit.width, y: fit.minY + b[1] * fit.height, width: b[2] * fit.width, height: b[3] * fit.height)
    }

    private func boxView(r: CGRect, color: Color, style: StrokeStyle, text: String) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().stroke(color, style: style)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .fixedSize()
                .padding(.horizontal, 3)
                .background(color.opacity(0.85))
                .foregroundColor(.black)
                .offset(y: -14)
        }
        .frame(width: max(r.width, 1), height: max(r.height, 1))
        .position(x: r.midX, y: r.midY)
    }
}
