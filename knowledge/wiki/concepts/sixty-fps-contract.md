---
title: The 60 FPS Contract
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [core-architecture, temporal-fidelity, requirements]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [1, 2, 9.2, 12, 31, 33, 34, 35, 65]
---

# The 60 FPS Contract

## Definition

The PRD calls this its most important requirement (PRD §12):

> Every captured frame advances the semantic timeline.

This does **not** mean that every model runs on every frame. A 60 fps session produces 60 semantic transitions per second, and only some of those transitions call high-cost models (PRD §12). 60 fps is the *baseline target*. Capture runs at the native or configured source rate (PRD §1, §31).

## Why it exists

- General video models reduce frames before they reason. The PRD notes Gemini's documented default sampling of 1 fps, which can miss fast motion (PRD §2). Gameplay events such as muzzle flashes, hit markers and parries can last only 1–2 frames (PRD §2, §33).
- The opposite extreme, running large vision models on every region of every frame, wastes compute on redundant content (PRD §2).

## Decoupling state rate from inference rate

The architectural consequence comes from §9.2. The PRD reports that even a state-of-the-art multi-object tracker cannot do all of the semantic work at 60 fps on dense scenes. Its example is SAM 3.1 at "up to 32 fps for 16 tracked objects on a single H100". The product implication is therefore:

> the architecture must separate the **60-fps semantic-state contract** from the rate of expensive segmentation inference. (PRD §9.2)

> 🔎 Unverified: the SAM 3.1 throughput figure (32 fps / 16 objects / one H100) is the PRD's claim about Meta's reporting. See [[sam-family]].

The engine meets the contract with cheap per-frame operations (COPY, PROPAGATE, REVALIDATE) and uses expensive RE-INFER and FULL REFRESH operations only occasionally. See [[region-update-modes]] and [[selective-inference-scheduler]].

## Requirements it satisfies

- **FR-01**: capture source video with frame-accurate timestamps.
- **FR-02**: maintain a semantic transition for every captured frame.
- Acceptance criterion *Frame continuity*: every captured source frame has a semantic timeline position (PRD §65).
- NFR *Temporal fidelity* (single-frame events must remain representable), *Fault tolerance* (dropped inference must not break the capture timeline) and *Graceful degradation* (lower the inference frequency, keep raw video and frame identity) (PRD §35).

## Design tensions

- **Advancing is not the same as being correct.** A frame can "advance" through COPY while the underlying state is stale. The contract guarantees temporal addressability, not freshness. Freshness depends on [[drift-control]] and [[confidence-and-uncertainty]].
- **Latency is not stated.** The contract does not say whether the transition for frame N must exist in real time, or whether it can be written later (for example after a deferred RE-INFER). Offline reprocessing (FR-23) suggests that later writes are allowed.

> ⚠️ Tension: FR-02 applies to every *captured* frame, and §31 requires *detecting* dropped frames. The PRD does not say whether a dropped source frame gets a timeline position (for example an explicit gap record) or is simply missing. "Every frame advances the timeline" is therefore undefined at drops.

> ⚠️ Tension: "60 transitions per second" (PRD §12) assumes a 60 fps source. Capture follows the native rate (PRD §31), so a 144 Hz source would produce 144 transitions per second. The PRD does not say whether the contract scales with the source rate or is capped at 60.

## Related

[[semantic-video-codec]] · [[region-update-modes]] · [[frame-identity-and-capture]] · [[short-event-preservation]] · [[selective-inference-scheduler]] · [[model-hierarchy]] · [[sam-family]] · [[gemini-video-understanding]] · [[semantic-video-state-engine-prd]]
