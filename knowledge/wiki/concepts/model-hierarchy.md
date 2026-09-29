---
title: Model Hierarchy (L0–L5)
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [compute, escalation, perception]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [8, 12, 27, 50, 54, 60]
---

# Model Hierarchy (L0–L5)

**Definition.** The cost ladder of resolvers. The rule is that the engine "should use the least expensive model capable of resolving an uncertainty" (PRD §27).

## Tiers (PRD §27)

| Tier | Resolver | Typical §12 mode it serves |
|---|---|---|
| L0 | deterministic comparison | COPY |
| L1 | motion / optical flow / codec analysis | PROPAGATE |
| L2 | lightweight detector / OCR / embedding | REVALIDATE |
| L3 | specialist perception model | RE-INFER REGION |
| L4 | large vision-language model | RE-INFER / FULL REFRESH (rare) |
| L5 | human correction or offline adjudication | post-hoc, see [[human-verification]] |

The mode mapping is this wiki's reading. The PRD lists the tiers and modes separately (PRD §12, §27). The §12 REVALIDATE examples (embedding similarity, OCR checksum, mask overlap, colour histogram, lightweight detector, confidence decay) sit at L0–L2.

**Principle.** "A large multimodal LLM should therefore be the exception rather than the default mechanism for basic localization" (PRD §27). This matches the non-goal of running a large multimodal LLM on every frame (PRD §8). Each tier is filled by a swappable provider ([[model-agnostic-providers]], PRD §60).

## Requirements satisfied

FR-10 (copy, propagation, validation, partial and full inference) (PRD §34). Supports the [[compute-efficiency-objective]] of maximum semantic information per unit compute (PRD §54).

## Risks

Stopping escalation too early leaves stale or wrong state, which is the Accuracy NFR (§35). Escalating too late misses events. Swapping models across tiers breaks comparability ("Model upgrades", §57). See [[failure-modes]].

> ⚠️ Tension: "Least expensive model *capable* of resolving an uncertainty" presumes the engine knows in advance which tier can resolve a given uncertainty. There are no escalation criteria, no confidence thresholds per tier, and no rule for when a lower tier's answer is accepted versus escalated.

> ⚠️ Tension: L5 (human/offline adjudication) sits in the same ladder as L0 (per-frame comparison), but it cannot run in the real-time path. The PRD does not split the hierarchy into online and offline tiers, or say how an L5 correction propagates back into already-emitted deltas (cf. FR-24).

## Related

[[selective-inference-scheduler]] · [[region-update-modes]] · [[perception-modules]] · [[model-agnostic-providers]] · [[human-verification]] · [[compute-efficiency-objective]] · [[evidence-and-provenance]] · [[failure-modes]]
