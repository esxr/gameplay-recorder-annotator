# Engine contract (owned by orchestrator — change only by agreement)

Implements `GOAL-pipeline.md` (PRD §12-§40, §63, §65). Python 3.13 in `/Users/pranav/Desktop/gameplay_recorder_annotator/.venv` only.

## Session layout
`engine run <video.mp4>` → session dir `<video>.session/`:
- `stream.jsonl` — ONE line per decoded video frame (count must equal ffprobe nb_frames):
  `{"f": int, "t_ms": float, "kind": "snapshot"|"delta", "modes": "<48 chars>", "delta": {...} | "state": {...}, "vlm": bool}`
  - `modes`: 8 cols × 6 rows region grid, row-major, one char per region: C=COPY P=PROPAGATE V=REVALIDATE R=RE-INFER F=FULL REFRESH
  - snapshot every 300 frames (f % 300 == 0) and on FULL REFRESH scene cut; else delta (may be `{}` = ∅)
- `events.jsonl` — `{"id","type","f_start","f_end","t_ms","entity"?,"from"?,"to"?,"confidence","source","evidence":{"f","bbox","crop"}}`
  types: `flash`, `ui_value_changed`, `text_changed`, `entity_created`, `entity_removed`, `scene_changed`, `confidence_warning`
- `summary.json` — long-term summary per 10 s window (§25), plus session stats
- `evidence/` — crops `f<frame>_<id>.jpg`
- `meta.json` — fps, nb_frames, width, height, grid, model ids, stage timings

## State (what snapshot "state" holds and deltas change)
```
{"scene": {"label": field, "id": str},
 "entities": {"<id>": {"type": field, "label": field, "bbox": field, "visible": field}},
 "hud": {"<name>": field},          # e.g. health, ammo, score
 "text": {"<region_id>": field}}    # OCR text by region
field = {"v": value, "conf": 0..1, "source": "observed"|"propagated"|"inferred", "f": frame_observed, "bbox": [x,y,w,h] normalized, "crop": "evidence/…jpg"|null}
```
Delta = JSON-merge-patch of state vs previous frame (keys → new field or null for removal).
`get_state(N)` = nearest snapshot ≤ N + apply deltas up to N.

## Python API (`engine/api.py`) and HTTP (`engine/server.py`, port 8765)
`get_state(session, f)`, `get_changes(session, f0, f1)`, `get_entity_history(session, entity_id)`,
`get_events(session, f0, f1, type=None)`, `search_semantics(session, query)`, `get_evidence(session, annotation_id)`,
`compile_context(session, query, token_budget=4000)`, `reanalyze(session, f0, f1, region=None, fidelity="high")`.
HTTP: `GET /<op>?session=<dir>&...` → JSON. `POST /ask {session, question}` → `{answer, context_tokens, evidence:[{f,crop}]}`.

## Stage logging
Engine prints `STAGE <name> key=value…` lines for: capture, change, schedule, state, store, compile, answer.
App forwards them into `~/Library/Logs/GameplayRecorder/app.log` as `engine_stage name=<name> …`.

## Test game ground truth (`testgame/`)
`truth.jsonl`: one line per game frame `{"gf": int, "sync": int, "hud": {"health","ammo","score"}, "objective": str, "enemies": [{"id","x","y","w","h"}], "flash": bool}`.
The game draws a sync barcode (16-bit frame number, top-left 16 squares) so eval (`report.py` only) can map video frame → game frame. The engine must never read truth.jsonl or the barcode.
