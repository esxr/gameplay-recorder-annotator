---
title: Perception Modules
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [perception, modularity, architecture]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.2, 26, 27, 35, 60, 61, 62]
---

# Perception Modules

**Definition.** The perception layer is a **modular** set of optional analysers. Their outputs are fused into [[persistent-world-state]]. "No particular module is mandatory across every deployment" (PRD §26).

## Candidate modules (PRD §26)

| Group | Modules |
|---|---|
| Scene / objects | scene classifier, object detector, open-vocabulary detector, video segmentation tracker, panoptic segmentation |
| Screen | UI parser, OCR, icon recognizer |
| Geometry / motion | pose estimator, depth estimator, optical flow, motion estimator |
| Identity | appearance embedding |
| Audio | audio-event detector, speech-to-text |
| Higher-level | event classifiers, vision-language reasoner |

Cited references: [[mask2former]] for unifying semantic, instance and panoptic segmentation, and the [[sam-family]] for promptable segmentation and video tracking (PRD §26). The recommended current picks (PRD §61):
- a pluggable open-vocabulary detector/segmenter, with SAM 3/3.1 as reference and SAM 2 as a streaming-memory foundation;
- a UI pipeline inspired by [[screenai]] and [[omniparser]];
- [[nvidia-deepstream]]-style cascaded inference for the low-level pipeline.

> 🔎 Unverified: "SAM 3.1 … up to 32 fps for 16 tracked objects on a single H100" is Meta's figure as relayed by the PRD (PRD §9.2).

## How modules are invoked

Modules are not run per frame. The [[selective-inference-scheduler]] dispatches them by cost tier ([[model-hierarchy]], PRD §27), and each is accessed through a provider interface ([[model-agnostic-providers]], PRD §60). Per §62 these are "commodity or rapidly evolving capabilities" to integrate, not build. The moat is the fusion into a temporally coherent world state (PRD §62; [[build-vs-buy]]).

## Requirements satisfied

NFR Modularity: individual perception models must be replaceable (PRD §35). FR-03, FR-04, FR-05, FR-06, FR-22 (PRD §34).

## Risks

Heterogeneous outputs (boxes vs masks, closed vs open vocabulary) must merge into one schema. Module disagreement must be surfaced, not hidden. See [[failure-modes]].

> ⚠️ Tension: §26 lists modules with no fusion or arbitration rule. When the detector, VLM and tracker disagree on class or identity, the PRD names "model disagreement" as a scheduler signal (§22) but not how the conflict is resolved in stored state.

> ⚠️ Tension: The module list (§26) and the provider interfaces (§60) do not align. Scene classifier, icon recognizer, pose, depth, audio-event detector and speech-to-text have no provider interface, although FR-22 requires every perception model to be replaceable without schema change.

## Related

[[model-agnostic-providers]] · [[model-hierarchy]] · [[selective-inference-scheduler]] · [[ui-hud-perception]] · [[ocr-and-text]] · [[auxiliary-channels]] · [[build-vs-buy]] · [[sam-family]] · [[mask2former]] · [[nvidia-deepstream]] · [[failure-modes]]
