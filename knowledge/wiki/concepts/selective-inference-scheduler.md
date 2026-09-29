---
title: Selective Inference Scheduler
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [scheduling, compute, sparse-inference]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [4.2, 7, 9.1, 12, 23, 27, 35, 41, 54, 61, 62, 65, 66.2, 66.7]
---

# Selective Inference Scheduler

**Definition.** The component that "decides how compute is spent" (PRD §23). Each frame and region, it turns change/importance signals into one of the §12 update modes, and so into a tier of the [[model-hierarchy]]. The PRD lists the "change-aware scheduler" among the differentiated core to build in-house (PRD §62).

## Mechanism

Priority **increases** when (PRD §23): a static region changes; a new object appears; an object disappears unexpectedly; identity becomes ambiguous; OCR changes; a tracked mask drifts; a scene cut is detected; an object becomes occluded; an event detector fires; downstream reasoning requests detail; stored confidence decays below a threshold.

Priority **decreases** when (PRD §23): appearance is stable; motion is predictable; UI values are unchanged; adjacent tokens stay highly similar; the region is irrelevant to current tasks.

The output is a per-region mode: COPY → PROPAGATE → REVALIDATE → RE-INFER REGION → FULL REFRESH (PRD §12; see [[region-update-modes]]). Inputs come from [[change-importance-scoring]] and [[drift-control]]. [[scene-resets]] force refresh.

**Precedents.** [[framefusion]] exploits adjacent-frame token similarity. [[nvidia-deepstream]] skips inference frames while a tracker fills the gaps (PRD §23, §61). [[deep-feature-flow]] frames full inference as a sparse "refresh operation" (PRD §9.1).

> 🔎 Unverified: DeepStream configurations that "infer every second or third frame" are the PRD's description (PRD §10, §61).

**Learning.** §66.7 proposes that the scheduler learn from downstream errors, for example preserving more detail around event types an LLM repeatedly asks raw evidence for (PRD §66.7).

**Observability.** Allocation decisions must be inspectable (NFR Observability, PRD §35). The live overlay shows COPIED / PROPAGATED / REVALIDATED / RE-INFERRED per region (PRD §41; see [[inspection-and-session-explorer]]).

## Requirements satisfied

FR-09, FR-10, FR-18 (downstream re-analysis requests) (PRD §34). Acceptance criterion "Selective inference": a substantial portion of unchanged content advances without full re-inference (PRD §65). Metric: re-inference avoidance (PRD §51).

## Risks

Under-scheduling misses short events; over-scheduling burns compute on particles and camera pans (PRD §54, §57). See [[failure-modes]], [[compute-efficiency-objective]] and [[short-event-preservation]].

> ⚠️ Tension: No compute budget, GPU target, or per-frame latency bound is stated for real-time mode, although Goal 14 requires "real-time streaming" (PRD §7). "Graceful degradation" (§35) presumes a budget that is never defined. The PRD's own [[sam-family]] figure (SAM 3.1 ~32 fps for 16 objects on one H100, §9.2) shows the gap without closing it.

> ⚠️ Tension: There is no per-class refresh policy. §66.2 leaves open how often persistent state must be authoritatively refreshed ("different object classes may require different refresh policies"), so the scheduler lacks its baseline cadence.

> ⚠️ Tension: The mode vocabularies do not line up. §12 has five modes, the §41 overlay shows four (no FULL REFRESH), and §30 provenance modes (observed/propagated/copied/derived/inferred/human_verified) have no "revalidated". A revalidated annotation cannot be distinguished in provenance.

> ⚠️ Tension: "An object becomes occluded" raises priority (§23), but an occluded object gives no pixels to re-infer. The intended action (hold identity? flag uncertainty?) is unstated.

## Related

[[change-importance-scoring]] · [[region-update-modes]] · [[model-hierarchy]] · [[drift-control]] · [[scene-resets]] · [[compute-efficiency-objective]] · [[sixty-fps-contract]] · [[framefusion]] · [[nvidia-deepstream]] · [[deep-feature-flow]] · [[open-research-questions]] · [[failure-modes]]
