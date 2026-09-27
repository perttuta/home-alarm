#!/usr/bin/env python3
"""Mock camera and Telegram API for testing home-alarm without real services.

Serves:
  * camera snapshot:      GET /cgi-bin/api.cgi?cmd=Snap...  -> a tiny image
  * Telegram sendDocument: POST /bot<token>/sendDocument    -> {"ok": true}
  * Telegram sendMessage:  GET/POST /bot<token>/sendMessage -> {"ok": true}

Every request is logged to stdout so `docker compose logs mock` shows the
exact requests made by the alarm scripts.
"""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# 1x1 transparent PNG used as the "camera snapshot" during tests
SNAPSHOT = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"
    "0000000d49444154789c6360f8cfc0500f00050a0180ad93a7e90000000049454e"
    "44ae426082"
)

BOT_ROUTES = {
    "sendDocument": (b"photo document", None),
    "sendMessage": (None, "message sent"),
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[mock] {self.command} {self.path}", flush=True)

    def _read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            return self.rfile.read(length)
        return b""

    def _telegram_reply(self, path):
        m = re.match(r"^/bot[^/]+/(\w+)", path)
        if not m:
            return None
        route = BOT_ROUTES.get(m.group(1))
        if not route:
            return None
        photo_upload, text = route
        body = self._read_body()
        if photo_upload:
            # curl -F document=@file sends multipart/form-data
            print(f"[mock] telegram sendDocument received {len(body)} bytes", flush=True)
        else:
            print(f"[mock] telegram sendMessage: {body.decode(errors='replace')[:200]}", flush=True)
        return json.dumps({"ok": True, "result": {"message_id": 1, "text": text}}).encode()

    def do_GET(self):
        if self.path.startswith("/cgi-bin/api.cgi") and "cmd=Snap" in self.path:
            print("[mock] camera snapshot requested", flush=True)
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(SNAPSHOT)))
            self.end_headers()
            self.wfile.write(SNAPSHOT)
            return
        reply = self._telegram_reply(self.path)
        if reply is not None:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(reply)))
            self.end_headers()
            self.wfile.write(reply)
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        reply = self._telegram_reply(self.path)
        if reply is not None:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(reply)))
            self.end_headers()
            self.wfile.write(reply)
            return
        self.send_response(404)
        self.end_headers()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    print(f"[mock] listening on :{port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()