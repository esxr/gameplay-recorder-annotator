"""Session Query API (PRD §39) over an engine session dir (see engine/CONTRACT.md).

Ops: get_state, get_changes, get_entity_history, get_events, search_semantics,
get_evidence, compile_context, reanalyze, plus ask() (compile_context -> Claude).
Stdlib + numpy/PIL only.
"""
import copy
import json
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

try:  # replay owned by engine/core (other agent); fall back to our own
    from engine.core.replay import reconstruct as _core_reconstruct  # type: ignore
except Exception:  # pragma: no cover
    _core_reconstruct = None

ANSWER_MODEL = os.environ.get("ENGINE_ANSWER_MODEL", "claude-haiku-4-5-20251001")
GRID_COLS, GRID_ROWS = 8, 6

# ----------------------------------------------------------------------------
# loading + index
# ----------------------------------------------------------------------------

def merge_patch(target, patch):
    """RFC 7386 JSON merge patch, in place on dict target. Returns target."""
    if not isinstance(patch, dict):
        return copy.deepcopy(patch)
    if not isinstance(target, dict):
        target = {}
    for k, v in patch.items():
        if v is None:
            target.pop(k, None)
        elif isinstance(v, dict):
            target[k] = merge_patch(target.get(k), v)
        else:
            target[k] = copy.deepcopy(v)
    return target


def _read_jsonl(path):
    out = []
    if not os.path.exists(path):
        return out
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return out


class Session:
    def __init__(self, sdir):
        self.dir = os.path.abspath(sdir)
        self.meta = self._json("meta.json") or {}
        self.summary = self._json("summary.json") or {}
        self.stream = _read_jsonl(os.path.join(self.dir, "stream.jsonl"))
        self.stream.sort(key=lambda r: r.get("f", 0))
        self.by_f = {r["f"]: i for i, r in enumerate(self.stream)}
        self.events = _read_jsonl(os.path.join(self.dir, "events.jsonl"))
        self.events.sort(key=lambda e: (e.get("f_start", 0), str(e.get("id"))))
        self.event_by_id = {str(e.get("id")): e for e in self.events}
        self.nb_frames = len(self.stream)
        self.fps = float(self.meta.get("fps") or 30.0)
        self.snap_idx = [i for i, r in enumerate(self.stream) if r.get("kind") == "snapshot"]
        self._build_index()

    def _json(self, name):
        p = os.path.join(self.dir, name)
        if os.path.exists(p):
            try:
                with open(p) as fh:
                    return json.load(fh)
            except Exception:
                return None
        return None

    # --- dense single pass: timelines of every field (value changes only) ---
    def _build_index(self):
        self.timelines = {}   # path tuple -> [(f, v, conf, source, f_obs, bbox, crop)]
        self.entity_first = {}
        self.entity_last = {}
        self.vlm_frames = []
        state = {}
        for r in self.stream:
            f = r["f"]
            if r.get("vlm"):
                self.vlm_frames.append(f)
            if r.get("kind") == "snapshot" and isinstance(r.get("state"), dict):
                state = copy.deepcopy(r["state"])
            else:
                state = merge_patch(state, r.get("delta") or {})
            self._record(f, state)
        self.final_state = state

    def _record(self, f, state):
        def rec(path, fld):
            if not isinstance(fld, dict) or "v" not in fld:
                return
            tl = self.timelines.setdefault(path, [])
            v = fld.get("v")
            if not tl or tl[-1][1] != v:
                tl.append((f, v, fld.get("conf"), fld.get("source"), fld.get("f"),
                           fld.get("bbox"), fld.get("crop")))
        for name, fld in (state.get("hud") or {}).items():
            rec(("hud", name), fld)
        for rid, fld in (state.get("text") or {}).items():
            rec(("text", rid), fld)
        sc = state.get("scene") or {}
        if "label" in sc:
            rec(("scene", "label"), sc["label"])
        seen = set()
        for eid, ent in (state.get("entities") or {}).items():
            seen.add(eid)
            self.entity_first.setdefault(eid, f)
            self.entity_last[eid] = f
            for k, fld in (ent or {}).items():
                if k == "bbox":
                    continue
                rec(("entities", eid, k), fld)
            # bbox: record only at visibility start + every 30 frames
            bb = (ent or {}).get("bbox")
            if isinstance(bb, dict):
                tl = self.timelines.setdefault(("entities", eid, "bbox"), [])
                if not tl or f - tl[-1][0] >= 30:
                    tl.append((f, bb.get("v"), bb.get("conf"), bb.get("source"), bb.get("f"), None, bb.get("crop")))
        nvis = sum(1 for e in (state.get("entities") or {}).values()
                   if (e or {}).get("visible", {}).get("v", True))
        rec(("derived", "visible_entity_count"), {"v": nvis, "conf": None, "source": "inferred", "f": f})
        # mark removal
        for eid in list(self.entity_last):
            if eid not in seen:
                tl = self.timelines.setdefault(("entities", eid, "present"), [])
                if not tl or tl[-1][1] is not False:
                    tl.append((f, False, 1.0, "observed", f, None, None))
            else:
                tl = self.timelines.setdefault(("entities", eid, "present"), [])
                if not tl or tl[-1][1] is not True:
                    tl.append((f, True, 1.0, "observed", f, None, None))

    def replay(self, f):
        if not self.stream:
            return {}
        f = max(self.stream[0]["f"], min(int(f), self.stream[-1]["f"]))
        i = self.by_f.get(f)
        if i is None:
            i = max(j for j, r in enumerate(self.stream) if r["f"] <= f)
        s0 = None
        for si in reversed(self.snap_idx):
            if si <= i:
                s0 = si
                break
        if s0 is None:
            state, start = {}, 0
        else:
            state, start = copy.deepcopy(self.stream[s0].get("state") or {}), s0 + 1
        for j in range(start, i + 1):
            state = merge_patch(state, self.stream[j].get("delta") or {})
        return state

    def f_to_ms(self, f):
        i = self.by_f.get(f)
        if i is not None and "t_ms" in self.stream[i]:
            return self.stream[i]["t_ms"]
        return f * 1000.0 / self.fps


