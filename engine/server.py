"""HTTP front for engine/api.py (stdlib). GET /<op>?session=<dir>&..., POST /ask {session, question}.
Run: .venv/bin/python engine/server.py [--port 8765]
"""
import json
import os
import sys
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from engine import api  # noqa: E402

PARAMS = {
    "get_state": ["f"], "get_changes": ["f0", "f1"], "get_entity_history": ["entity_id"],
    "get_events": ["f0", "f1", "type"], "search_semantics": ["query"], "get_evidence": ["annotation_id"],
    "compile_context": ["query", "token_budget"], "reanalyze": ["f0", "f1", "region", "fidelity"],
}
ALIASES = {"frame": "f", "start": "f0", "end": "f1", "q": "query", "id": "annotation_id", "entity": "entity_id",
           "budget": "token_budget", "filter": "type"}


class H(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        body = json.dumps(obj, default=str).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self._send(204, {})

    def do_GET(self):
        u = urlparse(self.path)
        op = u.path.strip("/")
        q = {ALIASES.get(k, k): v[0] for k, v in parse_qs(u.query).items()}
        if op in ("", "health"):
            return self._send(200, {"ok": True, "ops": list(PARAMS) + ["ask"]})
        if op == "ask":
            return self._ask(q)
        if op not in PARAMS:
            return self._send(404, {"error": f"unknown op {op}"})
        sess = q.get("session")
        if not sess or not os.path.isdir(sess):
            return self._send(400, {"error": "session=<dir> required"})
        try:
            kw = {k: q[k] for k in PARAMS[op] if k in q}
            return self._send(200, api.OPS[op](sess, **kw))
        except Exception as e:
            return self._send(500, {"error": f"{type(e).__name__}: {e}", "trace": traceback.format_exc()[-800:]})

    def do_POST(self):
        u = urlparse(self.path)
        n = int(self.headers.get("Content-Length") or 0)
        try:
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            body = {}
        if u.path.strip("/") != "ask":
            return self._send(404, {"error": "POST only /ask"})
        return self._ask(body)

    def _ask(self, b):
        sess, qu = b.get("session"), b.get("question")
        if not sess or not qu or not os.path.isdir(sess):
            return self._send(400, {"error": "session and question required"})
        try:
            return self._send(200, api.ask(sess, qu, int(b.get("token_budget", 4000))))
        except Exception as e:
            return self._send(500, {"error": f"{type(e).__name__}: {e}"})

    def log_message(self, fmt, *args):
        sys.stderr.write("server " + (fmt % args) + "\n")


def main():
    port = 8765
    if "--port" in sys.argv:
        port = int(sys.argv[sys.argv.index("--port") + 1])
    srv = ThreadingHTTPServer(("127.0.0.1", port), H)
    print(f"engine server on http://127.0.0.1:{port}", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
