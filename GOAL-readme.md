# GOAL: Public README with demo GIF + full PRD, live on GitHub by 2026-10-01 01:00 AEST

Repo `github.com/esxr/gameplay-recorder-annotator` (PUBLIC), file `README.md`. Source: `knowledge/raw/semantic-video-state-engine-prd.md` (72 sections; do not edit it). Times AEST.

**Rules**
- Public repo: no secrets, no personal screen content (other apps, terminals, chats, names) in any committed file or image.
- Screen use allowed for the demo take; never activate windows of other apps.

**Proof: made by the agent; Pranav checks nothing**
- Save to `proofs/readme-*`; open every PNG (Read tool) and name what it shows. `scripts/readme_check.py` prints every metric below.

## G1: Demo GIF in the first 15 lines shows the app on Pranav's 3D gameplay recording
- TO-DO: Use `Recording 2026-09-30 21.29.12.mp4` (3D city game) cropped to the game viewport: gameplay → the app's review window of it with region overlay, annotations, events and an "Ask" answer; save `docs/demo.gif`.
- NOT TO-DO: No Roblox Studio chrome, file paths or other apps in any frame. No mockups.
- PROOF: `ffprobe`: 15-60 s, ≥ 10 fps, width ≥ 800 px, size ≤ 10 MB; `proofs/readme-G1-sheet.png` (1 frame per 2 s) shows gameplay, review overlay and answer, 0 frames with other apps or paths.
- NOT-PROOF: A still PNG renamed .gif. A GIF checked only at its first frame.

## G2: Top section lets a new user build and run in ≤ 5 commands
- TO-DO: Title, PRD §71 sentence, GIF, "Quick start" (build app, run engine, ask a question), results table of `proofs/pipeline-G1..G6` metrics, repo layout.
- NOT TO-DO: No claims without a linked proof file.
- PROOF: `proofs/readme-G2-quickstart.txt`: every Quick-start command run in a fresh `git clone` in scratch, all exit 0, ends `** BUILD SUCCEEDED **` and an engine session dir; each table number matches its proof file (script diff 0).
- NOT-PROOF: Commands run in the working copy with ignored build output present.

## G3: PRD content carried over as-is, ≥ 95% of prose lines
- TO-DO: Append the PRD below the top section: all 72 sections, a linked table of contents, GitHub markdown (tables, lists, code for JSON/API examples).
- NOT TO-DO: No summarising or rewording beyond formatting.
- PROOF: `readme_check.py`: 72/72 PRD section headings present; ≥ 95% of PRD prose lines (outside code blocks) found verbatim after whitespace normalising; 72/72 TOC links match rendered heading ids.
- NOT-PROOF: A link to the PRD file instead of the content.

## G4: Every PRD diagram replaced by an Excalidraw drawing, 0 ASCII diagrams left
- TO-DO: List every PRD `text` block that draws a flow, tree or layout (≥ 6) in `docs/diagrams/INDEX.md` with PRD line numbers; draw each as `docs/diagrams/<name>.excalidraw`, export SVG with Excalidraw's `exportToSvg`, embed in README.
- NOT TO-DO: No Mermaid, no hand-written SVG, no ASCII art kept beside the image.
- PROOF: `readme_check.py`: INDEX count = `.excalidraw` count = README diagram images; each SVG contains `svg-source:excalidraw`; 0 listed ASCII blocks remain in README; `proofs/readme-G4-diagrams.png` shows all drawings with labels matching the PRD block text.
- NOT-PROOF: An SVG from another tool. A diagram with PRD labels missing.

## G5: GitHub renders it: 0 broken images or links
- TO-DO: Commit and push; add `.gitignore` exceptions only for files checked in G1 and G4.
- NOT TO-DO: No force-push. No files > 10 MB.
- PROOF: `gh api repos/esxr/gameplay-recorder-annotator/readme -H "Accept: application/vnd.github.html"` saved to `proofs/readme-G5-rendered.html`: GIF + all diagram `<img>` present; every image and relative link returns HTTP 200; `git ls-remote` = local HEAD.
- NOT-PROOF: A local markdown preview. Links checked before the push.

## Done when
G1-G5 PROOFs exist in `proofs/`, the pushed HEAD contains them, and Pranav replies "ship".
