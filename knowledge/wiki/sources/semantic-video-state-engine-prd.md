---
title: Semantic Video State Engine — Product Requirements Document
type: source
created: 2026-09-30
updated: 2026-09-30
tags: [prd, product-definition, semantic-video, gameplay, llm-context]
source: raw/semantic-video-state-engine-prd.md
research_cutoff: 2026-09-30
---

# Semantic Video State Engine — PRD (source summary)

**Status:** Product definition · **Research cutoff:** 2026-09-30 · **Core output:** Temporal Semantic State Stream · **Primary domain:** high-frame-rate gameplay and screen recordings · **Secondary domains:** computer-use agents, robotics, simulation, sports, surveillance, UI testing, multimodal training.

72 sections. This is the founding source of the wiki; every page currently traces back to it.

## Key claims

1. **Problem (§2):** raw video is a poor input for exact temporal reasoning. Sparse sampling misses short events (Gemini samples 1 fps by default). Dense VLM inference wastes compute on duplicate frames.
2. **Thesis (§4):** the right representation is *persistent semantic state + temporally encoded deltas + selectively kept visual evidence*. Five design principles follow: capture densely, infer sparsely, keep identity through time, encode change and not repetition, keep evidence. → [[semantic-video-codec]]
3. **60 fps contract (§12):** every captured frame moves the semantic timeline forward. For each region the engine picks COPY, PROPAGATE, REVALIDATE, RE-INFER REGION or FULL REFRESH. → [[sixty-fps-contract]], [[region-update-modes]]
4. **Six layers (§11):** capture → change/motion analysis → selective perception or propagation → persistent world state → temporal delta codec → LLM context/search/query.
5. **State model (§13–§18):** scene, entities, UI/HUD, text, relationships, motion, events, audio, confidence and evidence pointers. Every field has a confidence value (§49). → [[persistent-world-state]], [[semantic-annotation-taxonomy]], [[relationships-and-events]]
6. **Storage (§19–§20):** periodic snapshots + per-frame deltas + events + evidence refs + long-term summaries. `State(N) = nearest_snapshot_before(N) + Σ deltas`. → [[snapshot-delta-storage]]
7. **Scheduling (§22–§24, §27, §54–§55):** an importance score per region built from codec residual, pixel diff, flow, uncertainty, novelty, salience and query relevance. Use the cheapest model that can resolve the uncertainty (L0–L5). The goal is *most semantic information kept per unit of compute*. Visual change ≠ semantic change. → [[change-importance-scoring]], [[selective-inference-scheduler]], [[model-hierarchy]], [[change-versus-meaning]], [[drift-control]]
8. **LLM interface (§28–§29, §39–§40, §43):** a context compiler builds a view for each query within a token budget. There is a query API, a streaming API, and three integration modes (feed / retrospective / hybrid; hybrid is recommended). → [[context-compiler]], [[query-adaptive-fidelity]], [[query-and-streaming-api]], [[llm-integration-modes]]
9. **Trust (§30, §49, §65):** provenance on every claim. The system must never present propagated or uncertain information as equal to observed information. → [[evidence-and-provenance]], [[confidence-and-uncertainty]]
10. **Moat (§62, §67):** build the state graph, scheduler, delta format, memory, compiler and provenance layer. Integrate segmentation, OCR, flow, ASR and VLMs as replaceable parts. Positioning: "a semantic codec and memory layer for machine video understanding". → [[build-vs-buy]], [[strategic-differentiation]]
11. **Boundaries (§8, §58–§59):** pixels only, no memory reading or injection. Privacy controls must cover extracted OCR text as well as pixels. → [[game-integrity-boundary]], [[privacy-and-security]]

## Data points (as claimed by the PRD — unverified)

