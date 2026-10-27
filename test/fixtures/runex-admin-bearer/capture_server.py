"""Header-capture HTTP stub for test/validate-runex-admin-bearer.nu.

Records, per request: method, path, every Authorization header value, and the
multipart form field names. Appends one JSON line per request to argv[2].
Binds 127.0.0.1 on an ephemeral port and writes the port to argv[1].
"""
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT_FILE, LOG_FILE = sys.argv[1], sys.argv[2]


class H(BaseHTTPRequestHandler):
    def _handle(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else b""
        fields = re.findall(rb'Content-Disposition: form-data; name="([^"]+)"', body)
        rec = {
            "method": self.command,
            "path": self.path,
            "auth": self.headers.get_all("Authorization") or [],
            "fields": [f.decode() for f in fields],
        }
        with open(LOG_FILE, "a") as fh:
            fh.write(json.dumps(rec) + "\n")
        out = b"{}"
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    do_GET = _handle
    do_POST = _handle

    def log_message(self, *a):
        pass


srv = HTTPServer(("127.0.0.1", 0), H)
with open(PORT_FILE, "w") as fh:
    fh.write(str(srv.server_address[1]))
srv.serve_forever()
