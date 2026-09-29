---
title: OmniParser
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [ui-understanding, screen-parsing, gui-agents, microsoft]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.3, 61, 69]
---

# OmniParser

## What it is

Lu et al., "OmniParser for Pure Vision Based GUI Agent," Microsoft Research, 2024 (PRD §69). It turns screenshots into structured UI elements. It detects interactable regions and extracts what each one does, so that downstream multimodal agents can use them (PRD §9.3).

## Key claims (per PRD)

- Parses screenshots into structured UI elements using vision only (PRD §9.3, §69).
- Detects **interactable** regions and their **functional semantics** (PRD §9.3).

> 🔎 Unverified: The PRD quotes no figures for OmniParser. The description above is the PRD's summary only.

## Why it matters to the engine

PRD §61 names OmniParser, together with [[screenai]], as the model for the engine's specialized UI pipeline: "a specialized UI pipeline inspired by ScreenAI and OmniParser rather than relying exclusively on natural-image models." Its agent-oriented output (what a region *does*, not only what it *is*) fits the engine's goal of machine-usable state for agent developers ([[target-users-and-jobs]]).

It informs:

- [[ui-hud-perception]]: structured, functional HUD/UI elements.
- [[model-agnostic-providers]]: `UIParserProvider` (PRD §60).
- [[llm-integration-modes]]: structured element lists that agents can read directly.

> ⚠️ Tension: PRD §9.3 gives no year ("Microsoft Research"), while §69 dates it 2024.

## Related

[[screenai]] · [[ferret-ui]] · [[ui-hud-perception]] · [[perception-modules]] · [[model-agnostic-providers]] · [[game-adapters]] · [[semantic-video-state-engine-prd]]
