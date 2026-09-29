import AVFoundation
import AVKit
import AppKit
import SwiftUI

// MARK: - Root

struct ReviewRootView: View {
    @ObservedObject var model: ReviewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VideoPane(model: model)
                    .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                AnnotationSidebar(model: model)
                    .frame(width: 340)
            }
            Divider()
            VStack(spacing: 4) {
                TimelineBar(model: model)
                    .frame(height: 64)
                if model.engine.hasSession {
                    EventsLane(model: model, engine: model.engine)
                        .frame(height: 30)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color.black)
    }
}

// MARK: - Video + bbox overlay

struct PlayerViewRep: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .inline
        v.videoGravity = .resizeAspect
        v.showsFullScreenToggleButton = true
        return v
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player { nsView.player = player }
    }
}

struct VideoPane: View {
    @ObservedObject var model: ReviewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlayerViewRep(player: model.player)
            RegionOverlay(model: model, engine: model.engine)
            GeometryReader { geo in
                if model.showBoxes, let rec = model.selectedRecord {
                    let fit = AVMakeRect(aspectRatio: model.videoSize, insideRect: CGRect(origin: .zero, size: geo.size))
                    ForEach(Array(rec.entities.enumerated()), id: \.offset) { _, e in
                        if let b = e.bbox, b.count == 4 {
                            let r = CGRect(x: fit.minX + b[0] * fit.width, y: fit.minY + b[1] * fit.height,
                                           width: b[2] * fit.width, height: b[3] * fit.height)
                            ZStack(alignment: .topLeading) {
                                Rectangle().stroke(color(for: e.type), lineWidth: 2)
                                Text("\(e.label) \(Int(e.confidence * 100))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 3)
                                    .background(color(for: e.type).opacity(0.85))
                                    .foregroundColor(.black)
                                    .offset(y: -14)
                            }
                            .frame(width: max(r.width, 1), height: max(r.height, 1))
                            .position(x: r.midX, y: r.midY)
                        }
                    }
                }
            }
            .allowsHitTesting(false)

            HStack(spacing: 8) {
                Toggle("Show boxes", isOn: $model.showBoxes)
                    .toggleStyle(.checkbox)
                if model.isGrowing {
                    Label("Annotating… \(model.records.count) records", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange.opacity(0.85)))
                        .foregroundColor(.black)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.45)))
            .padding(10)

            VStack {
                Spacer()
                RegionLegend(model: model, engine: model.engine)
                    .padding(.bottom, 60)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func color(for type: String) -> Color { entityColor(type) }
}

func entityColor(_ type: String) -> Color {
    switch type.lowercased() {
    case "player", "character", "self": return .green
    case "enemy", "npc", "opponent": return .red
    case "item", "pickup", "loot": return .yellow
    case "ui", "hud", "text", "ui_element": return .cyan
    case "projectile", "vehicle": return .orange
    default: return .pink
    }
}

// MARK: - Sidebar

struct AnnotationSidebar: View {
    @ObservedObject var model: ReviewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Annotation").font(.headline)
                Spacer()
                Text("\(model.records.count) records").font(.caption).foregroundColor(.secondary)
                Toggle("List", isOn: $model.showList).toggleStyle(.switch).controlSize(.mini)
            }
            .padding(10)
            Divider()
            ScrollView {
                if let r = model.selectedRecord {
                    RecordDetail(record: r)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(model.records.isEmpty ? "Waiting for annotations…" : "Select a marker")
                        .foregroundColor(.secondary).padding()
                }
            }
            if model.showList {
                Divider()
                RecordList(model: model).frame(height: model.engine.hasSession ? 120 : 230)
            }
            Divider()
            AskPanel(model: model, engine: model.engine)
                .frame(height: model.engine.hasSession ? 300 : 170)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

func formatMs(_ ms: Int) -> String {
    let s = ms / 1000
    return String(format: "%d:%02d.%03d", s / 60, s % 60, ms % 1000)
}

struct RecordDetail: View {
    let record: AnnotationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let img = NSImage(contentsOfFile: record.evidence_frame) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity).cornerRadius(4)
            }
            grid([
                ("Time", formatMs(record.t_ms)),
                ("Frame", "\(record.frame)"),
                ("Trigger", record.trigger),
                ("Scene", record.scene),
                ("Confidence", String(format: "%.2f", record.confidence)),
                ("Model", record.model),
            ])
            section("Entities (\(record.entities.count))") {
                ForEach(Array(record.entities.enumerated()), id: \.offset) { _, e in
                    HStack(spacing: 6) {
                        Circle().fill(entityColor(e.type)).frame(width: 7, height: 7)
                        Text(e.label).lineLimit(1)
                        Text(e.type).foregroundColor(.secondary).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.2f", e.confidence)).monospacedDigit().foregroundColor(.secondary)
                    }.font(.caption)
                }
            }
            section("HUD (\(record.hud.count))") {
                ForEach(record.hud.keys.sorted(), id: \.self) { k in
                    HStack(alignment: .top) {
                        Text(k).foregroundColor(.secondary)
                        Spacer()
                        Text(record.hud[k] ?? "").multilineTextAlignment(.trailing)
                    }.font(.caption)
                }
            }
            section("Text (\(record.text.count))") {
                ForEach(Array(record.text.enumerated()), id: \.offset) { _, t in
                    Text("“\(t)”").font(.caption).textSelection(.enabled)
                }
            }
            section("Events (\(record.events.count))") {
                ForEach(Array(record.events.enumerated()), id: \.offset) { _, ev in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text(ev.type).bold()
                            Spacer()
                            Text(String(format: "%.2f", ev.confidence)).monospacedDigit().foregroundColor(.secondary)
                        }
                        Text(ev.description).foregroundColor(.secondary)
                    }.font(.caption)
                }
            }
        }
    }

    private func grid(_ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(rows, id: \.0) { k, v in
                HStack(alignment: .top) {
                    Text(k).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                    Text(v).textSelection(.enabled)
                    Spacer(minLength: 0)
                }.font(.callout)
            }
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
    }
}

struct RecordList: View {
    @ObservedObject var model: ReviewModel

    var body: some View {
        ScrollViewReader { proxy in
            List(model.records) { r in
                HStack(spacing: 6) {
                    Circle().fill(r.trigger == "scene_change" ? Color.purple : Color.accentColor).frame(width: 6, height: 6)
                    Text(formatMs(r.t_ms)).monospacedDigit()
                    Text(r.scene).lineLimit(1).foregroundColor(.secondary)
                    Spacer()
                    if !r.events.isEmpty { Image(systemName: "bolt.fill").foregroundColor(.yellow) }
                    Text("\(r.entities.count)").foregroundColor(.secondary)
                }
                .font(.caption)
                .padding(.vertical, 1)
                .contentShape(Rectangle())
                .listRowBackground(r.frame == model.selectedFrame ? Color.accentColor.opacity(0.35) : Color.clear)
                .onTapGesture { model.select(r) }
                .id(r.frame)
            }
            .listStyle(.plain)
            .onChange(of: model.selectedFrame) { _, f in
                if let f { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(f, anchor: .center) } }
            }
        }
    }
}
