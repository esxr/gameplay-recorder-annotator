---
title: ScreenAI
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [ui-understanding, screen-annotation, vision-language, google]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.3, 61, 69]
---

# ScreenAI

## What it is

Baechler et al., "ScreenAI: A Vision-Language Model for UI and Infographics Understanding," 2024 (PRD §69). This Google model introduced a dedicated **screen-annotation** task that finds the type and location of each UI element. It then uses those structured annotations to describe screens to language models (PRD §9.3).

## Key claims (per PRD)

- Screen annotation (UI element type plus location) works as its own task (PRD §9.3, §69).
- Structured annotations are a way to pass screen content to LLMs (PRD §9.3).

> 🔎 Unverified: The PRD quotes no figures for ScreenAI. The description above is the PRD's summary only.

## Why it matters to the engine

PRD §9.3 notes that game video "differs from ordinary natural-scene video because screens contain large numbers of small semantic elements." Its product implication is that "UI/HUD interpretation must be a first-class perception path, not a side effect of generic object detection." PRD §61 recommends "a specialized UI pipeline inspired by ScreenAI and OmniParser rather than relying exclusively on natural-image models."

Engine concepts it informs:

- [[ui-hud-perception]]: a dedicated UI/HUD parsing path.
- [[ocr-and-text]]: text is one kind of UI element.
- [[context-compiler]]: ScreenAI's pattern of "structured annotation, then LLM description" matches how the engine compiles state into LLM context.
- [[model-agnostic-providers]]: this capability sits behind `UIParserProvider` (PRD §60).

## Related

[[ferret-ui]] · [[omniparser]] · [[ui-hud-perception]] · [[ocr-and-text]] · [[perception-modules]] · [[context-compiler]] · [[game-adapters]] · [[semantic-video-state-engine-prd]]
