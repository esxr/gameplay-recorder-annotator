---
title: Streaming Dense Video Captioning
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [dense-video-captioning, streaming, fixed-size-memory, clustering]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.4, 69]
---

# Streaming Dense Video Captioning

## What it is

Zhou et al., "Streaming Dense Video Captioning," CVPR 2024 (PRD §69). It keeps a **fixed-size memory** built by clustering incoming visual tokens. It produces descriptions localized in time **without waiting for the complete video** (PRD §9.4).

## Key claims (per PRD)

- Memory stays a fixed size as the video grows, because incoming visual tokens are clustered (PRD §9.4).
- Captions localized in time can be emitted while the video is still streaming (PRD §9.4, §69).

> 🔎 Unverified: The PRD quotes no figures for this work. The description above is the PRD's summary only.

## Why it matters to the engine

It shows that a streaming system can describe events live with bounded memory. The engine needs both properties:

- [[query-and-streaming-api]] and [[llm-integration-modes]]: live consumers get semantic output before the session ends.
- [[three-level-semantic-memory]]: bounded memory for long sessions, which is the §9.4 implication about not "forcing every historical visual token into every downstream prompt."
- [[relationships-and-events]]: event descriptions localized in time.
- [[semantic-cache]] / [[snapshot-delta-storage]]: clustering redundant tokens is a relative of storing change instead of repetition.

## Related

[[vid2seq]] · [[moviechat]] · [[xmem]] · [[framefusion]] · [[three-level-semantic-memory]] · [[query-and-streaming-api]] · [[relationships-and-events]] · [[semantic-video-state-engine-prd]]
