"""Tesseract CLI wrapper (cheap REVALIDATE / full-res RE-INFER of text)."""
import io
import re
import subprocess
import numpy as np
from PIL import Image

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


def ocr_lines_full(png_path):
    """Full-frame tesseract TSV → list of lines {text, box:[x,y,w,h] px, conf, words}."""
    try:
        r = subprocess.run(["tesseract", png_path, "stdout", "--psm", "11", "tsv"], capture_output=True, timeout=60)
    except Exception:
        return []
    rows = r.stdout.decode("utf-8", "ignore").splitlines()
    words = []
    for row in rows[1:]:
        c = row.split("\t")
        if len(c) < 12 or not c[11].strip():
            continue
        try:
            conf = float(c[10])
        except ValueError:
            continue
        if conf < 40:
            continue
        x, y, w, h = map(int, c[6:10])
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
