---
title: CVAT
type: entity
kind: product
created: 2026-09-30
updated: 2026-09-30
tags: [annotation-platform, open-source, video-annotation, human-in-the-loop, qa-tooling]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [10, 50, 61, 62, 67, 70]
---

# CVAT

**What it is:** An open annotation platform for images and video, grouped by the PRD with Encord and Supervisely as "annotation / perception" tooling (PRD §10, §67, §70).

## Capabilities (as described by the PRD)

- Automatic annotation (PRD §10, §70).
- **SAM2 tracking** of existing objects across video frames (PRD §10, §70).
- Open platform (PRD §70).

> 🔎 Unverified: automatic annotation and SAM2 video tracking are the PRD's summary of CVAT documentation; no primary source is in `raw/`.

## Gap vs the engine

> **Gap:** "annotation platform rather than live semantic video codec" (PRD §10).

CVAT tracks objects a human has already defined; the engine must itself maintain identities, UI/HUD state, relationships and events at 60 fps and compile them for an LLM (PRD §7, §13, §28). See [[semantic-video-codec]].

## How the PRD proposes to use it

- **QA / correction tooling** for dataset curation and correction workflows, instead of rebuilding conventional annotation capabilities (PRD §61).
- **Pattern source for [[human-verification]]**: its human-in-the-loop workflows can inform how corrections to identity switches, OCR failures, class errors, false events and missing objects are captured (PRD §50).
- Annotation UI is an *integrate* item under [[build-vs-buy]] (PRD §62).

## Related

- [[encord]]
- [[supervisely]]
- [[human-verification]]
- [[sam-family]]
- [[build-vs-buy]]
- [[strategic-differentiation]]
- [[semantic-video-codec]]
