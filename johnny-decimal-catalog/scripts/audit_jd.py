#!/usr/bin/env python3
"""Audit a Johnny.Decimal vault for catalog-space compliance.

Usage: python3 audit_jd.py /path/to/vault
Exit code 0 = clean, 1 = findings.
"""
import os, re, sys

RESERVED = {"06", "07", "08"}
STANDARD = set(f"{n:02d}" for n in range(10))
THREE = re.compile(r'^(\d{2})\.(\d{2})\.(\d{2})')
TOP = re.compile(r'^\d{2}-')
SKIP = {".obsidian", ".git", ".trash"}

def audit(root):
    findings = []
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP]
        for name in list(dns) + list(fns):
            rel = os.path.relpath(os.path.join(dp, name), root)
            if THREE.match(name):
                findings.append(("third-segment", rel))
            m = re.match(r'^(\d{2})\.(\d{2})-', name)
            if m:
                nn = m.group(2)
                if nn in RESERVED:
                    findings.append(("reserved-slot", rel))
                elif nn not in STANDARD and nn.endswith("0"):
                    findings.append(("zero-ending-content-id", rel))
    for name in os.listdir(root):
        if name in SKIP:
            continue
        if os.path.isdir(os.path.join(root, name)) and not TOP.match(name):
            findings.append(("bad-top-level", name))
    return findings

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 audit_jd.py /path/to/vault")
        return 1
    findings = audit(sys.argv[1])
    if not findings:
        print("OK: vault is catalog-space compliant")
        return 0
    for kind, rel in findings:
        print(f"[{kind}] {rel}")
    print(f"\n{len(findings)} finding(s)")
    return 1

if __name__ == "__main__":
    sys.exit(main())
