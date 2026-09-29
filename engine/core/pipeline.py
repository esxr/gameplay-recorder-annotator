"""Semantic video state engine: change analysis → per-region scheduler (C/P/V/R/F) → state → snapshot+delta store.

Every decoded frame gets exactly one stream line. Analysis runs on a 640-px decode, region/blob
analysis on a further 4× subsampled image (numpy vectorised). A 2-frame lookahead lets 1- and
2-frame flashes be told apart from sustained scene cuts.
"""
import copy
import hashlib
import json
import os
import time
from collections import Counter, deque

import numpy as np
from PIL import Image

from . import ocr as ocrmod
from . import video as vid
from . import vlm as vlmmod

GX, GY = 8, 6
NREG = GX * GY
SUB = 4                      # subsample factor from 640-px decode for change analysis
T_COPY = 6.0                 # region residual (sum of |dRGB|, 0..765) below which region is unchanged
T_BIG = 45.0                 # big local change
T_FLASH = 30.0               # region counted as "flashed"
FLASH_FRAC = 0.45            # fraction of regions flashed (or global mean shift) to open a flash / cut
FLASH_SHIFT = 12.0           # global mean colour shift (sum of channels)
RETURN_FRAC = 0.15
CUT_FRAC = 0.6
FG_T = 60                    # foreground colour distance to background model
DECAY_C = 0.998              # per-frame confidence decay of unchanged region state
DECAY_P = 0.995              # per-frame decay of propagated fields
CONF_REINFER = 0.55
HIDE_FRAMES_S = 2.0
SNAP_EVERY = 300


def rnd(x, n=4):
    return round(float(x), n)


def field(v, conf, source, f, bbox=None, crop=None):
    return {"v": v, "conf": rnd(conf, 2), "source": source, "f": int(f),
            "bbox": [rnd(b) for b in bbox] if bbox is not None else [0.0, 0.0, 1.0, 1.0], "crop": crop}


def is_field(d):
    return isinstance(d, dict) and "v" in d and "source" in d


def diff(a, b):
    """JSON merge-patch turning a into b (fields replaced whole)."""
    out = {}
    for k, v in b.items():
        if k not in a:
            out[k] = v
        elif isinstance(v, dict) and not is_field(v) and isinstance(a[k], dict):
            d = diff(a[k], v)
            if d:
                out[k] = d
        elif a[k] != v:
            out[k] = v
    for k in a:
        if k not in b:
            out[k] = None
    return out


class Track:
    def __init__(self, tid, bbox, f):
        self.id = tid
        self.bbox = np.array(bbox, float)
        self.vel = np.zeros(2)
        self.first = f
        self.last_seen = f
        self.hits = 1
        self.confirmed = False
        self.anchor_f = f
        self.anchor_conf = 0.9
        self.crop = None
        self.label = None
        self.label_src = "inferred"
        self.label_conf = 0.4
        self.label_f = f
        self.label_crop = None
        self.type = "object"
        self.hidden_since = None
        self.moved = 0.0
        self._vlm = False
        self.anchor_bb = [float(v) for v in bbox]


def cells_of(bbox):
    x, y, w, h = bbox
    c0, c1 = int(max(0, min(GX - 1, x * GX))), int(max(0, min(GX - 1, (x + w) * GX)))
    r0, r1 = int(max(0, min(GY - 1, y * GY))), int(max(0, min(GY - 1, (y + h) * GY)))
    return [r * GX + c for r in range(r0, r1 + 1) for c in range(c0, c1 + 1)]


def blobs(mask, min_area=6, max_blobs=40):
    """Connected components (8-conn) on a small boolean mask → list of (x0,y0,x1,y1,area) in mask px."""
    ys, xs = np.nonzero(mask)
    if len(ys) == 0 or len(ys) > 6000:
        return []
    pts = set(zip(ys.tolist(), xs.tolist()))
    out = []
    while pts:
        p = pts.pop()
        stack = [p]
        y0 = y1 = p[0]; x0 = x1 = p[1]; area = 0
        while stack:
            cy, cx = stack.pop()
            area += 1
            if cy < y0: y0 = cy
            if cy > y1: y1 = cy
            if cx < x0: x0 = cx
            if cx > x1: x1 = cx
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    q = (cy + dy, cx + dx)
                    if q in pts:
                        pts.remove(q)
                        stack.append(q)
        if area >= min_area:
            out.append((x0, y0, x1 + 1, y1 + 1, area))
    out.sort(key=lambda b: -b[4])
    return out[:max_blobs]


