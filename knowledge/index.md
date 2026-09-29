# Index

_Last updated: 2026-09-30 · 1 source · 67 pages (1 overview, 1 source, 23 entities, 42 concepts)_

## Overview
- [[overview]] — thesis, how the pieces fit, current assessment, next sources to ingest

## Sources
- [[semantic-video-state-engine-prd]] — founding PRD: 60 fps semantic state stream for gameplay video; key claims, unverified data points, 12 internal tensions

## Concepts — core architecture
- [[semantic-video-codec]] — encode which *meanings* changed, not which pixels changed
- [[sixty-fps-contract]] — every frame advances the timeline; inference rate is decoupled
- [[region-update-modes]] — COPY / PROPAGATE / REVALIDATE / RE-INFER / FULL REFRESH per region
- [[persistent-world-state]] — WorldState(t): scene, entities, HUD, text, relations, events, confidence, evidence
- [[semantic-annotation-taxonomy]] — per-object fields, JSON shape, per-field confidence
- [[relationships-and-events]] — time-bounded relation graph and derived event records
- [[snapshot-delta-storage]] — periodic snapshots + frame deltas; State(N) reconstruction
- [[frame-identity-and-capture]] — capture requirements and deterministic frame IDs
- [[adaptive-spatial-representation]] — masks, boxes, UI regions + adaptive quadtree tiles
- [[annotation-density]] — thousands of addressable elements per frame, deltas only for changes

## Concepts — compute & scheduling
- [[change-importance-scoring]] — per-region score from codec, pixel, flow, uncertainty, salience, query
- [[change-versus-meaning]] — large visual change ≠ semantic change and vice versa
- [[selective-inference-scheduler]] — where compute goes; priority up/down triggers
- [[model-hierarchy]] — L0 deterministic → L5 human; cheapest capable model first
- [[drift-control]] — confidence decay and refresh thresholds for propagated state
- [[scene-resets]] — selective invalidation on cuts, loads, respawns, window switches
- [[short-event-preservation]] — 1–few-frame events as the core differentiator
- [[compute-efficiency-objective]] — maximize retained semantic info per unit compute; graceful degradation

## Concepts — perception & adaptation
- [[ui-hud-perception]] — HUD/UI as a first-class perception path with persistent IDs
- [[ocr-and-text]] — text objects, change history, retrigger conditions, flicker
- [[perception-modules]] — modular detector/tracker/OCR/flow/VLM catalog
- [[model-agnostic-providers]] — provider interfaces so models are swappable
- [[game-adapters]] — per-game ontology extensions learned from repetition
- [[semantic-cache]] — visual pattern → prior interpretation, confidence-aware
- [[auxiliary-channels]] — audio and recorded input; inferred vs recorded actions

## Concepts — memory, retrieval, LLM interface
- [[three-level-semantic-memory]] — sensory / working / long-term episodic
- [[context-compiler]] — query + token budget → the most relevant representation
- [[query-adaptive-fidelity]] — same archive compiled differently per question
- [[evidence-and-provenance]] — every claim traceable to frame, region, model, mode
- [[confidence-and-uncertainty]] — per-field confidence; unknown ≠ hallucinated
- [[query-and-streaming-api]] — get_state / compile_context / reanalyze + event subscriptions
- [[llm-integration-modes]] — feed / retrospective / hybrid (recommended)
- [[inspection-and-session-explorer]] — live overlay and recorded-session debugging UI
- [[human-verification]] — corrections that supersede without destroying history

## Concepts — product, quality & strategy
- [[target-users-and-jobs]] — six user groups, the core job, example questions
- [[evaluation-and-metrics]] — metrics, benchmark dataset, benchmark questions, acceptance
- [[failure-modes]] — risk → mitigation table
- [[privacy-and-security]] — local processing, redaction across pixels *and* OCR text
- [[game-integrity-boundary]] — display capture only; no memory/injection; not a cheat
- [[build-vs-buy]] — build the state core, integrate commodity perception
- [[strategic-differentiation]] — bridging annotation/perception and video reasoning
- [[open-research-questions]] — §66's seven open R&D questions

## Entities — research
- [[deep-feature-flow]] — sparse keyframe inference + flow propagation (CVPR 2017)
- [[video-propagation-networks]] — online propagation of structured labels (CVPR 2017)
- [[stcn]] — space-time correspondence VOS (NeurIPS 2021)
- [[xmem]] — sensory/working/long-term memory for long-video VOS (ECCV 2022)
- [[sam-family]] — SAM 2 → SAM 3 → SAM 3.1: streaming, open-vocab, multiplexed tracking
- [[mask2former]] — unified semantic/instance/panoptic segmentation (CVPR 2022)
- [[screenai]] — structured screen annotation for LLMs (2024)
- [[ferret-ui]] — grounded understanding of small UI elements (2024)
- [[omniparser]] — screenshot → structured interactable elements (Microsoft, 2024)
- [[vid2seq]] — time-token dense event captioning (CVPR 2023)
- [[streaming-dense-video-captioning]] — fixed-size clustered memory, streaming captions (CVPR 2024)
- [[moviechat]] — short-term + long-term memory for long video (CVPR 2024)
- [[sttm]] — quadtree spatio-temporal token merging (ICCV 2025)
- [[framefusion]] — adjacent-frame token merging + pruning (ICCV 2025)
- [[metom]] — codec residual/GOP metadata to budget tokens (CVPR 2026)
- [[vpt]] — inverse-dynamics labelling of 70k h Minecraft video (OpenAI 2022)

## Entities — products & platforms
- [[nvidia-deepstream]] — sparse inference + tracker production pipeline; systems reference
- [[encord]] — video annotation platform with SAM 3 assist; QA tooling option
- [[cvat]] — open annotation platform with SAM2 tracking
- [[supervisely]] — video annotation and model-assisted tracking
- [[google-cloud-video-intelligence]] — timestamped object tracking API
- [[twelvelabs]] — Marengo embeddings + Pegasus video-to-text; downstream baseline
- [[gemini-video-understanding]] — direct video reasoning; 1 fps default; downstream baseline

## Reports
- [Before/after reports](ba-reports/index.md) — verification reports, newest first (none yet)
