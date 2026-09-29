---
title: Three-Level Semantic Memory
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [memory, long-video, retrieval, llm-interface]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [9.2, 9.4, 20, 25, 57, 34]
---

# Three-Level Semantic Memory

**Definition.** The engine keeps three conceptual memory tiers that trade temporal resolution for retention span: a short-lived *sensory state*, a live *working semantic state*, and a compressed *long-term episodic memory* (PRD §25). The split is explicitly modelled on [[xmem]] (sensory / working / long-term stores for video object segmentation, PRD §9.2) and [[moviechat]] (fast short-term memory vs compressed long-term memory, PRD §9.4).

## The three tiers

| Tier | Contents | Purpose (PRD §25) |
|---|---|---|
| Sensory state | Extremely recent, high-resolution visual information | Tracking, optical flow, fast transient detection, frame-level reconstruction |
| Working semantic state | Active objects, HUD, relationships, current events | Live LLM reasoning, interaction, immediate context |
| Long-term episodic memory | Compressed events, significant snapshots, trajectories, summaries | Long-session reasoning, retrieval, historical queries |

## Mechanism

- The sensory tier feeds the tracker and change detector ([[change-importance-scoring]], [[short-event-preservation]]); it is the only tier that holds pixel-level detail for the current moment.
- The working tier is the live projection of [[persistent-world-state]] and is what [[llm-integration-modes]] Mode A streams.
- The long-term tier maps onto the "long-term summaries" and "event records" of the [[snapshot-delta-storage]] model (PRD §20). Its stated product implication is that a long session can be preserved "without forcing every historical visual token into every downstream prompt" (PRD §9.4); the [[context-compiler]] draws from it for retrospective queries.
- It is the named mitigation for the *long-session memory growth* failure mode (PRD §57, see [[failure-modes]]).
- Crucially, summaries must not replace fine-grained history: FR-19 requires "long-term session summaries without deleting fine-grained history" (PRD §34). The tiers are therefore *views with different access costs*, not a destructive compaction pipeline.

Related research lineage for streaming compressed memory: [[streaming-dense-video-captioning]] (fixed-size clustered memory) and [[vid2seq]] (time-tokenised event descriptions) (PRD §9.4).

## Requirements satisfied

- **FR-19** — long-term summaries without deleting fine-grained history.
- **FR-15** — entity/UI history retrieval (served from episodic memory + deltas).
- **FR-17** — supplies compressed material for query + token-budget context.

> ⚠️ Tension: Long-term summaries are lossy by design (PRD §20, §25), yet "every machine-generated semantic claim should be traceable" (PRD §30). The PRD never says how a summary sentence carries provenance — whether it links to the set of underlying events/deltas, gets its own `derived` evidence record with parent evidence, or is exempt. See [[evidence-and-provenance]].

> ⚠️ Tension: The retention window of the sensory tier is unspecified ("extremely recent"). Since §4.5 requires original pixels to stay inspectable, evidence must live in a separate raw-video store rather than the sensory tier — but the PRD does not state how the tiers relate to that store or to user-controlled retention (PRD §58).

> ⚠️ Tension: FR-19 forbids deleting fine-grained history, while §58 requires user-controlled retention and deletion. The PRD does not say which wins when a user shortens retention.

## Related

[[xmem]] · [[moviechat]] · [[streaming-dense-video-captioning]] · [[vid2seq]] · [[snapshot-delta-storage]] · [[persistent-world-state]] · [[context-compiler]] · [[evidence-and-provenance]] · [[failure-modes]] · [[privacy-and-security]] · [[open-research-questions]]
