---
title: TwelveLabs (Marengo + Pegasus)
type: entity
kind: product
created: 2026-09-30
updated: 2026-09-30
tags: [video-foundation-model, embeddings, video-search, video-to-text, baseline]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [8, 10, 47, 61, 67, 70]
---

# TwelveLabs (Marengo + Pegasus)

**What it is:** A video-understanding company whose two model lines the PRD reviews: **Marengo** (multimodal video embeddings for retrieval) and **Pegasus** (video-to-text generation). The PRD places it in the "video reasoning" group, opposite the annotation tools (PRD §10, §67).

## Capabilities (as described by the PRD)

- **Marengo** embeds visual, audio and textual video content for retrieval (PRD §10).
- **Pegasus** generates video-to-text output and supports timestamped structured video segmentation and multimodal understanding (PRD §10).
- Combined: multimodal video embeddings, search, temporal localization, structured segmentation, video-to-text generation (PRD §70).
- Joint representation of visual, speech and non-speech audio for retrieval and generation — cited as evidence for the engine's audio channel (PRD §47).

> 🔎 Unverified: all Marengo/Pegasus capability claims are the PRD's summary of TwelveLabs documentation; no primary source is in `raw/`.

## Gap vs the engine

> **Gap:** "high-level semantic indexing and generation rather than exhaustive frame-continuous state reconstruction" (PRD §10).

The engine must reconstruct complete semantic state at an arbitrary frame (PRD §7) and preserve events lasting a handful of frames (PRD §33); TwelveLabs is framed as segment-level indexing and generation.

## How the PRD proposes to use it

- **Downstream baseline:** Gemini and TwelveLabs "provide useful baselines against which to measure whether the semantic representation improves reasoning quality, token efficiency, or fast-event recall" (PRD §61). See [[evaluation-and-metrics]].
- **Precedent for multimodal audio** in [[auxiliary-channels]] (PRD §47).
- **Not a permanent dependency:** the product must not "depend permanently on SAM, Gemini, TwelveLabs, or any single third-party model" (PRD §8); embeddings are an integrate item (PRD §62) behind an `EmbeddingProvider` interface (PRD §60).

## Related

- [[gemini-video-understanding]]
- [[evaluation-and-metrics]]
- [[auxiliary-channels]]
- [[model-agnostic-providers]]
- [[strategic-differentiation]]
- [[vid2seq]]
- [[three-level-semantic-memory]]