class Engine:
    def __init__(self, video, out, use_vlm=True, repo_root=None, log=print):
        self.video = video
        self.out = out
        self.log = log
        self.repo_root = repo_root or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        os.makedirs(os.path.join(out, "evidence"), exist_ok=True)
        self.timings = Counter()
        self.vlm = None
        if use_vlm:
            key = vlmmod.load_key(self.repo_root)
            if key:
                self.vlm = vlmmod.VLM(key)
        self.pending = []           # (future, kind, payload)
        self.events = []
        self.ev_n = 0
        self.mode_hist = Counter()
        self.vlm_frames = 0
        self.ocr_calls = 0
        self.ocr_cache = {}
        self.ocr_q = deque()
        self.ocr_done = []
        from concurrent.futures import ThreadPoolExecutor
        self.ocr_pool = ThreadPoolExecutor(max_workers=6)
        self.fullrefresh_ocr = 0

    # ------------------------------------------------------------------ helpers
    def crop_save(self, frame, bbox, f, name, pad=0.01):
        H, W = frame.shape[:2]
        x, y, w, h = bbox
        x0 = int(max(0, (x - pad) * W)); y0 = int(max(0, (y - pad) * H))
        x1 = int(min(W, (x + w + pad) * W)); y1 = int(min(H, (y + h + pad) * H))
        if x1 <= x0 or y1 <= y0:
            x0, y0, x1, y1 = 0, 0, W, H
        rel = f"evidence/f{f}_{name}.jpg"
        p = os.path.join(self.out, rel)
        if not os.path.exists(p):
            Image.fromarray(frame[y0:y1, x0:x1]).save(p, "JPEG", quality=70)
        return rel

    def event(self, typ, f0, f1, conf, source, ev_f, ev_bbox, crop, **kw):
        self.ev_n += 1
        e = {"id": f"ev{self.ev_n}", "type": typ, "f_start": int(f0), "f_end": int(f1),
             "t_ms": rnd(f0 * 1000.0 / self.fps, 2)}
        e.update(kw)
        e.update({"confidence": rnd(conf, 3), "source": source,
                  "evidence": {"f": int(ev_f), "bbox": [rnd(b) for b in ev_bbox], "crop": crop}})
        self.events.append(e)
        return e

    def region_resid(self, a, b):
        d = np.abs(a - b).sum(axis=2, dtype=np.int32)
        s = np.add.reduceat(np.add.reduceat(d, self.rows[:-1], axis=0), self.cols[:-1], axis=1)
        return (s / self.cell_area).ravel()

    def box_px(self, bbox, H, W):
        x, y, w, h = bbox
        return int(max(0, x * W)), int(max(0, y * H)), int(min(W, (x + w) * W)), int(min(H, (y + h) * H))

    # ------------------------------------------------------------------ HUD / text discovery
    def discover_text(self, f, frame):
        """FULL REFRESH text discovery: tesseract on a full-res frame; returns hud/text boxes."""
        if self.fullrefresh_ocr >= 6:
            return
        self.fullrefresh_ocr += 1
        png = os.path.join(self.out, "evidence", f"_full_{f}.png")
        vid.extract_full(self.video, f / self.fps, png)
        if not os.path.exists(png):
            return
        W, H = self.info["width"], self.info["height"]
        lines = ocrmod.ocr_lines_full(png)
        try:
            os.remove(png)
        except OSError:
            pass
        huds, texts = {}, []
        for ln in lines:
            x, y, w, h = ln["box"]
            nb = [x / W, y / H, w / W, h / H]
            k = ocrmod.hud_key(ln["text"])
            vals = ocrmod.parse_hud(ln["text"])
            if k:
                vv = dict(vals).get(k)
                if k not in huds:
                    huds[k] = (nb, vv, ln["text"])
            elif sum(c.isalpha() for c in ln["text"]) >= 6 and len(ln["text"].split()) >= 2 and ln["conf"] > 60:
                texts.append((h, nb, ln["text"]))
        texts.sort(key=lambda t: -t[0])
        for name, (nb, vv, txt) in huds.items():
            # widen box to the right so growing numbers stay inside
            x0 = max(0.0, nb[0] - 0.5 * nb[2]); x1 = min(1.0, nb[0] + 1.5 * nb[2])
            nb = [x0, max(0, nb[1] - 0.008), x1 - x0, nb[3] + 0.016]
            self.hud_boxes[name] = nb
            if vv is None:
                self.revalidate_box(f, frame, name, nb, True)
                continue
            crop = self.crop_save(frame, nb, f, f"hud_{name}")
            old = self.state["hud"].get(name)
            if old and old["v"] != vv:
                self.event("ui_value_changed", f, f, 0.85, "observed", f, nb, crop, entity=f"hud.{name}",
                           **{"from": old["v"], "to": vv})
            self.state["hud"][name] = field(vv, 0.9, "observed", f, nb, crop)
        for i, (_, nb, txt) in enumerate(texts[:4]):
            x0 = max(0.0, nb[0] - 0.3 * nb[2]); x1 = min(1.0, nb[0] + 1.3 * nb[2])
            nb = [x0, max(0, nb[1] - 0.008), x1 - x0, nb[3] + 0.016]
            rid = f"t{len(self.text_boxes) + 1}"
            # reuse an existing text region if overlapping
            for k, b in self.text_boxes.items():
                if abs(b[1] - nb[1]) < 0.02 and abs(b[0] - nb[0]) < 0.05:
                    rid = k
            self.text_boxes[rid] = nb
            crop = self.crop_save(frame, nb, f, f"text_{rid}")
            self.state["text"][rid] = field(txt, 0.8, "observed", f, nb, crop)
        self.box_cells = {}
        for name, nb in list(self.hud_boxes.items()) + [("text:" + k, v) for k, v in self.text_boxes.items()]:
            for c in cells_of(nb):
                self.box_cells.setdefault(c, []).append(name)

    def box_sig(self, frame, nb):
        H, W = frame.shape[:2]
        x0, y0, x1, y1 = self.box_px(nb, H, W)
        g = frame[y0:y1, x0:x1].mean(axis=2)
        if g.size == 0:
            return None, None
        th = g > (g.max() + g.min()) / 2
        return hashlib.md5(np.packbits(th).tobytes() + str(th.shape).encode()).hexdigest(), frame[y0:y1, x0:x1]

    def revalidate_box(self, f, frame, name, nb, is_hud):
        """REVALIDATE: checksum of binarised crop; OCR (async tesseract pool) only on an unseen checksum."""
        sig, crop_arr = self.box_sig(frame, nb)
        if sig is None:
            return
        key = (name, sig)
        if key in self.ocr_cache:
            self.ocr_done.append((f, frame, name, nb, is_hud, self.ocr_cache[key]))
            return
        if self.ocr_calls > max(300, 0.1 * self.nb) or len(self.ocr_q) > 12:
            return
        self.ocr_calls += 1
        fut = self.ocr_pool.submit(ocrmod.ocr_line, crop_arr.copy(), 3)
        self.ocr_q.append((fut, key, f, frame, name, nb, is_hud))

    def poll_ocr(self, wait=False):
        while self.ocr_q and (wait or self.ocr_q[0][0].done()):
            fut, key, f0, fr0, name, nb, is_hud = self.ocr_q.popleft()
            try:
                txt = fut.result()
            except Exception:
                txt = ""
            self.ocr_cache[key] = txt
            self.ocr_done.append((f0, fr0, name, nb, is_hud, txt))
        done, self.ocr_done = self.ocr_done, []
        for f, frame, name, nb, is_hud, txt in done:
            self.apply_ocr(f, frame, name, nb, is_hud, txt)

    def apply_ocr(self, f, frame, name, nb, is_hud, txt):
        if is_hud:
            vals = [v for k, v in ocrmod.parse_hud(txt) if k == name]
            if not vals:
                return
            val = vals[0]
            old = self.state["hud"].get(name)
            if old is None or old["v"] != val:
                crop = self.crop_save(frame, nb, f, f"hud_{name}")
                if old is not None:
                    self.event("ui_value_changed", f, f, 0.85, "observed", f, nb, crop, entity=f"hud.{name}",
                               **{"from": old["v"], "to": val})
                self.state["hud"][name] = field(val, 0.9, "observed", f, nb, crop)
        else:
            txt = " ".join(txt.split())
            if sum(c.isalpha() for c in txt) < 4:
                return
            old = self.state["text"].get(name)
            if old is None or old["v"] != txt:
                crop = self.crop_save(frame, nb, f, f"text_{name}")
                if old is not None:
                    self.event("text_changed", f, f, 0.8, "observed", f, nb, crop, entity=f"text.{name}",
                               **{"from": old["v"], "to": txt})
                self.state["text"][name] = field(txt, 0.85, "observed", f, nb, crop)

    # ------------------------------------------------------------------ VLM
    def vlm_budget_ok(self, f):
        if not self.vlm:
            return False
        cap = min(int(0.05 * self.nb) - 1, 40)
        return self.vlm_frames < cap and self.vlm_frames <= 0.05 * (f + 1) + 2

    def poll_vlm(self, f, wait=False):
        keep = []
        for fut, kind, payload in self.pending:
            if not (wait or fut.done()):
                keep.append((fut, kind, payload))
                continue
            try:
                res = fut.result(timeout=60 if wait else 0)
            except Exception:
                continue
            if not isinstance(res, dict) or "error" in res:
                continue
            if kind == "scene":
                sf, crop = payload
                lab = str(res.get("scene") or "").strip()[:60]
                if lab and self.state["scene"]["id"] == self.scene_id_at.get(sf):
                    self.state["scene"]["label"] = field(lab, 0.8, "inferred", sf, [0, 0, 1, 1], crop)
            elif kind == "entity":
                tid, ef, crop, bb = payload
                t = self.tracks.get(tid)
                if t is not None:
                    t.label = str(res.get("label") or "object")[:40]
                    t.type = str(res.get("type") or t.type)[:20]
                    t.label_src, t.label_conf, t.label_f, t.label_crop = "inferred", 0.8, ef, crop
        self.pending = keep

    # ------------------------------------------------------------------ main
    def run(self):
        t0 = time.time()
        self.info = vid.probe(self.video)
        self.fps = self.info["fps"]
        self.nb = self.info["nb_frames"]
        self.log(f"STAGE capture video={os.path.basename(self.video)} nb_frames={self.nb} fps={self.fps:.2f} "
                 f"size={self.info['width']}x{self.info['height']}")
        self.state = {"scene": {"label": field("unknown", 0.3, "inferred", 0), "id": "s0"},
                      "entities": {}, "hud": {}, "text": {}}
        self.hud_boxes, self.text_boxes, self.box_cells = {}, {}, {}
        self.tracks = {}
        self.tent = []
        self.next_tid = 1
        self.scene_n = 0
        self.scene_id_at = {}
        self.reg_conf = np.ones(NREG)
        self.box_last = {}
        self.last_F = -10 ** 9
        prev_state = None
        stream = open(os.path.join(self.out, "stream.jsonl"), "w")
        buf = deque()
        gen = vid.decode(self.video, 640, self.info)
        ref = None                       # last non-flash small frame
        prev_small = None
        bg = None
        flash_until = -1
        n_written = 0
        windows = {}
        stored_bytes = 0
        hide_max = int(HIDE_FRAMES_S * self.fps)
        last_warn = {}

        def pull():
            tc = time.time()
            try:
                fr = next(gen)
            except StopIteration:
                fr = None
            self.timings["capture"] += time.time() - tc
            if fr is None:
                return False
            tc = time.time()
            sm = fr[::SUB, ::SUB].astype(np.int16)
            buf.append((fr, sm))
            self.timings["change"] += time.time() - tc
            return True

        more = True
        while len(buf) < 3 and more:
            more = pull()
        if buf:
            h, w = buf[0][1].shape[:2]
            self.rows = np.linspace(0, h, GY + 1).astype(int)
            self.cols = np.linspace(0, w, GX + 1).astype(int)
            self.cell_area = np.outer(np.diff(self.rows), np.diff(self.cols)).astype(float)
        f = -1
        while buf:
            f += 1
            frame, sm = buf[0]
            look = [b[1] for b in list(buf)[1:3]]
            H, W = frame.shape[:2]
            # ---------------------------------------------------------- change
            tc = time.time()
            is_F = False
            in_flash = f <= flash_until
            if ref is None:
                is_F = True
                resid = np.full(NREG, 999.0)
            else:
                resid = self.region_resid(sm, ref)
                gshift = float(np.abs(sm.reshape(-1, 3).mean(0) - ref.reshape(-1, 3).mean(0)).sum())
                frac = float((resid > T_FLASH).mean())
                if not in_flash and (frac >= FLASH_FRAC or gshift >= FLASH_SHIFT):
                    def back(x):
                        r = self.region_resid(x, ref)
                        gs = float(np.abs(x.reshape(-1, 3).mean(0) - ref.reshape(-1, 3).mean(0)).sum())
                        return (r > T_FLASH).mean() < RETURN_FRAC and gs < FLASH_SHIFT / 3, (r > T_FLASH).mean()
                    k = 0
                    if len(look) >= 1:
                        ok1, fr1 = back(look[0])
                        if ok1:
                            k = 1
                        elif len(look) >= 2:
                            ok2, fr2 = back(look[1])
                            if ok2:
                                k = 2
                            elif frac >= CUT_FRAC and fr1 >= CUT_FRAC and fr2 >= CUT_FRAC and f - self.last_F > 30:
                                is_F = True
                    if k:
                        flash_until = f + k - 1
                        in_flash = True
                        crop = self.crop_save(frame, [0, 0, 1, 1], f, "flash")
                        self.event("flash", f, f + k - 1, 0.9 if frac >= FLASH_FRAC else 0.7, "observed", f,
                                   [0, 0, 1, 1], crop, duration_frames=k,
                                   color=[int(c) for c in sm.reshape(-1, 3).mean(0)])
            self.timings["change"] += time.time() - tc

            # ---------------------------------------------------------- state: entities (blob tracking)
            ts = time.time()
            explained = set()
            new_cells = set()
            if is_F:
                bg = sm.astype(np.float32)
                med = vid.sample_median(self.video, f / self.fps, 10.0, sm.shape[1], sm.shape[0])
                if med is not None and med.shape == bg.shape:
                    bg = med

            elif not in_flash:
                dist = np.abs(sm.astype(np.float32) - bg).sum(axis=2)
                fg = dist > FG_T
                bl = blobs(fg)
                hh, ww = fg.shape
                dets = [np.array([b[0] / ww, b[1] / hh, (b[2] - b[0]) / ww, (b[3] - b[1]) / hh]) for b in bl
                        if (b[2] - b[0]) < 0.5 * ww and (b[3] - b[1]) < 0.5 * hh]
                # update background: fast where background, slow where foreground
                a = np.where(fg, 0.004, 0.15)[..., None].astype(np.float32)
                bg += a * (sm - bg)
                # match
                cand = []
                live = [t for t in self.tracks.values()] + self.tent
                for ti, t in enumerate(live):
                    pc = t.bbox[:2] + t.bbox[2:] / 2 + t.vel
                    for di, d in enumerate(dets):
                        dc = d[:2] + d[2:] / 2
                        dd = float(np.hypot(*(pc - dc)))
                        gate = max(0.05, 1.5 * float(np.hypot(*t.bbox[2:])))
                        if dd < gate:
                            cand.append((dd, ti, di))
                cand.sort()
                used_t, used_d = set(), set()
                for dd, ti, di in cand:
                    if ti in used_t or di in used_d:
                        continue
                    used_t.add(ti); used_d.add(di)
                    t = live[ti]
                    d = dets[di]
                    oc = t.bbox[:2] + t.bbox[2:] / 2
                    nc = d[:2] + d[2:] / 2
                    t.vel = 0.6 * t.vel + 0.4 * (nc - oc)
                    t.moved += float(np.hypot(*(nc - oc)))
                    old = t.bbox.copy()
                    t.bbox = d
                    t.last_seen = f
                    t.hits += 1
                    if t.confirmed:
                        if t.hidden_since is not None:     # re-appeared → observed again
                            t.hidden_since = None
                            t.anchor_f, t.anchor_conf = f, 0.9
                            t.crop = self.crop_save(frame, d, f, t.id)
                            t.anchor_bb = [float(v) for v in d]
                        if float(np.hypot(*(nc - oc))) > 1e-3:
                            explained.update(cells_of(old)); explained.update(cells_of(d))
                for di, d in enumerate(dets):
                    if di not in used_d:
                        t = Track(None, d, f)
                        self.tent.append(t)
                        new_cells.update(cells_of(d))
                # tentative → confirmed
                still = []
                for t in self.tent:
                    if t.last_seen == f and t.hits >= 3:
                        t.id = f"e{self.next_tid}"; self.next_tid += 1
                        t.confirmed = True
                        t.anchor_f, t.anchor_conf = f, 0.9
                        t.crop = self.crop_save(frame, t.bbox, f, t.id)
                        t.label_crop = t.crop
                        t.anchor_bb = [float(v) for v in t.bbox]
                        t.label = "moving object" if t.moved > 0.01 else "object"
                        self.tracks[t.id] = t
                        self.event("entity_created", t.first, f, 0.8, "observed", f, t.bbox, t.crop, entity=t.id)
                        new_cells.update(cells_of(t.bbox))
                        t._vlm = True  # noqa
                    elif f - t.last_seen < 3:
                        still.append(t)
                self.tent = still
                # hidden / removal
                for tid in list(self.tracks):
                    t = self.tracks[tid]
                    if t.last_seen < f:
                        if t.hidden_since is None:
                            t.hidden_since = f
                        t.bbox[:2] += t.vel * 0.5
                        t.vel *= 0.5
                        if f - t.last_seen > hide_max:
                            self.event("entity_removed", f, f, 0.7, "inferred", t.last_seen, t.bbox.tolist(),
                                       t.crop, entity=tid)
                            del self.tracks[tid]
            self.timings["state"] += time.time() - ts

            # ---------------------------------------------------------- schedule
            tsch = time.time()
            modes = ["C"] * NREG
            reinfer_regions = []
            if is_F:
                modes = ["F"] * NREG
                self.reg_conf[:] = 1.0
            else:
                for j in range(NREG):
                    r = resid[j]
                    if in_flash:
                        modes[j] = "V" if r > T_COPY else "C"
                        continue
                    if r < T_COPY:
                        self.reg_conf[j] *= DECAY_C
                        modes[j] = "C"
                        if self.reg_conf[j] < CONF_REINFER:
                            reinfer_regions.append(j)
                    elif j in self.box_cells:
                        modes[j] = "V"
                    elif j in new_cells or (r > T_BIG and j not in explained):
                        reinfer_regions.append(j)
                    elif j in explained:
                        modes[j] = "P"
                        self.reg_conf[j] *= DECAY_P
                        if self.reg_conf[j] < CONF_REINFER:
                            reinfer_regions.append(j)
                    else:
                        modes[j] = "V"
                        self.reg_conf[j] = max(self.reg_conf[j], 0.8)
                # tracks whose propagated confidence is low → re-anchor (RE-INFER) their region
                for t in self.tracks.values():
                    if t.hidden_since is None and t.anchor_conf * DECAY_P ** (f - t.anchor_f) < CONF_REINFER:
                        c = cells_of(t.bbox)[0]
                        reinfer_regions.append(c)
                        t.anchor_f, t.anchor_conf = f, 0.9
                        t.crop = self.crop_save(frame, t.bbox, f, t.id)
                        t.anchor_bb = [float(v) for v in t.bbox]
            vlm_this = False
            if is_F:
                self.last_F = f
                self.scene_n += 1
                sid = f"s{self.scene_n}"
                self.state["scene"]["id"] = sid
                self.scene_id_at[f] = sid
                crop = self.crop_save(frame, [0, 0, 1, 1], f, "scene")
                lab = self.state["scene"]["label"]["v"] if f > 0 else "unknown"
                self.state["scene"]["label"] = field(lab, 0.5, "inferred", f, [0, 0, 1, 1], crop)
                if f > 0:
                    self.event("scene_changed", f, f, 0.8, "observed", f, [0, 0, 1, 1], crop, to=sid)
                if self.vlm_budget_ok(f):
                    self.pending.append((self.vlm.submit(frame, vlmmod.SCENE_PROMPT), "scene", (f, crop)))
                    vlm_this = True
                self.discover_text(f, frame)
                for c in range(NREG):
                    self.reg_conf[c] = 1.0
            else:
                # RE-INFER: entity labels (VLM within budget) / local re-detection; else downgrade to REVALIDATE
                rset = sorted(set(reinfer_regions))
                if rset:
                    newt = [t for t in self.tracks.values() if getattr(t, "_vlm", False)]
                    budget_ok = self.vlm_budget_ok(f)
                    if newt and budget_ok:
                        t = newt[0]
                        t._vlm = False
                        x, y, w, h = t.bbox
                        pad = max(w, h)
                        cb = [max(0, x - pad), max(0, y - pad), w + 2 * pad, h + 2 * pad]
                        x0, y0, x1, y1 = self.box_px(cb, H, W)
                        self.pending.append((self.vlm.submit(frame[y0:y1, x0:x1], vlmmod.ENTITY_PROMPT),
                                             "entity", (t.id, f, t.crop, cb)))
                        vlm_this = True
                    for t in newt:
                        if not budget_ok:
                            t._vlm = False
                    # local re-infer budget: at most ~3% of region-frames
                    for j in rset:
                        if self.mode_hist["R"] < 0.03 * NREG * (f + 1) + 8:
                            modes[j] = "R"
                            self.reg_conf[j] = 0.95
                        else:
                            modes[j] = "V"
                            self.reg_conf[j] *= DECAY_P
                            if self.reg_conf[j] < 0.3 and f - last_warn.get(j, -10 ** 9) > 600:
                                last_warn[j] = f
                                rb = [(j % GX) / GX, (j // GX) / GY, 1 / GX, 1 / GY]
                                self.event("confidence_warning", f, f, float(self.reg_conf[j]), "inferred", f, rb,
                                           self.crop_save(frame, rb, f, f"r{j}"), region=j)
            if vlm_this:
                self.vlm_frames += 1
            self.timings["schedule"] += time.time() - tsch

            # ---------------------------------------------------------- state: HUD/text revalidate, fields
            ts = time.time()
            if not in_flash and not is_F and ref is not None:
                for name, nb in list(self.hud_boxes.items()) + [("text:" + k, v) for k, v in self.text_boxes.items()]:
                    x0, y0, x1, y1 = self.box_px(nb, sm.shape[0], sm.shape[1])
                    x1 = max(x1, x0 + 1); y1 = max(y1, y0 + 1)
                    cur = sm[y0:y1, x0:x1]
                    lastv = self.box_last.get(name)
                    if lastv is None or lastv.shape != cur.shape or float(np.abs(cur - lastv).mean()) > 4.0:
                        self.box_last[name] = cur.copy()
                        if name.startswith("text:"):
                            self.revalidate_box(f, frame, name[5:], nb, False)
                        else:
                            self.revalidate_box(f, frame, name, nb, True)
            self.poll_ocr()
            self.poll_vlm(f)
            ents = {}
            for t in self.tracks.values():
                bb = [float(np.clip(v, 0, 1)) for v in t.bbox]
                if t.hidden_since is None:
                    conf = t.anchor_conf * DECAY_P ** (f - t.anchor_f)
                    src = "observed" if t.anchor_f == f else "propagated"
                    vis = field(True, 0.9, "observed", t.anchor_f, t.anchor_bb, t.crop)
                else:
                    conf = 0.5 * DECAY_P ** (f - t.hidden_since)
                    src = "inferred"
                    vis = field(False, 0.5, "inferred", t.hidden_since, t.anchor_bb, t.crop)
                ents[t.id] = {"type": field(t.type, t.label_conf, t.label_src, t.label_f, t.anchor_bb, t.label_crop),
                              "label": field(t.label, t.label_conf, t.label_src, t.label_f, t.anchor_bb, t.label_crop),
                              "bbox": field(bb, conf, src, t.anchor_f, bb, t.crop),
                              "visible": vis}
            self.state["entities"] = ents
            self.timings["state"] += time.time() - ts

            # ---------------------------------------------------------- store
            tst = time.time()
            mstr = "".join(modes)
            self.mode_hist.update(mstr)
            t_ms = rnd(f * 1000.0 / self.fps, 2)
            if f % SNAP_EVERY == 0 or is_F:
                rec = {"f": f, "t_ms": t_ms, "kind": "snapshot", "modes": mstr, "state": self.state, "vlm": vlm_this}
            else:
                rec = {"f": f, "t_ms": t_ms, "kind": "delta", "modes": mstr, "delta": diff(prev_state, self.state),
                       "vlm": vlm_this}
            line = json.dumps(rec, separators=(",", ":"))
            stored_bytes += len(line) + 1
            stream.write(line + "\n")
            n_written += 1
            prev_state = copy.deepcopy(self.state)
            wi = int(f / self.fps // 10)
            win = windows.setdefault(wi, {"window": wi, "f_start": f, "t_start_s": wi * 10, "modes": Counter(),
                                          "entities": set(), "vlm_frames": 0})
            win["f_end"] = f
            win["modes"].update(mstr)
            win["entities"].update(ents.keys())
            win["vlm_frames"] += int(vlm_this)
            win["hud"] = {k: v["v"] for k, v in self.state["hud"].items()}
            win["text"] = {k: v["v"] for k, v in self.state["text"].items()}
            win["scene"] = self.state["scene"]["label"]["v"]
            self.timings["store"] += time.time() - tst

            if not in_flash:
                ref = sm
            prev_small = sm
            buf.popleft()
            if more:
                more = pull()
            if f % 600 == 0:
                self.log(f"STAGE change f={f} elapsed={time.time() - t0:.1f}s")

        # drain pending VLM results into a final state note (not re-written into stream; recorded in summary)
        late = len(self.pending)
        self.poll_ocr(wait=True)          # late OCR results still yield exact-frame events
        self.ocr_pool.shutdown(wait=False)
        stream.close()
        if self.vlm:
            self.vlm.shutdown()
        total = time.time() - t0
        tot = sum(self.mode_hist.values()) or 1
        skip = (self.mode_hist["C"] + self.mode_hist["P"] + self.mode_hist["V"]) / tot
        self.log(f"STAGE change frames={n_written} flashes={sum(e['type'] == 'flash' for e in self.events)} "
                 f"secs={self.timings['change']:.1f}")
        self.log("STAGE schedule " + " ".join(f"{m}={self.mode_hist[m]}" for m in "CPVRF") +
                 f" skip_vlm_pct={100 * skip:.1f} vlm_frames={self.vlm_frames} "
                 f"vlm_pct={100 * self.vlm_frames / max(1, n_written):.2f}")
        self.log(f"STAGE state entities={self.next_tid - 1} events={len(self.events)} hud={list(self.state['hud'])} "
                 f"ocr_calls={self.ocr_calls}")
        # events + summary + meta
        with open(os.path.join(self.out, "events.jsonl"), "w") as fh:
            for e in sorted(self.events, key=lambda e: (e["f_start"], e["id"])):
                fh.write(json.dumps(e, separators=(",", ":")) + "\n")
        wins = []
        for wi in sorted(windows):
            w = windows[wi]
            evs = [e for e in self.events if w["f_start"] <= e["f_start"] <= w["f_end"]]
            wins.append({"window": wi, "t_start_s": w["t_start_s"], "f_start": w["f_start"], "f_end": w["f_end"],
                         "scene": w["scene"], "entities_seen": sorted(w["entities"]),
                         "events": dict(Counter(e["type"] for e in evs)),
                         "hud_end": w["hud"], "text_end": w["text"], "modes": dict(w["modes"]),
                         "vlm_frames": w["vlm_frames"],
                         "highlights": [f"f{e['f_start']} {e['type']}" + (f" {e.get('entity', '')} {e.get('from', '')}→{e.get('to', '')}" if e["type"] in ("ui_value_changed", "text_changed") else "")
                                        for e in evs if e["type"] != "confidence_warning"][:20]})
        summary = {"windows": wins, "session": {
            "frames": n_written, "duration_s": rnd(n_written / self.fps, 2), "entities_total": self.next_tid - 1,
            "events": dict(Counter(e["type"] for e in self.events)), "mode_hist": dict(self.mode_hist),
            "skip_vlm_ratio": rnd(skip), "vlm_frames": self.vlm_frames,
            "final_hud": {k: v["v"] for k, v in self.state["hud"].items()}}}
        json.dump(summary, open(os.path.join(self.out, "summary.json"), "w"), indent=1)
        meta = {"video": os.path.abspath(self.video), "fps": self.fps, "nb_frames": self.nb, "frames": n_written,
                "width": self.info["width"], "height": self.info["height"], "analysis_width": 640,
                "grid": [GX, GY], "snapshot_every": SNAP_EVERY,
                "models": {"vlm": vlmmod.MODEL if self.vlm else None, "ocr": "tesseract"},
                "vlm_calls": self.vlm.calls if self.vlm else 0, "vlm_errors": self.vlm.errors if self.vlm else 0,
                "vlm_frames": self.vlm_frames, "vlm_pending_dropped": late, "ocr_calls": self.ocr_calls,
                "mode_hist": dict(self.mode_hist), "skip_vlm_ratio": rnd(skip),
                "stage_timings_s": {k: rnd(v, 2) for k, v in self.timings.items()}, "total_s": rnd(total, 2),
                "stored_bytes": stored_bytes}
        json.dump(meta, open(os.path.join(self.out, "meta.json"), "w"), indent=1)
        self.log(f"STAGE store frames={n_written} nb_frames={self.nb} match={n_written == self.nb} "
                 f"bytes={stored_bytes} events={len(self.events)} secs={total:.1f} out={self.out}")
        return meta