| Claim | § | Page |
|---|---|---|
| Gemini default static video path samples at 1 fps | 2, 10 | [[gemini-video-understanding]] |
| STCN > 20 fps for multiple objects | 9.2 | [[stcn]] |
| SAM 3.1: up to 32 fps for 16 tracked objects on one H100 | 9.2 | [[sam-family]] |
| STTM: ~2× speedup at 50% token budget, small accuracy loss | 9.5 | [[sttm]] |
| FrameFusion: −70% visual tokens, 1.6–3.6× end-to-end | 9.5 | [[framefusion]] |
| MeToM: 2.65× over baseline, no accuracy loss | 9.5 | [[metom]] |
| VPT: 70,000 h of Minecraft video auto-labelled; 20 Hz native control | 9.6 | [[vpt]] |
| DeepStream: infer every 2nd/3rd frame, tracker in between | 10 | [[nvidia-deepstream]] |
| Illustrative frame density: 204 objects, 81 UI/text, 2,100 regions, 600 relations, 1,900 tokens; 14 changed → 14 delta records | 36 | [[annotation-density]] |

## Requirements inventory

- **25 functional requirements** FR-01…FR-25 (§34). They map across the concept pages; each page lists the FR IDs it satisfies.
- **9 NFRs** (§35): accuracy, temporal fidelity, determinism, scalability, modularity, observability, privacy, fault tolerance, graceful degradation.
- **9 acceptance criteria** (§65) and **13 success metrics** (§51) → [[evaluation-and-metrics]].

## Internal tensions & gaps (flagged during ingest)

See the per-page `⚠️ Tension` callouts. Consolidated:

1. **Mode vocabulary drift.** §12/FR-10 list 5 update modes. §41's overlay shows 4 (no FULL REFRESH). The §72 diagram shows 3. §30's annotation modes (observed/propagated/copied/derived/inferred/human_verified) and §14's `state_source` field use another vocabulary, and no mapping between them is given. → [[region-update-modes]], [[evidence-and-provenance]]
2. **Field naming.** §14 lists "last strong re-inference frame" but the JSON example uses `last_full_inference_frame`. → [[semantic-annotation-taxonomy]]
3. **Deltas mix facts and estimates.** §20 reconstruction treats deltas as exact, but PROPAGATE deltas are estimates. Determinism (§35) holds for replay but not for truth. → [[snapshot-delta-storage]]
4. **Snapshot cadence undefined** ("periodic"). → [[snapshot-delta-storage]]
5. **One score, two axes.** §22 puts change signals and importance signals into one linear score, while §55 argues they are different dimensions. → [[change-importance-scoring]]
6. **No compute or latency budget** for real-time mode, and no per-class refresh policy (left open in §66.2). → [[selective-inference-scheduler]], [[drift-control]]
7. **Codec residuals assume encoder access** ("where available", §31), yet they sit first in the importance formula. → [[change-importance-scoring]]
8. **Privacy vs audit.** §58 requires OCR text to be deleted along with pixels. FR-24 and §50 keep audit history and original predictions. → [[privacy-and-security]], [[human-verification]]
9. **Lossy summaries vs traceability.** Long-term summaries (§20, §25) must still trace back to evidence (§30), but the mechanism is not specified. → [[three-level-semantic-memory]]
10. **No numeric targets.** The metrics (§51) have no thresholds. The acceptance criteria (§65) use words like "substantial portion". → [[evaluation-and-metrics]]
11. **Semantic cache invalidation** ("changes materially") has no threshold. → [[semantic-cache]]
12. **Context compiler ranking policy** under a token budget is not specified. → [[context-compiler]]

## Provenance notes

- The raw file keeps `citeturn…` markers exported from a chat research tool. They do not resolve, so each cited external claim still needs a primary source.
- The PRD's "research cutoff" is the same as the ingest date (2026-09-30).

## Related
[[overview]] · [[sixty-fps-contract]] · [[persistent-world-state]] · [[snapshot-delta-storage]] · [[context-compiler]] · [[open-research-questions]] · [[strategic-differentiation]]
