"""Test sink for load/chaos runs. POST anything -> 200 (or 500 with probability FAIL_RATE).
GET /stats -> {"total": N, "unique": distinct webhook-id values}. Env: PORT, FAIL_RATE, LATENCY_MS. Proves delivery counts: with
at-least-once delivery, unique must equal events sent (total >= unique shows retries/duplicates)."""
import json, os, random, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

FAIL_RATE = float(os.getenv("FAIL_RATE", "0"))
PORT = int(os.getenv("PORT", "9000"))
LATENCY_MS = float(os.getenv("LATENCY_MS", "0"))   # artificial response delay
lock = threading.Lock()
total, seen = 0, set()

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        with lock: body = json.dumps({"total": total, "unique": len(seen)}).encode()
        self.send_response(200); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        global total
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if LATENCY_MS: time.sleep(LATENCY_MS / 1000)
        with lock:
            total += 1
            fail = random.random() < FAIL_RATE
            if not fail: seen.add(self.headers.get("webhook-id"))
        self.send_response(500 if fail else 200); self.send_header("Content-Length", "0"); self.end_headers()

ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
