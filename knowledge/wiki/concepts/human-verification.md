---
title: Human Verification
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [human-in-the-loop, correction, audit, training-data]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [10, 30, 34, 50, 58, 62]
---

# Human Verification

**Definition.** A human-in-the-loop correction path for the engine's mistakes (PRD §50). Humans can correct:

- identity switches;
- OCR failures;
- incorrect class assignments;
- false events;
- missing objects.

## Correction semantics (PRD §50)

A correction should:

1. update the state;
2. preserve the original prediction;
3. optionally trigger reprocessing around the corrected region;
4. become eligible as future training data.

Corrected annotations take the `human_verified` mode in [[evidence-and-provenance]] (PRD §30) and supersede — but do not erase — the machine prediction (FR-24). Reprocessing reuses the `reanalyze` / offline-reprocessing machinery ([[query-and-streaming-api]], FR-18, FR-23); because identity corrections change entity continuity, re-deriving downstream relationships and events ([[relationships-and-events]]) is implied.

## Build vs integrate

The PRD does not want to reinvent labelling tools: [[encord]], [[cvat]] and [[supervisely]] "demonstrate mature human-in-the-loop patterns that can inform this interface" (PRD §50). All three are characterised as annotation platforms rather than live semantic codecs (PRD §10); annotation-QA and training-data workflows are an "integrate where advantageous" area (PRD §61–62, [[build-vs-buy]]). The correction UI naturally lives in the [[inspection-and-session-explorer]].

## Requirements satisfied

- **FR-24** — corrected annotations supersede earlier predictions without destroying audit history.
- **FR-11** — provenance (human_verified mode).
- **FR-23** — offline reprocessing after correction.

> ⚠️ Tension: Redaction vs immutable audit trail. §58 requires that privacy controls apply to extracted semantic text and that "a password visible in pixels but deleted from video while remaining in OCR history is not acceptable", while FR-24 forbids destroying audit history and §50 requires preserving the original prediction. If a human corrects/redacts an OCR read of a password, the preserved original prediction *is* the leak. The PRD does not define a privacy-deletion exception to audit immutability. See [[privacy-and-security]].

> ⚠️ Tension: "Eligible as future training data" (PRD §50) conflicts in spirit with local-only processing and user-controlled retention (PRD §58): consent, scope, and whether training copies are deleted with the session are unspecified.

> ⚠️ Tension: No conflict policy for multiple reviewers or for a later machine re-inference contradicting a human correction (does `human_verified` pin the value against reprocessing?).

## Related

[[evidence-and-provenance]] · [[inspection-and-session-explorer]] · [[privacy-and-security]] · [[encord]] · [[cvat]] · [[supervisely]] · [[build-vs-buy]] · [[query-and-streaming-api]] · [[relationships-and-events]] · [[evaluation-and-metrics]]
