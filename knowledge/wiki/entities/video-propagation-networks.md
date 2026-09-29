---
title: Video Propagation Networks
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [temporal-propagation, online, label-propagation]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [2, 9.1, 69]
---

# Video Propagation Networks

## What it is

Jampani et al., "Video Propagation Networks," CVPR 2017 (PRD §69). The paper propagates structured information, such as semantic labels, forward through a video. It works online and does not need future frames (PRD §9.1).

## Key claims (per PRD)

- Structured semantic information, not only low-level features, can be propagated forward frame to frame (PRD §9.1, §2).
- Propagation works **online**, with no access to future frames (PRD §9.1).

> 🔎 Unverified: The PRD quotes no metrics for this work. The description above is the PRD's summary only.

## Why it matters to the engine

It shares the §9.1 product implication with [[deep-feature-flow]]: full semantic inference is a *refresh*, not a per-frame duty (PRD §9.1). Video Propagation Networks adds two points that Deep Feature Flow does not make:

- What gets propagated can be **semantic labels themselves**. This supports carrying annotations forward in [[persistent-world-state]] through the PROPAGATE mode of [[region-update-modes]].
- It is **online / causal**, which a live engine needs. [[query-and-streaming-api]] and live [[llm-integration-modes]] cannot wait for future frames.

Propagated labels still need [[drift-control]] and [[confidence-and-uncertainty]] tracking (PRD §24).

## Related

[[deep-feature-flow]] · [[stcn]] · [[xmem]] · [[sam-family]] · [[region-update-modes]] · [[persistent-world-state]] · [[sixty-fps-contract]] · [[drift-control]] · [[semantic-video-state-engine-prd]]
