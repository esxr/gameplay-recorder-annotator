---
title: UI and HUD Perception
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [ui, hud, screen-parsing, perception]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.3, 13, 15, 44, 45, 57, 61]
---

# UI and HUD Perception

**Definition.** A dedicated perception path that maintains **persistent identities and semantic values** for on-screen UI components. "UI parsing is a separate logical system" (PRD §15). It must be "a first-class perception path, not a side effect of generic object detection" (PRD §9.3).

## Scope (PRD §15)

Health, armour, stamina, cooldowns, resource counters, score, ammunition, weapons, abilities, minimap, quest/objective markers, reticle, inventory, chat, kill feed, subtitles, button prompts, menus, timers, status icons. In the world-state tree these live under `UI / HUD` (PRD §13).

## Mechanism

UI is modelled *semantically* rather than as pixels (PRD §15):

```json
{ "id": "hud.health", "type": "scalar", "value": 72, "unit": "percent",
  "bbox": [0.018, 0.911, 0.194, 0.958], "confidence": 0.998 }
```

- **Parsing.** A specialised UI pipeline "inspired by [[screenai]] and [[omniparser]]" rather than natural-image models (PRD §61). [[ferret-ui]] is cited for grounded handling of tiny icons and text (PRD §9.3).
- **Persistence.** UI elements hold stable IDs across frames. Unchanged values COPY cheaply, and text-like values revalidate via OCR checksum (PRD §12). See [[ocr-and-text]].
- **Specialisation.** A game adapter ([[game-adapters]]) may turn generic detections into named fields "after observing repeated structure" (PRD §15, §44). HUD templates are a prime target for learning from repetition (PRD §45).
- **Tiny features.** Mitigation for tiny UI features is a separate UI parser, high-resolution crops, and stable ROI definitions (PRD §57).

## Requirements satisfied

FR-05 (detect and persist UI/HUD elements), FR-07 (track numerical UI values over time), FR-15 (history for any UI property) (PRD §34). Goal 10 (PRD §7). Metric: UI-value accuracy (PRD §51).

## Risks

Generic VLM resolution misses tiny features. Semantically huge HUD changes (health 91 → 9) are visually small ([[change-versus-meaning]]). Menus and overlays occlude HUD. See [[failure-modes]].

> ⚠️ Tension: The example shows `"unit": "percent"` and a named `hud.health`, but without a game adapter ([[game-adapters]]) the generic engine has no way to know a bar's unit or that it is health. The PRD does not specify what the generic, adapter-free HUD output looks like, although the engine "should work without game-specific integration" (§44).

> ⚠️ Tension: The research cited ([[screenai]], [[omniparser]], [[ferret-ui]]) targets static app and web screenshots. Nothing addresses temporal HUD issues: animated bars, damage-flash tinting, or diegetic UI rendered in world space.

## Related

[[ocr-and-text]] · [[game-adapters]] · [[semantic-cache]] · [[perception-modules]] · [[persistent-world-state]] · [[semantic-annotation-taxonomy]] · [[screenai]] · [[omniparser]] · [[ferret-ui]] · [[failure-modes]]
