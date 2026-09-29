"""Tesseract CLI wrapper (cheap REVALIDATE / full-res RE-INFER of text)."""
import io
import re
import subprocess
import numpy as np
from PIL import Image

WL = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789:/ "
HUD_KEYS = ["health", "hp", "ammo", "score", "lives", "life", "time", "level", "gold", "coins", "kills", "shield", "armor"]


def _png(arr, scale=1):
    im = Image.fromarray(arr)
    if scale != 1:
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.BICUBIC)
    im = im.convert("L")
    b = io.BytesIO()
    im.save(b, "PNG")
    return b.getvalue()


def ocr_line(arr, scale=3, whitelist=None):
    if arr.size == 0:
        return ""
    cmd = ["tesseract", "stdin", "stdout", "--psm", "7"]
    if whitelist:
        cmd += ["-c", f"tessedit_char_whitelist={whitelist}"]
    try:
        r = subprocess.run(cmd, input=_png(arr, scale), capture_output=True, timeout=10)
        return r.stdout.decode("utf-8", "ignore").strip()
    except Exception:
        return ""


def _tsv(png_bytes, psm):
    try:
        r = subprocess.run(["tesseract", "stdin", "stdout", "--psm", str(psm), "tsv"], input=png_bytes,
                           capture_output=True, timeout=60)
        return r.stdout.decode("utf-8", "ignore").splitlines()[1:]
    except Exception:
        return []


def ocr_lines_full(png_path):
    """Full-frame tesseract TSV (psm 11 + psm 3, gray, upscaled if small) → lines {text, box px, conf}."""
    im = Image.open(png_path).convert("L")
    sc = 2.0 if im.width < 2000 else 1.0
    if sc != 1.0:
        im = im.resize((int(im.width * sc), int(im.height * sc)), Image.BICUBIC)
    b = io.BytesIO(); im.save(b, "PNG"); pb = b.getvalue()
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(2) as ex:
        rows = sum(ex.map(lambda ps: _tsv(pb, ps), [11, 3]), [])
    words = []
    seen = set()
    for row in rows:
        c = row.split("\t")
        if len(c) < 12 or not c[11].strip():
            continue
        try:
            conf = float(c[10])
        except ValueError:
            continue
        if conf < 40:
            continue
        x, y, w, h = (int(int(v) / sc) for v in c[6:10])
        kk = (c[11].strip(), x // 8, y // 8)
        if kk in seen:
            continue
        seen.add(kk)
        words.append({"t": c[11].strip(), "x": x, "y": y, "w": w, "h": h, "conf": conf})
    # group words into lines by vertical overlap and horizontal proximity
    words.sort(key=lambda w: (w["y"], w["x"]))
    lines = []
    for w in words:
        placed = False
        for ln in lines:
            cy = w["y"] + w["h"] / 2
            if ln["y0"] <= cy <= ln["y1"] and w["x"] - ln["x1"] < 3.0 * max(w["h"], ln["y1"] - ln["y0"]):
                ln["words"].append(w)
                ln["x1"] = max(ln["x1"], w["x"] + w["w"])
                ln["y0"] = min(ln["y0"], w["y"]); ln["y1"] = max(ln["y1"], w["y"] + w["h"])
                placed = True
                break
        if not placed:
            lines.append({"words": [w], "x0": w["x"], "x1": w["x"] + w["w"], "y0": w["y"], "y1": w["y"] + w["h"]})
    out = []
    for ln in lines:
        ln["words"].sort(key=lambda w: w["x"])
        x0 = min(w["x"] for w in ln["words"])
        out.append({"text": " ".join(w["t"] for w in ln["words"]),
                    "box": [x0, ln["y0"], ln["x1"] - x0, ln["y1"] - ln["y0"]],
                    "conf": float(np.mean([w["conf"] for w in ln["words"]]))})
    return out


NUM_RE = re.compile(r"-?\d+")


def parse_hud(text):
    """'HEALTH: 87' → ('health', 87); returns list of (key, int)."""
    t = text.lower().replace("|", " ").replace(":", " ")
    t = re.sub(r"(?<=[\s\d])[o@](?=[\d\s]|$)", "0", t)
    res = []
    toks = re.findall(r"[a-z]+|-?\d+", t)
    for i, tok in enumerate(toks):
        if tok in HUD_KEYS:
            for nxt in toks[i + 1:i + 3]:
                if NUM_RE.fullmatch(nxt):
                    res.append(("health" if tok == "hp" else tok, int(nxt)))
                    break
    return res


def hud_key(text):
    t = text.lower()
    for k in HUD_KEYS:
        if re.search(r"\b" + k + r"\b", t):
            return "health" if k == "hp" else k
    return None


def ocr_line_robust(arr, whitelist=None, attempt=0):
    """Pad + multi-scale vote: two reads (scales 4, 3) must agree; otherwise majority over 5 scales.
    Two identical independent reads are required before a value is trusted."""
    if arr.size == 0:
        return ""
    pad = np.pad(arr, ((6, 6), (8, 8), (0, 0)), mode="edge")
    if attempt % 2 == 1:                       # retry: invert (dark text on light) for a different binarisation
        pad = 255 - pad
    reads = [ocr_line(pad, 4, whitelist), ocr_line(pad, 3, whitelist)]
    if reads[0] == reads[1]:
        return reads[0]
    for sc in (5, 2.5, 3.5):
        reads.append(ocr_line(pad, sc, whitelist))
    from collections import Counter
    best, n = Counter(r for r in reads if r).most_common(1)[0] if any(reads) else ("", 0)
    return best if n >= 2 else ""


def ocr_line_confirm(arr, whitelist=None, attempt=0):
    """Independent confirmation read (different scales/padding than ocr_line_robust)."""
    if arr.size == 0:
        return ""
    pad = np.pad(arr, ((10, 10), (12, 12), (0, 0)), mode="edge")
    a = ocr_line(pad, 5, whitelist)
    b = ocr_line(pad, 2.5, whitelist)
    if a == b:
        return a
    c = ocr_line(pad, 3.5, whitelist)
    return c if c in (a, b) else a