_CACHE = {}
_LOCK = threading.Lock()


def load(session):
    if isinstance(session, Session):
        return session
    sdir = os.path.abspath(session)
    sp = os.path.join(sdir, "stream.jsonl")
    key = (sdir, os.path.getmtime(sp) if os.path.exists(sp) else 0)
    with _LOCK:
        s = _CACHE.get(sdir)
        if s is None or s[0] != key:
            s = (key, Session(sdir))
            _CACHE[sdir] = s
        return s[1]


# ----------------------------------------------------------------------------
# the 8 ops
# ----------------------------------------------------------------------------

def get_state(session, f):
    s = load(session)
    f = int(f)
    if _core_reconstruct is not None:
        try:
            return _core_reconstruct(s.dir, f)
        except Exception:
            pass
    return s.replay(f)


def get_changes(session, f0, f1):
    """Per-frame deltas (non-empty) in [f0, f1] plus events in range."""
    s = load(session)
    f0, f1 = int(f0), int(f1)
    changes = []
    for r in s.stream:
        if f0 <= r["f"] <= f1:
            if r.get("kind") == "snapshot":
                changes.append({"f": r["f"], "kind": "snapshot"})
            elif r.get("delta"):
                changes.append({"f": r["f"], "delta": r["delta"]})
    return {"f0": f0, "f1": f1, "changes": changes,
            "events": get_events(s, f0, f1)["events"]}


def get_entity_history(session, entity_id):
    s = load(session)
    eid = str(entity_id)
    hist = {"/".join(k[2:]): [dict(zip(("f", "v", "conf", "source", "f_obs", "bbox", "crop"), t)) for t in tl]
            for k, tl in s.timelines.items() if k[0] == "entities" and k[1] == eid}
    return {"entity_id": eid, "first_f": s.entity_first.get(eid), "last_f": s.entity_last.get(eid),
            "history": hist,
            "events": [e for e in s.events if str(e.get("entity")) == eid]}


def get_events(session, f0=None, f1=None, type=None):
    s = load(session)
    f0 = -1 if f0 in (None, "") else int(f0)
    f1 = 10 ** 12 if f1 in (None, "") else int(f1)
    types = set(type.split(",")) if isinstance(type, str) and type else None
    ev = [e for e in s.events
          if e.get("f_end", e.get("f_start", 0)) >= f0 and e.get("f_start", 0) <= f1
          and (types is None or e.get("type") in types)]
    return {"count": len(ev), "events": ev}


