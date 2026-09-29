---
title: Game integrity boundary
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [anti-cheat, capture, non-goals, trust, compliance]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [5, 8, 31, 48, 58, 59]
---

# Game integrity boundary

The engine is a **video recorder plus perception system**, not a game-hacking or automation tool. It observes pixels via ordinary display capture and never reaches into the game process (PRD §59).

## The rule (PRD §59)

The default architecture uses ordinary display capture rather than:

- memory inspection,
- code injection,
- process manipulation,
- internal game-state hooks.

"This keeps the product conceptually similar to a video recorder plus perception system." Where operating systems or games restrict screen capture, **those restrictions should be respected** (PRD §59).

## Supporting non-goals (PRD §8)

The core product is not intended to:

- require access to game memory, private game APIs, or game-engine internals;
- depend on a particular game providing telemetry;
- operate as game automation or cheating software.

"Screen pixels are the primary source of truth" (PRD §8). This is also what makes the product useful to game analytics teams who lack internal telemetry (PRD §5.4, [[target-users-and-jobs]]).

## What is still allowed

Optional controller, keyboard, mouse, audio, accessibility or game telemetry can be attached as additional channels, but the visual pipeline must work without them (PRD §8). Input data is recorded, and the engine must keep "visually inferred action" distinct from "directly recorded input" (PRD §48). See [[auxiliary-channels]].

The engine is observational: it produces state, not actions. Automation and cheating are explicit non-goals (PRD §8), even though "agent observation streams" are a supported extension (PRD §64).

> ⚠️ Tension: §59 scopes the ban to the *default* architecture ("should use"), and §8 allows optional "game telemetry" channels, while §8 also says the product won't *require* game internals. The PRD does not say whether a non-default mode could ingest memory- or hook-derived telemetry, nor how such a channel would be kept anti-cheat-safe.

## Relationship to privacy

The integrity boundary is about the game; [[privacy-and-security]] covers the user — local-only modes, excluded windows, OCR redaction, explicit capture indicator (PRD §58). Both reinforce that capture is transparent and user-controlled.

## Related

- [[frame-identity-and-capture]]
- [[auxiliary-channels]]
- [[privacy-and-security]]
- [[target-users-and-jobs]]
- [[game-adapters]]
- [[failure-modes]]
- [[semantic-video-state-engine-prd]]
