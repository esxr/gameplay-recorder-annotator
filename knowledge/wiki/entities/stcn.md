---
title: STCN (Space-Time Correspondence Networks)
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [video-object-segmentation, tracking, memory, efficiency]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.2, 69]
---

# STCN (Space-Time Correspondence Networks)

## What it is

Cheng et al., "Rethinking Space-Time Networks with Improved Memory Coverage for Efficient Video Object Segmentation," NeurIPS 2021 (PRD §69). The PRD calls it "Space-Time Correspondence Networks." It uses information from earlier frames to segment video objects efficiently (PRD §9.2).

**Background:** STCN is the name usually used for this paper. Its first author (Ho Kei Cheng) is also the first author of [[xmem]].

## Key claims (per PRD)

- Uses prior-frame information for efficient video object segmentation (PRD §9.2).

> 🔎 Unverified: "The published system reported speeds above 20 fps for multiple objects while maintaining strong segmentation performance." (PRD §9.2)

## Why it matters to the engine

STCN is the first entry in PRD §9.2, "Persistent segmentation and tracking." That section ends with this implication: the architecture must separate the 60-fps semantic-state contract from the rate of expensive segmentation inference (PRD §9.2). A reported speed of about 20 fps for multiple objects is well below 60 fps. This is early evidence for:

- [[sixty-fps-contract]]: the segmentation tracker cannot set the timeline's pace.
- [[persistent-world-state]]: object identity and masks carry forward using memory of earlier frames.
- [[selective-inference-scheduler]]: memory-based segmentation is an expensive step that the scheduler decides when to run.

## Related

[[xmem]] · [[sam-family]] · [[mask2former]] · [[deep-feature-flow]] · [[video-propagation-networks]] · [[sixty-fps-contract]] · [[persistent-world-state]] · [[perception-modules]] · [[semantic-video-state-engine-prd]]
