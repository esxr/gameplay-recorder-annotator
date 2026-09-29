---
title: Model-Agnostic Providers
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [architecture, interfaces, modularity, versioning]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [7, 8, 26, 30, 35, 57, 60, 62]
---

# Model-Agnostic Providers

**Definition.** Perception capabilities are exposed as **interfaces, not permanent dependencies**, because "research progress is moving too quickly to make any single model the product architecture" (PRD §60).

## Provider interfaces (PRD §60)

```text
SegmentationProvider   TrackerProvider   OCRProvider      UIParserProvider
EmbeddingProvider      VLMProvider       EventDetectorProvider   FlowProvider
```

The PRD's example of churn is the [[sam-family]]: SAM 2 (2024, streaming memory), SAM 3 (2025, open-vocabulary concept segmentation), and SAM 3.1 (2026, multi-object throughput). "The system must expect that stronger replacements will appear" (PRD §60).

## Mechanism

- Tiers of the [[model-hierarchy]] are filled by whichever provider is configured.
- Every annotation records **model** and **model version** in its provenance (PRD §30; [[evidence-and-provenance]]). Model upgrades are mitigated by "provenance and schema/model versioning" (PRD §57).
- Offline reprocessing (FR-23) plus supersession without losing audit history (FR-24) lets a session be re-run with newer providers.

## Requirements satisfied

- FR-22: "Permit replacement of perception models without changing the storage schema" (PRD §34).
- Goal 15: remain model-agnostic (PRD §7). Non-goal: no permanent dependence on SAM, Gemini, TwelveLabs or any single third-party model (PRD §8).
- NFR Modularity (PRD §35). Part of the "integrate where advantageous" list (PRD §62; [[build-vs-buy]]).

## Risks

"Model upgrades: stored annotations become incomparable" (PRD §57). See [[failure-modes]].

> ⚠️ Tension: FR-22 promises a stable schema across providers, but providers differ in *output shape*: masks vs boxes (FR-04 allows "and/or"), open vs closed vocabulary, and confidence calibration. A stable schema does not make values comparable. Confidence 0.9 from two OCR providers need not mean the same thing, and no calibration layer is specified.

> ⚠️ Tension: The §60 interface list omits providers for modules §26 names (scene classifier, icon recognizer, pose, depth, audio-event detection, speech-to-text), and for the codec-analysis signal in the L1 tier (§27).

> ⚠️ Tension: The NFR Determinism requirement ("a frame and annotation version should produce reproducible state", §35) presumes providers are deterministic. GPU-nondeterministic or hosted VLM providers (VLMProvider) may not be. The PRD does not say whether provider outputs are cached as the reproducible artefact.

## Related

[[perception-modules]] · [[model-hierarchy]] · [[evidence-and-provenance]] · [[build-vs-buy]] · [[sam-family]] · [[gemini-video-understanding]] · [[twelvelabs]] · [[failure-modes]]
