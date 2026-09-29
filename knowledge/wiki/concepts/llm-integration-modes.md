---
title: LLM Integration Modes
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [llm-interface, integration, agents]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [10, 39, 40, 43, 58, 64]
---

# LLM Integration Modes

**Definition.** Three ways a downstream LLM consumes the semantic engine (PRD §43).

| Mode | What the LLM gets | Best for | Interface |
|---|---|---|---|
| **A — state feed** | A continuous event/state stream | Live agents | Streaming API (PRD §40) |
| **B — retrospective query** | Asks the semantic store for relevant historical information | Analysis | Session Query API (PRD §39) |
| **C — hybrid** | Important live events pushed, detailed history queried on demand | General use — **recommended** | Both |

## Mechanism

- **Mode A** subscribes to [[query-and-streaming-api]] events (`state_delta`, `event_started`, `confidence_warning`, …) — the working tier of [[three-level-semantic-memory]] projected as a stream.
- **Mode B** uses `compile_context`, `get_events`, `get_evidence` and `reanalyze`; the [[context-compiler]] and [[query-adaptive-fidelity]] do the heavy lifting.
- **Mode C** combines them: push keeps the model situationally aware cheaply; pull lets it drill into the long-term tier and evidence when it needs detail. This matches the product's "LLM-native retrieval" differentiator (PRD §10, [[strategic-differentiation]]).

The engine is intended to sit *upstream* of general video-reasoning models. The PRD positions [[gemini-video-understanding]] as an "excellent downstream reasoning interface" whose default static-video path samples at 1 fps, and [[twelvelabs]] as high-level semantic indexing — both complements rather than substitutes (PRD §10). Agent observation streams and multimodal RAG are listed as extensions (PRD §64).

> 🔎 Unverified: "Gemini's documented default static video path samples at 1 fps" is the PRD's claim (PRD §10), not independently checked.

## Requirements satisfied

- **FR-17** (Mode B/C context), **FR-18** (on-demand re-analysis in B/C), **FR-25** (confidence-aware state in all modes), **FR-13** (events in Mode A).

> ⚠️ Tension: Mode C's "important live events" is undefined — no importance threshold or filtering policy decides what is pushed versus left for query. It likely depends on [[change-importance-scoring]], but the PRD does not connect them.

> ⚠️ Tension: Modes B/C naturally send compiled context to external LLM APIs, while §58 requires local-only processing modes (see [[privacy-and-security]]). Whether local-only extends to the downstream LLM, and how redaction applies to compiled context, is unspecified.

## Related

[[query-and-streaming-api]] · [[context-compiler]] · [[query-adaptive-fidelity]] · [[three-level-semantic-memory]] · [[gemini-video-understanding]] · [[twelvelabs]] · [[strategic-differentiation]] · [[target-users-and-jobs]] · [[privacy-and-security]]
