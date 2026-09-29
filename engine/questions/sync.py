"""EVAL ONLY (never imported by the engine): map video frame -> game frame (gf) by decoding the
16-bit sync barcode drawn top-left by testgame/index.html. Uses testgame/decode_sync.py if present.
"""
import json
import os
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _probe(video):
    r = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_packets", "-show_entries",
                        "stream=width,height,nb_frames,nb_read_packets,r_frame_rate", "-of", "json", video],
                       capture_output=True, text=True)
    s = json.loads(r.stdout)["streams"][0]
    return s


def _frame0(video, W, H):
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                       capture_output=True)
    return np.frombuffer(r.stdout, np.uint8)[: W * H * 3].reshape(H, W, 3)


def locate(img):
    """Find gray (#808080) barcode strip in the top-left area. Returns (x0, y0, scale)."""
    H, W, _ = img.shape
    sub = img[: H // 4, : W // 3].astype(int)
    m = (np.abs(sub - 128).max(axis=2) <= 10)
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        raise RuntimeError("barcode not found")
    # the strip: rows with many gray pixels
    rows = np.bincount(ys, minlength=sub.shape[0])
    good = np.nonzero(rows >= 6)[0]
    y0, y1 = good.min(), good.max()
    cols = np.bincount(xs[(ys >= y0) & (ys <= y1)], minlength=sub.shape[1])
    goodc = np.nonzero(cols >= 2)[0]
    x0, x1 = goodc.min(), goodc.max()
    scale = (x1 - x0 + 1) / 200.0
    return int(x0), int(y0), scale


def decode_video(video):
    dec = os.path.join(ROOT, "testgame", "decode_sync.py")
    if False and os.path.exists(dec):  # decode_sync.py is per-frame CLI (slow); same geometry used below
        try:
            sys.path.insert(0, os.path.dirname(dec))
            import decode_sync  # type: ignore
            for name in ("decode_video", "decode", "map_video", "main_map"):
                fn = getattr(decode_sync, name, None)
                if fn:
                    out = fn(video)
                    if isinstance(out, dict):
                        out = [out[k] for k in sorted(out)]
                    return list(out)
        except Exception as e:
            print(f"decode_sync.py failed ({e}); using built-in decoder", file=sys.stderr)
    p = _probe(video)
    W, H = int(p["width"]), int(p["height"])
    # canvas is 1280 px wide scaled to video width; it may sit below a window title bar -> find y offset
    s = W / 1280.0
    img = _frame0(video, W, H).astype(int)
    bw = int(196 * s)
    def grayrow(y):
        return (np.abs(img[y, :bw] - 128).max(axis=1) <= 12).mean() >= 0.9
    y0 = None
    for y in range(0, min(H - int(20 * s), 81)):
        if grayrow(y) and grayrow(y + int(17 * s)) and not grayrow(y + int(10 * s)):
            y0 = y
            break
    if y0 is None:
        raise RuntimeError("sync barcode not found in top 80 px")
    x0 = 0
    print(f"sync: barcode at y0={y0} scale={s:.3f}", file=sys.stderr)
    cw, ch = int(200 * s) + 2, int(20 * s) + 2
    cw += cw % 2
    ch += ch % 2
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", video, "-vf", f"crop={cw}:{ch}:{x0}:{y0}", "-f", "rawvideo",
                        "-pix_fmt", "gray", "-"], capture_output=True)
    buf = np.frombuffer(r.stdout, np.uint8)
    n = len(buf) // (cw * ch)
    fr = buf[: n * cw * ch].reshape(n, ch, cw).astype(int)
    cy = int(round(10 * s))
    out = []
    for k in range(n):
        v = 0
        for i in range(16):
            cx = int(round((4 + i * 12 + 6) * s))
            patch = fr[k, max(0, cy - 2): cy + 3, max(0, cx - 2): cx + 3]
            v = (v << 1) | int(patch.mean() > 128)
        out.append(v)
    return out


def clean(gfs):
    """Fix isolated decode glitches: enforce non-decreasing sequence using neighbours."""
    g = list(gfs)
    for i in range(1, len(g) - 1):
        if not (g[i - 1] <= g[i] <= g[i + 1]) and g[i - 1] <= g[i + 1] and g[i + 1] - g[i - 1] <= 8:
            g[i] = g[i - 1]
    return g


if __name__ == "__main__":
    g = clean(decode_video(sys.argv[1]))
    print(len(g), g[:20], g[-5:])
