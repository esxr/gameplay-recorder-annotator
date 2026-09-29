---
title: Scene Resets
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [invalidation, scene-cut, state-management]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [12, 23, 24, 40, 56, 57]
---

# Scene Resets

**Definition.** Selective invalidation of [[persistent-world-state]] when the screen undergoes a hard transition. The PRD requires that state "be selectively invalidated". A reset "does not necessarily destroy all state" (PRD §56).

## Triggers (PRD §56)

scene cuts · loading transitions · menu changes · respawn · camera teleport · cutscene transition · game/window switch.

§12 lists largely the same set as triggers for FULL REFRESH (scene cut, menu transition, respawn, loading screen, camera teleport), plus "catastrophic tracking failure" and "widespread uncertainty" (PRD §12).

## Selective invalidation (PRD §56 example)

```text
inventory persists
current visible enemies reset
HUD template persists
scene objects reset
player identity persists
```

Mechanically: a reset is detected → the [[selective-inference-scheduler]] raises priority ("a scene cut is detected", §23) → affected state is invalidated (§24 "scene cuts must automatically invalidate affected state") → broad re-analysis runs (FULL REFRESH, §12) → a `scene_changed` event is emitted on the streaming API (PRD §40).

## Requirements satisfied

FR-08: "Detect scene transitions and invalidate stale state" (PRD §34). Mitigates "Scene-cut leakage", where entities persist after a hard transition (PRD §57).

## Risks

Under-invalidation leaks ghost entities. Over-invalidation breaks identity continuity (FR-03) and wastes compute re-deriving persistent HUD. See [[failure-modes]].

> ⚠️ Tension: §56 gives one illustrative persist/reset list but no rule for *which* state classes survive which trigger. A game/window switch plausibly invalidates the HUD template and player identity too, which contradicts the example. The policy presumably belongs in [[game-adapters]] or a per-class table, and neither is specified.

> ⚠️ Tension: §12 treats scene cuts as FULL REFRESH ("broad re-analysis"), while §56 says resets are selective. The PRD does not say whether a full *compute* refresh coexists with partial *state* invalidation, or how a persisted value (e.g. inventory) is revalidated once it reappears.

> ⚠️ Tension: Detection of the triggers themselves (e.g. telling "camera teleport" from fast camera motion, or "menu change" from an overlay) is not assigned to any module. §26's "Scene classifier" is the implied owner but is optional ("no module is mandatory").

## Related

[[persistent-world-state]] · [[drift-control]] · [[selective-inference-scheduler]] · [[region-update-modes]] · [[relationships-and-events]] · [[query-and-streaming-api]] · [[game-adapters]] · [[failure-modes]]
