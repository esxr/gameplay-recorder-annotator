# GOAL: Full PRD pipeline runs on app recordings by 2026-09-30 05:00 AEST

Part 2 of `GOAL.md`. Spec: `knowledge/raw/semantic-video-state-engine-prd.md` §12-§40, §63 (7 scope items), §65 (9 acceptance criteria). Engine in `engine/` (Python, `.venv` only), run by the app on every stop. Times AEST.

**Rules**
- Test input: `testgame/` HTML game (moving enemies, HUD health/ammo, objective text, 1- and 2-frame hit flashes) writing `truth.jsonl` per frame; played in a new `my-browser` window, never focused; recorded by `build/GameplayRecorder.app`.
- Only RE-INFER/FULL REFRESH regions call Claude (key in `.secrets/anthropic.env`).

**Proof: made by the agent; Pranav checks nothing**
- `proofs/pipeline-G<n>-*`; `engine/report.py <session>` prints every metric below; open every PNG.

## G1: 100% of frames on timeline; ≥ 70% region-frames skip VLM
- TO-DO: 8×6 region grid; per region per frame pick COPY / PROPAGATE / REVALIDATE / RE-INFER / FULL REFRESH (§12) from pixel residual, motion, confidence decay; scene cut → FULL REFRESH.
- NOT TO-DO: No 1 fps sampling as the timeline; no VLM call per frame.
- PROOF: `stream` frame count = ffprobe `nb_frames`; mode histogram with all 5 modes > 0; COPY+PROPAGATE+REVALIDATE ≥ 70%; VLM calls ≤ 5% of frames (`pipeline-G1-report.txt`).
- NOT-PROOF: Frame count from the 1 fps JSONL. Modes set by a constant.

## G2: State at any frame rebuilt from snapshot + deltas, 20/20 match
- TO-DO: Snapshot every 300 frames, per-frame deltas (∅ allowed), event records, evidence refs, long-term summary (§19-§20, §25); same entity id for the same object across frames.
- NOT TO-DO: No full snapshot per frame.
- PROOF: `get_state(N)` for 20 random N equals direct replay state 20/20; stored size ≥ 10× smaller than dense per-frame JSON; identity switches ≤ 5% vs `truth.jsonl`.
- NOT-PROOF: Match checked only on snapshot frames.

## G3: 1- and 2-frame events found at exact frame, ≥ 9/10
- TO-DO: Detect short flashes and HUD value changes between samples (§33); emit `ui_value_changed`, `event_started` (§40).
- NOT TO-DO: No reading `truth.jsonl` inside the engine.
- PROOF: 10 flashes in `truth.jsonl` → ≥ 9 events with frame index ±0; HUD health/ammo values correct on ≥ 90% of changes; same clip at 1 fps finds ≤ 3 (`pipeline-G3-report.txt`).
- NOT-PROOF: Events found on a synthetic ffmpeg clip only.

## G4: 100% of claims carry evidence, confidence, provenance
- TO-DO: Every field stores `source` (observed/propagated/inferred), confidence, frame, bbox, crop path; propagated confidence decays (§30).
- NOT TO-DO: No field without provenance.
- PROOF: `report.py` 0 fields missing provenance; mean confidence propagated < observed; `pipeline-G4-evidence.png` of 5 crops with their claims.
- NOT-PROOF: Evidence paths that do not open.

## G5: 8 query ops return data; LLM answers ≥ 8/10 §53-style questions
- TO-DO: `get_state, get_changes, get_entity_history, get_events, search_semantics, get_evidence, compile_context, reanalyze` (§39) over HTTP; `compile_context` fits a token budget (§28).
- NOT TO-DO: No raw frames to the answering LLM.
- PROOF: `pipeline-G5-api.txt` 8 curl calls, HTTP 200, non-empty; 10 questions with answers from `truth.jsonl` written first; Claude via `compile_context` ≤ 4,000 tokens gets ≥ 8/10; tokens ≤ 10% of all-frame input.
- NOT-PROOF: Questions written after seeing answers.

## G6: App runs whole pipeline and answers 1 question in the review window
- TO-DO: On stop the app runs `engine/`; review window shows region modes, events, "Ask" box with answer + evidence frame link.
- NOT TO-DO: No manual engine run for this proof.
- PROOF: app log has all 7 stages `capture, change, schedule, state, store, compile, answer` for 1 session; `pipeline-G6-ask.png` shows question, answer, evidence frame.
- NOT-PROOF: Engine run from terminal only.

## Done when
G1-G6 PROOFs exist in `proofs/`, `GOAL.md` is done, and Pranav replies "ship".
