---
title: Change Versus Meaning
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [semantic-change, scheduling, principle]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [1, 7, 8, 22, 55, 57, 66.1, 66.3]
---

# Change Versus Meaning

**Definition.** The principle that *visual* change and *semantic* change are separate axes. Pixel motion alone "cannot determine inference priority" (PRD §55). This is Goal 9: "distinguish visual movement from meaningful semantic state change" (PRD §7). The non-goals also exclude "treat[ing] every pixel difference as meaningful" (PRD §8).

## The two quadrants the PRD names (PRD §55)

| Large visual change, little meaning | Small visual change, large meaning |
|---|---|
| camera panning across a wall | health 91 → 9 |
| animated water | tiny objective icon change |
| particle effects | ammo 1 → 0 |
| screen shake | one-frame hit indicator |
| | small distant enemy silhouette |

The conclusion is that the scheduler "must combine visual information density with semantic importance" (PRD §55). The product framing in §1 is the same: a video codec asks *which pixels changed*, this product asks *which meaningful entities, properties, relationships and events changed* (PRD §1).

## Mechanism (as specified)

- [[change-importance-scoring]] mixes density signals (pixel, codec, flow) with semantic signals (uncertainty, novelty, event salience, query relevance) (PRD §22).
- Mitigations in §57: estimate global camera motion separately from local motion, and "learn low-semantic-value motion classes and background dynamics" for particles (PRD §57).
- [[ui-hud-perception]] and [[game-adapters]] give small HUD regions semantic weight that pixel magnitude would not (PRD §15, §44).

## Requirements satisfied

FR-09 (region-level change analysis), FR-07 (track numerical UI values), FR-13 (events) (PRD §34). NFR Accuracy: reuse must not silently propagate invalid state (PRD §35).

## Risks

The main failure is a false COPY on a semantically large but visually small change, such as a one-frame hit marker. The mirror failure is compute waste on particles and camera pans (PRD §54, §57). See [[failure-modes]] and [[short-event-preservation]].

> ⚠️ Tension: §55 treats change and meaning as distinct axes, but §22 collapses them into one weighted sum. The PRD never says how "semantic importance" is known *before* inference runs. The meaning of a small change (is this pixel cluster a hit marker?) is exactly what the skipped inference would have told you. This circularity is unresolved; §66.1 defers it to a possible learned scheduler.

> ⚠️ Tension: "Semantic change" itself is undefined (§66.1 is an open question). That leaves [[evaluation-and-metrics]] such as semantic delta precision and recall (§51) without a ground-truth definition.

## Related

[[change-importance-scoring]] · [[selective-inference-scheduler]] · [[compute-efficiency-objective]] · [[short-event-preservation]] · [[semantic-video-codec]] · [[open-research-questions]] · [[failure-modes]]