def _tokens(q):
    return [w for w in re.findall(r"[a-z0-9_]+", q.lower()) if len(w) > 1]


def search_semantics(session, query, limit=50):
    """Keyword search over events, field timelines (values), entity ids, summary."""
    s = load(session)
    toks = _tokens(query)
    hits = []
    for e in s.events:
        blob = json.dumps(e).lower()
        sc = sum(blob.count(t) for t in toks)
        if sc:
            hits.append({"score": sc, "kind": "event", "f": e.get("f_start"), "id": e.get("id"), "event": e})
    for k, tl in s.timelines.items():
        name = "/".join(k).lower()
        for (f, v, conf, src, fo, bb, crop) in tl:
            blob = (name + " " + str(v)).lower()
            sc = sum(blob.count(t) for t in toks)
            if sc:
                hits.append({"score": sc, "kind": "field", "path": "/".join(k), "f": f, "v": v,
                             "conf": conf, "source": src, "crop": crop})
    for w in (s.summary.get("windows") or []) if isinstance(s.summary, dict) else []:
        blob = json.dumps(w).lower()
        sc = sum(blob.count(t) for t in toks)
        if sc:
            hits.append({"score": sc, "kind": "summary", "window": w})
    hits.sort(key=lambda h: (-h["score"], h.get("f") or 0))
    return {"query": query, "count": len(hits), "hits": hits[:int(limit)]}


def get_evidence(session, annotation_id):
    """annotation_id = event id, or '<path>@<f>' e.g. 'hud/health@120'."""
    s = load(session)
    aid = str(annotation_id)
    e = s.event_by_id.get(aid)
    if e is not None:
        ev = dict(e.get("evidence") or {})
        crop = ev.get("crop")
        ev["crop_abs"] = os.path.join(s.dir, crop) if crop else None
        ev["exists"] = bool(crop) and os.path.exists(ev["crop_abs"])
        return {"id": aid, "claim": _event_line(e, s), "evidence": ev, "source": e.get("source"),
                "confidence": e.get("confidence")}
    m = re.match(r"(.+)@(\d+)$", aid)
    if m:
        path, f = m.group(1).split("/"), int(m.group(2))
        st = get_state(s, f)
        node = st
        for p in path:
            node = (node or {}).get(p) if isinstance(node, dict) else None
        if isinstance(node, dict):
            crop = node.get("crop")
            return {"id": aid, "claim": f"{'/'.join(path)}={node.get('v')} at f{f}", "field": node,
                    "evidence": {"f": node.get("f"), "bbox": node.get("bbox"), "crop": crop,
                                 "crop_abs": os.path.join(s.dir, crop) if crop else None,
                                 "exists": bool(crop) and os.path.exists(os.path.join(s.dir, crop))}}
    return {"id": aid, "error": "not found"}


# ----------------------------------------------------------------------------
# context compiler (§28-29)
# ----------------------------------------------------------------------------

def _src_tag(src, conf):
    t = {"observed": "obs", "propagated": "PROP", "inferred": "INFER"}.get(src, str(src))
    return f"{t}{'' if conf is None else f' {conf:.2f}'}"


def _fmt(v):
    if isinstance(v, float):
        return f"{v:.3g}"
    if isinstance(v, (list, tuple)):
        return "[" + ",".join(_fmt(x) for x in v) + "]"
    if isinstance(v, str):
        return json.dumps(v)
    return str(v)


def _event_line(e, s):
    fs, fe = e.get("f_start"), e.get("f_end", e.get("f_start"))
    t = e.get("t_ms", s.f_to_ms(fs) if fs is not None else 0) / 1000.0
    rng = f"f{fs}" if fs == fe else f"f{fs}-f{fe}"
    parts = [f"{rng} t={t:.2f}s {e.get('type')}"]
    if e.get("entity") is not None:
        parts.append(f"entity={e['entity']}")
    if "from" in e or "to" in e:
        parts.append(f"{_fmt(e.get('from'))}->{_fmt(e.get('to'))}")
    parts.append(f"[{_src_tag(e.get('source'), e.get('confidence'))}] id={e.get('id')}")
    return " ".join(parts)


