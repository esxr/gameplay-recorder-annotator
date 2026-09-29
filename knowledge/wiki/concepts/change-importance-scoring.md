---
title: Change/Importance Scoring
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [change-detection, scheduling, codec-residual, compute]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.5, 12, 22, 31, 55, 66.1, 66.3]
---

# Change/Importance Scoring

**Definition.** The Change Detection Engine assigns every region a dynamic **change/importance score** each frame; the score is the main input the [[selective-inference-scheduler]] uses to choose between COPY, PROPAGATE, REVALIDATE, RE-INFER REGION and FULL REFRESH (PRD §12, §22).

## Mechanism

The PRD gives a conceptual linear form (PRD §22):

```text
importance = a*codec_residual + b*pixel_difference + c*optical_flow
           + d*semantic_uncertainty + e*track_uncertainty + f*OCR_difference
           + g*object_novelty + h*event_salience + i*query_relevance
```

It adds that "the exact function may be learned rather than manually weighted" (PRD §22), echoed as an open question in §66.1.

Named input signals (PRD §22):

| Signal | Question it answers |
|---|---|
| Pixel residual | How different are the raw pixels? |
| Codec residual | How much new information did the encoder need? |
| Motion | How much did the region move? |
| Appearance similarity | Is this likely the same object despite motion? |
| Confidence decay | How long since authoritative revalidation? (see [[drift-control]]) |
| Model disagreement | Do lightweight models disagree with stored state? |
| Query relevance | Does a downstream task care about this region now? |

The codec-residual signal is borrowed from [[metom]], which uses residuals and GOP metadata to estimate information density for video-LLM token allocation (PRD §9.5, §22). The PRD's product implication is that compressed-video metadata is "a perception signal rather than merely a storage detail" (PRD §9.5).

> 🔎 Unverified: MeToM's "2.65× inference acceleration without sacrificing benchmark accuracy" is the PRD's claim (PRD §9.5).

## Requirements satisfied

- FR-09 region-level visual change analysis; feeds FR-10 (copy/propagate/validate/partial/full) (PRD §34).
- Goal 6–7 (avoid regenerating unchanged annotations, reinfer changed/uncertain regions) and Goal 9 (distinguish movement from semantic change) (PRD §7).

## Risks

Camera motion and particle effects inflate pixel/flow terms; tiny semantic changes score low (PRD §55, §57). See [[failure-modes]] and [[change-versus-meaning]].

> ⚠️ Tension: The single score mixes *visual-change* terms (pixel, codec, flow) with *semantic-importance* terms (event salience, novelty, query relevance), yet §55 says change and meaning are different axes that the scheduler must "combine". One additive scalar lets a large enough camera pan outrank a health 91→9 drop; a two-axis or gated form is not considered.

> ⚠️ Tension: The formula's terms and the §22 signal list do not match. Appearance similarity, confidence decay and model disagreement are listed as inputs but absent from the formula; OCR difference, object novelty, event salience and track uncertainty are in the formula but not described.

> ⚠️ Tension: Appearance similarity should *lower* priority (same object despite motion; cf. §23 "appearance remains stable"), but every term in the formula is additive with no sign convention given.

> ⚠️ Tension: Codec residual presumes access to encoder internals. §31 only preserves compressed-video metadata "where available", and §66.3 concedes residual magnitude is not semantic importance. No fallback weighting for when residuals are missing (e.g. uncompressed capture or an opaque hardware encoder) is given.

> ⚠️ Tension: `query_relevance` is computable only when a query exists. In offline ingest before any question is asked, or when future queries differ, it is zero or stale, which makes the stored state depend on which queries arrived during capture.

## Related

[[selective-inference-scheduler]] · [[change-versus-meaning]] · [[drift-control]] · [[model-hierarchy]] · [[region-update-modes]] · [[adaptive-spatial-representation]] · [[query-adaptive-fidelity]] · [[metom]] · [[framefusion]] · [[open-research-questions]] · [[failure-modes]]
