#!/usr/bin/env python3
"""Generate docs/prd-body.md from the PRD (formatting only).

- demote every heading one level (README top section owns the H1)
- add a linked table of contents for the 72 numbered sections
- replace each ASCII diagram listed in docs/diagrams/INDEX.md with its Excalidraw SVG
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRD = ROOT / "knowledge/raw/semantic-video-state-engine-prd.md"
INDEX = ROOT / "docs/diagrams/INDEX.md"
OUT = ROOT / "docs/prd-body.md"
sys.path.insert(0, str(ROOT / "scripts"))
from readme_check import slugify, parse_index, strip_citations  # noqa: E402

lines = PRD.read_text(encoding="utf-8").split("\n")
if lines and lines[-1] == "":
    lines = lines[:-1]
diagrams = {start: (name, end) for name, start, end in parse_index(INDEX.read_text(encoding="utf-8"))}

sections = [l[2:].strip() for l in lines if re.match(r"^# \d+\. ", l)]
assert len(sections) == 72, len(sections)
toc = ["### PRD table of contents", ""]
toc += [f"- [{s}](#{slugify(s)})" for s in sections]
toc += [""]

out = []
i, in_code = 0, False
while i < len(lines):
    n = i + 1  # 1-based PRD line number
    l = lines[i]
    if not in_code and n in diagrams:
        name, end = diagrams[n]
        assert l.startswith("```") and lines[end - 1].startswith("```"), (name, n, end)
        out.append(f"![{name}](docs/diagrams/{name}.svg)")
        i = end
        continue
    if l.startswith("```"):
        in_code = not in_code
    elif not in_code:
        l = strip_citations(l)
        if re.match(r"^#{1,5} ", l):
            l = "#" + l
    out.append(l)
    if n == 11:  # after the document metadata block and its rule
        out += [""] + toc + ["---"]
    i += 1

OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"wrote {OUT.relative_to(ROOT)}: {len(out)} lines, {len(diagrams)} diagrams, {len(sections)} TOC entries")
