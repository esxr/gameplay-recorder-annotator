---
title: Evidence and Provenance
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [provenance, evidence, audit, grounding]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [4.5, 12, 20, 30, 34, 39, 41, 57, 63, 65]
---

# Evidence and Provenance

**Definition.** Every machine-generated semantic claim should be traceable back to the pixels and the model decision that produced it (PRD §30). This operationalises thesis principle 4.5: "semantic compression must not eliminate the ability to inspect the original pixels that led to an annotation" (PRD §4.5).

## Evidence reference fields (PRD §30)

- original frame number;
- timestamp;
- bounding region;
- model that produced the annotation;
- model version;
- annotation mode;
- confidence;
- parent evidence where derived.

## Annotation modes (PRD §30)

```text
observed | propagated | copied | derived | inferred | human_verified
```

The mode lets downstream systems distinguish a directly read fact ("health changed from 72 to 49") from a hypothesis ("enemy probably moved behind cover") (PRD §30). Modes and confidence together form the basis of [[confidence-and-uncertainty]]; `human_verified` is set by [[human-verification]].

## Mechanism

- Evidence references are a first-class stream element alongside snapshots, deltas, events and summaries (PRD §20, [[snapshot-delta-storage]]).
- `get_evidence(annotation_id)` returns the backing record (PRD §39, [[query-and-streaming-api]]); the [[inspection-and-session-explorer]] lets a human "inspect the exact evidence region" (PRD §42).
- Derived claims (relationships, events) chain to parent evidence, forming a provenance DAG.
- Model and version fields are the stated mitigation for the *model upgrades* failure mode — "stored annotations become incomparable" (PRD §57, [[failure-modes]], [[model-agnostic-providers]]).

## Requirements satisfied

- **FR-16** — return source evidence for semantic claims.
- **FR-11** — store annotation confidence and provenance.
- **FR-24** — corrections supersede without destroying audit history (provenance is the audit trail).
- Core scope item 7, "traced back to visual evidence" (PRD §63); acceptance criterion *Evidence grounding* — "traced to the exact source frame and region" (PRD §65); metric *evidence reliability* (PRD §51).

> ⚠️ Tension: Three different mode vocabularies exist. §30 annotation modes are `observed/propagated/copied/derived/inferred/human_verified`; the 60 fps contract update modes are COPY / PROPAGATE / REVALIDATE / RE-INFER REGION / FULL REFRESH (PRD §12); the inspection overlay shows COPIED / PROPAGATED / REVALIDATED / RE-INFERRED (PRD §41). "Revalidated" and "full refresh" have no §30 equivalent, and "observed" vs "re-inferred" are not mapped. See [[region-update-modes]].

> ⚠️ Tension: Long-term summaries (PRD §20, §25) are lossy compressions, yet must remain traceable. Whether a summary is a `derived` claim with a list of parent evidence (potentially huge) or some coarser pointer is unspecified. See [[three-level-semantic-memory]].

> ⚠️ Tension: Evidence requires retaining the original pixels (PRD §4.5), but §58 requires deletion of semantic state together with raw media and user-controlled retention. After retention expiry, surviving semantic claims would point to deleted evidence; the PRD does not say whether such claims are also deleted or downgraded. See [[privacy-and-security]].

> ⚠️ Tension: The §38 example stream includes a tracker `transform` update with a `source` but no confidence or mode, and no evidence reference at all, so the example wire format does not yet demonstrate per-claim provenance.

## Related

[[confidence-and-uncertainty]] · [[human-verification]] · [[region-update-modes]] · [[snapshot-delta-storage]] · [[query-and-streaming-api]] · [[inspection-and-session-explorer]] · [[privacy-and-security]] · [[failure-modes]] · [[model-agnostic-providers]] · [[evaluation-and-metrics]]