def _parse_frames(q, s):
    """Frame / time references in the query -> list of frames."""
    fr = []
    for m in re.finditer(r"\bframes?\s*#?\s*(\d+)(?:\s*(?:-|to|and)\s*(\d+))?", q, re.I):
        fr.append(int(m.group(1)))
        if m.group(2):
            fr.append(int(m.group(2)))
    for m in re.finditer(r"\b(\d+):(\d{2}(?:\.\d+)?)\b", q):
        fr.append(int(round((int(m.group(1)) * 60 + float(m.group(2))) * s.fps)))
    for m in re.finditer(r"(?<![\w.])(\d+(?:\.\d+)?)\s*(?:s|sec|secs|seconds?)\b", q, re.I):
        fr.append(int(round(float(m.group(1)) * s.fps)))
    return sorted(set(max(0, min(f, max(0, s.nb_frames - 1))) for f in fr))


KW = {
    "hud": ["health", "hp", "ammo", "score", "hud", "damage", "lost", "shot", "shots", "fire", "fired", "bullet", "points"],
    "text": ["objective", "text", "say", "said", "message", "notification", "read", "ocr", "label"],
    "entities": ["enemy", "enemies", "entity", "visible", "appear", "appears", "seen", "cover", "count", "many", "object", "target"],
    "flash": ["flash", "flashes", "hit", "muzzle", "one frame", "1-frame", "single frame", "briefly", "only one"],
}


