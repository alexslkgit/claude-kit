#!/usr/bin/env python3
"""Static server for ~/Tasks on port 8899, plus one write endpoint.

Everything it serves is exactly what `python3 -m http.server` served before. The one addition is
POST /messages/edit, which appends one JSON line to ~/Tasks/messages/edits.jsonl.

Why a write endpoint exists at all: he rewrites almost every draft before sending it, and until
2026-09-17 those rewrites lived only in the Slack composer, so no session ever saw them and the
same defects came back the next day. The page now lets him edit a card in place; the edit lands in
edits.jsonl, and the draft-message skill reads that file and turns the pattern into a rule.

Only loopback clients may POST, and only that one path. Nothing else on the page writes anything.

usage: tasks-server.py <port> <directory>
"""
import ipaddress
import json
import os
import sys
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import socket

MAX_BODY = 64 * 1024
EDITS = 'messages/edits.jsonl'


class Handler(SimpleHTTPRequestHandler):
    def _loopback(self):
        try:
            return ipaddress.ip_address(self.client_address[0].split('%')[0]).is_loopback
        except ValueError:
            return False

    def do_POST(self):
        if self.path.rstrip('/') != '/messages/edit' or not self._loopback():
            self.send_error(404)
            return
        try:
            length = int(self.headers.get('Content-Length', 0))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY:
            self.send_error(413)
            return
        try:
            payload = json.loads(self.rfile.read(length).decode('utf-8'))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self.send_error(400)
            return
        if not isinstance(payload, dict):
            self.send_error(400)
            return
        payload['at'] = time.strftime('%Y-%m-%d %H:%M:%S')
        path = os.path.join(os.getcwd(), EDITS)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'a', encoding='utf-8') as fh:
            fh.write(json.dumps(payload, ensure_ascii=False) + '\n')
        body = b'{"ok":true}'
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        if self.command == 'POST':
            super().log_message(fmt, *args)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8899
    directory = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser('~/Tasks')
    os.chdir(directory)
    ThreadingHTTPServer.address_family = socket.AF_INET6
    ThreadingHTTPServer.allow_reuse_address = True
    server = ThreadingHTTPServer(('::', port), partial(Handler, directory=directory))
    server.serve_forever()


if __name__ == '__main__':
    main()
