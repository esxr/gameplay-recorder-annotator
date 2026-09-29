import json,sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def _s(self,o):
        b=json.dumps(o).encode(); self.send_response(200); self.send_header("Content-Type","application/json"); self.end_headers(); self.wfile.write(b)
    def do_GET(self): self._s({"ok":True})
    def do_POST(self):
        n=int(self.headers.get("Content-Length",0)); b=json.loads(self.rfile.read(n))
        self._s({"answer":f"(mock) Health first dropped from 100 to 90 at frame 200 (t=3.33 s); a hit flash preceded it at frame 130. session={b['session'].split('/')[-1]}","context_tokens":1873,"evidence":[{"f":130,"crop":"evidence/f130_e0.jpg"},{"f":200,"crop":"evidence/f200_e1.jpg"}]})
ThreadingHTTPServer(("127.0.0.1",int(sys.argv[1])),H).serve_forever()
