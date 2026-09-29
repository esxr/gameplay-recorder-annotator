---
title: Encord
type: entity
kind: product
created: 2026-09-30
updated: 2026-09-30
tags: [annotation-platform, video-annotation, human-in-the-loop, qa-tooling]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [10, 50, 61, 62, 67, 70]
---

# Encord

**What it is:** A commercial data-annotation platform with native video support, positioned by the PRD in the "annotation / perception" group of existing systems (PRD §10, §67).

## Capabilities (as described by the PRD)

- Native video annotation and tracking (PRD §10).
- Semantic and panoptic segmentation (PRD §10).
- Customizable ontologies and **dynamic attributes** / dynamic ontologies (PRD §10, §70).
- Model-assisted workflows; SAM-based assisted labeling, with current documentation supporting **SAM 3-based** object detection, segmentation and forward/backward tracking (PRD §10, §70).

> 🔎 Unverified: all capability claims above (including SAM 3 support and forward/backward tracking) are the PRD's reading of Encord documentation; no primary source is in `raw/`.

> ⚠️ Tension: §10 says Encord supports "SAM 3-based" detection/segmentation/tracking, while §70 says only "SAM-based assisted labeling". Not contradictory, but the model version is stated inconsistently.

## Gap vs the engine

> **Gap:** "designed primarily for dataset creation and annotation workflows rather than a continuous 60-fps semantic state stream consumed directly by an LLM" (PRD §10).

The engine's output is a live/offline [[persistent-world-state]] with [[snapshot-delta-storage]] and a [[context-compiler]], not a labeled dataset (PRD §11, §63). "A frame annotation editor alone does not satisfy the product definition" (PRD §63).

## How the PRD proposes to use it

- **QA / correction tooling:** "Encord, CVAT, or Supervisely-like tooling can serve dataset curation and correction workflows" — don't rebuild conventional annotation capabilities (PRD §61).
- **Pattern source for [[human-verification]]:** mature human-in-the-loop patterns that can inform the correction interface (PRD §50).
- "Annotation UI" is explicitly on the *integrate* side of [[build-vs-buy]] (PRD §62).

## Related

- [[cvat]]
- [[supervisely]]
- [[human-verification]]
- [[build-vs-buy]]
- [[strategic-differentiation]]
- [[sam-family]]
- [[semantic-annotation-taxonomy]]
