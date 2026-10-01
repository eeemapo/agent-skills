#!/usr/bin/env python3
"""komodo_api.py - minimal, dependency-free client for the Komodo Core HTTP API.

Every Komodo call is `POST /<module>` with body {"type": <Name>, "params": <obj>}.
This tool sends that, optionally polls an execution's Update to completion, and
prints JSON. It requires only the Python standard library.

Credentials (flags override environment):
  KOMODO_HOST        Core base URL, e.g. https://komodo.example.com
  KOMODO_API_KEY     API key     (K_...)
  KOMODO_API_SECRET  API secret  (S_...)
  KOMODO_CORE        alias for KOMODO_HOST

Examples:
  komodo_api.py read GetCoreInfo
  komodo_api.py read ListStacks '{"limit":0}'
  komodo_api.py write UpdateStack '{"id":"my-stack","config":{"branch":"release"}}'
  komodo_api.py execute DeployStack '{"stack":"my-stack"}' --wait
  komodo_api.py read ListStacks @params.json --output stacks.json
  echo '{"server":"prod-01"}' | komodo_api.py read GetServerState -
  komodo_api.py terminal '{"target":{"type":"Server","params":{"server":"prod-01"}},"command":"uptime"}'

Exit codes: 0 ok, 2 usage, 3 missing credentials, 4 API/HTTP error,
            5 execution reported failure, 6 connection error, 7 timeout.
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import ssl
import sys
import time
import urllib.error
import urllib.request

DEFAULT_TIMEOUT = 60.0
MODULES = ("read", "write", "execute", "auth", "terminal")


class ApiError(Exception):
    def __init__(self, message, status=None, trace=None):
        super().__init__(message)
        self.message = message
        self.status = status
        self.trace = trace or []


class Client:
    def __init__(self, host, key=None, secret=None, timeout=DEFAULT_TIMEOUT, insecure=False):
        self.host = host.rstrip("/")
        self.key = key
        self.secret = secret
        self.timeout = timeout
        self._ctx = None
        if insecure:
            self._ctx = ssl.create_default_context()
            self._ctx.check_hostname = False
            self._ctx.verify_mode = ssl.CERT_NONE

    def _headers(self):
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/plain, */*",
        }
        if self.key and self.secret:
            headers["X-Api-Key"] = self.key
            headers["X-Api-Secret"] = self.secret
        return headers

    def request(self, path, body):
        data = json.dumps(body).encode()
        req = urllib.request.Request(
            self.host + path, data=data, method="POST", headers=self._headers()
        )
        kwargs = {"timeout": self.timeout}
        if self._ctx is not None:
            kwargs["context"] = self._ctx
        try:
            with urllib.request.urlopen(req, **kwargs) as resp:
                return resp.read()
        except urllib.error.HTTPError as exc:
            raw = exc.read()
            message, trace = f"HTTP {exc.code}", []
            try:
                parsed = json.loads(raw.decode() or "{}")
                message = parsed.get("error", message)
                trace = parsed.get("trace", []) or []
            except (ValueError, UnicodeDecodeError):
                message = raw.decode(errors="replace") or message
            raise ApiError(message, status=exc.code, trace=trace) from None
        except socket.timeout as exc:
            raise TimeoutError(str(exc)) from exc
        except urllib.error.URLError as exc:
            if isinstance(exc.reason, socket.timeout):
                raise TimeoutError(str(exc.reason)) from exc
            raise ConnectionError(str(exc.reason)) from exc

    def call(self, module, req_type, params):
        if module == "terminal":
            return self.request("/terminal/execute", params or {})
        body = {"type": req_type, "params": params or {}}
        raw = self.request(f"/{module}", body)
        if not raw:
            return None
        return json.loads(raw.decode())

    def wait_update(self, update, timeout=600.0, interval=2.0):
        update_id = _update_id(update)
        if not update_id:
            return update
        deadline = time.monotonic() + timeout
        current = update
        while True:
            status = current.get("status")
            if status == "Complete":
                return current
            if time.monotonic() >= deadline:
                raise TimeoutError(
                    f"update {update_id} still {status!r} after {timeout:.0f}s"
                )
            time.sleep(interval)
            current = self.call("read", "GetUpdate", {"id": update_id})


def _update_id(update):
    if not isinstance(update, dict):
        return None
    ident = update.get("_id") or update.get("id")
    if isinstance(ident, dict):
        return ident.get("$oid") or ident.get("oid")
    return ident


def _read_params(value):
    if value is None:
        return {}
    if value == "-":
        value = sys.stdin.read()
    elif value.startswith("@"):
        with open(value[1:], "r", encoding="utf-8") as handle:
            value = handle.read()
    try:
        parsed = json.loads(value or "{}")
    except ValueError as exc:
        raise SystemExit(f"error: params is not valid JSON: {exc}")
    if not isinstance(parsed, dict):
        raise SystemExit("error: params JSON must be an object")
    return parsed


def _resolve(flag, *env_names):
    if flag:
        return flag
    for name in env_names:
        value = os.environ.get(name)
        if value:
            return value
    return None


def build_parser():
    parser = argparse.ArgumentParser(
        prog="komodo_api.py",
        description="Call the Komodo Core HTTP API and print JSON.",
        epilog="Exit codes: 0 ok, 2 usage, 3 no creds, 4 API error, 5 exec failed, 6 conn, 7 timeout",
    )
    parser.add_argument("module", choices=MODULES, help="API module to POST to")
    parser.add_argument("request", nargs="?", help="Request type (or terminal body); omit only for `terminal`")
    parser.add_argument("params", nargs="?", help="params JSON, '@file', or '-' for stdin")
    parser.add_argument("--host", help="Core base URL (env KOMODO_HOST / KOMODO_CORE)")
    parser.add_argument("--key", help="API key (env KOMODO_API_KEY)")
    parser.add_argument("--secret", help="API secret (env KOMODO_API_SECRET)")
    parser.add_argument("--wait", action="store_true", help="poll execute Update until Complete")
    parser.add_argument("--wait-timeout", type=float, default=600.0, help="seconds to wait (default 600)")
    parser.add_argument("--wait-interval", type=float, default=2.0, help="poll interval seconds (default 2)")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, help="request timeout seconds (default 60)")
    parser.add_argument("--insecure", action="store_true", help="skip TLS verification (self-signed Core)")
    parser.add_argument("--raw", action="store_true", help="compact JSON instead of pretty")
    parser.add_argument("--output", help="write response body to this file")
    parser.add_argument("--dry-run", action="store_true", help="print the request without sending it")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if args.module == "terminal":
        if args.request is None:
            build_parser().error("terminal requires a body JSON as the first argument")
        params = _read_params(args.request)
        req_type = None
    else:
        if args.request is None:
            build_parser().error(f"{args.module} requires a request type")
        params = _read_params(args.params)
        req_type = args.request

    host = _resolve(args.host, "KOMODO_HOST", "KOMODO_CORE")
    key = _resolve(args.key, "KOMODO_API_KEY")
    secret = _resolve(args.secret, "KOMODO_API_SECRET")

    if args.dry_run:
        if not host:
            print("error: --dry-run needs a host (--host or KOMODO_HOST)", file=sys.stderr)
            return 2
        if args.module == "terminal":
            payload = {"POST": f"{host.rstrip('/')}/terminal/execute", "body": params}
        else:
            payload = {"POST": f"{host.rstrip('/')}/{args.module}", "body": {"type": req_type, "params": params}}
        print(json.dumps(payload, indent=2))
        return 0

    if not host:
        print("error: no host; pass --host or set KOMODO_HOST", file=sys.stderr)
        return 2
    if not key or not secret:
        print("error: need both --key and --secret (or KOMODO_API_KEY / KOMODO_API_SECRET)", file=sys.stderr)
        return 3

    client = Client(host, key, secret, timeout=args.timeout, insecure=args.insecure)
    try:
        result = client.call(args.module, req_type, params)
        if args.module == "terminal":
            out = sys.stdout.buffer
            out.write(result if isinstance(result, (bytes, bytearray)) else str(result).encode())
            out.flush()
            return 0
        if args.wait:
            if args.module != "execute":
                print("error: --wait only applies to `execute`", file=sys.stderr)
                return 2
            result = client.wait_update(result, timeout=args.wait_timeout, interval=args.wait_interval)
    except ApiError as exc:
        print(json.dumps({"error": exc.message, "trace": exc.trace, "status": exc.status}, indent=2), file=sys.stderr)
        return 4
    except TimeoutError as exc:
        print(f"error: timeout: {exc}", file=sys.stderr)
        return 7
    except ConnectionError as exc:
        print(f"error: cannot reach Komodo Core: {exc}", file=sys.stderr)
        return 6

    text = json.dumps(result, separators=(",", ":")) if args.raw else json.dumps(result, indent=2)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text + "\n")
        print(f"wrote {args.output}", file=sys.stderr)
    else:
        print(text)

    if args.wait and isinstance(result, dict) and result.get("success") is False:
        return 5
    return 0


if __name__ == "__main__":
    sys.exit(main())
