---
title: MovieChat
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [long-video, memory, video-llm]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.4, 25, 61, 69]
---

# MovieChat

## What it is

Song et al., "MovieChat: From Dense Token to Sparse Memory for Long Video Understanding," CVPR 2024 (PRD §69). It separates a **short-term memory** that updates quickly from a **compressed long-term memory**. This addresses the compute and memory cost of long-video understanding with LLMs (PRD §9.4).

## Key claims (per PRD)

- A short-term / long-term memory split lowers the cost of long-video understanding (PRD §9.4, §69).
- Long-term memory is compressed: "from dense token to sparse memory" (PRD §69 title).

> 🔎 Unverified: The PRD quotes no figures for MovieChat. The description above is the PRD's summary only.

## Why it matters to the engine

MovieChat is credited next to [[xmem]] as the inspiration for [[three-level-semantic-memory]] (PRD §25). PRD §61 recommends "sensory/working/long-term memory concepts inspired by XMem and MovieChat." XMem supplies the object-segmentation memory model. MovieChat supplies the **video-LLM** version: compressed long-term memory that feeds a language model. That connects the idea to:

- [[context-compiler]] and [[query-adaptive-fidelity]]: the §9.4 implication is that long sessions should not force "every historical visual token into every downstream prompt."
- [[snapshot-delta-storage]]: long-term summaries (PRD §20).

> ⚠️ Tension: MovieChat is a two-tier (short/long) design, but PRD §25 credits it for a three-level model. The sensory tier comes from XMem only.

## Related

[[xmem]] · [[streaming-dense-video-captioning]] · [[vid2seq]] · [[sttm]] · [[framefusion]] · [[three-level-semantic-memory]] · [[context-compiler]] · [[query-adaptive-fidelity]] · [[semantic-video-state-engine-prd]]
