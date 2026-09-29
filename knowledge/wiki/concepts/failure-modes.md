---
title: Failure Modes
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [risk, quality, robustness]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [24, 35, 52, 56, 57]
---

# Failure Modes

**Definition.** The PRD's catalogue of known ways a persistent, propagated semantic state can go wrong, each paired with a mitigation (PRD §57). Most arise from the core bet — reusing state instead of re-inferring every frame — and several reappear as categories in the evaluation dataset (PRD §52).

## Risk / mitigation table (PRD §57)

| Failure mode | Risk | Mitigation | Linked concept |
|---|---|---|---|
| Tracker drift | Propagated masks gradually move off the intended object | Confidence decay, periodic visual validation, appearance checks, partial re-inference | [[drift-control]] |
| Identity swaps | Two visually similar entities cross paths | Appearance embeddings, trajectory history, re-identification, ambiguity flags | [[persistent-world-state]] |
| Tiny UI features | Generic VLM resolution insufficient | Separate UI parser, high-res crops, stable ROI definitions | [[ui-hud-perception]] |
| Particle effects | Visual motion triggers excessive inference | Learn low-semantic-value motion classes and background dynamics | [[change-versus-meaning]] |
| Camera movement | Entire frame appears changed | Estimate global camera motion separately from local object motion | [[change-importance-scoring]] |
| Hidden semantic state | Some game state is not visually observable | Explicitly mark it unknown rather than hallucinating | [[confidence-and-uncertainty]] |
| OCR flicker | Unstable OCR creates false text-change events | Temporal consensus, confidence hysteresis | [[ocr-and-text]] |
| Scene-cut leakage | Entities persist after a hard transition | Scene-reset policies | [[scene-resets]] |
| Long-session memory growth | Semantic history becomes too large | Snapshot/delta encoding, hierarchical episodic memory | [[three-level-semantic-memory]] |
| Model upgrades | Stored annotations become incomparable | Provenance and schema/model versioning | [[evidence-and-provenance]] |

## Cross-cutting safeguards

- NFR *Accuracy*: reuse must not "silently propagate obviously invalid state"; NFR *Graceful degradation*: under compute pressure, lower inference frequency but keep raw video and frame identity (PRD §35).
- Drift indicators with configurable refresh thresholds; scene cuts auto-invalidate state (PRD §24, §56).

> ⚠️ Tension: Mitigations are named but not specified — e.g. "learn low-semantic-value motion classes" and "scene-reset policies" have no mechanism, and "ambiguity flags" for identity swaps have no field in the §49 schema or §40 event list.

> ⚠️ Tension: "Mark it unknown" for hidden state has no representation in the value+confidence schema (PRD §49); see [[confidence-and-uncertainty]].

> ⚠️ Tension: The model-upgrade mitigation records versions, but the PRD never says whether old sessions are re-processed, mixed-version sessions are allowed, or how the *determinism* NFR (PRD §35) is kept when a model is replaced (FR-22).

> ⚠️ Tension: Graceful degradation lowers inference frequency under load (PRD §35), which directly raises drift and missed-short-event risk; no floor on revalidation rate or priority for [[short-event-preservation]] under degradation is set.

## Related

[[drift-control]] · [[scene-resets]] · [[confidence-and-uncertainty]] · [[evidence-and-provenance]] · [[three-level-semantic-memory]] · [[ocr-and-text]] · [[ui-hud-perception]] · [[change-versus-meaning]] · [[evaluation-and-metrics]] · [[short-event-preservation]]
