---
title: OCR and Text
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [ocr, text, perception, flicker]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [12, 16, 22, 29, 33, 40, 44, 57]
---

# OCR and Text

**Definition.** Detection, recognition, and *persistent tracking* of on-screen text as first-class objects with lifetimes and change history (PRD §16).

## Text classes (PRD §16)

Static labels, rapidly changing counters, floating numbers, subtitles, player names, chat, kill feed, quest text, menus, tooltips, notifications, environmental text.

## Per-object fields (PRD §16)

Normalised text · exact observed string · location · style (where useful) · confidence · first visible timestamp · last visible timestamp · change history.

## Mechanism

- **Selective retriggering.** OCR re-runs only when a text region changes, confidence falls, geometry changes, a new region appears, or a downstream query demands high-confidence OCR (PRD §16).
- **Cheap validation.** An "OCR checksum" is a REVALIDATE-tier test (PRD §12). `OCR_difference` is a term in [[change-importance-scoring]] (PRD §22).
- **Structure.** A [[game-adapters|game adapter]] parses raw strings into fields, e.g. `"27 / 160"` → `ammo.current = 27`, `ammo.reserve = 160` (PRD §44).
- **Query-time fidelity.** "What did the notification say?" prioritises OCR, exact crops, and text confidence (PRD §29; [[query-adaptive-fidelity]]).
- **Streaming.** A `text_changed` event is published (PRD §40).

## OCR flicker (PRD §57)

**Risk:** unstable OCR creates false text-change events. **Mitigation:** temporal consensus and confidence hysteresis. Keeping both the normalised and the exact observed string lets consensus run on normalised text while the raw evidence is retained.

## Requirements satisfied

FR-06 (detect and persist text regions), FR-07 (numeric UI values), FR-15, FR-16 (evidence) (PRD §34). Metric: OCR accuracy (PRD §51).

## Risks

Flicker, tiny fonts, stylised game fonts, and floating damage numbers that move and fade. See [[failure-modes]].

> ⚠️ Tension: Temporal consensus and hysteresis need several agreeing frames. That conflicts with preserving text shown for "less than a conventional 1-fps sampling interval" or a single frame (§33). The PRD gives no window length or rule for when a single-frame reading is kept as a low-confidence observation rather than suppressed.

> ⚠️ Tension: "OCR checksum" (§12) is undefined. A checksum of pixels or crops is not a checksum of recognised text, and anti-aliasing or background motion behind semi-transparent text would break a pixel checksum without any text change.

## Related

[[ui-hud-perception]] · [[game-adapters]] · [[short-event-preservation]] · [[change-importance-scoring]] · [[query-adaptive-fidelity]] · [[semantic-cache]] · [[perception-modules]] · [[failure-modes]]
