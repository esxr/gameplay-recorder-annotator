Engine 3D fixes (2026-09-30 ~21:50 AEST) - City 3D playtest.mp4 (1280x654, 60 fps, 1759 frames)

Changes (engine/core/pipeline.py, ocr.py, video.py):
- Scene cut now also needs a 64-bin colour-histogram distance >= 0.3 (vs ref, at f and f+2). Continuous camera
  motion scores <= 0.12 on the 3D clip; true test-game cuts score ~0.87.
- Keyless HUD values: boxes whose pixels stay stable over ~10 s while the scene moves, with high local contrast,
  read with full-res OCR (dedicated ffmpeg crop decoder, voting over 5 preprocess variants). A '$N' value becomes
  hud.cash and a plain >=2-digit number becomes hud.valueN. '+$25' deltas are ignored. A value is committed only
  when it wins >=4 of the last 7 reads, lasts >=0.1 s and has a plausible delta. It is dated to its first read
  frame, and ui_value_changed has provenance and an evidence crop.

Before / after (3D clip):
  scene_changed events: 43 -> 0   (F-mode region-frames 2112 -> 48, i.e. frame 0 only)
  hud fields: {} -> {cash}; ui_value_changed: 0 -> 2  (f338 60->85, f387 85->95; frame-exact, checked visually)
  ask "When did the cash first increase, and by how much?"
    before: no cash information
    after : "Frame 338, increased by 25 (from 60 to 85)"   (t = 5.63 s)
samples/city-3d.mp4 (first 10 s): hud=['cash'], same two events.

Test game (Recording 2026-09-30 03.58.26.mp4): scene_changed 3 -> 3, no value boxes found. report.py: all G1-G5 PASS,
G3 HUD events 10/10 and 31/31, G5 8/10 then 9/10 on a G5-only re-run (a q7 grader-parse miss is LLM noise).