def compile_context(session, query, token_budget=4000):
    s = load(session)
    token_budget = int(token_budget)
    ql = (query or "").lower()
    want = {k: any(w in ql for w in ws) for k, ws in KW.items()}
    if not any(want.values()):
        want = {k: True for k in want}
    if "shot" in ql or "fire" in ql or "ammo" in ql:
        want["hud"] = True
    frames = _parse_frames(query or "", s)
    evidence = []

    sections = []  # (priority, title, lines)
    head = [f"SESSION {os.path.basename(s.dir)}: frames 0..{s.nb_frames - 1} at {s.fps:g} fps "
            f"(frame f -> time f/{s.fps:g} s). Frame indices are source video frames.",
            "Tags: obs=observed this frame by perception; PROP=propagated from earlier observation "
            "(not re-seen; conf decays); INFER=inferred. Number after tag = confidence."]
    sections.append((0, "HEADER", head))

    # hud timelines
    hud_names = sorted({k[1] for k in s.timelines if k[0] == "hud"})
    focus_hud = [h for h in hud_names if h.lower() in ql] or hud_names
    if want["hud"] or frames:
        lines = []
        for h in focus_hud:
            tl = s.timelines[("hud", h)]
            items, last_v = [], object()
            for (f, v, conf, src, fo, bb, crop) in tl:
                if v == last_v:
                    continue
                fc = fo if isinstance(fo, int) and fo <= f else f  # frame where the value was first observed
                items.append(f"f{fc}={_fmt(v)}" + ("" if src == "observed" else f"({_src_tag(src, conf)})"))
                last_v = v
            lines.append(f"hud.{h} value timeline (value holds until next entry): " + " ".join(items))
        sections.append((1 if want["hud"] else 3, "HUD VALUE TIMELINES (exact frames of change)", lines))

    # text timelines
    text_keys = sorted(k for k in s.timelines if k[0] in ("text", "scene"))
    if text_keys and (want["text"] or frames):
        lines = []
        for k in text_keys:
            tl = s.timelines[k]
            items, last_v = [], object()
            for (f, v, conf, src, fo, bb, crop) in tl:
                if v == last_v:
                    continue
                fc = fo if isinstance(fo, int) and fo <= f else f
                items.append(f"f{fc}={_fmt(v)}[{_src_tag(src, conf)}]")
                last_v = v
                if crop:
                    evidence.append({"f": f, "crop": crop})
            lines.append(f"{'.'.join(k)}: " + " ".join(items))
        sections.append((1 if want["text"] else 3, "TEXT / OCR TIMELINES", lines))

    # entities
    eids = sorted(s.entity_first, key=lambda e: s.entity_first[e])
    if eids and (want["entities"] or frames):
        lines = []
        for eid in eids:
            vis = s.timelines.get(("entities", eid, "visible"), [])
            pres = s.timelines.get(("entities", eid, "present"), [])
            lab = s.timelines.get(("entities", eid, "label"), []) or s.timelines.get(("entities", eid, "type"), [])
            label = lab[0][1] if lab else ""
            # intervals of (present and visible)
            ivs = _visible_intervals(pres, vis, s.nb_frames)
            iv = " ".join(f"f{a}-f{b}" for a, b in ivs[:20]) + (" ..." if len(ivs) > 20 else "")
            prop = [f"f{f}" for (f, v, c, src, *_r) in vis if src != "observed"][:8]
            line = f"{eid} ({_fmt(label)}): first f{s.entity_first[eid]} last f{s.entity_last[eid]}; visible intervals: {iv or 'none'}"
            if prop:
                line += f"; visibility PROP/INFER at {' '.join(prop)}"
            lines.append(line)
        tl = s.timelines.get(("derived", "visible_entity_count"), [])
        lines.insert(0, "visible entity count timeline (count holds until next entry): " +
                     " ".join(f"f{f}={v}" for (f, v, *_r) in tl))
        sections.append((1 if want["entities"] else 3, "ENTITIES (visible intervals, inclusive)", lines))

    # events
    ev_lines = []
    ev_sorted = s.events
    types_pri = []
    if want["flash"]:
        types_pri.append("flash")
    if want["hud"]:
        types_pri.append("ui_value_changed")
    if want["text"]:
        types_pri.append("text_changed")
    if want["entities"]:
        types_pri += ["entity_created", "entity_removed"]
    pri_ev = [e for e in ev_sorted if e.get("type") in types_pri]
    rest = [e for e in ev_sorted if e.get("type") not in types_pri]
    for e in pri_ev:
        ev_lines.append(_event_line(e, s))
        ev = e.get("evidence") or {}
        if ev.get("crop"):
            evidence.append({"f": ev.get("f", e.get("f_start")), "crop": ev["crop"], "id": e.get("id")})
    counts = {}
    for e in ev_sorted:
        counts[e.get("type")] = counts.get(e.get("type"), 0) + 1
    sections.append((1, "EVENT COUNTS", [", ".join(f"{k}={v}" for k, v in sorted(counts.items()))]))
    if ev_lines:
        sections.append((1, f"EVENTS ({'/'.join(types_pri)}) chronological", ev_lines))
    if rest:
        sections.append((4, "OTHER EVENTS", [_event_line(e, s) for e in rest]))

    # key-frame compact states
    if frames:
        lines = []
        for f in frames[:6]:
            lines.append(_compact_state(s, f))
        sections.insert(1, (0, "STATE AT REFERENCED FRAMES", lines))

    # assemble with budget
    budget_chars = int(token_budget * 3.5)
    out, used = [], 0
    for pri in sorted({p for p, _, _ in sections}):
        for p, title, lines in sections:
            if p != pri:
                continue
            hdr = f"## {title}"
            if used + len(hdr) + 1 > budget_chars:
                continue
            out.append(hdr)
            used += len(hdr) + 1
            for ln in lines:
                if used + len(ln) + 1 > budget_chars:
                    # try truncating a long line
                    room = budget_chars - used - 20
                    if room > 200:
                        out.append(ln[:room] + " …[trimmed]")
                        used += room + 12
                    out.append("…[section trimmed to fit token budget]")
                    used += 40
                    break
                out.append(ln)
                used += len(ln) + 1
    ctx = "\n".join(out)
    toks = int(len(ctx) / 3.5) + 1
    seen, ev_out = set(), []
    for e in evidence:
        k = (e.get("f"), e.get("crop"))
        if k not in seen:
            seen.add(k)
            ev_out.append(e)
    return {"context": ctx, "tokens": toks, "token_budget": token_budget, "evidence": ev_out[:20],
            "focus": {k: v for k, v in want.items() if v}, "frames": frames}


def _visible_intervals(pres, vis, nb):
    """Merge present/visible timelines into intervals where both are true."""
    pts = sorted({f for f, *_ in pres} | {f for f, *_ in vis})
    def val_at(tl, f, default):
        v = default
        for (ff, vv, *_r) in tl:
            if ff <= f:
                v = vv
            else:
                break
        return v
    ivs, start = [], None
    for i, f in enumerate(pts):
        on = bool(val_at(pres, f, False)) and bool(val_at(vis, f, True) if vis else True)
        if on and start is None:
            start = f
        if not on and start is not None:
            ivs.append((start, f - 1))
            start = None
    if start is not None:
        last = max(pts) if pts else start
        # present until last frame recorded as present
        end = None
        for (ff, vv, *_r) in pres:
            end = ff
        ivs.append((start, nb - 1 if (pres and pres[-1][1]) else last))
    return ivs


