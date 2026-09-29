"""Goal metrics G1-G5 for one session (EVAL: may read truth.jsonl; the engine never does).

  .venv/bin/python engine/report.py <session_dir> [--truth testgame/out/truth.jsonl] [--video <mp4>]
         [--only G1,G2,...] [--questions engine/questions/testgame.json] [--model <id>]
Writes proofs/pipeline-G<n>-report.txt, proofs/pipeline-G4-evidence.png, proofs/pipeline-G5-api.txt.
"""
import argparse
import copy
import json
import os
import random
import subprocess
import sys
import time
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.join(ROOT, "engine", "questions"))
from engine import api  # noqa: E402

PROOFS = os.path.join(ROOT, "proofs")
MODES = "CPVRF"
MODE_NAMES = {"C": "COPY", "P": "PROPAGATE", "V": "REVALIDATE", "R": "RE-INFER", "F": "FULL_REFRESH"}


class Out:
    def __init__(self, g):
        self.g, self.lines = g, []

    def __call__(self, *a):
        s = " ".join(str(x) for x in a)
        print(s, flush=True)
        self.lines.append(s)

    def save(self, name=None):
        os.makedirs(PROOFS, exist_ok=True)
        p = os.path.join(PROOFS, name or f"pipeline-{self.g}-report.txt")
        with open(p, "w") as fh:
            fh.write("\n".join(self.lines) + "\n")
        print(f"-> {os.path.relpath(p, ROOT)}\n", flush=True)


def ffprobe_frames(video):
    r = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=nb_frames",
                        "-of", "csv=p=0", video], capture_output=True, text=True)
    try:
        return int(r.stdout.strip().split(",")[0])
    except Exception:
        r = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
                            "stream=nb_read_frames", "-of", "csv=p=0", video], capture_output=True, text=True)
        return int(r.stdout.strip() or 0)


def dense_states(s, want=None):
    """Sequential dense replay (independent of snapshot seeking). Yields (f, state) for f in want (or all)."""
    state = {}
    for r in s.stream:
        if r.get("kind") == "snapshot" and isinstance(r.get("state"), dict):
            state = copy.deepcopy(r["state"])
        else:
            state = api.merge_patch(state, r.get("delta") or {})
        if want is None or r["f"] in want:
            yield r["f"], state


def iter_fields(state):
    sc = state.get("scene") or {}
    for k, v in sc.items():
        if isinstance(v, dict):
            yield f"scene.{k}", v
    for eid, ent in (state.get("entities") or {}).items():
        for k, v in (ent or {}).items():
            yield f"entities.{eid}.{k}", v
    for grp in ("hud", "text"):
        for k, v in (state.get(grp) or {}).items():
            yield f"{grp}.{k}", v


# ---------------------------------------------------------------- mapping
_MAP = {}


def video_rows(truth, video):
    if (truth, video) not in _MAP:
        from testgame import video_truth  # engine/questions/testgame.py
        rows, _ = video_truth(truth, video)
        _MAP[(truth, video)] = rows
    return _MAP[(truth, video)]


