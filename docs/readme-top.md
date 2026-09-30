# Gameplay Recorder Annotator

**The Semantic Video State Engine turns every moment of high-frame-rate video into a persistent, evidence-grounded machine world state while spending expensive vision compute primarily on what actually changed.**

A macOS screen recorder with the same toolbar as the built-in one (⇧⌘5), plus an engine that converts each 60 fps recording into a queryable semantic state stream. You can then ask Claude questions about the recording and get answers that cite exact frames.

![Demo: 3D city gameplay recorded with the app → review window with region modes, annotations, events and an answered question](docs/demo.gif)

<sub>Demo: a 3D city game (Roblox) recorded with the app at 60 fps, shown cropped to the game viewport and sped up. The review window then shows the 8×6 region-mode grid, the 1 fps Claude annotations, the events lane and an answer from the engine that cites evidence frames.</sub>

## Quick start

Requirements: macOS 15+ with Xcode, [Homebrew](https://brew.sh), Python 3.11+ and an Anthropic API key. The key is read from `ANTHROPIC_API_KEY` or `.secrets/anthropic.env`, and is needed only for Claude annotation and answers.

```sh
git clone https://github.com/esxr/gameplay-recorder-annotator.git && cd gameplay-recorder-annotator
brew install xcodegen ffmpeg tesseract && python3 -m venv .venv && .venv/bin/pip install -r engine/requirements.txt
app/build.sh && open build/GameplayRecorder.app
.venv/bin/python engine/run.py samples/city-3d.mp4
.venv/bin/python engine/api.py samples/city-3d.mp4.session ask "When did the cash first increase, and by how much?"
```

1. Clone the repo.
2. Install the tools and the engine's Python packages.
3. Build and open the app. It lives in the menu bar. Press **⌥⌘5** to show the capture toolbar, choose a mode, then press **Record**. Stop from the menu-bar item. The first recording asks for the Screen Recording permission. On stop, the app annotates the recording, runs the engine and opens the review window.
4. Run the engine on the bundled 10 s clip of 3D gameplay. This writes `samples/city-3d.mp4.session/` (`stream.jsonl`, `events.jsonl`, `summary.json`, `evidence/`, `meta.json`).
5. Ask a question. The engine compiles at most 4,000 tokens of state for Claude, sends no raw frames, and prints the answer with its evidence frames.

To query over HTTP, run `.venv/bin/python engine/server.py`. It serves port 8765 with `GET /get_state`, `/get_changes`, `/get_entity_history`, `/get_events`, `/search_semantics`, `/get_evidence`, `/compile_context` and `/reanalyze`, plus `POST /ask`. See [`engine/CONTRACT.md`](engine/CONTRACT.md).

## Results

The engine was measured on a 76 s, 60 fps app recording of the [test game](testgame/). It was scored against the game's own per-frame ground truth, which only the evaluator reads (`engine/report.py`).

| Check | Result | Proof |
|---|---|---|
| Frames on the timeline | 4580 / 4580 (= ffprobe `nb_frames`) | [pipeline-G1-report.txt](proofs/pipeline-G1-report.txt) |
| Region-frames that skip the vision model (COPY + PROPAGATE + REVALIDATE) | 99.58% | [pipeline-G1-report.txt](proofs/pipeline-G1-report.txt) |
| Frames that call the vision model | 20 / 4580 = 0.44% | [pipeline-G1-report.txt](proofs/pipeline-G1-report.txt) |
| State rebuilt from snapshot + deltas = direct replay | 20 / 20 | [pipeline-G2-report.txt](proofs/pipeline-G2-report.txt) |
| Storage vs dense per-frame JSON | 14.3× smaller | [pipeline-G2-report.txt](proofs/pipeline-G2-report.txt) |
| Identity switches | 0.37% | [pipeline-G2-report.txt](proofs/pipeline-G2-report.txt) |
| 1- and 2-frame flashes found at the exact frame | 10 / 10 (1 fps sampling: 0 / 10) | [pipeline-G3-report.txt](proofs/pipeline-G3-report.txt) |
| HUD changes at the exact frame with the correct value | health 10 / 10, ammo 31 / 31 | [pipeline-G3-report.txt](proofs/pipeline-G3-report.txt) |
| State fields missing provenance | 0 of 89920 | [pipeline-G4-report.txt](proofs/pipeline-G4-report.txt) |
| Query ops over HTTP returning 200 | 8 / 8 | [pipeline-G5-api.txt](proofs/pipeline-G5-api.txt) |
| Questions answered correctly (claude-sonnet-5-5, questions frozen before answering) | 9 / 10 | [pipeline-G5-report.txt](proofs/pipeline-G5-report.txt) |
| Largest compiled context | 3849 tokens (0.084% of all-frame image input) | [pipeline-G5-report.txt](proofs/pipeline-G5-report.txt) |
| In-app run: all 7 stages, then an answered question | capture → change → schedule → state → store → compile → answer | [pipeline-G6-applog.txt](proofs/pipeline-G6-applog.txt), [pipeline-G6-ask.png](proofs/pipeline-G6-ask.png) |

## Repository layout

| Path | What it is |
|---|---|
| [`app/`](app/) | SwiftUI/AppKit recorder: toolbar clone, ScreenCaptureKit → H.264 60 fps writer, Claude annotation, review window |
| [`engine/`](engine/) | Semantic Video State Engine (Python): region scheduler, tracker, HUD OCR, events, snapshot + delta store, query API, context compiler |
| [`testgame/`](testgame/) | 60 Hz test game that writes per-frame ground truth (used for the results below) |
| [`samples/`](samples/) | `city-3d.mp4`: first 10 s of the demo recording, for the Quick start |
| [`proofs/`](proofs/) | Evidence for every result above |
| [`docs/`](docs/) | Demo GIF and Excalidraw diagrams (`docs/diagrams/*.excalidraw`) |
| [`knowledge/`](knowledge/) | Project wiki, including the source PRD ([`knowledge/raw/semantic-video-state-engine-prd.md`](knowledge/raw/semantic-video-state-engine-prd.md)) |

---

The rest of this README is the product requirements document it was built from.

