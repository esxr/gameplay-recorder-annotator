---
title: Privacy and Security
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [privacy, security, redaction, retention]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [4.5, 30, 34, 35, 43, 47, 48, 50, 58, 59]
---

# Privacy and Security

**Definition.** Because the engine can capture arbitrary screens, privacy controls are mandatory and must cover *both* raw pixels *and* everything extracted from them (PRD §58). NFR *Privacy*: "Captured screens may contain private information. Local processing and configurable redaction must be supported" (PRD §35).

## Required controls (PRD §58)

- local-only processing modes;
- excluded windows or regions;
- password-field suppression where detectable;
- configurable OCR redaction;
- PII filtering;
- encrypted storage;
- user-controlled retention;
- explicit capture indicator;
- deletion of semantic state with corresponding raw media.

**Key rule:** "Privacy controls must apply to both raw images and extracted semantic text. A password visible in pixels but deleted from video while remaining in OCR history is not acceptable" (PRD §58). Semantic derivatives — OCR strings, summaries, embeddings, compiled contexts — are therefore in scope, not just video.

## Mechanism

- Redaction must propagate along provenance links: deleting a region of pixels must find every claim whose [[evidence-and-provenance]] points to it, including `derived` claims and long-term summaries ([[three-level-semantic-memory]]).
- Excluded regions should be dropped before perception ([[ocr-and-text]], [[perception-modules]]) so they never enter the semantic store.
- Complements the [[game-integrity-boundary]]: ordinary display capture only, respecting OS/game capture restrictions (PRD §59).

## Requirements satisfied

NFR Privacy (PRD §35); constrains FR-01 (capture), FR-06 (text), FR-19 (summaries), FR-20 (export), FR-24 (audit).

> ⚠️ Tension: Redaction vs immutable audit trail. §58 requires OCR text to be deleted alongside pixels, but FR-24 requires corrections without "destroying audit history" and §50 requires "preserve the original prediction". A redacted password's original OCR prediction is exactly what must not survive. No redaction exception to audit immutability is defined. See [[human-verification]].

> ⚠️ Tension: FR-19 forbids deleting fine-grained history when summarising, and §4.5 requires original pixels to remain inspectable, yet §58 grants user-controlled retention and deletion. After deletion, surviving summaries or derived claims would carry dangling evidence references (PRD §30).

> ⚠️ Tension: Local-only processing (PRD §58) vs LLM integration modes B/C (PRD §43), which compile context for downstream — often cloud — LLMs. Whether compiled context is subject to redaction/PII filtering before egress is unspecified. See [[llm-integration-modes]].

> ⚠️ Tension: Privacy controls name "raw images and extracted semantic text" only. Optional audio speech transcription (PRD §47) and keyboard input capture (PRD §48) can capture passwords and PII too, but are not covered by any listed control.

> ⚠️ Tension: Human corrections "become eligible as future training data" (PRD §50) with no consent or retention rule, conflicting with user-controlled retention.

> ⚠️ Tension: "Excluded windows or regions" may leave gaps, while FR-02 and §65 *frame continuity* require a semantic transition for every captured frame; how excluded content is represented (e.g. as explicit `redacted` state) is unspecified.

## Related

[[evidence-and-provenance]] · [[human-verification]] · [[three-level-semantic-memory]] · [[llm-integration-modes]] · [[ocr-and-text]] · [[auxiliary-channels]] · [[game-integrity-boundary]] · [[frame-identity-and-capture]] · [[failure-modes]]