def iou(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    ix = max(0, min(ax + aw, bx + bw) - max(ax, bx))
    iy = max(0, min(ay + ah, by + bh) - max(ay, by))
    i = ix * iy
    u = aw * ah + bw * bh - i
    return i / u if u > 0 else 0


# ---------------------------------------------------------------- G1
def g1(s, video):
    o = Out("G1")
    o("== G1: every frame on timeline; region modes; VLM sparsity ==")
    n = len(s.stream)
    nb = ffprobe_frames(video) if video else s.meta.get("nb_frames")
    o(f"stream.jsonl lines={n}  ffprobe nb_frames={nb}  match={'PASS' if n == nb else 'FAIL'}")
    fs = [r['f'] for r in s.stream]
    o(f"frame indices contiguous 0..{n - 1}: {'PASS' if fs == list(range(n)) else 'FAIL'}")
    hist = {m: 0 for m in MODES}
    bad = 0
    for r in s.stream:
        m = r.get("modes") or ""
        if len(m) != 48:
            bad += 1
        for c in m:
            hist[c] = hist.get(c, 0) + 1
    tot = sum(hist.values()) or 1
    o("mode histogram (region-frames): " + "  ".join(f"{MODE_NAMES.get(k, k)}={v} ({100 * v / tot:.1f}%)" for k, v in hist.items()))
    o(f"all 5 modes > 0: {'PASS' if all(hist[m] > 0 for m in MODES) else 'FAIL'}   rows with modes!=48 chars: {bad}")
    cpv = 100 * (hist["C"] + hist["P"] + hist["V"]) / tot
    o(f"COPY+PROPAGATE+REVALIDATE = {cpv:.2f}%  (>=70%: {'PASS' if cpv >= 70 else 'FAIL'})")
    vl = sum(1 for r in s.stream if r.get("vlm"))
    o(f"VLM frames = {vl}/{n} = {100 * vl / max(1, n):.2f}%  (<=5%: {'PASS' if vl <= 0.05 * n else 'FAIL'})")
    o(f"snapshots={sum(1 for r in s.stream if r.get('kind') == 'snapshot')} deltas={sum(1 for r in s.stream if r.get('kind') == 'delta')} "
      f"empty deltas={sum(1 for r in s.stream if r.get('kind') == 'delta' and not r.get('delta'))}")
    o.save()


# ---------------------------------------------------------------- G2
def g2(s, truth, video):
    o = Out("G2")
    o("== G2: snapshot+delta reconstruction; storage; identity ==")
    n = len(s.stream)
    rnd = random.Random(7)
    snaps = {r["f"] for r in s.stream if r.get("kind") == "snapshot"}
    cand = [f for f in range(n) if f not in snaps] or list(range(n))
    picks = sorted(rnd.sample(cand, min(20, len(cand))))
    dense = {f: json.dumps(st, sort_keys=True) for f, st in dense_states(s, set(picks))}
    ok = 0
    src = "engine.core.replay.reconstruct" if api._core_reconstruct else "api fallback replay"
    for f in picks:
        got = json.dumps(api.get_state(s, f), sort_keys=True)
        m = got == dense[f]
        ok += m
        o(f"  f={f:6d} get_state==dense_replay: {'OK' if m else 'MISMATCH'}")
    o(f"reconstruct ({src}) vs sequential dense replay: {ok}/{len(picks)} (non-snapshot frames)  {'PASS' if ok == len(picks) == 20 else 'FAIL'}")
    stored = sum(os.path.getsize(os.path.join(s.dir, p)) for p in ("stream.jsonl", "events.jsonl", "summary.json")
                 if os.path.exists(os.path.join(s.dir, p)))
    dense_bytes = 0
    for f, st in dense_states(s):
        dense_bytes += len(json.dumps({"f": f, "state": st})) + 1
    ratio = dense_bytes / max(1, stored)
    o(f"stored bytes (stream+events+summary)={stored}  dense per-frame JSON bytes={dense_bytes}  ratio={ratio:.1f}x  (>=10x: {'PASS' if ratio >= 10 else 'FAIL'})")
    s._dense_bytes = dense_bytes
    if truth and video:
        rows = video_rows(truth, video)
        # truth boxes are canvas-normalized (1280x720); canvas sits at the bottom of the video (title bar on top)
        VW = int(s.meta.get("width") or 1280)
        VH = int(s.meta.get("height") or 720)
        if not s.meta.get("width"):
            pr = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                                 "-of", "csv=p=0", video], capture_output=True, text=True).stdout.strip().split(",")
            VW, VH = int(pr[0]), int(pr[1])
        sc = VW / 1280.0
        cy0 = VH - 720 * sc
        o(f"truth->video bbox transform: canvas y offset {cy0:.0f}px of {VH}, scale {sc:.3f}")
        assign, matches, switches = {}, 0, 0
        want = set(range(min(n, len(rows))))
        for f, st in dense_states(s, want):
            ents = [(eid, e) for eid, e in (st.get("entities") or {}).items()
                    if (e.get("visible") or {}).get("v", True) and isinstance((e.get("bbox") or {}).get("v"), list)]
            pairs = []
            for te in rows[f]["enemies"]:
                tb = (te["x"], (cy0 + te["y"] * 720 * sc) / VH, te["w"], te["h"] * 720 * sc / VH)
                for eid, e in ents:
                    v = iou(tb, e["bbox"]["v"])
                    if v >= 0.3:
                        pairs.append((v, te["id"], eid))
            pairs.sort(reverse=True)
            ut, ue = set(), set()
            for v, tid, eid in pairs:
                if tid in ut or eid in ue:
                    continue
                ut.add(tid)
                ue.add(eid)
                matches += 1
                if tid in assign and assign[tid] != eid:
                    switches += 1
                assign[tid] = eid
        pct = 100 * switches / max(1, matches)
        tot_truth = sum(len(rows[f]["enemies"]) for f in want)
        o(f"identity: truth-enemy frame instances={tot_truth} matched(IoU>=0.3)={matches} ({100 * matches / max(1, tot_truth):.1f}%) "
          f"switches={switches} = {pct:.2f}% of matches  (<=5%: {'PASS' if pct <= 5 and matches > 0 else 'FAIL'})")
    o.save()


