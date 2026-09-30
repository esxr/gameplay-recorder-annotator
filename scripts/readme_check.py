#!/usr/bin/env python3
"""Check README.md against the PRD and the Excalidraw diagrams (stdlib only).

Metrics (each printed with PASS/FAIL):
  1. 72/72 PRD section headings present in the README
  2. >= 95% of PRD prose lines (outside code blocks) found verbatim after whitespace normalising
  3. 72/72 TOC links resolve to heading ids (GitHub slug rules), one per PRD section
  4. INDEX rows = .excalidraw files = README diagram images (and >= 6)
  5. every docs/diagrams/*.svg contains the `svg-source:excalidraw` marker
  6. every label word of each listed PRD block appears in its .excalidraw drawing
  7. 0 listed ASCII blocks remain in the README
  8. 0 broken relative links / images / in-page anchors in the README
  9. 0 citation markers remain in the README

Usage: python3 scripts/readme_check.py [--readme PATH] [--root REPO_ROOT]
Exit status 0 only if every metric passes.
"""
import argparse
import json
import re
import sys
import unicodedata
from pathlib import Path

PRD_REL = "knowledge/raw/semantic-video-state-engine-prd.md"
DIAG_REL = "docs/diagrams"
FENCE = re.compile(r"^\s*(```|~~~)")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
LINK = re.compile(r"(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
# The PRD carries leftover chat-tool citation markers such as
# "citeturn658950search0turn658950search12" (optionally wrapped in private-use
# delimiter chars U+E200-U+E2FF). They render as junk on GitHub, so the README
# body drops them (formatting cleanup). The prose metric strips the same
# markers from the PRD side before comparing, so a line counts as verbatim
# when it matches the PRD line minus its markers.
CITE = re.compile(r"[ \t]*[\ue200-\ue2ff]*cite[\ue200-\ue2ff]*(?:turn\d+[a-z]+\d+[\ue200-\ue2ff]*)+")
CITE_LEFTOVER = re.compile(r"cite[\ue200-\ue2ff]*turn\d+|turn\d+(?:search|view|news|academia|image|file)\d+|[\ue200-\ue2ff]")
INDEX_ROW = re.compile(r"^\|\s*\d+\s*\|\s*([a-z0-9-]+)\s*\|\s*(\d+)\s*-\s*(\d+)\s*\|")


# ---------- helpers (also imported by the PRD body generator) ----------

def strip_inline(text):
    """Heading text as GitHub renders it: drop links, images, emphasis and code markers."""
    text = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("`", "")
    text = re.sub(r"(\*\*|__|\*)", "", text)
    return text.strip()


def slugify(text):
    """GitHub heading id (github-slugger): lowercase, drop punctuation, spaces -> '-'."""
    text = strip_inline(text).lower()
    out = []
    for ch in text:
        cat = unicodedata.category(ch)
        if ch == " ":
            out.append("-")
        elif ch in "-_" or cat[0] in ("L", "N", "M"):
            out.append(ch)
    return "".join(out)


def parse_index(text):
    """[(name, start_line, end_line)] from the INDEX.md diagram table."""
    rows = []
    for line in text.splitlines():
        m = INDEX_ROW.match(line)
        if m:
            rows.append((m.group(1), int(m.group(2)), int(m.group(3))))
    return rows


def strip_citations(line):
    return CITE.sub("", line)


def norm(line):
    line = re.sub(r"^\s*#{1,6}\s+", "", line)
    return " ".join(line.split())


def split_code(lines):
    """Yield (line, in_code) for each line; fence lines count as code."""
    in_code = False
    for line in lines:
        if FENCE.match(line):
            yield line, True
            in_code = not in_code
            continue
        yield line, in_code


def heading_ids(lines):
    ids, seen = [], {}
    for line, code in split_code(lines):
        if code:
            continue
        m = HEADING.match(line)
        if not m:
            continue
        base = slugify(m.group(2))
        slug = base if base not in seen else f"{base}-{seen[base]}"
        seen[base] = seen.get(base, 0) + 1
        ids.append((m.group(2), slug))
    return ids


def words(text):
    return re.findall(r"[a-z0-9]+", text.lower())


# ---------- checks ----------

def main():
    ap = argparse.ArgumentParser()
    root_default = Path(__file__).resolve().parents[1]
    ap.add_argument("--root", default=str(root_default))
    ap.add_argument("--readme", default=None)
    args = ap.parse_args()
    root = Path(args.root).resolve()
    readme_path = Path(args.readme) if args.readme else root / "README.md"
    prd_lines = (root / PRD_REL).read_text(encoding="utf-8").splitlines()
    rd_lines = readme_path.read_text(encoding="utf-8").splitlines()
    diag_dir = root / DIAG_REL
    index = parse_index((diag_dir / "INDEX.md").read_text(encoding="utf-8"))
    results = []

    def report(name, ok, detail):
        results.append(ok)
        print(f"[{'PASS' if ok else 'FAIL'}] {name}: {detail}")

    print(f"README checked: {readme_path}")
    print(f"PRD source:     {PRD_REL} ({len(prd_lines)} lines)\n")

    # 1. section headings
    sections = [l[2:].strip() for l in prd_lines if re.match(r"^# \d+\. ", l)]
    rd_heads = heading_ids(rd_lines)
    rd_head_texts = {norm(t) for t, _ in rd_heads}
    missing = [s for s in sections if norm(s) not in rd_head_texts]
    report("1 PRD section headings", not missing and len(sections) == 72,
           f"{len(sections) - len(missing)}/{len(sections)} present" + (f"; missing {missing[:5]}" if missing else ""))

    # 2. prose lines verbatim
    rd_norm = {norm(l) for l, code in split_code(rd_lines) if not code and l.strip()}
    prose = [norm(strip_citations(l)) for l, code in split_code(prd_lines) if not code and l.strip()]
    found = [p for p in prose if p in rd_norm]
    pct = 100.0 * len(found) / max(1, len(prose))
    notfound = [p for p in prose if p not in rd_norm]
    report("2 PRD prose lines verbatim", pct >= 95.0,
           f"{len(found)}/{len(prose)} = {pct:.2f}% (need >= 95%)" + (f"; first missing: {notfound[:3]}" if notfound else ""))

    # 3. TOC links -> heading ids
    slugs = {s for _, s in rd_heads}
    section_slug = {}
    for text, slug in rd_heads:
        if norm(text) in {norm(s) for s in sections}:
            section_slug.setdefault(norm(text), slug)
    toc_links = []
    for line, code in split_code(rd_lines):
        if code:
            continue
        for m in LINK.finditer(line):
            if not m.group(1) and m.group(3).startswith("#"):
                toc_links.append((m.group(2), m.group(3)[1:]))
    good = 0
    bad = []
    for s in sections:
        want = section_slug.get(norm(s))
        hit = [a for t, a in toc_links if a == want and want in slugs]
        if hit:
            good += 1
        else:
            bad.append(s)
    report("3 TOC links match heading ids", good == 72,
           f"{good}/{len(sections)} sections linked from the TOC to their rendered id" + (f"; unmatched {bad[:5]}" if bad else ""))

    # 4. counts
    exc_files = sorted(p.stem for p in diag_dir.glob("*.excalidraw"))
    img_re = re.compile(r"!\[[^\]]*\]\((docs/diagrams/([a-z0-9-]+)\.svg)\)")
    rd_imgs = [m.group(2) for l, code in split_code(rd_lines) if not code for m in img_re.finditer(l)]
    names = [n for n, _, _ in index]
    same = sorted(names) == exc_files == sorted(rd_imgs)
    report("4 INDEX = .excalidraw = README images", same and len(names) >= 6,
           f"INDEX {len(names)}, .excalidraw {len(exc_files)}, README images {len(rd_imgs)}"
           + ("" if same else f"; INDEX-only {set(names) - set(exc_files)}, img-diff {set(names) ^ set(rd_imgs)}"))

    # 5. svg marker + valid excalidraw JSON
    svg_bad, json_bad = [], []
    for n in names:
        svg = diag_dir / f"{n}.svg"
        if not svg.exists() or "svg-source:excalidraw" not in svg.read_text(encoding="utf-8"):
            svg_bad.append(n)
        try:
            d = json.loads((diag_dir / f"{n}.excalidraw").read_text(encoding="utf-8"))
            assert d.get("type") == "excalidraw" and d.get("version") == 2 and d.get("elements")
        except Exception:
            json_bad.append(n)
    report("5 SVGs carry svg-source:excalidraw", not svg_bad and not json_bad,
           f"{len(names) - len(svg_bad)}/{len(names)} SVGs with marker, {len(names) - len(json_bad)}/{len(names)} valid .excalidraw (type excalidraw, version 2)")

    # 6. every PRD label word appears in the drawing
    label_fail = []
    total_words = 0
    for n, a, b in index:
        block = "\n".join(prd_lines[a:b - 1])  # inside the fences
        try:
            d = json.loads((diag_dir / f"{n}.excalidraw").read_text(encoding="utf-8"))
            drawn = set(words(" ".join(e.get("originalText") or e.get("text", "") for e in d["elements"] if e.get("type") == "text")))
        except Exception:
            drawn = set()
        need = set(words(block))
        total_words += len(need)
        miss = sorted(need - drawn)
        if miss:
            label_fail.append(f"{n}: {miss[:6]}")
    report("6 PRD labels present in drawings", not label_fail,
           f"{len(index) - len(label_fail)}/{len(index)} drawings contain every label word ({total_words} distinct words checked)"
           + (f"; {label_fail}" if label_fail else ""))

    # 7. no listed ASCII block remains
    rd_code_blocks, cur = [], None
    for line in rd_lines:
        if FENCE.match(line):
            if cur is None:
                cur = []
            else:
                rd_code_blocks.append(cur)
                cur = None
        elif cur is not None:
            cur.append(norm(line))
    remaining = []
    rd_all_norm = " ".join(norm(l) for l in rd_lines)
    for n, a, b in index:
        blines = [norm(l) for l in prd_lines[a:b - 1] if norm(l) and not re.fullmatch(r"[│├└┌┐┘┬┴┼─▼▲\-\\/| ]+", norm(l))]
        whole = " ".join(norm(l) for l in prd_lines[a:b - 1] if norm(l))
        overlap = max((len(set(blines) & set(cb)) / max(1, len(set(blines))) for cb in rd_code_blocks), default=0)
        if whole in rd_all_norm or overlap > 0.5:
            remaining.append(f"{n} ({overlap:.0%} lines in a code block)")
    report("7 listed ASCII blocks remaining", not remaining, f"{len(remaining)} remain" + (f": {remaining}" if remaining else ""))

    # 8. broken relative links / images / anchors
    broken, checked = [], 0
    for line, code in split_code(rd_lines):
        if code:
            continue
        for m in LINK.finditer(line):
            target = m.group(3)
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue
            checked += 1
            if target.startswith("#"):
                if target[1:] not in slugs:
                    broken.append(target)
                continue
            path = target.split("#")[0].split("?")[0]
            if not (root / path).exists():
                broken.append(target)
    report("8 broken relative links/images", not broken, f"{len(broken)} broken of {checked} relative links checked" + (f": {broken[:8]}" if broken else ""))

    # 9. citation markers
    cites = [(i + 1, m.group()) for i, l in enumerate(rd_lines) for m in CITE_LEFTOVER.finditer(l)]
    prd_cites = sum(len(CITE.findall(l)) for l in prd_lines)
    report("9 citation markers remaining", not cites,
           f"{len(cites)} remain in README ({prd_cites} stripped from PRD text)" + (f": {cites[:5]}" if cites else ""))

    print(f"\n{sum(results)}/{len(results)} metrics PASS")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
