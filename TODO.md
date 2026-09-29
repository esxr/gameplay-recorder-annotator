# TODO — Gameplay Recorder (goal: GOAL.md, deadline 2026-09-30 04:00 AEST)

| # | Task | Owner | Files | Status |
|---|------|-------|-------|--------|
| T0 | Scaffold: xcodegen project, build.sh (stable signing), Contracts.swift, API key | orchestrator | app/project.yml, app/build.sh, Sources/Shared | done 03:05 |
| T1 | Cmd+Shift+5 toolbar clone + portion selection overlay + screenshot modes (G1) | agent-toolbar | Sources/Toolbar | done 03:16 (G1-compare.png: 6 modes, same position) |
| T2 | ScreenCaptureKit → AVAssetWriter 60 fps H.264 recorder (G2) | agent-recorder | Sources/Recording | done 03:06 (ffprobe 60/1 h264 full+portion) |
| T3 | Frame extraction (1 fps + scene change) + Claude vision → JSONL (G3) | agent-annotator | Sources/Annotation | done 03:12 (20/20 lines, 100% non-empty) |
| T4 | Review window: AVPlayer + timeline markers + annotation panel (G4) | agent-review | Sources/Review | done 03:07 (harness: 20 markers = 20 lines) |
| T5 | Integration: AppDelegate wiring, menu-bar stop item, hotkey | orchestrator | Sources/App | BUILD SUCCEEDED 03:10 |
| T6 | Proofs G1-G5 in proofs/ + e2e recording | orchestrator | proofs/ | G1 G2 G3 G4 done; G5 e2e in progress 03:30 |

## Part 2 — GOAL-pipeline.md (deadline 05:00 AEST)
| # | Task | Owner | Files | Status |
|---|------|-------|-------|--------|
| P0 | Contract, .venv (numpy+PIL copied locally; PyPI unreachable), `grctl record x,y,w,h` hook | orchestrator | engine/CONTRACT.md, app/Sources/App | done 03:47 |
| P1 | Test game + truth.jsonl + recording of it via app (no focus steal) | agent-testgame | testgame/ | redo: native 60 Hz game in normal background window + window-ID capture (browser run invalid: wrong screen, 30 fps) |
| P2 | Engine core: decode every frame, 8×6 change analysis, 5-mode scheduler, tracker ids, HUD OCR, flashes, VLM on R/F, snapshot+delta store, evidence | agent-engine | engine/core/, engine/run.py | in progress 03:47 |
| P3 | Query API (8 ops) + HTTP server + context compiler + /ask + report.py eval + 1 fps baseline | agent-api | engine/api.py, engine/server.py, engine/report.py | code done 03:57 (synthetic session: 20/20 reconstruct, 8/8 HTTP); awaiting valid capture |
| P4 | App: run engine on stop, stage logs, review window region modes + events + Ask box | agent-appint | app/Sources/Review, app/Sources/Pipeline | done 03:53 (build ok; tested w/ fake session) |
| P5 | Proofs pipeline-G1..G6 | orchestrator | proofs/ | todo |
| P6 | Fix static bboxes: per-frame engine entity boxes at playhead (observed/propagated/inferred styles) + 1 fps interpolation fallback | agent-appint | app/Sources/Review | in progress 04:08 (user bug) |