# ---------------------------------------------------------------- G3
def g3(s, truth, video):
    o = Out("G3")
    o("== G3: short events at exact frame; HUD values; 1 fps baseline ==")
    rows = video_rows(truth, video)
    runs, cur = [], None
    for r in rows:
        if r["flash"]:
            if cur and r["vf"] == cur[-1] + 1:
                cur.append(r["vf"])
            else:
                cur = [r["vf"]]
                runs.append(cur)
    tf = sorted({g for g, *_ in [(r["gf"],) for r in rows if r["flash"]]})
    o(f"truth flash frames present in video: {len(runs)} runs (gf flash frames seen: {tf})")
    fl = [e for e in s.events if e.get("type") == "flash"]
    starts = {e.get("f_start") for e in fl}
    hit = 0
    for run in runs:
        m = run[0] in starts
        hit += m
        near = sorted(starts, key=lambda x: abs(x - run[0]))[:1]
        o(f"  truth flash vf={run[0]}..{run[-1]} (len {len(run)}): engine event at exact frame: {'YES' if m else 'no'}"
          f"  nearest={near}")
    o(f"flash exact-frame (±0) matches: {hit}/{len(runs)}  engine flash events={len(fl)}  "
      f"(>=9/10: {'PASS' if hit >= 9 else 'FAIL'})")
    fps = s.fps
    sampled = {int(round(k * fps)) for k in range(int(len(rows) / fps) + 1)}
    b = sum(1 for run in runs if any(f in sampled for f in run))
    o(f"1 fps baseline (frames round(k*{fps:g})): catches {b}/{len(runs)} flashes  (<=3: {'PASS' if b <= 3 else 'FAIL'})")
    for name in ("health", "ammo"):
        tl = s.timelines.get(("hud", name), [])
        import bisect
        fr = [t[0] for t in tl]

        def val(f):
            i = bisect.bisect_right(fr, f) - 1
            return tl[i][1] if i >= 0 else None
        ch = [r for i, r in enumerate(rows) if i > 0 and r["hud"][name] != rows[i - 1]["hud"][name]]
        good = 0
        for r in ch:
            v = val(r["vf"])
            try:
                good += int(float(v)) == int(r["hud"][name])
            except Exception:
                pass
        # provenance frame: field.f (frame the value was observed) of the timeline entry
        obs_ok = 0
        for r in ch:
            ent = next((t for t in tl if t[4] == r["vf"] or (t[0] == r["vf"])), None)
            try:
                obs_ok += ent is not None and int(float(ent[1])) == int(r["hud"][name])
            except Exception:
                pass
        evs = {(e.get("f_start"), str(e.get("to"))) for e in s.events
               if e.get("type") == "ui_value_changed" and e.get("entity") == f"hud.{name}"}
        ev_ok = sum(1 for r in ch if (r["vf"], str(r["hud"][name])) in evs)
        o(f"HUD {name}: truth changes in video={len(ch)}")
        o(f"   ui_value_changed event at exact frame with correct new value: {ev_ok}/{len(ch)} = {100 * ev_ok / max(1, len(ch)):.1f}%"
          f"  (>=90%: {'PASS' if len(ch) and ev_ok >= 0.9 * len(ch) else 'FAIL'})")
        o(f"   state field with provenance frame f == change frame and correct value: {obs_ok}/{len(ch)}")
        o(f"   state value already correct AT the change frame (get_state(f)): {good}/{len(ch)}"
          f"  (state commit lag: value written after confirmation, field.f carries the observed frame)")
    uv = [e for e in s.events if e.get("type") == "ui_value_changed"]
    o(f"ui_value_changed events={len(uv)}  event_started-type (flash) events={len(fl)}")
    o.save()


