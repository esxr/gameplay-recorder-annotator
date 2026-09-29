---
title: Adaptive Spatial Representation
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [spatial, quadtree, representation]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.5, 18, 21, 36, 41, 66.4, 66.5]
---

# Adaptive Spatial Representation

## Definition

The PRD says "a single representation is insufficient for all content" (PRD §21). The engine combines several spatial primitives and uses an **adaptive quadtree** for regions that are not objects.

## Primitives (PRD §21)

- persistent object masks
- bounding boxes
- UI element regions
- semantic segmentation
- adaptive image tiles
- keypoints
- raw-pixel evidence

## The adaptive quadtree

Large uniform regions (sky, walls) stay as **coarse** tiles. A tile **subdivides** into finer tiles when it contains small text, edges, UI, fast motion, many objects or high uncertainty (PRD §21).

This lets resolution follow information density. It also gives [[region-update-modes]] and [[change-importance-scoring]] a natural unit for tiles, and the §41 inspection overlay shows "changed tiles".

The PRD bases this on STTM, which uses coarse-to-fine quadtree tokenisation for video-token reduction (PRD §9.5, §21).

> 🔎 Unverified: STTM's reported "approximately 2× acceleration at a 50% token budget with only a small benchmark accuracy reduction" (PRD §9.5) is the PRD's claim. See [[sttm]].

The scale involved is large. The §36 density example puts **2,100 adaptive visual regions** alongside 204 objects and 81 UI/text elements per frame ([[annotation-density]]).

## Requirements it satisfies

FR-04 (masks and/or boxes), FR-09 (region-level change analysis), FR-16 (evidence regions for claims).

## Design tensions

- **Symbolic vs latent tiles.** It is unclear whether a tile carries labels, embeddings or both. §66.4–66.5 leave this open ("learned visual tokens", "hybrid symbolic/latent").
- **Temporal tile coherence.** STTM merges tokens across time. The PRD does not say whether a quadtree persists across frames and is edited by deltas, or is rebuilt for each frame.

> ⚠️ Tension: Evidence references such as `frame:18472:region:392` (§18) assume addressable region IDs. If the quadtree re-subdivides as content changes, the PRD does not say whether tile IDs stay stable across frames or are valid only within one frame, and it defines no tile addressing scheme.

> ⚠️ Tension: The quadtree is a *token-reduction* technique in its source (STTM compresses input for a video-LLM). §21 reuses it as a *state* representation for non-object regions. The PRD does not specify what semantic content a non-object tile holds beyond "adaptive visual regions".

> ⚠️ Tension: §21 gives the quadtree's subdivision triggers, but where objects and tiles overlap (an enemy standing on a textured floor) the PRD defines no precedence between object masks and quadtree tiles for change analysis or update-mode selection.

## Related

[[annotation-density]] · [[region-update-modes]] · [[change-importance-scoring]] · [[persistent-world-state]] · [[evidence-and-provenance]] · [[ui-hud-perception]] · [[sttm]] · [[framefusion]] · [[open-research-questions]] · [[semantic-video-state-engine-prd]]
