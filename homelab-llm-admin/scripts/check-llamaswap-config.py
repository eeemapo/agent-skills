#!/usr/bin/env python3
"""Lint a llama-swap config.yaml before you put it in front of a live node.

Read-only: parses the file, never writes or touches a server.

    python3 check-llamaswap-config.py /path/to/config.yaml

Exit codes: 0 clean (warnings allowed), 1 errors, 2 unreadable/unparseable.

Checks
  - YAML parses; top-level `models` is a mapping
  - every model has `cmd` or `proxy` (not both)
  - model ids and aliases are unique; aliases are non-empty strings
  - `capabilities.context`, when present, is a positive int and matches a
    `--ctx-size`/`-c`/`CONTEXT` it can find in the command
  - docker-run stanzas join the tailscale netns and pin an image by digest
  - matrix `vars` and `sets` reference real model ids or vars
  - every model is mentioned by some set, else it can only run alone (warning)
  - unknown top-level keys (warning)
"""
from __future__ import annotations

import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("check-llamaswap-config: needs pyyaml (pip/apt python3-yaml)")

KNOWN_TOP = {
    "apiKeys", "healthCheckTimeout", "logLevel", "startPort", "sendLoadingState",
    "includeAliasesInList", "globalTTL", "performance", "models", "matrix",
    "routing", "macros", "env", "groups", "profiles", "hooks", "kubeswap",
    "metrics", "logging", "ui",
}
SET_OPS = re.compile(r"[|&+()]")


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def err(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def ctx_from_cmd(cmd: str) -> int | None:
    """--ctx-size N / -c N / CONTEXT=Nk, the three spellings these configs use."""
    for pat in (r"--ctx-size[= ](\d+)", r"(?:^|\s)-c[= ](\d+)", r"CONTEXT[=:](\d+)(k?)"):
        m = re.search(pat, cmd, re.M)
        if not m:
            continue
        n = int(m.group(1))
        return n * 1024 if m.lastindex and m.lastindex >= 2 and m.group(2) == "k" else n
    return None


def leaves(expr: str) -> set[str]:
    """Terminal names in a set expression, whitespace stripped and a leading
    '+' (a reference to another set) removed."""
    out = set()
    for tok in SET_OPS.split(expr):
        tok = tok.strip()
        if tok:
            out.add(tok.lstrip("+").strip())
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        print("usage: check-llamaswap-config.py <config.yaml>", file=sys.stderr)
        return 2

    path = argv[1]
    try:
        raw = open(path, encoding="utf-8").read()
    except OSError as e:
        print(f"cannot read {path}: {e}", file=sys.stderr)
        return 2

    if "\t" in raw:
        print(f"{path}: contains a TAB — YAML forbids tabs for indentation", file=sys.stderr)
        return 2

    try:
        cfg = yaml.safe_load(raw)
    except yaml.YAMLError as e:
        print(f"{path}: YAML does not parse — llama-swap would keep the old config\n{e}",
              file=sys.stderr)
        return 2

    r = Report()
    if not isinstance(cfg, dict):
        print(f"{path}: top level is not a mapping", file=sys.stderr)
        return 2

    for key in cfg:
        if key not in KNOWN_TOP:
            r.warn(f"unknown top-level key {key!r} (typo, or a newer schema?)")

    models = cfg.get("models")
    if not isinstance(models, dict) or not models:
        print(f"{path}: no `models` mapping", file=sys.stderr)
        return 1

    alias_owner: dict[str, str] = {}
    for mid, m in models.items():
        where = f"models.{mid}"
        if not isinstance(m, dict):
            r.err(f"{where}: not a mapping")
            continue

        has_cmd, has_proxy = bool(m.get("cmd")), bool(m.get("proxy"))
        if has_cmd and has_proxy:
            r.err(f"{where}: has both `cmd` and `proxy` — pick one")
        elif not (has_cmd or has_proxy):
            r.err(f"{where}: needs `cmd` or `proxy`")

        for a in m.get("aliases") or []:
            if not isinstance(a, str) or not a.strip():
                r.err(f"{where}: empty or non-string alias {a!r}")
                continue
            if a in alias_owner and alias_owner[a] != mid:
                r.err(f"{where}: alias {a!r} already used by models.{alias_owner[a]}")
            alias_owner[a] = mid
            if a in models and a != mid:
                r.err(f"{where}: alias {a!r} collides with a model id")

        caps = m.get("capabilities") or {}
        ctx = caps.get("context") if isinstance(caps, dict) else None
        cmd = m.get("cmd") or ""
        cmd_ctx = ctx_from_cmd(cmd) if isinstance(cmd, str) else None
        if ctx is not None:
            if not isinstance(ctx, int) or ctx <= 0:
                r.err(f"{where}: capabilities.context must be a positive int, got {ctx!r}")
            elif cmd_ctx is not None and cmd_ctx != ctx:
                r.warn(f"{where}: capabilities.context={ctx} but the command asks for "
                       f"{cmd_ctx} — clients trust the former")

        if isinstance(cmd, str) and "docker run" in cmd:
            if "--network container:" not in cmd:
                r.err(f"{where}: docker-run stanza must join the tailscale netns "
                      f"(`--network container:${{env.LLAMA_SWAP_TS_CTR}}`), else "
                      f"127.0.0.1:${{PORT}} is not shared with llama-swap")
            if "@sha256:" not in cmd:
                r.warn(f"{where}: image not pinned by digest — :latest drifts on the next pull")
            if "--rm" not in cmd:
                r.warn(f"{where}: docker-run stanza without --rm leaves dead containers behind")
            if m.get("checkEndpoint") is None:
                r.warn(f"{where}: no checkEndpoint; the default probe may not fit this backend")

    matrix = cfg.get("matrix") or {}
    used: set[str] = set()
    if isinstance(matrix, dict) and matrix:
        var = matrix.get("vars") or {}
        if not isinstance(var, dict):
            r.err("matrix.vars: not a mapping")
            var = {}
        for k, v in var.items():
            if v not in models:
                r.err(f"matrix.vars.{k}: {v!r} is not a model id")

        sets = matrix.get("sets") or {}
        if not isinstance(sets, dict) or not sets:
            r.warn("matrix present but no matrix.sets — nothing constrains co-residency")

        for sname, expr in (sets or {}).items():
            if not isinstance(expr, str):
                r.err(f"matrix.sets.{sname}: not a string expression")
                continue
            for leaf in leaves(expr):
                if leaf in sets:
                    continue                      # a reference resolved below
                target = var.get(leaf, leaf)
                if target not in models:
                    r.err(f"matrix.sets.{sname}: {leaf!r} is neither a model id nor a var")
                used.add(target)

        # references: +name expands another set, so its leaves are used too
        for sname, expr in (sets or {}).items():
            if isinstance(expr, str):
                for ref in re.findall(r"\+\s*([A-Za-z0-9_.:-]+)", expr):
                    if ref in sets and isinstance(sets[ref], str):
                        for leaf in leaves(sets[ref]):
                            used.add(var.get(leaf, leaf))

        costs = matrix.get("evict_costs") or {}
        for k in costs:
            target = var.get(k, k)
            if target not in models:
                r.err(f"matrix.evict_costs: {k!r} is not a model id or var")

        orphans = sorted(set(models) - used)
        for mid in orphans:
            r.warn(f"models.{mid}: named by no matrix set — it can only ever run alone")
    else:
        r.warn("no `matrix:` section — llama-swap runs one model at a time")

    for w in r.warnings:
        print(f"WARN  {w}")
    for e in r.errors:
        print(f"ERROR {e}")

    if r.errors:
        print(f"\n{len(r.errors)} error(s), {len(r.warnings)} warning(s)")
        return 1
    print(f"\nOK — {len(models)} models, {len(r.warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
