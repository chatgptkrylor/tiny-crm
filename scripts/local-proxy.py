#!/usr/bin/env python3
"""Bind Tiny CRM to :5174 (localhost + Tailscale) and proxy to the IIS guest."""
from __future__ import annotations

import argparse
import http.client
import http.server
import sys
from typing import Mapping

HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "proxy-connection",
}


class ShopProxy(http.server.BaseHTTPRequestHandler):
    upstream_host = "192.168.122.226"
    upstream_port = 80

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def do_GET(self) -> None:
        self._proxy()

    def do_POST(self) -> None:
        self._proxy()

    def do_HEAD(self) -> None:
        self._proxy()

    def do_PUT(self) -> None:
        self._proxy()

    def do_DELETE(self) -> None:
        self._proxy()

    def do_PATCH(self) -> None:
        self._proxy()

    def do_OPTIONS(self) -> None:
        self._proxy()

    def _proxy(self) -> None:
        if self.path in ("/", ""):
            self.send_response(302)
            self.send_header("Location", "/Shop")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0") or 0)
        body = self.rfile.read(length) if length > 0 else None
        headers = self._forward_headers(self.headers)

        conn = http.client.HTTPConnection(self.upstream_host, self.upstream_port, timeout=30)
        try:
            conn.request(self.command, self.path, body=body, headers=headers)
            resp = conn.getresponse()
            payload = resp.read()
            self.send_response(resp.status, resp.reason)
            for key, value in resp.getheaders():
                if key.lower() in HOP_BY_HOP:
                    continue
                if key.lower() == "location":
                    value = self._rewrite_location(value)
                self.send_header(key, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(payload)
        finally:
            conn.close()

    def _forward_headers(self, incoming: Mapping[str, str]) -> dict[str, str]:
        out: dict[str, str] = {}
        for key, value in incoming.items():
            if key.lower() in HOP_BY_HOP or key.lower() == "host":
                continue
            out[key] = value
        out["Host"] = f"{self.upstream_host}:{self.upstream_port}" if self.upstream_port != 80 else self.upstream_host
        out["X-Forwarded-Host"] = self.headers.get("Host", "localhost:5174")
        out["X-Forwarded-Proto"] = "http"
        out["Connection"] = "close"
        return out

    def _public_origin(self) -> str:
        host = self.headers.get("Host") or f"localhost:{self.server.server_address[1]}"
        return f"http://{host}"

    def _rewrite_location(self, value: str) -> str:
        guest = f"http://{self.upstream_host}"
        if self.upstream_port != 80:
            guest = f"http://{self.upstream_host}:{self.upstream_port}"
        if value.startswith(guest):
            return self._public_origin() + value[len(guest) :]
        return value


def main() -> int:
    parser = argparse.ArgumentParser(description="Localhost proxy for Tiny CRM")
    parser.add_argument("--listen-host", default="0.0.0.0")
    parser.add_argument("--listen-port", type=int, default=5174)
    parser.add_argument("--upstream-host", default="192.168.122.226")
    parser.add_argument("--upstream-port", type=int, default=80)
    args = parser.parse_args()

    ShopProxy.upstream_host = args.upstream_host
    ShopProxy.upstream_port = args.upstream_port

    server = http.server.ThreadingHTTPServer((args.listen_host, args.listen_port), ShopProxy)
    print(
        f"Tiny CRM proxy http://{args.listen_host}:{args.listen_port} -> "
        f"http://{args.upstream_host}:{args.upstream_port}/Shop",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
