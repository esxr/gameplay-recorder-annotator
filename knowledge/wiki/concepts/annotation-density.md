---
title: Annotation Density
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [economics, density, representation]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [4.4, 19, 21, 35, 36, 51, 54, 66.4]
---

# Annotation Density

## Definition

The PRD separates *annotation density* from *prose volume*: "The objective is not to literally write thousands of English sentences for every frame. A frame can instead have thousands of **addressable semantic/spatial state elements**" (PRD §36).

## Example budget (PRD §36)

```text
204   tracked/semantic objects
81    UI/text elements
2,100 adaptive visual regions
600   relationships/features
1,900 persistent low-level tokens
```

That is about 4,900 addressable elements in one frame. "If only 14 meaningful elements changed on the next frame, only those 14 require semantic delta records." The PRD calls this distinction "fundamental to the economics of the product" (PRD §36).

## How it works

- **Density is in the state. Cost is in the delta.** The [[persistent-world-state]] can be very rich because [[snapshot-delta-storage]] only pays for changes. The §19 example shows three changed fields at frame 18472 and `∅` at 18474.
- This is the storage side of "encode change rather than repetition" (PRD §4.4). The compute side is [[region-update-modes]]: elements that did not change are COPYed.
- The 2,100 regions come from the adaptive quadtree ([[adaptive-spatial-representation]]).

## Requirements it satisfies

NFR *Scalability*: "Storage should increase primarily with semantic change rather than linearly with a fixed number of textual annotations per frame" (PRD §35). It supports FR-02 (every frame gets a transition, most of them cheap) and the *Compression ratio* and *Context efficiency* metrics (PRD §51). See [[evaluation-and-metrics]] and [[compute-efficiency-objective]].

## Design tensions

- **Unchanged is not the same as free.** Elements with no delta still cost something to keep valid: revalidation, confidence decay and drift checks ([[drift-control]]). The "14 records" figure counts storage, not the compute spent confirming that the other ~4,886 did not change.
- **Propagation noise inflates deltas.** Every propagated object moves a little each frame (e.g. `enemy_17.x: -0.004`). With 204 moving objects, geometry deltas could dominate the "meaningful" ones unless small motions are thresholded or modelled as trajectories. The PRD does not say which.
- **Representation is open.** It is undecided whether "persistent low-level tokens" are symbolic or latent (PRD §66.4).

> ⚠️ Tension: The §36 categories do not match the §13 world-state tree or the §21 primitives. "Relationships/features" merges §17 relationships with unspecified "features", and "persistent low-level tokens" appears in neither §13 nor §21. The element count cannot be derived from the schema.

> ⚠️ Tension: §36 counts changes as "meaningful elements", which requires a semantic-change threshold. §66.1 lists "What constitutes semantic change?" as an open research question. So the headline economics depend on an unresolved definition ([[change-versus-meaning]]).

## Related

[[snapshot-delta-storage]] · [[persistent-world-state]] · [[adaptive-spatial-representation]] · [[region-update-modes]] · [[semantic-video-codec]] · [[compute-efficiency-objective]] · [[change-versus-meaning]] · [[evaluation-and-metrics]] · [[semantic-video-state-engine-prd]]
