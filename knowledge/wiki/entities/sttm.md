---
title: STTM (Multi-Granular Spatio-Temporal Token Merging)
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [token-compression, quadtree, video-llm, training-free]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.5, 21, 61, 69]
---

# STTM (Multi-Granular Spatio-Temporal Token Merging)

## What it is

Hyun et al., "Multi-Granular Spatio-Temporal Token Merging for Training-Free Acceleration of Video LLMs," ICCV 2025 (PRD §69). It tokenizes space coarse-to-fine with a **quadtree** and merges tokens over time, which speeds up video LLMs without retraining (PRD §9.5).

## Key claims (per PRD)

- Adaptive quadtree spatial tokenization plus temporal token merging (PRD §9.5, §69).
- Training-free acceleration of video LLMs (PRD §69).

> 🔎 Unverified: "approximately 2× acceleration at a 50% token budget with only a small benchmark accuracy reduction" (PRD §9.5, author-reported).

## Why it matters to the engine

STTM is the PRD's direct support for **adaptive spatial subdivision**. PRD §21 recommends "an adaptive quadtree ... for non-object regions": large uniform regions stay coarse, while regions with small text, edges, UI, fast motion, many objects, or high uncertainty split into finer tiles. "This direction is supported by STTM's use of coarse-to-fine quadtree tokenization" (PRD §21).

- [[adaptive-spatial-representation]]: the quadtree region model.
- [[change-importance-scoring]] / [[selective-inference-scheduler]]: PRD §61 lists "adaptive spatial subdivision ... informed by FrameFusion, STTM, and MeToM" for token/region prioritization.
- [[annotation-density]] and [[compute-efficiency-objective]]: detail is spent only where it is needed.

The §9.5 implication (shared with [[framefusion]] and [[metom]]) is that "compressed-video metadata should be treated as a perception signal rather than merely a storage detail."

## Related

[[framefusion]] · [[metom]] · [[moviechat]] · [[adaptive-spatial-representation]] · [[change-importance-scoring]] · [[selective-inference-scheduler]] · [[annotation-density]] · [[semantic-video-state-engine-prd]]
