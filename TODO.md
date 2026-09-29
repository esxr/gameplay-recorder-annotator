# TODO — Gameplay Recorder (goal: GOAL.md, deadline 2026-09-30 04:00 AEST)

| # | Task | Owner | Files | Status |
|---|------|-------|-------|--------|
| T0 | Scaffold: xcodegen project, build.sh (stable signing), Contracts.swift, API key | orchestrator | app/project.yml, app/build.sh, Sources/Shared | done 03:05 |
| T1 | Cmd+Shift+5 toolbar clone + portion selection overlay + screenshot modes (G1) | agent-toolbar | Sources/Toolbar | in progress 03:02 |
| T2 | ScreenCaptureKit → AVAssetWriter 60 fps H.264 recorder (G2) | agent-recorder | Sources/Recording | done 03:06 (ffprobe 60/1 h264 full+portion) |
| T3 | Frame extraction (1 fps + scene change) + Claude vision → JSONL (G3) | agent-annotator | Sources/Annotation | in progress 03:02 |
| T4 | Review window: AVPlayer + timeline markers + annotation panel (G4) | agent-review | Sources/Review | done 03:07 (harness: 20 markers = 20 lines) |
| T5 | Integration: AppDelegate wiring, menu-bar stop item, hotkey | orchestrator | Sources/App | wired, awaiting modules |
| T6 | Proofs G1-G5 in proofs/ + e2e recording | orchestrator | proofs/ | todo |
