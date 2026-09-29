---
title: Semantic Video Codec
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [core-architecture, thesis, compression, positioning]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [1, 3, 4, 11, 12, 19, 55, 67, 68, 71, 72]
---

# Semantic Video Codec

## Definition

The PRD's central framing. The engine works less like a video captioner and more like a **semantic video codec** (PRD §1):

- Traditional compression asks: *"Which pixels changed?"*
- This product asks: *"Which meaningful entities, properties, relationships, and events changed?"*

The stated thesis is that neither raw frames nor per-frame captions is the right representation for high-frame-rate reasoning. The right one is **persistent semantic state + temporally encoded deltas + selectively retained visual evidence** (PRD §4). The PRD's positioning line is "a semantic codec and memory layer for machine video understanding", not "better video annotation" (PRD §67).

## How it works

The codec analogy maps onto the six product layers (PRD §11):

| Video codec idea | Semantic analogue | Page |
|---|---|---|
| Keyframe (I-frame) | Periodic semantic snapshot | [[snapshot-delta-storage]] |
| Inter-frame residual (P-frame) | Semantic delta (`weapon.ammo: 27 → 26`) | [[snapshot-delta-storage]] |
| Motion compensation | PROPAGATE mode (geometry moved predictably) | [[region-update-modes]] |
| Skip block | COPY mode / empty delta `∅` | [[region-update-modes]] |
| Frame timeline | Every captured frame advances semantic time | [[sixty-fps-contract]] |

The five design decisions (PRD §4.1–4.5) are the principles behind the codec: capture densely, infer sparsely, preserve identity through time, encode change instead of repetition (`player.health = 73` should not be regenerated for 180 unchanged frames), and preserve evidence.

## Pixels changed vs meaning changed

The analogy has a limit. Pixel residual and semantic importance are different things (PRD §55). A camera pan, animated water or particles can cause a large pixel change with little semantic change. `health 91 → 9`, `ammo 1 → 0` or a one-frame hit marker cause a small pixel change with a large semantic change. So a semantic codec cannot use pixel or codec residuals alone to decide what to encode. It has to combine visual information density with semantic importance (PRD §22, §55). This is covered in [[change-versus-meaning]] and [[change-importance-scoring]].

## Long-term thesis

§68 names five kinds of redundancy that the engine combines: temporal pixel redundancy (codecs), temporal token redundancy (video-LLMs), entity continuity (trackers), persistent screen structure (UI models) and hierarchical memory (long-video models). The goal is "an observer maintaining an evolving internal representation of the world" instead of "a model repeatedly looking at screenshots" (PRD §68).

## Requirements it satisfies

FR-02 (semantic transition per frame), FR-10 (update modes), FR-14 (reconstruction), FR-16 (evidence). The NFR *Scalability* says storage should grow with semantic change, not with frame count (PRD §35).

## Design tensions

- **Lossy vs lossless.** A real codec has a defined decoder and a defined error. The PRD's "codec" mixes exact facts (OCR values) with estimates (propagated geometry). Its decoder output is therefore not a faithful reconstruction in the codec sense. See [[snapshot-delta-storage]].
- **No rate–distortion target.** The PRD does not define an acceptable semantic distortion per bit or per compute unit. [[compute-efficiency-objective]] is the closest it gets.

> ⚠️ Tension: The codec pipeline is drawn three ways. §11 has six layers, with "STATE PROPAGATION" as a sibling of selective perception. §12 has five per-region modes. The §72 "one diagram" has only three branches (COPY / PROPAGATE / RE-INFER) and omits REVALIDATE and FULL REFRESH. See [[region-update-modes]].

## Related

[[sixty-fps-contract]] · [[region-update-modes]] · [[persistent-world-state]] · [[snapshot-delta-storage]] · [[change-versus-meaning]] · [[change-importance-scoring]] · [[strategic-differentiation]] · [[deep-feature-flow]] · [[metom]] · [[semantic-video-state-engine-prd]]
