---
title: Build versus buy
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [strategy, architecture, moat, integrations]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [8, 10, 50, 60, 61, 62, 63]
---

# Build versus buy

The PRD's rule for what the team owns versus what it plugs in: **build the differentiated intellectual core; integrate commodity or fast-moving capabilities as replaceable components** (PRD §62).

## Build (the differentiated core)

(PRD §62)

- semantic state graph → [[persistent-world-state]], [[relationships-and-events]]
- change-aware scheduler → [[selective-inference-scheduler]], [[change-importance-scoring]]
- adaptive region model → [[adaptive-spatial-representation]]
- annotation persistence → [[region-update-modes]]
- delta format → [[snapshot-delta-storage]]
- uncertainty system → [[confidence-and-uncertainty]]
- semantic memory → [[three-level-semantic-memory]]
- context compiler → [[context-compiler]]
- evidence/provenance system → [[evidence-and-provenance]]
- game-specific adaptation layer → [[game-adapters]]

## Integrate where advantageous

(PRD §62) — each is replaceable, typically behind a provider interface (PRD §60):

- segmentation (e.g. [[sam-family]])
- OCR ([[ocr-and-text]])
- embeddings (e.g. [[twelvelabs]]-style)
- optical flow
- speech recognition
- general VLM reasoning (e.g. [[gemini-video-understanding]])
- video encoding
- annotation UI ([[encord]], [[cvat]], [[supervisely]])

## The moat

"The product's moat should not be owning a slightly better OCR model." The moat is **how heterogeneous perception becomes a persistent temporally coherent world state** (PRD §62).

This follows from §10: the engine should not duplicate annotation platforms or generic video APIs, and uses them as evidence that individual pieces are viable (PRD §10). It also follows from [[model-agnostic-providers]]: research moves too fast for any single model to be the architecture (PRD §60), and the product must not depend permanently on SAM, Gemini, TwelveLabs or any single third-party model (PRD §8).

## Concrete integration choices

The component strategy (PRD §61) maps the "buy" side to references:

| Layer | PRD's reference | Role |
|---|---|---|
| Capture / video pipeline | [[nvidia-deepstream]] | architectural reference |
| Detection / segmentation | [[sam-family]] | reference implementation |
| Screen parsing | [[screenai]], [[omniparser]] | inspiration for a specialized UI pipeline |
| Annotation QA | Encord / CVAT / Supervisely-like tooling | curation & correction |
| Downstream baselines | Gemini, TwelveLabs | measurement |

Human-in-the-loop patterns are borrowed from annotation platforms rather than recreated (PRD §50).

## Why it matters

The product scope bar makes clear that no single bought component suffices: "A segmentation tracker alone does not satisfy the product definition… A frame annotation editor alone does not satisfy the product definition" (PRD §63).

## Related

- [[strategic-differentiation]]
- [[model-agnostic-providers]]
- [[perception-modules]]
- [[human-verification]]
- [[nvidia-deepstream]]
- [[encord]]
- [[gemini-video-understanding]]
- [[semantic-video-state-engine-prd]]