def _compact_state(s, f):
    st = get_state(s, f)
    parts = [f"[f{f} t={s.f_to_ms(f) / 1000:.2f}s]"]
    for h, fld in sorted((st.get("hud") or {}).items()):
        parts.append(f"{h}={_fmt(fld.get('v'))}({_src_tag(fld.get('source'), fld.get('conf'))})")
    for rid, fld in sorted((st.get("text") or {}).items()):
        parts.append(f"text.{rid}={_fmt(fld.get('v'))}({_src_tag(fld.get('source'), fld.get('conf'))})")
    vis = []
    for eid, ent in sorted((st.get("entities") or {}).items()):
        v = (ent.get("visible") or {}).get("v", True)
        if v:
            bb = (ent.get("bbox") or {}).get("v")
            src = (ent.get("visible") or ent.get("bbox") or {}).get("source")
            vis.append(f"{eid}@{_fmt(bb)}({_src_tag(src, None)})")
    parts.append(f"visible_entities={len(vis)}: " + " ".join(vis))
    return " ".join(parts)


# ----------------------------------------------------------------------------
# reanalyze (§29): re-run perception at full res on a range
# ----------------------------------------------------------------------------

def _video_for(s):
    for k in ("video", "video_path", "source"):
        v = s.meta.get(k)
        if isinstance(v, str) and os.path.exists(v):
            return v
    if s.dir.endswith(".session"):
        v = s.dir[: -len(".session")]
        for cand in (v, v + ".mp4", v + ".mov"):
            if os.path.isfile(cand):
                return cand
    return None


def _region_box(region, W, H):
    """region: None | 'x,y,w,h' normalized | grid index 0..47 | 'r<row>c<col>'."""
    if region in (None, "", "all"):
        return (0, 0, W, H)
    if isinstance(region, (list, tuple)):
        x, y, w, h = [float(v) for v in region]
    else:
        r = str(region)
        m = re.match(r"r(\d+)c(\d+)$", r)
        if m or r.isdigit():
            if m:
                row, col = int(m.group(1)), int(m.group(2))
            else:
                row, col = divmod(int(r), GRID_COLS)
            return (col * W // GRID_COLS, row * H // GRID_ROWS, W // GRID_COLS, H // GRID_ROWS)
        x, y, w, h = [float(v) for v in r.split(",")]
    if max(x, y, w, h) <= 1.0:
        return (int(x * W), int(y * H), max(1, int(w * W)), max(1, int(h * H)))
    return (int(x), int(y), int(w), int(h))


def reanalyze(session, f0, f1, region=None, fidelity="high", max_frames=12):
    s = load(session)
    f0, f1 = int(f0), int(f1)
    try:  # prefer engine/core perception if it exposes one
        import engine.core as core  # type: ignore
        fn = getattr(core, "reanalyze", None)
        if fn is None:
            from engine.core import perception  # type: ignore
            fn = getattr(perception, "reanalyze", None)
        if fn is not None:
            return fn(s.dir, f0, f1, region=region, fidelity=fidelity)
    except Exception:
        pass
    video = _video_for(s)
    if not video:
        return {"error": "source video not found", "observations": []}
    W = int(s.meta.get("width") or 0)
    H = int(s.meta.get("height") or 0)
    if not W or not H:
        from PIL import Image
    frames = list(range(f0, f1 + 1))
    if len(frames) > max_frames:
        step = len(frames) / max_frames
        frames = sorted({frames[int(i * step)] for i in range(max_frames)} | {f1})
    obs = []
    with tempfile.TemporaryDirectory() as td:
        for f in frames:
            png = os.path.join(td, f"f{f}.png")
            t = s.f_to_ms(f) / 1000.0
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t:.4f}", "-i", video,
                            "-frames:v", "1", png], capture_output=True, timeout=60)
            if not os.path.exists(png):
                continue
            from PIL import Image
            im = Image.open(png).convert("RGB")
            W, H = im.size
            x, y, w, h = _region_box(region, W, H)
            crop = im.crop((x, y, x + w, y + h))
            if fidelity == "high" and crop.size[1] < 200:
                crop = crop.resize((crop.size[0] * 2, crop.size[1] * 2))
            cp = os.path.join(td, f"c{f}.png")
            crop.save(cp)
            r = subprocess.run(["tesseract", cp, "stdout", "--psm", "6"], capture_output=True, text=True, timeout=60)
            txt = " ".join(r.stdout.split())
            obs.append({"f": f, "text": {"v": txt, "conf": 0.9 if txt else 0.3, "source": "observed", "f": f,
                                         "bbox": [x / W, y / H, w / W, h / H], "crop": None},
                        "fidelity": fidelity, "method": "tesseract_fullres"})
    return {"f0": f0, "f1": f1, "region": region, "fidelity": fidelity, "observations": obs}


