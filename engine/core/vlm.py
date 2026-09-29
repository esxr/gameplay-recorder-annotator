"""Claude haiku VLM client (urllib, small JPEG crops, ≤4 concurrent). Used only for RE-INFER / FULL REFRESH."""
import base64
import io
import json
import os
import re
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

MODEL = "claude-haiku-4-5-20251001"


def load_key(repo_root):
    k = os.environ.get("ANTHROPIC_API_KEY")
    if k:
        return k
    p = os.path.join(repo_root, ".secrets", "anthropic.env")
    try:
        for line in open(p):
            if line.strip().startswith("ANTHROPIC_API_KEY"):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    return None


def jpeg_bytes(arr, max_side=512, q=60):
    im = Image.fromarray(arr)
    s = max(im.width, im.height)
    if s > max_side:
        r = max_side / s
        im = im.resize((max(1, int(im.width * r)), max(1, int(im.height * r))), Image.BILINEAR)
    b = io.BytesIO()
    im.save(b, "JPEG", quality=q)
    return b.getvalue()


class VLM:
    def __init__(self, key, workers=4, timeout=25):
        self.key = key
        self.pool = ThreadPoolExecutor(max_workers=workers)
        self.timeout = timeout
        self.calls = 0
        self.errors = 0
        self.bytes_sent = 0

    def _call(self, jpg, prompt):
        body = json.dumps({
            "model": MODEL, "max_tokens": 200,
            "messages": [{"role": "user", "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg",
                                             "data": base64.b64encode(jpg).decode()}},
                {"type": "text", "text": prompt}]}]}).encode()
        self.bytes_sent += len(body)
        req = urllib.request.Request("https://api.anthropic.com/v1/messages", data=body, headers={
            "x-api-key": self.key, "anthropic-version": "2023-06-01", "content-type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as r:
                resp = json.loads(r.read())
            text = "".join(c.get("text", "") for c in resp.get("content", []))
            m = re.search(r"\{.*\}", text, re.S)
            return json.loads(m.group(0)) if m else {"raw": text[:200]}
        except Exception as e:  # never log the key
            self.errors += 1
            return {"error": type(e).__name__}

    def submit(self, arr, prompt):
        self.calls += 1
        return self.pool.submit(self._call, jpeg_bytes(arr), prompt)

    def shutdown(self):
        self.pool.shutdown(wait=False, cancel_futures=True)


SCENE_PROMPT = ("This is a frame from a video game screen recording. Reply ONLY compact JSON: "
                "{\"scene\": \"<2-5 word scene label>\", \"entities\": [\"<short labels of visible characters/objects>\"]}")
ENTITY_PROMPT = ("This crop (centered) shows one object from a video game frame. Reply ONLY compact JSON: "
                 "{\"label\": \"<1-3 word label, e.g. red enemy, player ship, coin>\", \"type\": \"enemy|player|item|projectile|ui|other\"}")
