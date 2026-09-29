# Gameplay Recorder Annotator — Semantic Video State Engine

This project turns 60 fps gameplay and screen video into a **persistent, evidence-grounded semantic world state** that LLMs can query. It does not caption every frame or sample sparsely. It keeps entities, HUD values, text, relationships and events as **snapshots + per-frame deltas**, re-runs expensive perception only on what changed, and compiles context for each query within a token budget.

## Repository layout

- [`knowledge/`](knowledge/) — the project knowledge base, an LLM-maintained wiki
  - [`knowledge/index.md`](knowledge/index.md) — catalog of every page (start here)
  - [`knowledge/wiki/overview.md`](knowledge/wiki/overview.md) — thesis and current assessment
  - [`knowledge/raw/semantic-video-state-engine-prd.md`](knowledge/raw/semantic-video-state-engine-prd.md) — the founding PRD (immutable)
  - [`knowledge/AGENTS.md`](knowledge/AGENTS.md) — wiki schema and conventions

The wiki uses `[[wikilinks]]` and YAML frontmatter. Open `knowledge/` as an [Obsidian](https://obsidian.md) vault to get graph view and Dataview queries.
