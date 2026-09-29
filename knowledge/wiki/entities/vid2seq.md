---
title: Vid2Seq
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [dense-video-captioning, event-localization, time-tokens, video-language]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.4, 69]
---

# Vid2Seq

## What it is

Yang et al., "Vid2Seq," CVPR 2023 (PRD §69). It represents temporal event boundaries and their text descriptions together, using **time tokens**. It localizes dense events and generates captions in one output sequence (PRD §9.4).

## Key claims (per PRD)

- Event boundaries and descriptions can be produced jointly, with time expressed as tokens (PRD §9.4, §69).
- Shows a language-based representation of video events localized in time (PRD §9.4).

> 🔎 Unverified: The PRD quotes no figures for Vid2Seq. The description above is the PRD's summary only.

## Why it matters to the engine

Vid2Seq is the PRD's precedent for expressing *when* something happened next to *what* happened, in a form a language model can use. The shared §9.4 implication is that "hierarchical semantic memory can preserve a long gameplay session without forcing every historical visual token into every downstream prompt." Vid2Seq supplies the event-with-timestamps half of that idea:

- [[relationships-and-events]]: timestamped event records.
- [[context-compiler]]: time-anchored, text-shaped events are what the compiler puts into prompts.
- [[three-level-semantic-memory]]: long-term episodic memory stores "compressed events" (PRD §25).

> ⚠️ Tension: The PRD's time tokens are temporal anchors in *generated text*. The engine instead anchors events to exact frame IDs ([[frame-identity-and-capture]]). The PRD does not say how, or whether, the two relate.

## Related

[[streaming-dense-video-captioning]] · [[moviechat]] · [[vpt]] · [[relationships-and-events]] · [[context-compiler]] · [[three-level-semantic-memory]] · [[semantic-video-state-engine-prd]]
