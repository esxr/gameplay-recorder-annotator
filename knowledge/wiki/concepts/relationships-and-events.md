---
title: Relationships and Events
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [data-model, relationships, events, temporal]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [13, 17, 18, 20, 32, 33, 38]
---

# Relationships and Events

## Definition

Two layers above raw entity state:

- **Relationships**: typed, time-bounded edges between entities in the state graph. The engine encodes them "rather than leaving all reasoning to downstream language models" (PRD §17).
- **Events**: "temporally bounded higher-level changes derived from lower-level state" (PRD §18).

## Relationships (PRD §17)

```text
player_1 holding weapon_3
player_1 aiming_at enemy_17
enemy_17 behind cover_9
enemy_17 inside region_room_4
vehicle_2 moving_toward player_1
projectile_88 emitted_by enemy_17
objective_marker_2 corresponds_to minimap_location_51
```

Each relationship has a source entity, relation type, destination entity, confidence, start time, end time and evidence. The examples cover spatial relations (`behind`, `inside`), possession/causal relations (`holding`, `emitted_by`) and cross-UI correspondence (`corresponds_to`, which links a world object to a HUD/minimap element).

## Events (PRD §18)

Example types: weapon fired, hit registered, damage taken, reload started/completed, enemy appeared/disappeared, item acquired, menu opened, objective changed, player died, respawn, ability activated, status effect applied, conversation started, cutscene began, level transition.

```json
{
  "event_id": "event_8820",
  "type": "weapon_fire",
  "start_frame": 18472,
  "end_frame": 18473,
  "participants": ["player_1", "weapon_3"],
  "effects": { "ammo": { "before": 27, "after": 26 } },
  "confidence": 0.987,
  "evidence": ["frame:18472:region:392"]
}
```

Events are frame-bounded, which keeps 1–2 frame occurrences queryable ([[short-event-preservation]]). Their `effects` link back to the state deltas that caused them (the ammo 27→26 delta in PRD §19).

## Requirements it satisfies

FR-12 (derived relationships between entities), FR-13 (temporally localised events), FR-15 (entity history), FR-16 (evidence for claims). Acceptance *Fast-event preservation* (PRD §65).

## Design tensions

- **Inference vs observation.** "Relationships" such as `aiming_at` or `behind cover` are often inferences. §30 contrasts "health changed from 72 to 49" with "enemy probably moved behind cover". Relationships need the same provenance discipline as fields ([[evidence-and-provenance]]).
- **Who derives events?** The PRD does not say whether events come from rules over deltas, dedicated event detectors (§23 mentions "an event detector fires") or game adapters.

> ⚠️ Tension: Relationships carry "start time / end time" (§17), while events use `start_frame` / `end_frame` (§18), and §32 says "no semantic record may depend solely on wall-clock time". The PRD does not say whether relationship times are frame IDs or timestamps.

> ⚠️ Tension: The event schema differs between §18 and §38. §18 uses `event_id`, `participants`, `start_frame`/`end_frame`, `effects` and `evidence`. The §38 stream appends `{type, actor, confidence}`, with `actor` instead of `participants` and no ID, frames or evidence.

> ⚠️ Tension: Events appear in three places: as a branch of `WorldState(t)` (§13), as separate "event records" in storage (§20), and as an `append` delta on path `events` (§38). Their canonical home is undefined. See [[persistent-world-state]].

> ⚠️ Tension: The evidence reference `frame:18472:region:392` implies stable region IDs. With an adaptive quadtree ([[adaptive-spatial-representation]]) that re-subdivides per frame, it is unclear whether "region 392" can be resolved after the fact.

## Related

[[persistent-world-state]] · [[semantic-annotation-taxonomy]] · [[snapshot-delta-storage]] · [[short-event-preservation]] · [[evidence-and-provenance]] · [[confidence-and-uncertainty]] · [[query-and-streaming-api]] · [[vid2seq]] · [[semantic-video-state-engine-prd]]
