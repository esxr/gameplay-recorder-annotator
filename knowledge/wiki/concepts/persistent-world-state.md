---
title: Persistent Semantic World State
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [core-architecture, state, data-model]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [1, 4.3, 11, 13, 17, 18, 56, 66.4, 72]
---

# Persistent Semantic World State

## Definition

`WorldState(t)` is the engine's continuously maintained model of what is on screen at time `t` (PRD §13). It is the fourth of the six logical layers (PRD §11), and it sits between perception/propagation and the delta codec:

```text
1. HIGH-FIDELITY CAPTURE
2. CHANGE + MOTION ANALYSIS
3. SELECTIVE PERCEPTION  |  STATE PROPAGATION
4. PERSISTENT SEMANTIC WORLD STATE
5. TEMPORAL SEMANTIC DELTA CODEC
6. LLM CONTEXT / SEARCH / QUERY LAYER
```

It is "persistent" because entities keep identity across frames. The enemy in frame 1,000 and the enemy in frame 1,001 are the same entity, not two detections (PRD §4.3).

## Structure (PRD §13)

```text
WorldState(t)
├── Scene      (environment, camera, lighting/effects, scene mode)
├── Entities   (characters, enemies, items, vehicles, projectiles, environmental objects)
├── UI / HUD   (health, armour, ammo, minimap, status effects, objective, inventory, notifications)
├── Text
├── Spatial Relationships
├── Motion
├── Events
├── Audio State
├── Confidence
└── Evidence Pointers
```

Per-element schemas are on [[semantic-annotation-taxonomy]] (objects), [[ui-hud-perception]], [[ocr-and-text]] and [[relationships-and-events]].

## How it is maintained

Each frame, [[region-update-modes]] update the state: COPY leaves it alone, PROPAGATE moves geometry, and RE-INFER/REFRESH overwrite it. [[scene-resets]] invalidate parts of it selectively (PRD §56). The state is not stored whole per frame. It is serialised as [[snapshot-delta-storage]].

## Requirements it satisfies

FR-03 (persistent object IDs), FR-05/06/07 (persistent UI, text, numeric values), FR-12 (relationships), FR-25 (confidence-aware state). Acceptance *Semantic persistence*: identities stay stable without rediscovery on every frame (PRD §65).

## Design tensions

- **Representation is an open question.** §66.4 lists graph state, key/value state, learned visual tokens, object-centric latents and hybrid symbolic/latent as candidates. §13 reads like a symbolic tree, but §66.5 suggests that latent embeddings may need to sit alongside it.
- **Is the state an observation or a belief?** Hidden state (for example an enemy behind cover) is kept by propagation and inference, not by observation. The tree has one `Confidence` branch, but per-field uncertainty is required (PRD §49).

> ⚠️ Tension: §13 has no branch for masks or game-state variables, even though §1 lists both among the maintained representation and the §72 world-state box lists "masks". Masks presumably live inside Entities, but the tree does not say so.

> ⚠️ Tension: `Events` is a branch of `WorldState(t)` (§13). §18 defines events as temporally bounded and "derived from lower-level state", and §20 stores them as separate *event records*. It is unclear whether events are part of instantaneous state, a derived layer over it, or both. §38 even appends them via a state-path delta (`"path": "events", "op": "append"`).

> ⚠️ Tension: §13 names a "Spatial Relationships" branch, but §17's relationship examples are mostly non-spatial (`holding`, `emitted_by`, `corresponds_to`).

> ⚠️ Tension: `Audio State` is part of the world state (§13), yet none of the six layers in §11 mentions audio, and audio capture is optional (PRD §31, §47).

## Related

[[semantic-annotation-taxonomy]] · [[relationships-and-events]] · [[region-update-modes]] · [[snapshot-delta-storage]] · [[three-level-semantic-memory]] · [[ui-hud-perception]] · [[scene-resets]] · [[confidence-and-uncertainty]] · [[xmem]] · [[semantic-video-state-engine-prd]]
