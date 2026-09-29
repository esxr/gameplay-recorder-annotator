"""Video probing and decoding via ffmpeg/ffprobe subprocess pipes (stdlib + numpy only)."""
import json
import subprocess
import numpy as np


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_packets",
         "-show_entries", "stream=width,height,nb_frames,nb_read_packets,r_frame_rate,avg_frame_rate,duration",
         "-of", "json", path], capture_output=True, text=True, check=True).stdout
    s = json.loads(out)["streams"][0]
    num, den = (s.get("avg_frame_rate") or s.get("r_frame_rate") or "60/1").split("/")
    fps = float(num) / float(den) if float(den) else 60.0
    nb = s.get("nb_frames")
    try:
        nb = int(nb)
    except (TypeError, ValueError):
        nb = int(s.get("nb_read_packets") or 0)
    return {"width": int(s["width"]), "height": int(s["height"]), "fps": fps, "nb_frames": nb}


def decode(path, width=640, info=None):
    """Yield every decoded frame as HxWx3 uint8 at `width` (no frame dropping)."""
    info = info or probe(path)
    h = int(round(info["height"] * width / info["width"] / 2.0)) * 2
    p = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-nostdin", "-i", path, "-vf", f"scale={width}:{h}",
         "-vsync", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE, bufsize=10 ** 7)
    size = width * h * 3
    try:
        while True:
            buf = p.stdout.read(size)
            if len(buf) < size:
                break
            yield np.frombuffer(buf, np.uint8).reshape(h, width, 3)
    finally:
        p.stdout.close()
        p.wait()


def extract_full(path, t_sec, out_png):
    """Extract one full-resolution frame (used only for FULL REFRESH text detection)."""
    subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-y", "-ss", f"{max(0.0, t_sec):.4f}", "-i", path,
                    "-frames:v", "1", out_png], check=False)
    return out_png
