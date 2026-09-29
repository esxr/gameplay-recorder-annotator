#!/usr/bin/env python3
"""engine/run.py <video.mp4> [--out <dir>] [--no-vlm]  → session dir per engine/CONTRACT.md"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from core.pipeline import Engine  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--out", default=None)
    ap.add_argument("--no-vlm", action="store_true")
    a = ap.parse_args()
    out = a.out or a.video + ".session"  # CONTRACT: <video>.session (x.mp4.session)
    os.makedirs(out, exist_ok=True)
    for fn in ("stream.jsonl", "events.jsonl"):
        try:
            os.remove(os.path.join(out, fn))
        except OSError:
            pass

    def log(msg):
        print(msg, flush=True)

    Engine(a.video, out, use_vlm=not a.no_vlm, repo_root=os.path.dirname(HERE), log=log).run()


if __name__ == "__main__":
    main()
