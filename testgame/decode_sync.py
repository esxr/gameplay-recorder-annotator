#!/usr/bin/env python3
"""decode_sync.py <mp4> <frame_idx> [more frame_idx...]

Decodes the test game's 16-bit sync barcode (top-left, 16 squares of 12x12 canvas px at x=4+12*i, y=4,
MSB first, white=1). Assumes the video is a crop of exactly the 1280x720 canvas (any scale).
Prints "<frame_idx> <gf>" (gf=-1 if the barcode is unreadable). Stdlib only (ffmpeg via subprocess).
"""
import json
import subprocess
import sys


def probe(mp4):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height", "-of", "json", mp4], capture_output=True, text=True, check=True)
    s = json.loads(out.stdout)["streams"][0]
    return s["width"], s["height"]


def read_frame(mp4, n, w, h):
    cmd = ["ffmpeg", "-v", "error", "-i", mp4, "-vf", f"select=eq(n\\,{n})", "-fps_mode", "passthrough",
           "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return raw if len(raw) == w * h * 3 else None


def decode(raw, w, h):
    sx, sy = w / 1280.0, h / 720.0
    bits = 0
    for i in range(16):
        cx, cy = (4 + 12 * i + 6) * sx, (4 + 6) * sy
        tot = 0
        for dx in (-2, 0, 2):  # small 3x3 average around the square centre
            for dy in (-2, 0, 2):
                x, y = int(cx + dx * sx), int(cy + dy * sy)
                o = (y * w + x) * 3
                tot += raw[o] + raw[o + 1] + raw[o + 2]
        lum = tot / 27.0
        if 70 < lum < 185:  # mid-grey -> not a barcode (e.g. loading/offset)
            return -1
        bits = (bits << 1) | (1 if lum >= 128 else 0)
    return bits


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    mp4 = sys.argv[1]
    w, h = probe(mp4)
    for a in sys.argv[2:]:
        n = int(a)
        raw = read_frame(mp4, n, w, h)
        print(n, decode(raw, w, h) if raw else -1)


if __name__ == "__main__":
    main()
