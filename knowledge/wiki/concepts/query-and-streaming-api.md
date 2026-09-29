---
title: Query and Streaming API
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [api, llm-interface, streaming, retrieval]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [20, 34, 37, 39, 40, 43]
---

# Query and Streaming API

**Definition.** The engine exposes two interfaces: a pull-style **Session Query API** for retrospective access to a stored session (PRD §39) and a push-style **Streaming API** for live consumers (PRD §40). Together they back the three [[llm-integration-modes]].

## Session Query API (PRD §39)

| Operation | Purpose | FR |
|---|---|---|
| `get_state(session, timestamp)` | Reconstruct full state at any frame (snapshot + Σ deltas, PRD §20) | FR-14 |
| `get_changes(session, start, end)` | Deltas over a range | FR-02 |
| `get_entity_history(session, entity_id)` | History of an entity or UI property | FR-15 |
| `get_events(session, start, end, filter)` | Temporally localised events | FR-13 |
| `search_semantics(session, query)` | Semantic search (embeddings output, PRD §37) | — |
| `get_evidence(annotation_id)` | Source evidence for a claim | FR-16 |
| `compile_context(session, query, token_budget)` | Token-budgeted LLM context | FR-17 |
| `reanalyze(session, time_range, region, fidelity)` | Higher-fidelity re-analysis | FR-18 |

`reanalyze` is the escalation path of [[query-adaptive-fidelity]]: a downstream model that finds stored state too coarse can request re-perception of a specific time range and region, relying on offline reprocessing (FR-23) and on the raw video retained under principle 4.5.

## Streaming API (PRD §40)

Subscribable event types: `state_delta`, `entity_created`, `entity_removed`, `event_started`, `event_completed`, `text_changed`, `ui_value_changed`, `scene_changed`, `confidence_warning`. The consumer "receives meaningful changes rather than polling entire snapshots" (PRD §40). Wire formats include event JSON and a compact binary (likely Protobuf) state stream (PRD §37).

## Requirements satisfied

FR-13, FR-14, FR-15, FR-16, FR-17, FR-18, FR-20 (machine-readable export), FR-25 (via `confidence_warning`).

> ⚠️ Tension: `reanalyze` results have no defined lifecycle — do they overwrite, supersede (as corrections do under FR-24), or sit alongside the original annotations as a new version? Nor is "fidelity" given a value space, or cost/latency bounds for an LLM-triggered call.

> ⚠️ Tension: The Streaming API has no latency, ordering, or backpressure requirements even though Mode A targets live agents (PRD §43), and there is no NFR for end-to-end live latency.

> ⚠️ Tension: The APIs are described as "conceptual" (PRD §39); none specifies how confidence, annotation mode or evidence IDs appear in responses, although FR-25 requires confidence-aware state.

## Related

[[llm-integration-modes]] · [[context-compiler]] · [[query-adaptive-fidelity]] · [[snapshot-delta-storage]] · [[evidence-and-provenance]] · [[confidence-and-uncertainty]] · [[relationships-and-events]] · [[scene-resets]] · [[inspection-and-session-explorer]]
