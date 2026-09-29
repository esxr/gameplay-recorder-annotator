#!/usr/bin/env python3
"""Test-game server (stdlib only). Port 8777.

GET  /            -> index.html
GET  /state       -> {"go": bool}  (polled by the game; game starts when go becomes true)
GET  /start       -> truncate out/truth.jsonl and let the game start
GET  /reset       -> truncate out/truth.jsonl, go=false
POST /truth       -> append newline-separated JSON records to out/truth.jsonl
POST /geo         -> page geometry (screenX/screenY/outer/inner sizes)
GET  /done        -> game signals it has finished
GET  /status      -> {"go","done","geo","lines","skipped"}
"""
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
TRUTH = os.path.join(OUT, "truth.jsonl")
os.makedirs(OUT, exist_ok=True)
lock = threading.Lock()
state = {"go": False, "done": False, "geo": None, "lines": 0, "skipped": None}


def truncate():
    with lock:
        open(TRUTH, "w").close()
        state["lines"] = 0
        state["done"] = False


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body)
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        p = u.path
        if p in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as f:
                return self._send(200, f.read(), "text/html; charset=utf-8")
        if p == "/state":
            return self._send(200, {"go": state["go"]})
        if p == "/start":
            truncate()
            state["go"] = True
            return self._send(200, {"ok": True})
        if p == "/reset":
            truncate()
            state["go"] = False
            return self._send(200, {"ok": True})
        if p == "/done":
            state["done"] = True
            q = parse_qs(u.query)
            state["skipped"] = int(q.get("skipped", ["0"])[0])
            return self._send(200, {"ok": True})
        if p == "/status":
            return self._send(200, state)
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        p = urlparse(self.path).path
        n = int(self.headers.get("Content-Length") or 0)
        data = self.rfile.read(n).decode("utf-8", "replace")
        if p == "/truth":
            lines = [l for l in data.split("\n") if l.strip()]
            with lock:
                with open(TRUTH, "a") as f:
                    for l in lines:
                        f.write(l + "\n")
                state["lines"] += len(lines)
            return self._send(200, {"ok": True, "n": len(lines)})
        if p == "/geo":
            try:
                state["geo"] = json.loads(data)
            except Exception:
                pass
            return self._send(200, {"ok": True})
        return self._send(404, {"error": "not found"})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8777"))
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
