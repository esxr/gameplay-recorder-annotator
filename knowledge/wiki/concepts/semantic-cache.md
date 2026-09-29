---
title: Semantic Cache
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [cache, reuse, compute, embeddings]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [12, 35, 44, 45, 46, 54]
---

# Semantic Cache

**Definition.** A cache that maps **visual patterns → prior semantic interpretations**, so recurring appearances resolve without re-running expensive perception (PRD §46).

## Cache entries (PRD §46)

```text
visual embedding  → known UI icon
screen crop       → prior OCR structure
object appearance → tracked entity identity
menu template     → parsed semantic layout
```

**Constraint:** "The cache must be confidence-aware and invalidated when appearance changes materially" (PRD §46).

## Mechanism

The cache gives a lookup path between REVALIDATE and RE-INFER (PRD §12). For example, embedding a region and matching a known icon costs L2 rather than L3/L4 ([[model-hierarchy]]). It is the runtime form of "learning from repetition" (PRD §45). Its long-lived, per-game knowledge overlaps with [[game-adapters]] (PRD §44). Caching directly serves the [[compute-efficiency-objective]]: do not "repeatedly understand unchanged HUD pixels" (PRD §54).

## Requirements satisfied

No FR names the cache. It supports FR-03 (persistent identity via appearance → identity), FR-05, FR-06 and FR-10 (PRD §34).

## Risks

A stale or over-general hit returns a confident wrong interpretation. Examples: an icon that keeps its appearance but changes meaning by context, or two visually identical enemies (identity swap, §57). See [[failure-modes]].

> ⚠️ Tension: "Invalidated when appearance changes materially" has no threshold, metric (embedding distance? pixel residual?), or per-entry-type setting. "Materially" is undefined in the same way semantic change is (§66.1).

> ⚠️ Tension: "Object appearance → tracked entity identity" makes appearance a key for identity. The PRD itself names visually similar entities as the identity-swap failure mode (§57), so this entry type needs trajectory and context, not appearance alone.

> ⚠️ Tension: Cache contents depend on session history, so the same frame can resolve differently depending on what was seen earlier. That strains NFR Determinism (§35) unless the cache state is versioned with the annotation. No cache scope (per session, per game, global), eviction, or provenance tag for "resolved from cache" is specified.

## Related

[[game-adapters]] · [[model-hierarchy]] · [[compute-efficiency-objective]] · [[ui-hud-perception]] · [[ocr-and-text]] · [[region-update-modes]] · [[evidence-and-provenance]] · [[failure-modes]]
