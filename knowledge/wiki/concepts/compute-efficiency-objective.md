---
title: Compute Efficiency Objective
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [compute, objective, graceful-degradation, economics]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [4.2, 7, 35, 36, 51, 54, 55]
---

# Compute Efficiency Objective

**Definition.** The engine's optimisation target is **"maximum retained semantic information per unit of compute"**, not low GPU utilisation (PRD §54).

## The two failure boundaries (PRD §54)

- "A low-compute system that misses critical events is a failure."
- "A high-compute system that repeatedly understands unchanged HUD pixels is also a failure."

Hence "compute scheduling must therefore optimize information gain" (PRD §54). This builds on thesis §4.2, "infer sparsely where possible" (PRD §4.2), and on the economics in §36: if only 14 of thousands of addressable elements change, only 14 delta records are needed (PRD §36; see [[annotation-density]]).

## Graceful degradation (NFR)

"When compute becomes constrained, the system should lower expensive inference frequency while preserving raw video and frame identity rather than silently dropping the session" (PRD §35). Related: Fault tolerance says dropped inference tasks must not break the raw capture timeline (PRD §35). The degradation order is therefore: keep capture and frame identity ([[frame-identity-and-capture]]), then thin out upper [[model-hierarchy]] tiers.

## Levers

[[selective-inference-scheduler]] · [[change-importance-scoring]] · [[semantic-cache]] and learning from repetition (§45: expensive inference should *decrease* as pattern confidence grows) · [[game-adapters]] · [[adaptive-spatial-representation]].

## Measurement

Re-inference avoidance, compression ratio, and context efficiency (PRD §51); see [[evaluation-and-metrics]].

## Requirements satisfied

Goals 6–7 (PRD §7). NFR Scalability: storage grows with semantic change (PRD §35). NFR Graceful degradation and Fault tolerance (PRD §35).

## Risks

Optimising avoidance metrics can reward skipping. See [[failure-modes]] and [[short-event-preservation]].

> ⚠️ Tension: "Information gain" is never defined or measured. No §51 metric expresses semantic information per unit compute. Re-inference avoidance on its own rewards doing less, and must be read against temporal event recall to mean anything.

> ⚠️ Tension: Graceful degradation has no trigger, budget, or priority order. There is no stated compute budget, the PRD does not say which tiers or classes degrade first, and it does not say whether degraded spans are marked in provenance so that downstream consumers see reduced fidelity (cf. §65 "Uncertainty visibility").

## Related

[[selective-inference-scheduler]] · [[model-hierarchy]] · [[change-versus-meaning]] · [[annotation-density]] · [[semantic-cache]] · [[evaluation-and-metrics]] · [[frame-identity-and-capture]] · [[failure-modes]]
