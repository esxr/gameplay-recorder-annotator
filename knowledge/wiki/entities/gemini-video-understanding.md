---
title: Gemini video understanding
type: entity
kind: product
created: 2026-09-30
updated: 2026-09-30
tags: [video-llm, multimodal-reasoning, frame-sampling, baseline, llm-consumer]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [2, 8, 10, 33, 61, 67, 70]
---

# Gemini video understanding

**What it is:** Google Gemini's native video-input capability — direct multimodal reasoning over video. The PRD uses it as the canonical example of a general-purpose video model that *reduces* temporal information before reasoning (PRD §2, §10).

## Capabilities (as described by the PRD)

- Direct video reasoning (PRD §10).
- Two processing modes: **static** and **agentic** (PRD §70).
- Static default path samples visual frames at **1 fps**; Google warns fast motion or rapid scene changes can be missed (PRD §2, §10, §70).
- Newer **agentic / adaptive** mode selectively explores relevant parts of a video rather than exhaustively representing every frame (PRD §2, §10).

> 🔎 Unverified: the 1-fps static default, Google's fast-motion warning, and the agentic exploration mode are the PRD's reading of Google documentation; no primary source is in `raw/`.

## Gap vs the engine

> **Gap:** "excellent downstream reasoning interface, but not equivalent to a persistent 60-fps screen-state representation" (PRD §10).

At 1 fps a 60 fps game shows 60 states per sample interval, and many decisive events (hit markers, muzzle flashes, kill-feed changes) last only a handful of frames (PRD §2). The engine explicitly targets events shorter than "a conventional 1-fps sampling interval" (PRD §33). See [[sixty-fps-contract]] and [[short-event-preservation]].

## How the PRD proposes to use it

- **Downstream reasoning consumer:** Gemini-class models are the kind of LLM the engine feeds via the [[context-compiler]] and [[llm-integration-modes]] — the PRD calls it an "excellent downstream reasoning interface" (PRD §10).
- **Downstream baseline:** with TwelveLabs, used to measure whether the semantic representation improves reasoning quality, token efficiency or fast-event recall (PRD §61) — e.g. on the [[evaluation-and-metrics]] benchmark questions (PRD §53).
- **Swappable:** no permanent dependency on Gemini (PRD §8); general VLM reasoning is an integrate item (PRD §62) behind a `VLMProvider` (PRD §60).

## Related

- [[twelvelabs]]
- [[sixty-fps-contract]]
- [[short-event-preservation]]
- [[context-compiler]]
- [[llm-integration-modes]]
- [[evaluation-and-metrics]]
- [[model-agnostic-providers]]
- [[strategic-differentiation]]
