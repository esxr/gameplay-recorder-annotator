---
title: MeToM (Metadata-Guided Token Merging)
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [token-compression, codec-residuals, gop, video-llm, compressed-domain]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.5, 22, 61, 66.3, 69]
---

# MeToM (Metadata-Guided Token Merging)

## What it is

Wu et al., "MeToM: Metadata-Guided Token Merging for Efficient Video LLMs," CVPR 2026 (PRD §69). It uses information already present in compressed video (**codec residuals** and **GOP-level metadata**) to estimate spatial and temporal information density. It then allocates visual-token budgets based on that estimate (PRD §9.5). The PRD calls it "especially relevant to this product."

## Key claims (per PRD)

- Codec residuals and GOP metadata can estimate information density at no extra perception cost (PRD §9.5).
- Token budgets can be allocated by that density (PRD §9.5, §69).

> 🔎 Unverified: "a 2.65× inference acceleration over their baseline without sacrificing benchmark accuracy" (PRD §9.5, author-reported).

## Why it matters to the engine

MeToM is the source for the `codec_residual` term. That term is listed **first** in the engine's importance function (PRD §22):

- [[change-importance-scoring]]: "Codec residual: how much new image information did the encoder need to describe? MeToM demonstrates that codec residuals can provide useful spatial information-density signals" (PRD §22).
- [[model-hierarchy]]: codec analysis sits at L1, one of the cheapest levels (PRD §27).
- [[selective-inference-scheduler]]: PRD §61 lists codec metadata, "informed by FrameFusion, STTM, and MeToM," for token/region prioritization.
- The §9.5 implication is: "compressed-video metadata should be treated as a perception signal rather than merely a storage detail." This links capture ([[frame-identity-and-capture]]) to perception.

**Caveat, [[open-research-questions]] §66.3:** "Can codec residuals predict semantic importance? MeToM shows they can help predict information density, but semantic importance is not identical to compression residual magnitude." See [[change-versus-meaning]].

> ⚠️ Tension: PRD §22 says MeToM "demonstrates" the value of codec residuals, while §66.3 treats their link to *semantic* importance as open. The two statements are compatible only because "information density" is not the same thing as "semantic importance."

## Related

[[sttm]] · [[framefusion]] · [[deep-feature-flow]] · [[change-importance-scoring]] · [[change-versus-meaning]] · [[open-research-questions]] · [[selective-inference-scheduler]] · [[model-hierarchy]] · [[semantic-video-state-engine-prd]]
