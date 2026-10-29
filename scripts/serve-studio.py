#!/usr/bin/env python3
"""Serves the Studio curation tools to Roblox Studio on this machine.

    python -I scripts/serve-studio.py [--port 8765]

Serves scripts/studio/ on 127.0.0.1 so a Studio command-bar one-liner can fetch mode.txt, then
lineup.lua or camera.lua, and lineup.lua can fetch pairs.json. A POST to /log appends its body to
scripts/studio/log.txt, which is where those scripts leave their report. The one-liner and the
rest of the workflow are in scripts/studio/README.md.

The server listens on the loopback address only, so nothing outside this machine can reach it. The
scripts in scripts/studio/ call port 8765, so change them too if you pass a different --port. It
refuses to start when the port is already taken. mode.txt, pairs.json and log.txt are local to each
run and git-ignored. Stop the server with Ctrl+C.
"""

import argparse
import functools
import http.server
import os
import sys

FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "studio")
LOG = os.path.join(FOLDER, "log.txt")
HOST = "127.0.0.1"
DEFAULT_PORT = 8765
# The most a /log body may be (bytes): a report is a few kilobytes.
MAX_LOG_BYTES = 1024 * 1024


class Server(http.server.ThreadingHTTPServer):
    # http.server turns address reuse on, and on Windows that lets a second server bind a port that
    # is already in use, so either copy might answer. Off, the second one fails to start.
    allow_reuse_address = False


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/log":
            self.send_error(404)
            return
        raw = self.headers.get("Content-Length", "0")
        if not (raw.isascii() and raw.isdigit()) or int(raw) > MAX_LOG_BYTES:
            self.send_error(400, "Bad or oversized Content-Length")
            return
        body = self.rfile.read(int(raw))
        with open(LOG, "ab") as f:
            f.write(body + b"\n---\n")
        self.send_response(200)
        self.send_header("Content-Length", "2")
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):
        # One line per request would bury the report, and the report is what matters.
        pass


def main():
    parser = argparse.ArgumentParser(description="Serve scripts/studio/ for the Studio command bar.")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"port to listen on (default {DEFAULT_PORT})")
    args = parser.parse_args()
    handler = functools.partial(Handler, directory=FOLDER)
    try:
        server = Server((HOST, args.port), handler)
    except OSError as error:
        print(f"Port {args.port} is already in use. Is another copy of this server running?", file=sys.stderr)
        print(f"({error})", file=sys.stderr)
        sys.exit(1)
    print(f"Serving {FOLDER} on http://{HOST}:{server.server_address[1]}/ (Ctrl+C to stop)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
