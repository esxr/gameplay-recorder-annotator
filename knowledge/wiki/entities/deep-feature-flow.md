---
title: Deep Feature Flow
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [temporal-propagation, keyframes, optical-flow, sparse-inference]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [2, 9.1, 69]
---

# Deep Feature Flow

## What it is

Zhu et al., "Deep Feature Flow for Video Recognition," CVPR 2017 (PRD §69). The paper runs an expensive convolutional recognition network only on sparse keyframes. It then uses estimated optical flow to carry the feature maps to the frames in between (PRD §9.1). The PRD lists it first in its research foundation, under "sparse expensive inference with temporal propagation."

## Key claims (per PRD)

- Expensive convolutional recognition does not have to run on every video frame (PRD §9.1).
- Feature maps computed on keyframes can be propagated to intervening frames using optical flow (PRD §9.1, §69).
- The problem statement cites it as evidence that video computation can exploit temporal redundancy (PRD §2).

> 🔎 Unverified: The PRD quotes no speed or accuracy figures for Deep Feature Flow. Its claims about the method come only from the PRD, not from the primary paper.

## Why it matters to the engine

The PRD's product implication, which it shares with [[video-propagation-networks]], is that "full semantic inference should be treated as a refresh operation rather than a mandatory per-frame operation" (PRD §9.1). This idea is the basis for:

- [[sixty-fps-contract]]: every frame advances the timeline, but not every model runs on every frame (PRD §12).
- [[region-update-modes]]: PROPAGATE and FULL REFRESH are the product versions of "propagate between keyframes" and "run the expensive network on a keyframe."
- [[selective-inference-scheduler]] and [[model-hierarchy]]: they decide when a refresh is worth its cost. L1 in the hierarchy (motion / optical flow / codec analysis) matches Deep Feature Flow's flow-based propagation step (PRD §27).
- [[drift-control]]: propagation builds up error, so the engine needs explicit refresh triggers (PRD §24).

## Related

[[video-propagation-networks]] · [[stcn]] · [[sam-family]] · [[framefusion]] · [[sixty-fps-contract]] · [[region-update-modes]] · [[selective-inference-scheduler]] · [[drift-control]] · [[compute-efficiency-objective]] · [[semantic-video-state-engine-prd]]