# ----------------------------------------------------------------------------
# ask: compile_context -> Claude
# ----------------------------------------------------------------------------

def _api_key():
    k = os.environ.get("ANTHROPIC_API_KEY")
    if k:
        return k
    p = os.path.join(ROOT, ".secrets", "anthropic.env")
    if os.path.exists(p):
        for line in open(p):
            if line.strip().startswith("ANTHROPIC_API_KEY"):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return None


def claude(prompt, system=None, model=None, max_tokens=600):
    body = {"model": model or ANSWER_MODEL, "max_tokens": max_tokens,
            "messages": [{"role": "user", "content": prompt}]}
    if system:
        body["system"] = system
    req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=json.dumps(body).encode(),
                                 headers={"x-api-key": _api_key() or "", "anthropic-version": "2023-06-01",
                                          "content-type": "application/json"})
    last = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                d = json.loads(r.read())
            return "".join(c.get("text", "") for c in d.get("content", [])), d.get("usage", {})
        except Exception as e:  # retry on 429/5xx
            last = e
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"claude call failed: {type(last).__name__}: {str(last)[:200]}")


SYSTEM = ("You answer questions about a recorded gameplay video using ONLY the compiled semantic state below "
          "(no raw frames). Frame numbers are exact source-video frame indices. Timelines list the frame where a "
          "value changed; a value holds until the next entry. Be precise; do arithmetic carefully. "
          "Treat PROP/INFER values as less certain than obs. First line: 'ANSWER: <short answer>' "
          "(a number, frame number, yes/no, or short text). Then one or two lines of justification citing frames.")


def ask(session, question, token_budget=4000, model=None):
    s = load(session)
    t0 = time.time()
    cc = compile_context(s, question, token_budget)
    print(f"STAGE compile tokens={cc['tokens']} budget={token_budget} evidence={len(cc['evidence'])} "
          f"ms={int((time.time() - t0) * 1000)}", flush=True)
    t1 = time.time()
    prompt = f"{cc['context']}\n\nQUESTION: {question}"
    text, usage = claude(prompt, system=SYSTEM, model=model)
    m = re.search(r"ANSWER:\s*(.+)", text)
    short = m.group(1).strip() if m else text.strip().split("\n")[0]
    ev = list(cc["evidence"])
    for fm in re.findall(r"\bf(?:rame)?\s*(\d+)", text):
        ev.insert(0, {"f": int(fm), "crop": None})
    seen, evo = set(), []
    for e in ev:
        if e["f"] not in seen:
            seen.add(e["f"])
            evo.append(e)
    print(f"STAGE answer model={model or ANSWER_MODEL} in_tokens={usage.get('input_tokens')} "
          f"out_tokens={usage.get('output_tokens')} ms={int((time.time() - t1) * 1000)}", flush=True)
    return {"answer": short, "full": text, "context_tokens": cc["tokens"],
            "input_tokens": usage.get("input_tokens"), "evidence": evo[:10]}


OPS = {"get_state": get_state, "get_changes": get_changes, "get_entity_history": get_entity_history,
       "get_events": get_events, "search_semantics": search_semantics, "get_evidence": get_evidence,
       "compile_context": compile_context, "reanalyze": reanalyze}

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("session")
    ap.add_argument("op")
    ap.add_argument("args", nargs="*")
    a = ap.parse_args()
    if a.op == "ask":
        print(json.dumps(ask(a.session, " ".join(a.args)), indent=1))
    else:
        print(json.dumps(OPS[a.op](a.session, *a.args), indent=1, default=str)[:20000])
