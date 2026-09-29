---
title: FrameFusion
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [token-compression, token-merging, token-pruning, video-llm]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [2, 9.5, 23, 61, 69]
---

# FrameFusion

## What it is

Fu et al., "FrameFusion," ICCV 2025 (PRD §69). It finds that matching visual tokens in adjacent video frames are highly redundant. It combines **similarity-based merging** with **importance-based pruning** to speed up video models (PRD §9.5).

## Key claims (per PRD)

- Corresponding tokens in adjacent frames are strongly redundant (PRD §9.5).
- Merging (by similarity) plus pruning (by importance) cuts visual tokens (PRD §9.5, §69).

> 🔎 Unverified: "a 70% reduction in visual tokens and 1.6–3.6× end-to-end acceleration across its tested models" (PRD §9.5, author-reported).

## Why it matters to the engine

FrameFusion supports the engine's view that **temporal redundancy should lower compute**:

- [[selective-inference-scheduler]]: priority should *drop* when "redundant adjacent tokens remain highly similar." PRD §23 calls this "conceptually aligned with FrameFusion's exploitation of adjacent-frame token similarity."
- [[change-importance-scoring]]: FrameFusion pairs similarity (is this redundant?) with importance (does it matter?). The engine's score likewise mixes change signals with salience and query relevance (PRD §22). PRD §61 names it as an input to token/region prioritization.
- [[region-update-modes]]: COPY and PROPAGATE are the engine's version of merging redundant content.
- [[compute-efficiency-objective]]: PRD §2 cites token merging/pruning as evidence that video computation can exploit redundancy.

## Related

[[sttm]] · [[metom]] · [[deep-feature-flow]] · [[streaming-dense-video-captioning]] · [[selective-inference-scheduler]] · [[change-importance-scoring]] · [[change-versus-meaning]] · [[region-update-modes]] · [[nvidia-deepstream]] · [[semantic-video-state-engine-prd]]