# ---------------------------------------------------------------- G4
def g4(s):
    o = Out("G4")
    o("== G4: provenance, confidence, evidence ==")
    req = ("v", "conf", "source", "f", "bbox")  # crop: key absent == null (merge-patch cannot carry null)
    missing, total = 0, 0
    conf = {"observed": [], "propagated": [], "inferred": []}
    examples = []
    for f, st in dense_states(s):
        for path, fld in iter_fields(st):
            total += 1
            if not isinstance(fld, dict) or any(k not in fld for k in req) or fld.get("source") not in conf:
                missing += 1
                if len(examples) < 5:
                    examples.append(f"f{f} {path}={json.dumps(fld)[:120]}")
                continue
            if isinstance(fld.get("conf"), (int, float)):
                conf[fld["source"]].append(fld["conf"])
    ev_missing = sum(1 for e in s.events if any(k not in e for k in ("confidence", "source", "evidence")))
    o(f"state field-frames checked={total}  missing provenance (any of {req})={missing}  (0: {'PASS' if missing == 0 and total else 'FAIL'})")
    for ex in examples:
        o("   e.g. " + ex)
    o(f"events={len(s.events)} missing confidence/source/evidence={ev_missing}")
    for k, v in conf.items():
        o(f"mean conf {k}: {sum(v) / len(v):.3f} (n={len(v)})" if v else f"mean conf {k}: n=0")
    mo = sum(conf["observed"]) / max(1, len(conf["observed"]))
    mp = sum(conf["propagated"]) / max(1, len(conf["propagated"]))
    o(f"propagated < observed: {'PASS' if conf['propagated'] and mp < mo else 'FAIL'}")
    crops = [e for e in s.events if (e.get("evidence") or {}).get("crop")]
    exist = [e for e in crops if os.path.exists(os.path.join(s.dir, e["evidence"]["crop"]))]
    o(f"event evidence crops: {len(crops)} referenced, {len(exist)} open on disk")
    # montage of 5 diverse evidence crops
    from PIL import Image, ImageDraw, ImageFont
    pick, seen = [], set()
    for e in exist:
        if e["type"] not in seen:
            pick.append(e)
            seen.add(e["type"])
    for e in exist:
        if len(pick) >= 5:
            break
        if e not in pick:
            pick.append(e)
    pick = pick[:5]
    if pick:
        cw, ch = 300, 220
        canvas = Image.new("RGB", (cw * len(pick), ch + 120), (20, 20, 24))
        d = ImageDraw.Draw(canvas)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 13)
        except Exception:
            font = ImageFont.load_default()
        for i, e in enumerate(pick):
            im = Image.open(os.path.join(s.dir, e["evidence"]["crop"])).convert("RGB")
            im.thumbnail((cw - 10, ch - 10))
            canvas.paste(im, (i * cw + 5, 5))
            claim = api._event_line(e, s)
            words, lines, cur = claim.split(), [], ""
            for w in words:
                if len(cur) + len(w) + 1 > 38:
                    lines.append(cur)
                    cur = w
                else:
                    cur = (cur + " " + w).strip()
            lines.append(cur)
            lines.append(f"crop: {e['evidence']['crop']}"[:40])
            for j, ln in enumerate(lines[:7]):
                d.text((i * cw + 6, ch + 4 + j * 16), ln, fill=(230, 230, 230), font=font)
        p = os.path.join(PROOFS, "pipeline-G4-evidence.png")
        os.makedirs(PROOFS, exist_ok=True)
        canvas.save(p)
        o(f"montage of {len(pick)} evidence crops + claims -> {os.path.relpath(p, ROOT)}")
    else:
        o("no evidence crops on disk -> montage FAIL")
    o.save()


# ---------------------------------------------------------------- G5
def _server_up(port):
    import urllib.request
    try:
        urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2).read()
        return True
    except Exception:
        return False


