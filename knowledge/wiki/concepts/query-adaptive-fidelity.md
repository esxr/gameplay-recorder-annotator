---
title: Query-Adaptive Fidelity
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [llm-interface, retrieval, fidelity]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [22, 23, 28, 29, 34, 39, 66]
---

# Query-Adaptive Fidelity

**Definition.** The same recorded session is compiled differently depending on the question asked, so the semantic archive is reusable rather than frozen into "one fixed caption of the video" (PRD §29). It is the selection policy inside the [[context-compiler]].

## Mechanism — per-query priorities (PRD §29)

| Query | Prioritise |
|---|---|
| "How many enemies crossed the doorway?" | object tracks, doorway region, identities, entry/exit events |
| "What did the notification say?" | OCR, exact screen crops, text confidence |
| "Why did the player miss?" | crosshair trajectory, target trajectory, firing timestamp, camera motion, hit markers |

Fidelity operates at two points:

1. **Read-time selection** — choosing which stored signals, regions and evidence crops go into context (the compiler's "desired precision" input, PRD §28).
2. **Write-time escalation** — if stored fidelity is too low, the consumer calls `reanalyze(session, time_range, region, fidelity)` (PRD §39) to force higher-fidelity re-analysis (FR-18). Live, *query relevance* is also a change-detection signal that raises scheduler priority (PRD §22, §23; see [[change-importance-scoring]], [[selective-inference-scheduler]]).

The loop closes in research question 66.7: if an LLM repeatedly requests raw evidence for a type of event, the scheduler might learn to preserve more detail there (PRD §66.7, see [[open-research-questions]]).

## Requirements satisfied

- **FR-17** — context driven by query and budget.
- **FR-18** — higher-fidelity re-analysis of a time range or region.
- **FR-23** — offline reprocessing of captured sessions (the substrate for retrospective escalation).

> ⚠️ Tension: The mapping from a free-text query to a fidelity profile is only illustrated with three examples; the PRD does not say whether it is rule-based, LLM-planned, or learned, nor what "fidelity" levels `reanalyze` accepts.

> ⚠️ Tension: Query relevance feeding the scheduler (PRD §22) means what gets inferred depends on which questions were asked, which sits awkwardly with the *determinism* NFR ("a frame and annotation version should produce reproducible state reconstruction", PRD §35) unless query-triggered refinements are versioned as separate annotation versions.

## Related

[[context-compiler]] · [[query-and-streaming-api]] · [[selective-inference-scheduler]] · [[change-importance-scoring]] · [[ocr-and-text]] · [[evidence-and-provenance]] · [[open-research-questions]]
