---
title: Drift Control
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [propagation, confidence, drift, tracking]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [12, 22, 23, 24, 35, 57, 65, 66.2, 66.6]
---

# Drift Control

**Definition.** Explicit safeguards against error accumulation. COPY and PROPAGATE reuse prior state, so "propagation creates the risk of accumulating errors" (PRD §24).

## Mechanism

Each annotation shall carry six drift indicators (PRD §24):

- confidence;
- time since authoritative inference;
- propagation distance;
- appearance consistency;
- motion consistency;
- model disagreement.

"A full or partial refresh is required when drift indicators cross configurable thresholds." Scene cuts must automatically invalidate affected state (PRD §24; see [[scene-resets]]). The same indicators feed [[change-importance-scoring]] (confidence decay, model disagreement) and the [[selective-inference-scheduler]] ("tracked mask drifts", "confidence decays below a threshold") (PRD §22, §23).

**Per-type decay.** §66.6 says confidence decay "should depend on annotation type": a copied value "may remain certain indefinitely", while a propagated object location "may become uncertain within several frames" (PRD §66.6). A static HUD label and a moving enemy mask therefore need different decay curves (see [[confidence-and-uncertainty]]).

**Mitigations (PRD §57).** For tracker drift: confidence decay, periodic visual validation, appearance checks, partial re-inference. For identity swaps: appearance embeddings, trajectory history, re-identification, ambiguity flags.

## Requirements satisfied

- NFR Accuracy: "Semantic reuse must not silently propagate obviously invalid state" (PRD §35).
- Acceptance "Uncertainty visibility": propagated info is never presented as equal to directly observed information (PRD §65).
- FR-11 (confidence and provenance), FR-25 (confidence-aware state) (PRD §34).

## Risks

Tracker drift, identity swaps, and scene-cut leakage (PRD §57). See [[failure-modes]].

> ⚠️ Tension: The thresholds are "configurable" but no default values, units, or per-class settings are given. §66.2 (refresh cadence per object class) and §66.6 (decay per annotation type) are both left open, so drift control has no concrete policy.

> ⚠️ Tension: §24 requires *every* annotation to track "time since authoritative inference" as a drift indicator, and §22 defines confidence decay as time without revalidation. §66.6 says a copied value may stay certain *indefinitely*. These cannot all hold unless decay is type-dependent, and §22/§24 do not say it is.

> ⚠️ Tension: §66.6's "copied value may remain certain indefinitely" is unsafe for HUD values hidden or occluded by menus or effects. COPY is decided by the absence of detected change, and missed change (e.g. a one-frame flash, [[short-event-preservation]]) would then never decay.

## Related

[[confidence-and-uncertainty]] · [[region-update-modes]] · [[selective-inference-scheduler]] · [[change-importance-scoring]] · [[scene-resets]] · [[evidence-and-provenance]] · [[xmem]] · [[sam-family]] · [[open-research-questions]] · [[failure-modes]]
