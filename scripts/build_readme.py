#!/usr/bin/env python3
"""Build README.md = docs/readme-top.md + docs/prd-body.md (plain concatenation, top first)."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ap = argparse.ArgumentParser()
ap.add_argument("--out", default=str(ROOT / "README.md"))
args = ap.parse_args()

top = (ROOT / "docs/readme-top.md").read_text(encoding="utf-8")
body = (ROOT / "docs/prd-body.md").read_text(encoding="utf-8")
if not top.endswith("\n"):
    top += "\n"
Path(args.out).write_text(top + "\n" + body, encoding="utf-8")
print(f"wrote {args.out}: {len((top + body).splitlines())} lines")
