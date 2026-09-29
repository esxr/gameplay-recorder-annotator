---
title: Open Research Questions
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [research, open-questions, roadmap]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [22, 23, 24, 49, 51, 65, 66]
---

# Open Research Questions

**Definition.** Areas the PRD itself flags as "genuine R&D questions rather than solved engineering problems" (PRD §66). Each blocks the full specification of one or more concept pages; until answered, those pages describe intent, not a buildable design.

| # | Question (PRD §66) | Current PRD position | Blocks |
|---|---|---|---|
| 66.1 | What constitutes semantic change? | A learned semantic scheduler may outperform manual thresholds | [[change-importance-scoring]], [[change-versus-meaning]], [[selective-inference-scheduler]]; ground truth for delta precision/recall in [[evaluation-and-metrics]] |
| 66.2 | How often must persistent state be authoritatively refreshed? | Different object classes may need different refresh policies | [[drift-control]], [[region-update-modes]] |
| 66.3 | Can codec residuals predict semantic importance? | [[metom]] shows residuals help predict information density, but semantic importance ≠ residual magnitude | [[change-importance-scoring]] (codec-residual signal), [[semantic-video-codec]] |
| 66.4 | How should thousands of persistent semantic elements be represented? | Graph, key/value, learned visual tokens, object-centric latents, or hybrid symbolic/latent | [[persistent-world-state]], [[snapshot-delta-storage]] |
| 66.5 | How should latent visual state and explicit symbols interact? | May need latent embeddings alongside symbolic annotations | [[persistent-world-state]], [[semantic-cache]], [[evidence-and-provenance]] (provenance of latent state) |
| 66.6 | How should confidence decay? | Decay should depend on annotation type — copied values may stay certain; propagated positions decay within frames | [[confidence-and-uncertainty]], [[drift-control]] |
| 66.7 | Can the scheduler learn from downstream errors? | Repeated raw-evidence requests for an event type could teach the scheduler to keep more detail there | [[selective-inference-scheduler]], [[query-adaptive-fidelity]] |

> 🔎 Unverified: the characterisation of [[metom]]'s findings (codec residuals help predict information density) is the PRD's claim (PRD §66.3).

## Why they matter

These are not peripheral: the scheduler (PRD §23), drift thresholds (PRD §24) and uncertainty system (PRD §49) — all in the "build" core (PRD §62) — depend on 66.1, 66.2 and 66.6. The acceptance criteria (PRD §65) are phrased so they could be demonstrated with hand-tuned heuristics, leaving learned approaches as upside.

> ⚠️ Tension: 66.4 leaves the state representation open, yet the PRD already commits to JSON-path deltas (`entities.weapon_3.ammo`, PRD §38), a Protobuf-like binary stream (PRD §37) and a "semantic state graph" as a build item (PRD §62) — the choice is partly pre-empted.

> ⚠️ Tension: 66.5 contemplates latent embeddings as state, but the evidence model (PRD §30) and uncertainty model (PRD §49) are defined only for symbolic fields; how a latent vector is "traceable" or carries per-field confidence is undefined.

> ⚠️ Tension: 66.7 (a scheduler that adapts to downstream requests) conflicts with the *determinism* NFR (PRD §35) unless scheduler policy versions are recorded as part of provenance.

> ⚠️ Tension: No research question covers evaluation targets, calibration, or context-compiler ranking — gaps noted on [[evaluation-and-metrics]] and [[context-compiler]] that are arguably equally open.

## Related

[[change-importance-scoring]] · [[selective-inference-scheduler]] · [[drift-control]] · [[confidence-and-uncertainty]] · [[persistent-world-state]] · [[metom]] · [[query-adaptive-fidelity]] · [[evaluation-and-metrics]] · [[semantic-video-state-engine-prd]]
