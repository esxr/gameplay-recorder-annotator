# G3 sample check — Recording 2026-09-30 03.19.10 (41.4 s, live screen)
- `annotation_started` 0.007 s after `recording_stopped` (≤ 5 s ✅) — see G3-check.txt
- 42 JSONL lines (≥ 30 ✅), `jq` parse ok, 42/42 (100%) non-empty entities/hud (≥ 80% ✅)
- Frame check (opened frame_240.jpg, t=4000 ms): screen shows Warp terminal, tab "Roblox: Map Design", clock "Wed Sep 30 3:19 AM", file tree of saraswati_studios, Claude session in right pane.
  - Record matches: active_tab "Roblox: Map Design" ✅, time "3:19 AM" ✅, file-tree panel ✅, terminal/console output ✅.
  - Record mismatch: labels the app "VS Code Editor" ❌ (it is Warp). Model: claude-haiku-4-5.
- t=19000 and t=34000 records describe the same static layout with the same entity ids (window/file tree/terminal) — consistent with the screen, which did not change app during the take.
