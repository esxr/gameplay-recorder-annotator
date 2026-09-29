---
title: Target users and jobs
type: concept
created: 2026-09-30
updated: 2026-09-30
tags: [users, personas, jobs-to-be-done, use-cases]
sources: [raw/semantic-video-state-engine-prd.md]
prd_sections: [3, 5, 6, 8, 53, 64]
---

# Target users and jobs

Who the engine is for, the single job it does for them, the questions it must answer, and the extensions the same substrate should support.

## Core user job (PRD §6)

> Record what happened on my screen with enough spatial, semantic, and temporal resolution that another AI can later understand the experience without needing to re-watch and reinterpret every raw video frame.

The "user" of the output is frequently another AI, which is why the output is compiled for LLMs ([[context-compiler]]) rather than for human viewing.

## Target users (PRD §5)

| Segment | Need |
|---|---|
| AI/gameplay researchers | Extremely detailed game-video datasets without manually annotating every frame |
| Agent developers | Machine-readable screen state for agents reasoning about visual environments |
| Multimodal foundation-model teams | Dense, structured video supervision and high-quality temporal training data |
| Game analytics teams | Automatic extraction of gameplay state, events and interactions when internal game telemetry is unavailable |
| Dataset and evaluation teams | Temporally consistent ground truth for evaluating video-language and embodied-agent models |
| Advanced users | Turning their own gameplay or computer sessions into searchable semantic histories |

The game-analytics need aligns with the non-goal of not depending on game telemetry (PRD §8); see [[game-integrity-boundary]].

## Example questions (PRD §3)

The vision is that an LLM can reason "as if it had access to a structured observer continuously watching the screen" (PRD §3). Representative questions:

- What was visible when the player started taking damage? Which enemy first entered the field of view?
- What changed in the HUD immediately before death? ([[ui-hud-perception]])
- How many rounds were fired during this encounter? ([[relationships-and-events]])
- Was the object visible before the player reacted? ([[auxiliary-channels]])
- Health, ammo, minimap position and weapon at a specific instant?
- Which UI element changed after a button press?
- Show the exact visual evidence ([[evidence-and-provenance]]).
- Reconstruct the semantic state at frame 18,472 ([[snapshot-delta-storage]]).
- Summarize only the important deltas; retrieve every moment a condition occurred ([[query-and-streaming-api]]).

The benchmark questions of §53 are the evaluation form of the same jobs (PRD §53, [[evaluation-and-metrics]]).

## Extended capabilities (PRD §64)

The architecture should remain compatible with: controller/input reconstruction; audio-event reasoning; automatic game ontology discovery; per-game specialist models; player-behavior analysis; imitation-learning datasets; agent observation streams; multimodal RAG; semantic replay; automatic highlight/event generation; visual debugging of AI agents; training-data generation for video-language-action models. "These are extensions of the same semantic substrate" (PRD §64). Imitation-learning data echoes [[vpt]]; per-game models echo [[game-adapters]].

The PRD's secondary domains — computer-use agents, robotics video, simulation, sports, surveillance, UI testing, multimodal model training — widen the same user base beyond games (PRD header).

## Related

- [[overview]]
- [[strategic-differentiation]]
- [[context-compiler]]
- [[llm-integration-modes]]
- [[evaluation-and-metrics]]
- [[game-adapters]]
- [[game-integrity-boundary]]
- [[vpt]]
