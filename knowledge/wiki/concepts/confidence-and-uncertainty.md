---
title: Confidence and Uncertainty
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [uncertainty, confidence, quality, llm-interface]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [22, 24, 30, 34, 40, 49, 57, 65, 66]
---

# Confidence and Uncertainty

**Definition.** "Annotations should not be treated as binary truth. Each field must support uncertainty" (PRD §49). Every attribute carries its own confidence, so downstream LLMs "can reason differently about certain versus uncertain facts" (PRD §49).

## Per-field confidence (PRD §49)

```text
class:    { value: "enemy",    confidence: .98 }
weapon:   { value: "rifle",    confidence: .71 }
identity: { value: "enemy_17", confidence: .89 }
```

Confidence is per field, not per object — the same entity may have a near-certain class and a doubtful weapon.

## Mechanism

- **Mode + confidence.** Each claim also carries an annotation mode (observed, propagated, copied, derived, inferred, human_verified) via [[evidence-and-provenance]] (PRD §30).
- **Decay.** Confidence decays with time since authoritative revalidation; decay is a change-detection signal and a scheduler trigger when it falls below threshold (PRD §22, §23; [[change-importance-scoring]], [[selective-inference-scheduler]]). Drift control tracks confidence, time since authoritative inference and propagation distance per annotation (PRD §24, [[drift-control]]). Decay should depend on annotation type — a copied value may stay certain indefinitely while a propagated location becomes uncertain within frames (PRD §66.6).
- **Hysteresis.** OCR uses temporal consensus and confidence hysteresis against flicker (PRD §57).
- **Streaming.** A `confidence_warning` event is part of the streaming API (PRD §40, [[query-and-streaming-api]]).
- **Unknown, not hallucinated.** For game state that is not visually observable, the mitigation is to "explicitly mark it unknown rather than hallucinating" (PRD §57, *hidden semantic state*; [[failure-modes]]).

## Requirements satisfied

- **FR-25** — expose confidence-aware state to downstream models.
- **FR-11** — store annotation confidence and provenance.
- Acceptance *Uncertainty visibility*: "the system never presents propagated or uncertain information as equivalent to directly observed high-confidence information" (PRD §65).
- NFR *Accuracy*: reuse must not "silently propagate obviously invalid state" (PRD §35).

> ⚠️ Tension: §57 requires hidden state be marked *unknown*, but the §49 schema is only `value + confidence`. There is no explicit `unknown` value, and "confidence 0" is not the same thing as "not observable" (a confidently absent value vs. an unobservable one).

> ⚠️ Tension: §65 forbids presenting propagated information as equivalent to observed information, while §66.6 says a *copied* value may remain certain indefinitely. Whether a long-copied value may be presented at the same confidence as a fresh observation — and thus be "equivalent" — is unresolved.

> ⚠️ Tension: No calibration requirement exists. Confidences from heterogeneous, swappable models (FR-22) are compared and thresholded (PRD §23, §24) without any statement that they are calibrated or comparable across models.

> ⚠️ Tension: Decay functions are an open research question (PRD §66.6), yet drift thresholds (§24) and the scheduler (§23) depend on them — core behaviour rests on an unresolved design.

## Related

[[evidence-and-provenance]] · [[drift-control]] · [[selective-inference-scheduler]] · [[change-importance-scoring]] · [[region-update-modes]] · [[ocr-and-text]] · [[failure-modes]] · [[context-compiler]] · [[open-research-questions]]
