# AGENTS.md — Semantic Video State Engine knowledge base

Schema and conventions for this wiki. Read this first every session; it overrides the llm-wiki skill defaults where they differ.

## Domain

Product knowledge for the **Semantic Video State Engine**: a system that turns high-frame-rate (60 fps baseline) gameplay/screen video into a persistent, evidence-grounded semantic world state, stored as snapshots + deltas, and compiled into LLM context on demand. The wiki covers:

- the product's own design concepts (what we are building and why),
- the research it builds on (papers/models → `entities/`),
- the commercial landscape (products/platforms → `entities/`),
- open questions, contradictions and gaps in the spec.

## Layout

```
knowledge/
├── AGENTS.md        # this file
├── index.md         # catalog of every page
├── log.md           # append-only activity log
├── ba-reports/      # before/after verification reports (+ index.md)
├── raw/             # immutable sources — never edit
└── wiki/
    ├── overview.md
    ├── sources/     # one summary per raw source
    ├── entities/    # papers, models, products, platforms
    └── concepts/    # product design concepts & mechanisms
```

## Page types

`type` enum: `overview`, `source`, `entity`, `concept`.
Entities additionally carry `kind: paper | model-family | product | platform`.

## Frontmatter

```yaml
---
title: XMem
type: entity
kind: paper
created: 2026-09-30
updated: 2026-09-30
tags: [video-object-segmentation, memory]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.2, 25, 61]     # PRD § numbers this page draws on (optional but encouraged)
---
```

Source pages use `source:` (single path) instead of `sources:`.

## Conventions

- Filenames `kebab-case.md`; links are `[[slug]]` or `[[slug|display text]]` (no folder prefix, no `.md`).
- Cite the PRD inline as `(PRD §12)`. Every non-obvious claim should have a § reference.
- **External claims are unverified.** Figures the PRD attributes to third parties (e.g. "SAM 3.1: 32 fps for 16 objects on one H100", "MeToM 2.65×") are recorded as *the PRD's claims*, not independently verified facts. Mark them with `> 🔎 Unverified: ...` until a primary source is ingested into `raw/`.
- The PRD's `citeturn…` markers are export artifacts from a chat tool; they do not resolve to anything. Don't copy them into wiki pages.
- Flag internal inconsistencies with `> ⚠️ Tension: ...` on the affected page, and list them on [[semantic-video-state-engine-prd]].
- Every page ends with a `## Related` section of `[[links]]`.
- Prefer editing existing pages over creating near-duplicates.

## Slug registry (canonical page names)

Use these exact slugs when linking. Adding a new page = add it here and in `index.md`.

**Overview / sources:** `overview`, `semantic-video-state-engine-prd`

**Concepts — core architecture:** `semantic-video-codec`, `sixty-fps-contract`, `region-update-modes`, `persistent-world-state`, `semantic-annotation-taxonomy`, `relationships-and-events`, `snapshot-delta-storage`, `frame-identity-and-capture`, `adaptive-spatial-representation`, `annotation-density`

**Concepts — compute & scheduling:** `change-importance-scoring`, `change-versus-meaning`, `selective-inference-scheduler`, `model-hierarchy`, `drift-control`, `scene-resets`, `short-event-preservation`, `compute-efficiency-objective`

**Concepts — perception & adaptation:** `ui-hud-perception`, `ocr-and-text`, `perception-modules`, `model-agnostic-providers`, `game-adapters`, `semantic-cache`, `auxiliary-channels`

**Concepts — memory, retrieval, LLM interface:** `three-level-semantic-memory`, `context-compiler`, `query-adaptive-fidelity`, `evidence-and-provenance`, `confidence-and-uncertainty`, `query-and-streaming-api`, `llm-integration-modes`, `inspection-and-session-explorer`, `human-verification`

**Concepts — product, quality & strategy:** `evaluation-and-metrics`, `failure-modes`, `privacy-and-security`, `game-integrity-boundary`, `build-vs-buy`, `strategic-differentiation`, `open-research-questions`, `target-users-and-jobs`

**Entities — research (kind: paper / model-family):** `deep-feature-flow`, `video-propagation-networks`, `stcn`, `xmem`, `sam-family`, `mask2former`, `screenai`, `ferret-ui`, `omniparser`, `vid2seq`, `streaming-dense-video-captioning`, `moviechat`, `sttm`, `framefusion`, `metom`, `vpt`

**Entities — products/platforms:** `nvidia-deepstream`, `encord`, `cvat`, `supervisely`, `google-cloud-video-intelligence`, `twelvelabs`, `gemini-video-understanding`
