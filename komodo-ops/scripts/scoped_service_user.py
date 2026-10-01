#!/usr/bin/env python3
"""scoped_service_user.py - idempotently bootstrap a scoped Komodo automation identity.

Creates (or reuses) a service user, applies base and per-target permissions,
and mints an API key. Safe to re-run: existing users/permissions are reused,
and a key with the same name is not recreated.

Permissions spec (JSON string, '@file', or '-' for stdin):
  {
    "base": [
      {"resource_type": "Server", "permission": {"level": "Read", "specific": ["Logs"]}}
    ],
    "targets": [
      {"resource_target": {"type": "Server", "id": "prod-01"},
       "permission": {"level": "Execute", "specific": ["Terminal", "Inspect"]}}
    ]
  }

Examples:
  scoped_service_user.py --username deploy-bot --description 'CI deployer'
  scoped_service_user.py --username deploy-bot --permissions @perms.json
  scoped_service_user.py --username deploy-bot --permissions @perms.json --dry-run

Credentials come from --host/--key/--secret, the environment (KOMODO_HOST /
KOMODO_API_KEY / KOMODO_API_SECRET), or a KEY=value file at $KOMODO_ENV_FILE
(default ~/.config/komodo/komodo.env). Requires an admin key (service users and
keys are admin-only).

Exit codes: 0 ok, 2 usage, 3 no creds, 4 API error, 6 connection error.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from komodo_api import ApiError, Client, _read_params, _resolve, load_env_file  # noqa: E402


def _load_permissions(value):
    if not value:
        return {"base": [], "targets": []}
    parsed = _read_params(value)
    return {
        "base": parsed.get("base", []) or [],
        "targets": parsed.get("targets", []) or [],
    }


def _find_user(client, username):
    try:
        return client.call("read", "FindUser", {"user": username})
    except ApiError:
        return None


def _existing_key(client, user_id, name):
    try:
        keys = client.call("read", "ListApiKeysForServiceUser", {"user_id": user_id})
    except ApiError:
        return None
    for key in keys or []:
        if key.get("name") == name:
            return key
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="scoped_service_user.py",
        description="Create/reuse a scoped service user and API key for Komodo automation.",
    )
    parser.add_argument("--username", required=True, help="service user username")
    parser.add_argument("--description", default="Automation service user", help="service user description")
    parser.add_argument("--key-name", default="automation", help="API key label (default: automation)")
    parser.add_argument("--expires", type=int, default=0, help="key expiry unix ms; 0 = never (default)")
    parser.add_argument("--permissions", help="permissions JSON / @file / - (see docstring)")
    parser.add_argument("--no-key", action="store_true", help="do not create an API key")
    parser.add_argument("--dry-run", action="store_true", help="print planned requests and exit")
    parser.add_argument("--json", action="store_true", help="compact JSON output")
    parser.add_argument("--host")
    parser.add_argument("--key")
    parser.add_argument("--secret")
    parser.add_argument("--insecure", action="store_true")
    parser.add_argument("--timeout", type=float, default=60.0)
    args = parser.parse_args(argv)
    load_env_file()

    perms = _load_permissions(args.permissions)
    host = _resolve(args.host, "KOMODO_HOST", "KOMODO_CORE")
    key = _resolve(args.key, "KOMODO_API_KEY")
    secret = _resolve(args.secret, "KOMODO_API_SECRET")

    planned = []

    if args.dry_run:
        planned = [
            {"module": "read", "type": "FindUser", "params": {"user": args.username}},
            {"module": "write", "type": "CreateServiceUser", "params": {"username": args.username, "description": args.description}},
            *[{"module": "write", "type": "UpdatePermissionOnResourceType",
               "params": {"user_target": {"type": "User", "id": "<user-id>"}, "resource_type": b.get("resource_type"), "permission": b.get("permission")}}
              for b in perms["base"]],
            *[{"module": "write", "type": "UpdatePermissionOnTarget",
               "params": {"user_target": {"type": "User", "id": "<user-id>"}, "resource_target": t.get("resource_target"), "permission": t.get("permission")}}
              for t in perms["targets"]],
        ]
        if not args.no_key:
            planned.append({"module": "write", "type": "CreateApiKeyForServiceUser",
                            "params": {"user_id": "<user-id>", "name": args.key_name, "expires": args.expires}})
        print(json.dumps({"dry_run": True, "host": host, "planned": planned}, indent=2))
        return 0

    if not host:
        print("error: no host; pass --host or set KOMODO_HOST", file=sys.stderr)
        return 2
    if not key or not secret:
        print("error: need an admin --key/--secret (or KOMODO_API_KEY / KOMODO_API_SECRET)", file=sys.stderr)
        return 3

    client = Client(host, key, secret, timeout=args.timeout, insecure=args.insecure)
    try:
        user = _find_user(client, args.username)
        created = False
        if user is None:
            user = client.call("write", "CreateServiceUser", {
                "username": args.username, "description": args.description,
            })
            created = True
        user_id = user.get("id")

        applied = []
        for base in perms["base"]:
            client.call("write", "UpdatePermissionOnResourceType", {
                "user_target": {"type": "User", "id": user_id},
                "resource_type": base.get("resource_type"),
                "permission": base.get("permission"),
            })
            applied.append({"scope": "type", "resource_type": base.get("resource_type")})
        for target in perms["targets"]:
            client.call("write", "UpdatePermissionOnTarget", {
                "user_target": {"type": "User", "id": user_id},
                "resource_target": target.get("resource_target"),
                "permission": target.get("permission"),
            })
            applied.append({"scope": "target", "resource_target": target.get("resource_target")})

        api_key = None
        key_reused = False
        if not args.no_key:
            existing = _existing_key(client, user_id, args.key_name)
            if existing is not None:
                key_reused = True
                api_key = {"key": existing.get("key"), "name": existing.get("name"), "reused": True}
            else:
                api_key = client.call("write", "CreateApiKeyForServiceUser", {
                    "user_id": user_id, "name": args.key_name, "expires": args.expires,
                })
    except ApiError as exc:
        print(json.dumps({"error": exc.message, "trace": exc.trace, "status": exc.status}, indent=2), file=sys.stderr)
        return 4
    except ConnectionError as exc:
        print(f"error: cannot reach Komodo Core: {exc}", file=sys.stderr)
        return 6

    summary = {
        "user": {"id": user_id, "username": user.get("username"), "created": created},
        "permissions_applied": applied,
        "api_key": api_key,
        "api_key_reused": key_reused,
    }
    print(json.dumps(summary, separators=(",", ":")) if args.json else json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
