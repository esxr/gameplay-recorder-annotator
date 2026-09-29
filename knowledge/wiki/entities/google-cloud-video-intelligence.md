---
title: Google Cloud Video Intelligence
type: entity
kind: platform
created: 2026-09-30
updated: 2026-09-30
tags: [video-api, object-tracking, cloud, conventional-video-analysis]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [10, 70]
---

# Google Cloud Video Intelligence

**What it is:** Google Cloud's video-analysis API. The PRD lists it as a generic video API that already produces temporally tracked object output — evidence that one piece of the architecture is viable (PRD §10, §70).

## Capabilities (as described by the PRD)

- Temporally tracked object labels and bounding boxes (PRD §10).
- Bounding boxes associated with timestamps (PRD §10).
- Timestamped object detection/tracking with entity information (PRD §70).

> 🔎 Unverified: these capability claims are the PRD's summary of Google documentation; no primary source is in `raw/`.

## Gap vs the engine

> **Gap:** "conventional video analysis with limited density and domain specialization" (PRD §10).

The PRD gives no figure for the density limit. The engine's target is far denser: potentially thousands of semantic/spatial properties per frame (PRD §7), every source frame represented in the timeline (PRD §12), plus UI/HUD state, OCR, relationships and events specialized for gameplay and screens (PRD §15–§18). See [[annotation-density]].

## How the PRD proposes to use it

Unlike the other reviewed products, the PRD assigns it **no explicit role**: it is not named in the component strategy (PRD §61), the build-vs-buy split (PRD §62), human verification (PRD §50) or the §67 positioning diagram. It serves only as landscape evidence that timestamped tracking is commodity (PRD §10), and the engine should not duplicate generic video APIs (PRD §10).

## Related

- [[gemini-video-understanding]]
- [[twelvelabs]]
- [[strategic-differentiation]]
- [[annotation-density]]
- [[persistent-world-state]]
- [[build-vs-buy]]
