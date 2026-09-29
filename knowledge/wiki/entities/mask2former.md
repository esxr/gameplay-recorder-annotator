---
title: Mask2Former
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [segmentation, panoptic, universal-segmentation, transformer]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [26, 69]
---

# Mask2Former

## What it is

Cheng et al., "Masked-Attention Mask Transformer for Universal Image Segmentation," CVPR 2022 (PRD §69). It is a single architecture that handles semantic, instance, and panoptic segmentation. The PRD files it under "General segmentation."

**Background:** The Mask2Former first author (Bowen Cheng) is a different person from the "Cheng" behind [[stcn]] and [[xmem]] (Ho Kei Cheng).

## Key claims (per PRD)

- One architecture can unify semantic, instance, and panoptic segmentation (PRD §26, §69).

> 🔎 Unverified: The PRD quotes no figures for Mask2Former. The description above is the PRD's summary only.

## Why it matters to the engine

PRD §26 cites Mask2Former as showing "the value of architectures capable of unifying semantic, instance, and panoptic segmentation." That supports a modular perception layer that includes a **panoptic segmentation** module next to detectors and trackers. For the engine this means:

- [[perception-modules]]: panoptic segmentation is one of the optional modules. "No particular module is mandatory across every deployment" (PRD §26).
- [[semantic-annotation-taxonomy]] and [[adaptive-spatial-representation]]: one model can label both "stuff" regions and object instances, which covers background regions that the quadtree would otherwise leave coarse.
- [[model-agnostic-providers]]: it sits behind `SegmentationProvider` like any other segmenter.

> ⚠️ Tension: Mask2Former appears in §26 and §69 but not in the §9 Research Foundation or in the §61 component strategy. It has no stated "product implication" of its own.

## Related

[[sam-family]] · [[stcn]] · [[xmem]] · [[perception-modules]] · [[model-agnostic-providers]] · [[semantic-annotation-taxonomy]] · [[adaptive-spatial-representation]] · [[semantic-video-state-engine-prd]]
