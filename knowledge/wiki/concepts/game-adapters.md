---
title: Game Adapters
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [adaptation, ontology, repetition, per-game]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [8, 15, 44, 45, 46, 57, 59, 62, 64]
---

# Game Adapters

**Definition.** A lightweight, per-game layer learned from **repeated exposure** that maps generic screen detections to game-specific named fields and conventions (PRD §44). The generic engine "should work without game-specific integration". Adapters are an accelerator, not a prerequisite (PRD §44; non-goal: "guarantee perfect interpretation of arbitrary unseen games", §8).

## Adapter contents (PRD §44)

HUD regions · known icons · weapon names · numerical parsers · map conventions · event signatures · object categories · UI states.

```text
generic OCR:  "27 / 160"
game adapter: ammo.current = 27
              ammo.reserve = 160
```

**Rule:** "Adapters should extend the general ontology rather than replace it" (PRD §44).

## Learning from repetition (PRD §45)

Games are visually repetitive. The system should learn persistent screen layouts, HUD templates, repeated icons, common animation states, common object appearances, map regions, and known transitions. "As confidence in these patterns increases, the amount of expensive general-purpose inference should decrease" (PRD §45). This directly serves the [[compute-efficiency-objective]], and it overlaps with the [[semantic-cache]] (PRD §46).

The PRD lists the "game-specific adaptation layer" as build-core (PRD §62). "Automatic game ontology discovery" and "per-game specialist models" are extensions (PRD §64). Adapters are derived from pixels only, consistent with the [[game-integrity-boundary]] (PRD §59).

## Requirements satisfied

FR-21: "Permit game-specific ontology extensions" (PRD §34). Supports FR-05 and FR-07 (named HUD fields and numeric parsing).

## Risks

Stale adapters after a game patch or UI mod, or a wrong numeric parser, would silently mislabel values at high confidence. See [[failure-modes]].

> ⚠️ Tension: There is no adapter lifecycle. The PRD does not say when an adapter is created ("after observing repeated structure", §15, with no threshold), how it is validated, how it is versioned against game patches, or how it is invalidated when the layout changes. Adapter version is also not among the §30 provenance fields.

> ⚠️ Tension: Adapters are "learned" and reduce inference as confidence rises (§45). Output then depends on how much of the game the system has seen, which strains NFR Determinism (§35): reprocessing the same session with a later adapter yields different state unless the adapter version is pinned.

> ⚠️ Tension: Adapters "extend, not replace" the ontology, but the example rewrites a generic OCR string into `ammo.current` / `ammo.reserve`. The PRD does not say whether both representations are stored, or how queries written against the generic schema find adapter-named fields.

## Related

[[semantic-cache]] · [[ui-hud-perception]] · [[ocr-and-text]] · [[semantic-annotation-taxonomy]] · [[compute-efficiency-objective]] · [[scene-resets]] · [[game-integrity-boundary]] · [[build-vs-buy]] · [[failure-modes]]
