---
title: Overview — Semantic Video State Engine
type: overview
created: 2026-09-30
updated: 2026-09-30
tags: [overview, thesis, semantic-video, gameplay]
sources: [raw/semantic-video-state-engine-prd.md]
---

# Overview

_The current summary of what the wiki knows. Built from one source so far: the product PRD ([[semantic-video-state-engine-prd]])._

## The thesis in one line

Turn every frame of 60 fps screen/gameplay video into a **persistent, evidence-grounded machine world state**, and spend expensive vision compute mainly on **what actually changed** (PRD §71).

## Why it should exist

Two ways of handing video to a reasoning model both fail (PRD §2, §4):

| Approach | Failure |
|---|---|
| Sample sparsely (e.g. [[gemini-video-understanding]] at 1 fps by default) | Misses events that last 1–5 frames: hit markers, muzzle flashes, damage ticks ([[short-event-preservation]]) |
| Run big vision models densely on every frame | Wastes compute, because neighbouring frames are almost the same |

The PRD's answer is a third representation: **persistent semantic state + temporally encoded deltas + selectively retained visual evidence** (PRD §4). The PRD compares this to a video codec that encodes *which meanings changed* instead of *which pixels changed* ([[semantic-video-codec]]).

## How the pieces fit

```
capture (60 fps, frame identity) ─► change analysis ─► per-region decision
   [[frame-identity-and-capture]]     [[change-importance-scoring]]   [[region-update-modes]]
                                                                        COPY / PROPAGATE / REVALIDATE / RE-INFER / FULL REFRESH
        ─► persistent world state ─► snapshot + delta stream ─► memory tiers ─► context compiler ─► LLM
           [[persistent-world-state]]  [[snapshot-delta-storage]]  [[three-level-semantic-memory]]  [[context-compiler]]
```

- **The decoupling that makes it work:** the [[sixty-fps-contract]] says every frame moves the semantic timeline forward. It does *not* say every model runs on every frame. The PRD reports that even SAM 3.1 reaches only about 32 fps for 16 objects on one H100 ([[sam-family]]). So inference rate and timeline rate must be separate.
- **Cheapest model first:** the [[selective-inference-scheduler]] escalates through the [[model-hierarchy]] (L0 deterministic compare … L4 VLM … L5 human).
- **Keep the scheduler honest:** [[drift-control]] and [[scene-resets]] limit error that builds up during propagation. [[change-versus-meaning]] explains why pixel motion alone cannot set priority.
- **Screens are not natural images:** HUD and text get their own perception path ([[ui-hud-perception]], [[ocr-and-text]]). Per-game specialization comes from [[game-adapters]] and the [[semantic-cache]].
- **Trust layer:** every claim carries [[evidence-and-provenance]] and [[confidence-and-uncertainty]], so an observed "health 72→49" is never presented as equal to "enemy probably behind cover".

## Where the moat is claimed to be

Not in any one perception model. Those are interchangeable ([[model-agnostic-providers]], [[build-vs-buy]]). The moat is **how different perception outputs combine into one persistent world state that stays consistent over time** (PRD §62). The PRD says it found no product that combines all of: 60 fps capture, dense persistent state, change-aware re-inference, delta encoding and native LLM retrieval ([[strategic-differentiation]]).

## Current assessment (wiki maintainer's view)

- **Strongest ideas:** decoupling timeline rate from inference rate; snapshot + delta storage for state reconstruction; provenance on every field; compiling context per query.
- **Weakest / least specified:** no numeric targets anywhere ([[evaluation-and-metrics]]); no compute budget or latency target for real-time mode; conflict between privacy redaction and an immutable audit trail ([[privacy-and-security]] vs [[human-verification]]); three different names for the update/annotation modes ([[region-update-modes]] vs [[evidence-and-provenance]]). See the tensions list on [[semantic-video-state-engine-prd]].
- **Unverified:** every third-party performance figure (SAM 3.1, STTM, FrameFusion, MeToM, STCN) comes only from the PRD. None of the primary papers is in `raw/` yet.
- **Real R&D risk:** [[open-research-questions]], especially what counts as semantic change, whether codec residuals predict semantic importance ([[metom]]), and how confidence should decay for each annotation type.

## Suggested next sources

1. MeToM (CVPR 2026) paper: it is the closest prior art for using codec metadata as a signal for the scheduler.
2. SAM 3 / SAM 3.1 papers and release notes: they set the throughput limits that the [[sixty-fps-contract]] has to work around.
3. NVIDIA DeepStream docs on inference interval and tracker: the reference design for "infer sparsely, track in between".
4. OmniParser and ScreenAI papers: the basis for [[ui-hud-perception]].
5. A game-specific HUD layout study for one target title, to ground [[game-adapters]].

## Related
[[semantic-video-state-engine-prd]] · [[semantic-video-codec]] · [[sixty-fps-contract]] · [[persistent-world-state]] · [[context-compiler]] · [[strategic-differentiation]] · [[open-research-questions]]
