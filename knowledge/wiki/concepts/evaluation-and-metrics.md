---
title: Evaluation and Metrics
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [evaluation, metrics, benchmark, acceptance]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [51, 52, 53, 54, 61, 65]
---

# Evaluation and Metrics

**Definition.** The product is evaluated on both perception quality and downstream reasoning quality (PRD §51), using a dedicated frame-accurate gameplay benchmark (PRD §52), a set of critical benchmark questions (PRD §53), and a concept-level acceptance checklist (PRD §65).

## Success metrics (PRD §51)

| Metric | Definition | Linked concept |
|---|---|---|
| Temporal event recall | % of ground-truth short-lived events preserved; emphasis on few-frame events | [[short-event-preservation]] |
| Object continuity | % of object lifetime with the correct persistent ID | [[persistent-world-state]] |
| Identity-switch rate | Erroneous ID changes per tracked-object duration | [[drift-control]] |
| Mask/box accuracy | Standard segmentation/detection metrics | [[perception-modules]] |
| OCR accuracy | Character/word accuracy | [[ocr-and-text]] |
| UI-value accuracy | Parsed scalar/categorical HUD values | [[ui-hud-perception]] |
| Semantic delta precision / recall | Generated changes that are real / meaningful changes captured | [[snapshot-delta-storage]] |
| Re-inference avoidance | % regions/frames handled without full perception | [[selective-inference-scheduler]] |
| Compression ratio | Semantic size vs naive dense per-frame annotation | [[semantic-video-codec]] |
| Context efficiency | LLM input tokens needed for a target reasoning accuracy | [[context-compiler]] |
| Evidence reliability | % claims whose linked evidence actually supports them | [[evidence-and-provenance]] |
| Downstream QA accuracy | Temporal, spatial, state reconstruction, causality, fast-event, UI questions | [[llm-integration-modes]] |

The overarching optimisation target is "maximum retained semantic information per unit of compute" (PRD §54, [[compute-efficiency-objective]]). [[gemini-video-understanding]] and [[twelvelabs]] serve as downstream baselines for reasoning quality, token efficiency and fast-event recall (PRD §61).

## Evaluation dataset (PRD §52)

Coverage: static HUD, high-motion combat, scene cuts, camera spins, particle-heavy effects, dark scenes, menus, inventories, dialogue, text-heavy UI, minimaps, repeated identical enemies, occlusion, projectiles, fast damage, respawns, cutscenes, loading screens, resolution changes. Ground truth "should be frame-accurate for selected sequences". Many categories map directly to [[failure-modes]] (particles, camera motion, identity swaps, scene cuts).

## Critical benchmark questions (PRD §53)

Frame-exact first appearance; visibility before firing; health lost between shots; damage-indicator direction; ammo decrease before/after muzzle flash; objective-text change; collected vs merely viewed; same enemy re-seen after cover; *what was shown for only one source frame*. These target the product's unique value better than generic summarisation benchmarks (PRD §53).

## Acceptance criteria (PRD §65)

Frame continuity · Semantic persistence · Selective inference · Fast-event preservation · State reconstruction · Evidence grounding · LLM utility · Context efficiency · Uncertainty visibility.

> ⚠️ Tension: No §51 metric has a numeric target or threshold, and §65 relies on vague terms — "a substantial portion of unchanged screen content" (selective inference), "a handful of frames" (fast events), "answer detailed temporal questions" (LLM utility), "accurately" (context efficiency). The product cannot currently pass or fail its own acceptance test.

> ⚠️ Tension: *Context efficiency* is defined relative to "a target reasoning accuracy" that is never set, and no baseline token cost (e.g. raw-frame ingestion) is fixed for comparison.

> ⚠️ Tension: Ground truth is frame-accurate only "for selected sequences" (PRD §52), but object continuity and identity-switch rate are defined over whole object lifetimes, and *semantic delta recall* needs a ground-truth notion of "meaningful change" — itself an open research question (PRD §66.1).

> ⚠️ Tension: No metric covers confidence calibration, although *uncertainty visibility* is an acceptance criterion (PRD §65) and FR-25 exposes confidence downstream.

## Related

[[failure-modes]] · [[short-event-preservation]] · [[context-compiler]] · [[evidence-and-provenance]] · [[confidence-and-uncertainty]] · [[compute-efficiency-objective]] · [[selective-inference-scheduler]] · [[gemini-video-understanding]] · [[twelvelabs]] · [[open-research-questions]]
