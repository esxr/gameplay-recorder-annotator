---
title: XMem
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [video-object-segmentation, memory, long-video]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.2, 25, 61, 69]
---

# XMem

## What it is

Cheng & Schwing, "XMem: Long-Term Video Object Segmentation with an Atkinson-Shiffrin Memory Model," ECCV 2022 (PRD §69). XMem segments objects in long videos using three separate memory stores: **sensory**, **working**, and **long-term** (PRD §9.2).

**Background:** The Atkinson-Shiffrin model is a classic model of human memory from psychology. It has sensory, short-term, and long-term stores.

## Key claims (per PRD)

- Separate sensory, working, and long-term memory stores support long-video object segmentation (PRD §9.2, §69).
- It is "an important conceptual precedent for separating rapidly changing state from compressed long-term visual memory" (PRD §9.2).

> 🔎 Unverified: The PRD quotes no numbers for XMem. The characterization above is the PRD's summary only.

## Why it matters to the engine

XMem is the main source for [[three-level-semantic-memory]]. PRD §25 says the engine's three levels are "inspired by XMem and MovieChat":

| XMem store | Engine level (PRD §25) |
|---|---|
| Sensory | Sensory state: very recent high-resolution visual data for tracking, flow, and transient detection |
| Working | Working semantic state: active objects, HUD, relationships, current events |
| Long-term | Long-term episodic memory: compressed events, snapshots, trajectories, summaries |

PRD §61 recommends "persistent tracked state plus sensory/working/long-term memory concepts inspired by XMem and MovieChat" as the current temporal-memory strategy. The long-term tier supplies [[context-compiler]] and [[query-adaptive-fidelity]], and the sensory tier supports [[short-event-preservation]].

> ⚠️ Tension: The three-level structure comes from XMem. [[moviechat]], which PRD §25 credits alongside it, is described as a **two-level** (short-term / long-term) design (PRD §9.4, §69).

## Related

[[moviechat]] · [[stcn]] · [[sam-family]] · [[streaming-dense-video-captioning]] · [[three-level-semantic-memory]] · [[persistent-world-state]] · [[snapshot-delta-storage]] · [[context-compiler]] · [[semantic-video-state-engine-prd]]
