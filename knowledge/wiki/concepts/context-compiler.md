---
title: LLM Context Compiler
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [llm-interface, retrieval, token-budget]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [28, 29, 34, 37, 39, 51, 63, 65]
---

# LLM Context Compiler

**Definition.** The Context Compiler turns the stored semantic session into a query-specific, token-budgeted representation for a downstream LLM. Its founding rule: "the engine shall never simply dump all annotations into the LLM context" (PRD §28).

## Inputs and output

Inputs (PRD §28):

- a user/model query;
- relevant timestamp range;
- token budget;
- desired precision;
- semantic state ([[persistent-world-state]]);
- event store ([[relationships-and-events]]);
- evidence store ([[evidence-and-provenance]]).

Output: "the most relevant representation" — the *LLM context* output format, a "token-budget-aware textual/structured representation" (PRD §37). It is exposed as `compile_context(session, query, token_budget)` in the [[query-and-streaming-api]] (PRD §39).

## Worked example — "Why did I die here?"

For this query the PRD shows the compiler emitting only causally relevant, timestamped state changes (PRD §28):

```text
[12:33.140] health=61; enemy_17 visible at screen-right; enemy_17 weapon=rifle
[12:33.223] enemy_17 firing event begins
[12:33.257] incoming_damage indicator from right; health 61→34
[12:33.441] health 34→7
[12:33.508] player firing; ammo 14→13
[12:33.590] health 7→0; death event
```

Note what it shows: the attacker's identity and weapon, the event, the damage direction, and the health *deltas* (not repeated values) — and what it omits: "every unchanged bounding box or HUD icon" (PRD §28). This is the delta principle of §4.4 applied at read time.

## Mechanism

1. Scope the timestamp range around the query anchor ("here").
2. Choose fidelity per signal type based on the query — see [[query-adaptive-fidelity]] (PRD §29).
3. Reconstruct state at the range start from [[snapshot-delta-storage]], then emit only meaningful deltas and events.
4. Attach confidence so the LLM can separate certain from uncertain facts ([[confidence-and-uncertainty]], FR-25).
5. If fidelity is insufficient, the consumer can call `reanalyze` (FR-18).

## Requirements satisfied

- **FR-17** — generate LLM-optimised context from a query and token budget.
- Core scope item 6, "supplied to an LLM through a context compiler" (PRD §63).
- Acceptance criteria *LLM utility* and *Context efficiency* (PRD §65); measured by the *context efficiency* metric (PRD §51, see [[evaluation-and-metrics]]).

> ⚠️ Tension: Token budgeting has no ranking or truncation policy. §28 says the compiler returns "the most relevant representation" within a budget, but defines no relevance score, no priority order between state/events/evidence, and no behaviour when the relevant material exceeds the budget (drop, summarise, or escalate to long-term summaries).

> ⚠️ Tension: The API signature `compile_context(session, query, token_budget)` (PRD §39) omits two inputs §28 lists — timestamp range and desired precision — so it is unclear whether they are inferred from the query or missing parameters.

> ⚠️ Tension: The example output contains no confidence values or annotation modes, although FR-25 and §65 (*uncertainty visibility*) require that uncertain/propagated state never be presented as equivalent to observed state. The compiled format for carrying confidence is unspecified.

## Related

[[query-adaptive-fidelity]] · [[query-and-streaming-api]] · [[llm-integration-modes]] · [[three-level-semantic-memory]] · [[evidence-and-provenance]] · [[confidence-and-uncertainty]] · [[snapshot-delta-storage]] · [[evaluation-and-metrics]] · [[semantic-video-codec]]
