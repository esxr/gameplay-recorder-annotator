---
title: Supervisely
type: entity
kind: product
created: 2026-09-30
updated: 2026-09-30
tags: [annotation-platform, video-annotation, tracking, human-in-the-loop, qa-tooling]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [10, 50, 61, 62, 67, 70]
---

# Supervisely

**What it is:** A video annotation and model-assisted tracking environment, placed by the PRD in the "annotation / perception" group alongside Encord and CVAT (PRD §10, §67, §70).

## Capabilities (as described by the PRD)

- Video tracking and **detection-based tracking** (PRD §10).
- Masks and skeletons (PRD §10).
- Multiple interchangeable tracking models (PRD §10).
- Model-assisted tracking environment (PRD §70).

> 🔎 Unverified: these capabilities are the PRD's summary of Supervisely documentation; no primary source is in `raw/`.

## Gap vs the engine

> **Gap:** "annotation tooling rather than persistent LLM context" (PRD §10).

Supervisely produces labels for datasets; it does not maintain a [[persistent-world-state]] across a session, encode semantic deltas, or serve an LLM through a [[context-compiler]] (PRD §19, §28, §63).

## How the PRD proposes to use it

- **QA / correction tooling:** "Encord, CVAT, or Supervisely-like tooling can serve dataset curation and correction workflows" (PRD §61).
- **Pattern source for [[human-verification]]:** its mature human-in-the-loop patterns inform the correction interface rather than the engine recreating labeling workflows from scratch (PRD §50).
- Annotation UI is an *integrate* item under [[build-vs-buy]] (PRD §62).

Note the PRD's phrasing "Supervisely-*like*" — the tool is an example of a class, not a committed dependency, in keeping with [[model-agnostic-providers]] (PRD §60, §61).

## Related

- [[encord]]
- [[cvat]]
- [[human-verification]]
- [[build-vs-buy]]
- [[strategic-differentiation]]
- [[perception-modules]]
