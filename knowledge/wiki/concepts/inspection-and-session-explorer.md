---
title: Live Inspection and Session Explorer
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [tooling, debugging, observability, ui]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [12, 35, 37, 41, 42, 50]
---

# Live Inspection and Session Explorer

**Definition.** Two developer-facing tools for seeing *what the engine believes and why*: a **Live Inspection Interface** that overlays semantic state on the running video (PRD §41), and a **Session Explorer** for navigating recorded sessions (PRD §42). They are the human side of [[evidence-and-provenance]].

## Live Inspection Interface (PRD §41)

Overlays: tracked objects, object IDs, masks, UI components, OCR, motion vectors, changed tiles, confidence, inference type, event labels.

It must make it "immediately obvious" whether a region was **COPIED, PROPAGATED, REVALIDATED or RE-INFERRED** — "essential for debugging temporal errors" (PRD §41). These correspond to the per-region update modes of the [[sixty-fps-contract]] / [[region-update-modes]] (PRD §12). Rendering uses the *frame overlays* output format (PRD §37).

## Session Explorer (PRD §42)

- scrub by frame; compare consecutive frames;
- inspect semantic state; inspect model confidence; inspect the exact evidence region;
- filter by entity or event;
- search text, objects, and semantic descriptions;
- jump between significant semantic changes.

## Mechanism and role

- Makes scheduler decisions visible, satisfying the *observability* NFR: "compute allocation and inference decisions inspectable" (PRD §35).
- Is the natural surface for [[human-verification]] corrections (PRD §50).
- Draws on the same substrate as the [[query-and-streaming-api]]: `get_state`, `get_changes`, `search_semantics`, `get_evidence`.

## Requirements satisfied

- **FR-14** (state at any frame), **FR-15** (entity history), **FR-16** (evidence), **FR-11** (confidence/provenance visible), supporting **FR-24** (correction UI).

> ⚠️ Tension: The overlay's mode labels (COPIED / PROPAGATED / REVALIDATED / RE-INFERRED, PRD §41) do not match the stored annotation modes (observed / propagated / copied / derived / inferred / human_verified, PRD §30) — "revalidated" is not storable and "human_verified"/"derived" are not displayable. See [[evidence-and-provenance]].

> ⚠️ Tension: "Significant semantic changes" (PRD §42) has no definition; it presumably reuses change-importance scores ([[change-importance-scoring]]) but the PRD does not say so.

## Related

[[evidence-and-provenance]] · [[human-verification]] · [[region-update-modes]] · [[sixty-fps-contract]] · [[query-and-streaming-api]] · [[confidence-and-uncertainty]] · [[selective-inference-scheduler]] · [[change-importance-scoring]]
