---
title: Ferret-UI
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [ui-understanding, grounding, multimodal-llm, small-objects]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.3, 69]
---

# Ferret-UI

## What it is

You et al., "Ferret-UI: Grounded Mobile UI Understanding with Multimodal LLMs," 2024 (PRD §69). It is a multimodal LLM for **grounded** UI understanding. It targets the very small objects, icons, and text found in user interfaces (PRD §9.3).

**Background:** Ferret-UI comes from Apple and builds on Apple's earlier Ferret grounding model.

## Key claims (per PRD)

- Handles fine-grained grounding and understanding of small screen elements (PRD §69).
- Explicitly targets the small scale of UI icons and text (PRD §9.3).

> 🔎 Unverified: The PRD quotes no figures for Ferret-UI. The description above is the PRD's summary only.

## Why it matters to the engine

Ferret-UI is the PRD's evidence that small UI elements are a separate, hard problem. That is the core of the §9.3 implication: "UI/HUD interpretation must be a first-class perception path, not a side effect of generic object detection." It informs:

- [[ui-hud-perception]]: HUD icons, counters, and small text need a dedicated path.
- [[adaptive-spatial-representation]]: regions with small text or UI subdivide into finer tiles (PRD §21).
- [[ocr-and-text]] and [[evidence-and-provenance]]: grounded outputs link each UI claim to a screen location.

> ⚠️ Tension: Ferret-UI is described as *mobile* UI understanding (PRD §69), but the PRD applies it to game HUDs without comment. Unlike ScreenAI and OmniParser, it is not named in the §61 component strategy.

## Related

[[screenai]] · [[omniparser]] · [[ui-hud-perception]] · [[ocr-and-text]] · [[adaptive-spatial-representation]] · [[perception-modules]] · [[semantic-video-state-engine-prd]]
