---
title: Frame Identity and Capture
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [capture, timeline, determinism]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [4.1, 11, 31, 32, 34, 35, 38, 48, 58]
---

# Frame Identity and Capture

## Definition

Layer 1 of the product (PRD §11). It records every source frame with deterministic identity and exact timing, so that each frame stays temporally addressable ("Capture densely", PRD §4.1). The raw video file stays **independent of the semantic representation** (PRD §31).

## Capture requirements (PRD §31)

- Capture at the native or configured source rate, targeting at least 60 fps for gameplay, at 1080p and above.
- Preserve exact presentation timestamps. Detect dropped frames. Record resolution changes.
- Avoid unnecessary CPU copies. Support hardware encoding. Preserve compressed-video metadata (codec residuals and motion vectors feed [[change-importance-scoring]]).
- Optional: game/system audio, microphone audio, and mouse/keyboard/controller input as a synchronised auxiliary stream ([[auxiliary-channels]]).

## Frame identity record (PRD §32)

```text
session_id
frame_id
source_timestamp
capture_timestamp
presentation_timestamp
resolution
codec metadata reference
semantic_delta reference
raw-video reference
```

The rules are: "No semantic record may depend solely on wall-clock time" and "Frame identity must remain deterministic" (PRD §32). Each frame points both to its pixels and to its semantic delta, which is the join that [[evidence-and-provenance]] relies on.

## Requirements it satisfies

- **FR-01**: capture source video with frame-accurate timestamps. **FR-02** relies on it (one semantic transition per captured frame, see [[sixty-fps-contract]]). **FR-23**: offline reprocessing of captured sessions.
- NFR *Determinism*, *Fault tolerance* (dropped inference must not break the capture timeline) and *Graceful degradation* (preserve raw video and frame identity under compute pressure) (PRD §35).

## Design tensions

- **Local capture vs privacy.** Full-rate 1080p+ capture of screens that may contain private data needs local processing and redaction (PRD §58, [[privacy-and-security]]).
- **Capture boundary.** Capture must stay on the observational side of anti-cheat rules ([[game-integrity-boundary]]).

> ⚠️ Tension: `frame_id` generation is unspecified. With dropped-frame detection (§31) and resolution changes, the PRD does not say whether `frame_id` is a dense counter over *captured* frames or is derived from source timestamps (leaving gaps at drops). This matters for "deterministic" identity and for FR-02.

> ⚠️ Tension: §32 defines three timestamps (source, capture, presentation). The §38 stream carries a single `time_sec` without saying which one. §31 emphasises presentation timestamps.

> ⚠️ Tension: Offline reprocessing (FR-23) and model replacement (FR-22) produce new semantic deltas for the same frame, but §32 gives each frame a single `semantic_delta reference`. Versioned references are not described.

## Related

[[sixty-fps-contract]] · [[evidence-and-provenance]] · [[snapshot-delta-storage]] · [[auxiliary-channels]] · [[change-importance-scoring]] · [[short-event-preservation]] · [[privacy-and-security]] · [[game-integrity-boundary]] · [[nvidia-deepstream]] · [[semantic-video-state-engine-prd]]
