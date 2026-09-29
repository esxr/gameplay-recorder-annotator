---
title: Region Update Modes
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [core-architecture, scheduling, propagation]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [1, 12, 14, 22, 24, 30, 34, 41, 56, 66.6, 72]
---

# Region Update Modes

## Definition

For each frame and each region, the state engine chooses one of five ways to advance semantic state (PRD §12). This is how the engine meets the [[sixty-fps-contract]] without running heavy models everywhere.

| Mode | Trigger (PRD §12) | Mechanism | Cost |
|---|---|---|---|
| **COPY** | No meaningful change detected | Reuse previous semantic state exactly | ~0 |
| **PROPAGATE** | Content moved predictably | Update geometry by tracking, optical flow, codec motion vectors or another light motion estimator | low |
| **REVALIDATE** | Annotation should be confirmed | Cheap tests: appearance-embedding similarity, OCR checksum, mask overlap, colour histogram, lightweight detector, confidence decay | low–medium |
| **RE-INFER REGION** | Significant local change or uncertainty | Stronger visual model on that region | high |
| **FULL REFRESH** | Scene cut, menu transition, respawn, loading screen, camera teleport, catastrophic tracking failure, widespread uncertainty | Broad re-analysis | highest |

§1 gives the same ladder in plain words: copied, geometrically propagated, cheaply revalidated, partially re-inferred, fully re-annotated.

## How it works

The [[change-importance-scoring]] function (PRD §22) and the [[selective-inference-scheduler]] (PRD §23) pick the mode for each region. [[drift-control]] forces a partial or full refresh when these indicators cross configurable thresholds: time since authoritative inference, propagation distance, appearance/motion consistency and model disagreement (PRD §24). FULL REFRESH overlaps with [[scene-resets]], which are *selective*: inventory and player identity persist, while visible enemies and scene objects reset (PRD §56).

The mode determines how trustworthy the result is. §66.6 notes that "a copied value may remain certain indefinitely, while a propagated object location may become uncertain within several frames". Confidence decay should therefore depend on the mode.

## Requirements it satisfies

- **FR-10**: support copy, propagation, validation, partial inference and full inference states.
- **FR-09** (region-level change analysis), **FR-08** (scene transitions invalidate stale state).
- Acceptance *Selective inference*: much of the unchanged content advances without full re-inference (PRD §65).
- NFR *Observability*: inference decisions must be inspectable (PRD §35, §41).

## Design tensions

- **"Region" is not defined.** Modes apply "per region", but a region could be an object track, a UI element or a quadtree tile ([[adaptive-spatial-representation]]). An object whose tile is COPY while its track is PROPAGATE has no stated resolution rule.
- **FULL REFRESH is frame-scoped, not region-scoped.** §12 frames every choice "for each frame and region", but FULL REFRESH is inherently whole-screen, and §56 says a reset is partial.
- **Partial updates within one object.** PROPAGATE changes geometry only. Attributes such as `stance` ride along as copies. One object-level `state_source` cannot express that mix ([[semantic-annotation-taxonomy]]).

> ⚠️ Tension: The mode count differs across sections. §12 and FR-10 define **five** modes. The §41 inspection overlay shows only **four** (COPIED / PROPAGATED / REVALIDATED / RE-INFERRED; no FULL REFRESH). The §72 one-diagram shows **three** (COPY / PROPAGATE / RE-INFER; no REVALIDATE and no FULL REFRESH).

> ⚠️ Tension: There are three vocabularies with no mapping between them. The update modes (§12: COPY/PROPAGATE/REVALIDATE/RE-INFER/FULL REFRESH), the evidence annotation modes (§30: `observed / propagated / copied / derived / inferred / human_verified`) and the object field `state_source` (§14, e.g. `"propagated"`) overlap only partly. The PRD does not say what a REVALIDATE-d or FULL-REFRESH-ed annotation records as its mode. It is also unclear whether §30's `inferred` means RE-INFER output or a speculative derivation ("enemy probably moved behind cover").

> ⚠️ Tension: §12 lists "confidence decay" as a REVALIDATE *test*. Elsewhere confidence decay is a *signal* that triggers revalidation (PRD §22, §23, §24), not a check that confirms validity.

## Related

[[sixty-fps-contract]] · [[selective-inference-scheduler]] · [[change-importance-scoring]] · [[drift-control]] · [[scene-resets]] · [[model-hierarchy]] · [[evidence-and-provenance]] · [[confidence-and-uncertainty]] · [[inspection-and-session-explorer]] · [[deep-feature-flow]] · [[semantic-video-state-engine-prd]]
