# GOAL: macOS recorder app records + annotates gameplay by 2026-09-30 04:00 AEST

Repo root `/Users/pranav/Desktop/gameplay_recorder_annotator`; app in `app/` (SwiftUI + ScreenCaptureKit, Swift 6.4, macOS 26.6). Spec: `knowledge/` wiki (read via `/llm-wiki`); annotation fields follow `knowledge/wiki/concepts/semantic-annotation-taxonomy.md`. Times AEST.

**Rules**
- First action: write `TODO.md` (1 line per task, owner agent, status); update it at each task finish. Run ≥ 4 subagents in parallel on separate files.
- Sign-ups: pranav@operantlabs.com Google via Bitwarden (`BW_MASTER_PASSWORD` env). Payments: Bitwarden card "openslate" only, ≤ $20 total. Never write secrets to git or logs.
- Browser: `/browser-harness` with `my-browser`; each agent opens its own new window and never activates or focuses it.

**Proof: made by the agent; Pranav checks nothing**
- Save to `proofs/G<n>-*`; open every PNG (Read tool) and name what it shows. Retake blank, error or permission-dialog shots.

## G1: Capture toolbar matches Cmd+Shift+5 with 5 mode buttons + Options + Record
- TO-DO: Borderless floating toolbar, bottom-center, dark vibrancy: close ✕, Capture Entire Screen, Capture Selected Window, Capture Selected Portion, Record Entire Screen, Record Selected Portion, "Options" menu, "Record" button; Esc closes.
- NOT TO-DO: No standard titled window, no web view, no calling `screencapture` for the UI.
- PROOF: `proofs/G1-native.png` (real Cmd+Shift+5) and `proofs/G1-app.png` side by side in `proofs/G1-compare.png`: same 5 mode icons in same order, same position ±40 px.
- NOT-PROOF: A Figma/HTML mockup. Xcode preview canvas.

## G2: Records 60 fps MP4 ≥ 30 s from screen and portion modes
- TO-DO: ScreenCaptureKit + AVAssetWriter, H.264, 60 fps; menu-bar stop button; save to `~/Movies/GameplayRecorder/`.
- NOT TO-DO: No shelling out to `screencapture -v` or ffmpeg for capture.
- PROOF: `ffprobe` on 2 files (full screen, selected portion): codec h264, `r_frame_rate` 60/1, duration ≥ 30 s, portion file smaller width than full; output in `proofs/G2-ffprobe.txt`.
- NOT-PROOF: A 0-byte or < 5 s file. A 30 fps file.

## G3: Annotation starts ≤ 5 s after stop, writes ≥ 1 record per sampled second
- TO-DO: On stop, extract frames at 1 fps + on scene change; send to Claude vision (key in `.secrets/anthropic.env`); write `<video>.annotations.jsonl` with `t_ms, frame, scene, entities[], hud{}, text[], events[], confidence, evidence_frame`.
- NOT TO-DO: No hardcoded or fake annotations; no blocking the UI thread.
- PROOF: For a 30 s recording of live screen activity: log line `annotation_started` ≤ 5 s after `recording_stopped`; JSONL has ≥ 30 lines, all parse with `jq`, ≥ 80% have non-empty `entities` or `hud`; `proofs/G3-sample.json` with 3 lines checked against their frames.
- NOT-PROOF: Output from a static image. A JSONL written by a test stub.

## G4: Review window plays video with timeline annotations for 100% of records
- TO-DO: AVPlayer + scrubber with markers; clicking a marker seeks and shows that record's fields.
- NOT TO-DO: No separate web app.
- PROOF: `proofs/G4-review.png` showing video, ≥ 10 markers and an open annotation panel; count of markers in app log = JSONL line count.
- NOT-PROOF: Screenshot with empty timeline.

## G5: .app builds and runs end-to-end in 1 take
- TO-DO: `xcodebuild -scheme GameplayRecorder build` → `build/GameplayRecorder.app`; record 60 s of gameplay → stop → annotate → review.
- NOT TO-DO: No run only from Xcode debugger.
- PROOF: build log ends `** BUILD SUCCEEDED **` with 0 errors; `proofs/G5-e2e.mp4` ≥ 90 s (ffprobe) showing toolbar → record → annotation progress → review.
- NOT-PROOF: Separate clips stitched together. Unit tests alone.

## Done when
G1-G5 PROOFs exist in `proofs/`, all rows in `TODO.md` are done, and Pranav replies "ship".
