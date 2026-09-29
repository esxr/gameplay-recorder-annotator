---
title: VPT (Video PreTraining)
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [gameplay, minecraft, inverse-dynamics, behavioral-cloning, openai]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [5, 9.6, 48, 59, 69]
---

# VPT (Video PreTraining)

## What it is

Baker et al., "Video PreTraining (VPT): Learning to Act by Watching Unlabeled Online Videos," OpenAI, 2022 (PRD §69). VPT showed that gameplay video can be turned automatically into useful behavioral supervision. An **inverse-dynamics model** trained on a fairly small labeled dataset was used to label a large amount of online Minecraft video (PRD §9.6).

## Key claims (per PRD)

> 🔎 Unverified: The inverse-dynamics model labeled "70,000 hours of online Minecraft video" (PRD §9.6).

> 🔎 Unverified: The resulting policy "operated through Minecraft's native mouse and keyboard interface at 20 Hz" (PRD §9.6, §69).

## Why it matters to the engine

VPT is the PRD's only **gameplay-specific** precedent (PRD §9.6). Its product implication is: "screen video can contain sufficient information to reconstruct much richer machine-usable state than conventional video captions." This supports the engine's premise ([[persistent-world-state]], [[semantic-video-codec]]).

- [[auxiliary-channels]]: PRD §48 says VPT "shows the value of aligning gameplay pixels with native mouse/keyboard actions, although the proposed product should not require action data to operate." The engine must keep **visually inferred action** separate from **directly recorded input** ([[evidence-and-provenance]]).
- [[target-users-and-jobs]]: AI/gameplay researchers and agent developers (PRD §5) are the audience for this kind of supervision.
- [[game-integrity-boundary]]: using only pixels (not game internals) fits the engine's default of ordinary display capture over memory inspection or game-state hooks (PRD §59).

> ⚠️ Tension: VPT's 20 Hz action rate is well below the engine's 60 fps baseline ([[sixty-fps-contract]]). The PRD does not discuss what action rate the engine's inferred-action layer should target.

## Related

[[vid2seq]] · [[auxiliary-channels]] · [[evidence-and-provenance]] · [[game-adapters]] · [[target-users-and-jobs]] · [[persistent-world-state]] · [[semantic-video-state-engine-prd]]
