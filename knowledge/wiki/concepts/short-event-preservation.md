---
title: Short Event Preservation
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [fast-events, temporal-fidelity, differentiator, benchmark]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [2, 7, 10, 12, 19, 33, 35, 53, 57, 65]
---

# Short Event Preservation

**Definition.** The requirement that events lasting **one frame, two frames, several frames, or less than a 1-fps sampling interval** remain detectable and queryable. The PRD calls this "a core differentiator from general video summarization" (PRD §33).

## Why it matters

At 60 fps, important gameplay events may last only a handful of frames: muzzle flashes, damage indicators, parries, hit markers, kill-feed changes, button prompts, brief text (PRD §2). General video models often sample at 1 fps by default. [[gemini-video-understanding]] is the PRD's example, with Google warning that fast motion can be missed (PRD §2, §10). §33 adds flashes, animation cancels, item pickups, and quick peeks.

## Mechanism

- **Dense timeline.** Every frame advances semantic state ([[sixty-fps-contract]], PRD §12). A one-frame event appears as a pair of deltas, e.g. `muzzle_flash: false → true` at frame 18472 and `true → false` at 18473 (PRD §19).
- **Sensory memory** holds recent high-resolution frames for "fast transient detection" (PRD §25; see [[three-level-semantic-memory]]).
- **Scheduler** raises priority when an event detector fires or a static region changes (PRD §23).
- **Evidence** keeps pixels addressable so a one-frame claim can be checked (PRD §30).

## Evaluation

§53 benchmark questions include "What was shown for only one source frame?", "Did ammunition decrease before or after the muzzle flash?" and "Exactly which frame first shows enemy A?" (PRD §53). Temporal event recall is a headline metric (PRD §51). See [[evaluation-and-metrics]].

## Requirements satisfied

Goal 8 (detect very short-lived events) (PRD §7). NFR Temporal fidelity: sub-second and single-frame events remain representable (PRD §35). Acceptance "Fast-event preservation" (PRD §65). FR-02, FR-13 (PRD §34).

## Risks

A COPY decision on a frame containing a small one-frame change silently erases the event. OCR hysteresis can suppress genuine one-frame text. See [[failure-modes]].

> ⚠️ Tension: *Representable* is not the same as *detected*. The contract guarantees a timeline slot per frame, but COPY is chosen when "no meaningful change [is] detected" (§12) by cheap L0–L1 signals. Nothing guarantees those signals catch a small one-frame hit marker, which is the exact case §55 says pixel magnitude under-weights.

> ⚠️ Tension: Graceful degradation "lower[s] expensive inference frequency" under compute pressure (§35), yet §54 calls a system that misses critical events a failure. The PRD does not say whether short-event detection is protected from degradation.

> ⚠️ Tension: OCR flicker is mitigated by "temporal consensus and confidence hysteresis" (§57), which by construction delays or suppresses text lasting one to two frames. That conflicts with §33's "brief text" and one-frame targets.

## Related

[[sixty-fps-contract]] · [[selective-inference-scheduler]] · [[change-versus-meaning]] · [[ocr-and-text]] · [[relationships-and-events]] · [[evaluation-and-metrics]] · [[gemini-video-understanding]] · [[strategic-differentiation]] · [[failure-modes]]
