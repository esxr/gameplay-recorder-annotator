import AppKit
import SwiftUI

/// Full-width scrubber: playhead + one marker per annotation record.
/// Blue ticks = sample_1fps, purple = scene_change, yellow dot on top = record has events.
struct TimelineBar: View {
    @ObservedObject var model: ReviewModel
    @State private var loggedCount: Int = -1

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: model.togglePlay) {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                }.buttonStyle(.borderless)
                Text("\(formatMs(model.currentMs)) / \(formatMs(model.durationMs))")
                    .font(.caption.monospacedDigit()).foregroundColor(.secondary)
                Spacer()
                Text("\(model.records.count) markers · \(model.jsonlLineCount) lines" +
                     (model.malformedLineCount > 0 ? " · \(model.malformedLineCount) malformed" : "") +
                     " · ←/→ jump")
                    .font(.caption).foregroundColor(.secondary)
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let dur = Double(model.durationMs)
                ZStack(alignment: .topLeading) {
                    // track
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                        .frame(width: w, height: h)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                            let ms = Int(max(0, min(1, v.location.x / max(w, 1))) * dur)
                            model.seek(toMs: ms)
                        })
                    // progress
                    Rectangle().fill(Color.white.opacity(0.10))
                        .frame(width: w * CGFloat(Double(model.currentMs) / dur), height: h)
                        .allowsHitTesting(false)
                    // markers
                    ForEach(model.records) { r in
                        let x = w * CGFloat(Double(r.t_ms) / dur)
                        let selected = r.frame == model.selectedFrame
                        let isScene = r.trigger == "scene_change"
                        ZStack(alignment: .top) {
                            Rectangle().fill(Color.clear).frame(width: 9, height: h)  // hit area
                            Rectangle()
                                .fill(isScene ? Color.purple : Color.accentColor)
                                .frame(width: selected ? 4 : 2, height: isScene ? h - 6 : h - 14)
                                .offset(y: isScene ? 6 : 14)
                                .overlay(selected ? Rectangle().stroke(Color.white, lineWidth: 1).offset(y: isScene ? 6 : 14) : nil)
                            if !r.events.isEmpty {
                                Circle().fill(Color.yellow).frame(width: 6, height: 6).offset(y: 1)
                            }
                        }
                        .frame(width: 9, height: h)
                        .contentShape(Rectangle())
                        .position(x: x, y: h / 2)
                        .onTapGesture { model.select(r) }
                        .help("\(formatMs(r.t_ms)) · \(r.trigger) · \(r.scene)")
                    }
                    // playhead
                    Rectangle().fill(Color.red)
                        .frame(width: 2, height: h + 4)
                        .position(x: w * CGFloat(Double(model.currentMs) / dur), y: h / 2)
                        .allowsHitTesting(false)
                }
            }
        }
        .onAppear { logIfNeeded() }
        .onChange(of: model.records.count) { _, _ in logIfNeeded() }
    }

    private func logIfNeeded() {
        let n = model.records.count
        guard n != loggedCount else { return }
        loggedCount = n
        AppLog.log("review_markers", ["count": n, "jsonl_lines": model.jsonlLineCount])
    }
}
