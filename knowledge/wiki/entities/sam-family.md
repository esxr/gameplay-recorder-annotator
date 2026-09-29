---
title: SAM family (SAM 2, SAM 3, SAM 3.1)
type: entity
kind: model-family
created: 2026-09-30
updated: 2026-09-30
tags: [segmentation, video-tracking, open-vocabulary, meta, streaming-memory]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.2, 10, 26, 60, 61, 67, 69]
---

# SAM family (SAM 2, SAM 3, SAM 3.1)

## What it is

Meta's Segment Anything models for promptable and concept-based segmentation and video tracking. The PRD cites three generations (PRD §69):

- **Ravi et al., "SAM 2: Segment Anything in Images and Videos," 2024.** A streaming-memory design for promptable video segmentation.
- **Carion et al., "SAM 3: Segment Anything with Concepts," 2025.** Open-vocabulary concept detection, segmentation, unique identities, and video tracking.
- **Meta, SAM 3.1 update, March 2026.** Multi-object multiplexing and more efficient video tracking.

## Timeline (per PRD)

| Year | Release | What the PRD says it added |
|---|---|---|
| 2024 | SAM 2 | Streaming memory for promptable segmentation. Processes video frame by frame and keeps information about tracked objects. Meta describes it as built for efficient streaming inference and real-time interactive video (PRD §9.2). |
| 2025 | SAM 3 | Open-vocabulary detection, segmentation, and tracking from noun phrases, exemplars, and visual prompts. Pairs an image detector with a memory-based video tracker and returns unique identities for matching instances (PRD §9.2). |
| Mar 2026 | SAM 3.1 | Object multiplexing: multiple tracked objects are processed together (PRD §9.2, §60). |

## Key claims (per PRD)

> 🔎 Unverified: SAM 3.1 reaches "up to 32 fps for 16 tracked objects on a single H100 in the described configuration" (PRD §9.2, Meta-reported).

> 🔎 Unverified: SAM 2 is "designed for efficient streaming inference and real-time interactive video applications" (PRD §9.2, Meta's description).

> 🔎 Unverified: Encord's documentation supports SAM 3-based detection, segmentation, and forward/backward tracking (PRD §10).

## Why it matters to the engine

- **[[sixty-fps-contract]]**: The SAM 3.1 throughput figure is the PRD's main argument for keeping the semantic timeline separate from the inference rate. Even a state-of-the-art tracker, reported at about 32 fps for 16 objects on an H100, "should not be expected to exhaustively perform all semantic work at 60 fps for arbitrary dense scenes." So "the architecture must separate the 60-fps semantic-state contract from the rate of expensive segmentation inference" (PRD §9.2).
- **[[model-agnostic-providers]]**: PRD §60 uses the SAM timeline as its example of fast model turnover (SAM 2 relevant in 2024, SAM 3 in 2025, SAM 3.1 in 2026). This is why segmentation and tracking sit behind `SegmentationProvider` and `TrackerProvider` interfaces. The engine "must expect that stronger replacements will appear."
- **[[perception-modules]]**: SAM 3/3.1 is the "obvious reference implementation" for a pluggable open-vocabulary detector/segmenter. SAM 2 "remains useful as a well-documented streaming-memory research foundation" (PRD §61). PRD §26 calls it "a strong model family for promptable segmentation and video tracking."
- **[[persistent-world-state]]**: SAM 3's unique instance identities fit the goal of keeping identity stable over time.
- **[[build-vs-buy]]**: segmentation is on the list of capabilities to integrate rather than build (PRD §62). PRD §67 places SAM in the "annotation / perception" group that the engine sits on top of.

## Related

[[stcn]] · [[xmem]] · [[mask2former]] · [[deep-feature-flow]] · [[sixty-fps-contract]] · [[model-agnostic-providers]] · [[perception-modules]] · [[selective-inference-scheduler]] · [[strategic-differentiation]] · [[encord]] · [[nvidia-deepstream]] · [[semantic-video-state-engine-prd]]
