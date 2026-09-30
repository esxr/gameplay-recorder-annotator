# readme_check.py run for G3/G4 on a temp concat of docs/readme-top.md + docs/prd-body.md (built with scripts/build_readme.py --out)
# command: python3 scripts/readme_check.py --readme README.concat.md
# date: 2026-09-30 21:34 AEST

README checked: README.concat.md
PRD source:     knowledge/raw/semantic-video-state-engine-prd.md (2360 lines)

[PASS] 1 PRD section headings: 72/72 present
[PASS] 2 PRD prose lines verbatim: 1154/1154 = 100.00% (need >= 95%)
[PASS] 3 TOC links match heading ids: 72/72 sections linked from the TOC to their rendered id
[PASS] 4 INDEX = .excalidraw = README images: INDEX 8, .excalidraw 8, README images 8
[PASS] 5 SVGs carry svg-source:excalidraw: 8/8 SVGs with marker, 8/8 valid .excalidraw (type excalidraw, version 2)
[PASS] 6 PRD labels present in drawings: 8/8 drawings contain every label word (238 distinct words checked)
[PASS] 7 listed ASCII blocks remaining: 0 remain
[PASS] 8 broken relative links/images: 0 broken of 104 relative links checked
[PASS] 9 citation markers remaining: 0 remain in README (68 stripped from PRD text)

9/9 metrics PASS
