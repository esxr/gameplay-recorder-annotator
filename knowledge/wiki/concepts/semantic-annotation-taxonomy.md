---
title: Semantic Annotation Taxonomy
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [data-model, annotation, schema, confidence]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [14, 15, 16, 30, 49, 65, 66.6]
---

# Semantic Annotation Taxonomy

## Definition

The per-object schema of the [[persistent-world-state]] (PRD §14.1). UI elements and text have their own schemas (PRD §15, §16). See [[ui-hud-perception]] and [[ocr-and-text]].

## Object fields (PRD §14.1)

Persistent ID; class; aliases; bounding box; optional segmentation mask; center point; depth estimate (where possible); visibility; occlusion; orientation; appearance embedding; motion vector; velocity estimate; attributes; parent/child relationships; confidence; source model; last strong re-inference frame; provenance.

Example from the PRD:

```json
{
  "id": "enemy_17",
  "class": "enemy_character",
  "bbox": [0.712, 0.318, 0.795, 0.741],
  "visibility": 0.84,
  "occlusion": 0.11,
  "motion": { "dx": -0.0041, "dy": 0.0009 },
  "attributes": { "stance": "crouched", "weapon": "rifle" },
  "confidence": 0.94,
  "state_source": "propagated",
  "last_full_inference_frame": 18460
}
```

Coordinates are normalised to [0,1]. `state_source` records how the current value was produced. `last_full_inference_frame` tells [[drift-control]] how old the last authoritative read is (12 frames here).

## Per-field confidence (PRD §49)

"Annotations should not be treated as binary truth. Each field must support uncertainty":

```text
class:    value: "enemy"     confidence: .98
weapon:   value: "rifle"     confidence: .71
identity: value: "enemy_17"  confidence: .89
```

Downstream LLMs can then treat certain and uncertain facts differently. See [[confidence-and-uncertainty]].

## Requirements it satisfies

FR-03 (persistent IDs), FR-04 (masks and/or boxes), FR-11 (confidence and provenance), FR-21 (game-specific ontology extensions), FR-25 (confidence-aware state). Acceptance *Uncertainty visibility*: propagated or uncertain info must never look equivalent to observed high-confidence info (PRD §65).

## Design tensions

- **Granularity of provenance.** Under PROPAGATE only geometry changes, so `bbox` is propagated while `attributes.weapon` is copied from an earlier observation. The object-level `state_source` cannot express this. Per-field provenance would be needed to meet the §65 uncertainty-visibility criterion.
- **Open ontology.** `class` and `attributes` are free-form. Game-specific ontologies are allowed (FR-21, [[game-adapters]]), but the PRD specifies no base class vocabulary.

> ⚠️ Tension: The §14.1 field list says "last strong re-inference frame", but the example uses `last_full_inference_frame`. It is unclear whether a region-level RE-INFER resets this counter or only a FULL REFRESH does, since "strong" and "full" are different modes in §12.

> ⚠️ Tension: §49 requires per-field confidence, but the §14 example carries one object-level `"confidence": 0.94` and plain scalar fields. The example schema does not meet the requirement it sits beside.

> ⚠️ Tension: `state_source` (§14) takes values like `"propagated"`, but no enumeration is given. It is unclear whether it uses the §30 annotation-mode vocabulary (`observed/propagated/copied/derived/inferred/human_verified`) or the §12 update-mode vocabulary. No mapping is defined. See [[region-update-modes]].

> ⚠️ Tension: `"source_model"` and `"provenance"` are listed as object fields (§14.1), and §30 separately defines evidence references that carry model, model version and annotation mode. The split between inline provenance and evidence records is not specified. See [[evidence-and-provenance]].

## Related

[[persistent-world-state]] · [[confidence-and-uncertainty]] · [[evidence-and-provenance]] · [[region-update-modes]] · [[drift-control]] · [[ui-hud-perception]] · [[ocr-and-text]] · [[relationships-and-events]] · [[game-adapters]] · [[human-verification]] · [[semantic-video-state-engine-prd]]
