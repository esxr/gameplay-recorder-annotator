---
title: Snapshot + Delta Storage
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [core-architecture, storage, reconstruction, codec]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [4.4, 19, 20, 25, 34, 35, 37, 38, 57, 65]
---

# Snapshot + Delta Storage

## Definition

The **Temporal Semantic State Stream** is the engine's core output. It serialises the [[persistent-world-state]] as occasional full snapshots plus per-frame deltas, like keyframes and residuals in a video codec (PRD §19, §20). The PRD says: "A complete state snapshot should not be emitted for every frame" (PRD §19).

## Components (PRD §20)

| Component | Content |
|---|---|
| Periodic semantic snapshots | Enough state to reconstruct the entire scene independently |
| Frame deltas | Changes relative to the previous state |
| Event records | Derived higher-level temporal occurrences ([[relationships-and-events]]) |
| Evidence references | Pointers to source video regions ([[evidence-and-provenance]]) |
| Long-term summaries | Compressed activity for LLM retrieval ([[three-level-semantic-memory]]) |

## How it works

Text form (PRD §19):

```text
Frame 18471  SNAPSHOT: player.health = 72; weapon.ammo = 27; enemy_17.visible = true; enemy_17.x = .713
Frame 18472  DELTA: weapon.ammo: 27 → 26; muzzle_flash: false → true; crosshair.x: +0.008
Frame 18473  DELTA: muzzle_flash: true → false; enemy_17.x: -0.004
Frame 18474  DELTA: ∅
```

An empty delta costs almost nothing, but the frame still exists in the timeline ([[sixty-fps-contract]]). The wire form (PRD §38) is a list of JSON-Patch-like ops (`replace` with `previous`/`value`, `append`, `transform` with `dx`/`dy`) keyed by frame and `time_sec`. Output formats include Event JSON and a binary stream ("likely Protobuf or equivalent") (PRD §37).

**Reconstruction** (PRD §20):

```text
State(frame N) = nearest_snapshot_before(N) + Σ deltas until N
```

## Requirements it satisfies

- **FR-14**: reconstruct full semantic state at any frame. **FR-15** (history per entity/UI property), **FR-19** (summaries without deleting fine history), **FR-20** (machine-readable export), **FR-24** (corrections supersede without destroying audit history).
- NFR *Determinism* (reproducible reconstruction per annotation version) and *Scalability* (storage grows with semantic change) (PRD §35). Acceptance *State reconstruction* (PRD §65). Mitigates *long-session memory growth* (PRD §57).

## Design tensions

> ⚠️ Tension: The §20 reconstruction formula treats deltas as exact. But PROPAGATE deltas (e.g. §38's `transform` with `"source": "tracker"`) are *estimates*, and in the §38 example that op has no confidence while the other ops do. The delta stream therefore mixes facts and estimates, and reconstruction sums them without regard to uncertainty. Errors accumulate between snapshots, which is the drift problem in storage form ([[drift-control]]).

> ⚠️ Tension: Snapshot cadence is unspecified. §20 says only "periodic". Neither a frame interval, a trigger (e.g. snapshot on FULL REFRESH or scene reset) nor a bound on worst-case reconstruction cost is given.

> ⚠️ Tension: FR-24 lets corrected annotations supersede earlier predictions, but deltas are relative to "the previous state". A correction at frame K invalidates every delta and snapshot after K that was computed from the wrong value. The PRD does not describe re-basing or annotation-version branching, only that determinism is per "annotation version" (§35).

> ⚠️ Tension: Paths are inconsistent. §19 uses `player.health` and `weapon.ammo`, §38 uses `entities.weapon_3.ammo` and `entities.enemy_17.position`, and §15 names the HUD element `hud.health`. No canonical addressing scheme is given, although FR-15 (history for any property) depends on one.

- **Delta granularity**: deltas are defined per frame, but events span frames and relationships have start/end times, so part of the stream is interval-based, not frame-based.

## Related

[[semantic-video-codec]] · [[persistent-world-state]] · [[region-update-modes]] · [[drift-control]] · [[relationships-and-events]] · [[evidence-and-provenance]] · [[three-level-semantic-memory]] · [[human-verification]] · [[query-and-streaming-api]] · [[semantic-video-state-engine-prd]]