def g5(s, qpath, model=None, port=8765):
    o = Out("G5")
    o("== G5: query API over HTTP + LLM answers via compile_context ==")
    proc = None
    if not _server_up(port):
        proc = subprocess.Popen([sys.executable, os.path.join(ROOT, "engine", "server.py"), "--port", str(port)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(50):
            if _server_up(port):
                break
            time.sleep(0.2)
    sess = urllib.parse.quote(s.dir)
    mid = len(s.stream) // 2
    eid = next(iter(s.entity_first), "e1")
    ev = next((e for e in s.events if (e.get("evidence") or {}).get("crop")), s.events[0] if s.events else {"id": "x"})
    calls = [
        f"get_state?session={sess}&f={mid}",
        f"get_changes?session={sess}&f0={mid}&f1={mid + 30}",
        f"get_entity_history?session={sess}&entity_id={urllib.parse.quote(str(eid))}",
        f"get_events?session={sess}&f0=0&f1={len(s.stream)}&type=flash",
        f"search_semantics?session={sess}&query=objective",
        f"get_evidence?session={sess}&annotation_id={urllib.parse.quote(str(ev.get('id')))}",
        f"compile_context?session={sess}&query={urllib.parse.quote('how many flashes and when did health drop')}&token_budget=4000",
        f"reanalyze?session={sess}&f0={mid}&f1={mid + 2}&region=0.3,0.0,0.4,0.12&fidelity=high",
    ]
    api_lines, ok = [], 0
    for c in calls:
        url = f"http://127.0.0.1:{port}/{c}"
        r = subprocess.run(["curl", "-s", "-w", "\n%{http_code}", url], capture_output=True, text=True, timeout=300)
        body, _, code = r.stdout.rpartition("\n")
        good = code == "200" and len(body) > 2 and body not in ("{}", "[]")
        ok += good
        api_lines += [f"$ curl -s '{url}'", f"HTTP {code}  bytes={len(body)}", body[:300], ""]
    api_lines.append(f"{ok}/8 ops HTTP 200 non-empty")
    with open(os.path.join(PROOFS, "pipeline-G5-api.txt"), "w") as fh:
        fh.write("\n".join(api_lines) + "\n")
    o(f"HTTP ops: {ok}/8 returned 200 + non-empty  -> proofs/pipeline-G5-api.txt  ({'PASS' if ok == 8 else 'FAIL'})")
    if proc:
        proc.terminate()
    if not qpath or not os.path.exists(qpath):
        o("questions file missing -> skip LLM eval")
        o.save()
        return
    from testgame import grade
    qd = json.load(open(qpath))
    o(f"questions: {os.path.relpath(qpath, ROOT)} created_at={qd.get('created_at')} (file mtime "
      f"{time.strftime('%Y-%m-%dT%H:%M:%S', time.localtime(os.path.getmtime(qpath)))}); eval started {time.strftime('%Y-%m-%dT%H:%M:%S')}")
    score, toks = 0, []
    for q in qd["questions"]:
        try:
            r = api.ask(s, q["q"], 4000, model=model)
        except Exception as e:
            r = {"answer": f"ERROR {e}", "context_tokens": 0}
        g = grade(q, r["answer"])
        score += g
        toks.append(r.get("context_tokens") or 0)
        o(f"  [{q['id']}] {'CORRECT' if g else 'WRONG'} ctx_tokens={r.get('context_tokens')} in_tokens={r.get('input_tokens')}")
        o(f"      Q: {q['q']}")
        o(f"      expected: {q['answer']}   got: {r['answer'][:160]}")
    n = len(s.stream)
    img_base = n * 1000
    dense_b = getattr(s, "_dense_bytes", None)
    if dense_b is None:
        dense_b = sum(len(json.dumps(st)) for _, st in dense_states(s))
    dense_tok = int(dense_b / 3.5)
    mx = max(toks) if toks else 0
    avg = sum(toks) / max(1, len(toks))
    o(f"score {score}/{len(qd['questions'])}  (>=8: {'PASS' if score >= 8 else 'FAIL'})  model={model or api.ANSWER_MODEL}")
    o(f"context tokens per question: {toks}  max={mx} (<=4000: {'PASS' if mx <= 4000 else 'FAIL'}) mean={avg:.0f}")
    o(f"all-frames baseline: {n} frames x ~1000 image tokens = {img_base} tokens; dense per-frame JSON = {dense_tok} tokens")
    o(f"ratio max-context / image baseline = {100 * mx / img_base:.3f}%  / dense JSON = {100 * mx / max(1, dense_tok):.2f}%  "
      f"(<=10%: {'PASS' if mx <= 0.1 * min(img_base, dense_tok) else 'FAIL'})")
    o.save()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("session")
    ap.add_argument("--truth", default=os.path.join(ROOT, "testgame", "out", "truth.jsonl"))
    ap.add_argument("--video")
    ap.add_argument("--only", default="G1,G2,G3,G4,G5")
    ap.add_argument("--questions", default=os.path.join(ROOT, "engine", "questions", "testgame.json"))
    ap.add_argument("--model")
    a = ap.parse_args()
    s = api.load(a.session)
    video = a.video or api._video_for(s)
    truth = a.truth if a.truth and os.path.exists(a.truth) else None
    only = set(a.only.upper().split(","))
    print(f"session={s.dir} frames={len(s.stream)} events={len(s.events)} video={video} truth={truth}\n")
    if "G1" in only:
        g1(s, video)
    if "G2" in only:
        g2(s, truth, video)
    if "G3" in only and truth and video:
        g3(s, truth, video)
    if "G4" in only:
        g4(s)
    if "G5" in only:
        g5(s, a.questions, a.model)


if __name__ == "__main__":
    main()
