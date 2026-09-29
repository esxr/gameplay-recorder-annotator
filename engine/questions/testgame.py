"""EVAL ONLY. Build §53-style benchmark questions + expected answers from testgame/out/truth.jsonl
and the video->gf mapping, and grade answers.

  make:  .venv/bin/python engine/questions/testgame.py make <truth.jsonl> <video.mp4> [out.json]
Writes engine/questions/testgame.json (with created_at) BEFORE any LLM answering; never edit after.
"""
import datetime
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def load_truth(path):
    t = {}
    for line in open(path):
        line = line.strip()
        if line:
            r = json.loads(line)
            t[r["gf"]] = r
    return t


def video_truth(truth_path, video):
    import sync
    gfs = sync.clean(sync.decode_video(video))
    t = load_truth(truth_path)
    maxgf = max(t)
    rows = []
    for f, g in enumerate(gfs):
        g = min(max(g, 0), maxgf)
        rows.append(dict(t.get(g) or t[min(t, key=lambda k: abs(k - g))], vf=f))
    return rows, gfs


def _first(rows, pred, start=0):
    for r in rows[start:]:
        if pred(r):
            return r["vf"]
    return None


def make(truth_path, video, out_path, fps=None):
    rows, gfs = video_truth(truth_path, video)
    n = len(rows)
    if fps is None:
        import subprocess
        o = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate",
                            "-of", "csv=p=0", video], capture_output=True, text=True).stdout.strip()
        a, b = (o.split("/") + ["1"])[:2]
        fps = float(a) / float(b or 1)
    cnt = lambda r: len(r["enemies"])  # noqa: E731
    Q = []
    # 1 first frame with 4 enemies visible at once (enemy 4 spawns)
    f1 = _first(rows, lambda r: cnt(r) >= 4)
    Q.append({"id": "q1", "type": "frame", "tol": 2,
              "q": "Exactly which video frame first shows four enemies visible on screen at the same time?",
              "answer": f1})
    # 2 visible enemies just before the first ammo decrease
    a0 = rows[0]["hud"]["ammo"]
    fa = _first(rows, lambda r: r["hud"]["ammo"] < a0)
    Q.append({"id": "q2", "type": "number", "tol": 0,
              "q": "How many enemies were visible in the frame just before the ammo value first decreased?",
              "answer": cnt(rows[fa - 1]), "aux": {"ammo_drop_f": fa}})
    # 3 health lost between 1st and 4th ammo decrease
    drops, prev = [], rows[0]["hud"]["ammo"]
    for r in rows[1:]:
        if r["hud"]["ammo"] != prev:
            drops.append(r["vf"])
        prev = r["hud"]["ammo"]
    h1, h4 = rows[drops[0]]["hud"]["health"], rows[drops[3]]["hud"]["health"]
    Q.append({"id": "q3", "type": "number", "tol": 0,
              "q": "How much health was lost between the first shot (first ammo decrease) and the fourth shot (fourth ammo decrease)?",
              "answer": h1 - h4, "aux": {"shots": drops[:4]}})
    # flash runs in video frames
    runs, cur = [], None
    for r in rows:
        if r["flash"]:
            if cur and r["vf"] == cur[-1] + 1:
                cur.append(r["vf"])
            else:
                cur = [r["vf"]]
                runs.append(cur)
    # 4 ammo before/after first flash -> did ammo decrease before or after first flash
    ff = runs[0][0]
    Q.append({"id": "q4", "type": "choice", "choices": ["before", "after"],
              "q": "Did the ammo value first decrease before or after the first screen flash? Answer 'before' or 'after'.",
              "answer": "before" if fa < ff else "after"})
    # 5 objective text change
    o0 = rows[0]["objective"]
    fo = _first(rows, lambda r: r["objective"] != o0)
    Q.append({"id": "q5", "type": "text_pair",
              "q": "What did the objective text change from and to?",
              "answer": [o0, rows[fo]["objective"]], "aux": {"f": fo}})
    # 6 frame of a one-frame flash (first single-frame run)
    one = [r for r in runs if len(r) == 1]
    Q.append({"id": "q6", "type": "frame", "tol": 2,
              "q": "At which video frame did the first flash that lasted exactly one frame occur?",
              "answer": (one[0][0] if one else runs[0][0])})
    # 7 enemy behind cover: first drop in count (in level1 not at spawn/death) -> reappear frame
    fd, eid = None, None
    for i in range(1, n):
        if cnt(rows[i]) < cnt(rows[i - 1]) and rows[i]["scene"] == rows[i - 1]["scene"] == "level1":
            ids_prev = {e["id"] for e in rows[i - 1]["enemies"]}
            gone = ids_prev - {e["id"] for e in rows[i]["enemies"]}
            eid = list(gone)[0]
            if rows[i]["gf"] < 2400 or eid != 3:
                fd = i
                break
    fr = None
    if fd is not None:
        fr = _first(rows, lambda r: eid in {e["id"] for e in r["enemies"]}, fd)
    Q.append({"id": "q7", "type": "frame", "tol": 2,
              "q": f"Around frame {fd} an enemy disappears behind the grey cover pillar (visible enemy count drops). "
                   f"Was it seen again, and at which frame did it first reappear? Answer with the reappearance frame.",
              "answer": fr, "aux": {"disappear_f": fd, "truth_id": eid if fd else None}})
    # 8 score at time T (stable window)
    T = 40.0
    fT = int(round(T * fps))
    while fT < n - 10 and len({rows[k]["hud"]["score"] for k in range(fT - 5, fT + 6)}) > 1:
        fT += 3
    Q.append({"id": "q8", "type": "number", "tol": 0,
              "q": f"What was the score shown at video frame {fT} (t = {fT / fps:.2f} s)?",
              "answer": rows[fT]["hud"]["score"]})
    # 9 total flashes
    Q.append({"id": "q9", "type": "number", "tol": 0,
              "q": "How many separate screen flashes occurred in the whole video?", "answer": len(runs),
              "aux": {"runs": runs}})
    # 10 enemy count at time T (stable window)
    fC = int(round(20.0 * fps))
    while fC < n - 10 and len({cnt(rows[k]) for k in range(fC - 8, fC + 9)}) > 1:
        fC += 3
    Q.append({"id": "q10", "type": "number", "tol": 0,
              "q": f"How many enemies were visible at video frame {fC} (t = {fC / fps:.2f} s)?",
              "answer": cnt(rows[fC])})
    th = hashlib.sha256(open(truth_path, "rb").read()).hexdigest()[:16]
    doc = {"created_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
           "truth": os.path.relpath(truth_path), "truth_sha256_16": th, "video": os.path.abspath(video),
           "video_frames": n, "fps": fps, "note": "answers derived only from truth.jsonl + barcode video->gf map; "
           "written before any LLM answering", "questions": Q}
    if os.path.exists(out_path):
        raise SystemExit(f"{out_path} exists; refusing to overwrite (questions are frozen)")
    with open(out_path, "w") as fh:
        json.dump(doc, fh, indent=1)
    return doc


def _ints(s):
    return [int(x) for x in re.findall(r"-?\d+", s.replace(",", ""))]


def grade(q, answer):
    a = (answer or "").lower()
    t = q["type"]
    exp = q["answer"]
    if exp is None:
        return False
    if t in ("frame", "number"):
        nums = _ints(a)
        if not nums:
            return False
        return abs(nums[0] - int(exp)) <= q.get("tol", 0)
    if t == "choice":
        hits = [c for c in q["choices"] if re.search(r"\b" + c + r"\b", a)]
        return hits[:1] == [exp] or (len(hits) >= 1 and a.strip().startswith(exp))
    if t == "text_pair":
        norm = lambda x: re.sub(r"[^a-z0-9]+", " ", x.lower()).strip()  # noqa: E731
        na = norm(a)
        return all(norm(x) in na for x in exp)
    return False


if __name__ == "__main__":
    if sys.argv[1] == "make":
        out = sys.argv[4] if len(sys.argv) > 4 else os.path.join(HERE, "testgame.json")
        d = make(sys.argv[2], sys.argv[3], out)
        for q in d["questions"]:
            print(q["id"], q["q"], "->", q["answer"])
