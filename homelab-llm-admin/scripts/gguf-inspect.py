#!/usr/bin/env python3
"""Inspect a GGUF without loading it: header, metadata, tensor summary.

Pure stdlib — no `gguf` package, no llama.cpp build, no venv. Works on any host
and inside a container. Reads only the header + metadata + tensor table, never
the weight data, so it is instant even on a 60 GB file.

    python3 gguf-inspect.py /path/to/model.gguf
    python3 gguf-inspect.py /path/to/model-00001-of-00003.gguf   # shard 1 of N

What it answers:
  - which architecture and quant type is this really
  - what context length does the file declare
  - is there a chat template, and does it mention thinking
  - is this shard 1 of a split set (and how many shards)
  - what are the tensors (dtype histogram, parameter estimate)

Exit codes: 0 ok, 1 not a GGUF / truncated, 2 usage.
"""
from __future__ import annotations

import os
import re
import struct
import sys

MAGIC = b"GGUF"

# gguf metadata value types -> struct format (or None for variable length)
SCALARS = {
    0: "<B", 1: "<b", 2: "<H", 3: "<h", 4: "<I", 5: "<i",
    6: "<f", 7: "<?", 10: "<Q", 11: "<q", 12: "<d",
}
STRING, ARRAY = 8, 9

# ggml tensor types -> (name, bytes per block, elements per block)
GGML_TYPES = {
    0: ("F32", 4, 1), 1: ("F16", 2, 1), 2: ("Q4_0", 18, 32), 3: ("Q4_1", 20, 32),
    6: ("Q5_0", 22, 32), 7: ("Q5_1", 24, 32), 8: ("Q8_0", 34, 32), 9: ("Q8_1", 36, 32),
    10: ("Q2_K", 84, 256), 11: ("Q3_K", 110, 256), 12: ("Q4_K", 144, 256),
    13: ("Q5_K", 176, 256), 14: ("Q6_K", 210, 256), 15: ("Q8_K", 292, 256),
    16: ("IQ2_XXS", 66, 256), 17: ("IQ2_XS", 74, 256), 18: ("IQ3_XXS", 98, 256),
    19: ("IQ1_S", 50, 256), 20: ("IQ4_NL", 18, 32), 21: ("IQ3_S", 110, 256),
    22: ("IQ2_S", 82, 256), 23: ("IQ4_XS", 136, 256), 24: ("I8", 1, 1),
    25: ("I16", 2, 1), 26: ("I32", 4, 1), 27: ("I64", 8, 1), 28: ("F64", 8, 1),
    29: ("IQ1_M", 56, 256), 30: ("BF16", 2, 1), 34: ("TQ1_0", 54, 256),
    35: ("TQ2_0", 66, 256), 39: ("MXFP4", 17, 32),
}

INTERESTING = (
    "general.architecture", "general.name", "general.basename", "general.size_label",
    "general.file_type", "general.quantization_version", "general.license",
    "general.parameter_count",
)


class Reader:
    def __init__(self, path: str) -> None:
        self.f = open(path, "rb")

    def read(self, n: int) -> bytes:
        b = self.f.read(n)
        if len(b) != n:
            raise EOFError("unexpected end of file (truncated download?)")
        return b

    def u32(self) -> int:
        return struct.unpack("<I", self.read(4))[0]

    def u64(self) -> int:
        return struct.unpack("<Q", self.read(8))[0]

    def string(self) -> str:
        return self.read(self.u64()).decode("utf-8", "replace")

    def value(self, vtype: int, depth: int = 0):
        if vtype in SCALARS:
            fmt = SCALARS[vtype]
            return struct.unpack(fmt, self.read(struct.calcsize(fmt)))[0]
        if vtype == STRING:
            return self.string()
        if vtype == ARRAY:
            itype = self.u32()
            count = self.u64()
            if depth > 1:                       # don't materialise nested arrays
                for _ in range(count):
                    self.value(itype, depth + 1)
                return f"<array of {count}>"
            return [self.value(itype, depth + 1) for _ in range(count)]
        raise ValueError(f"unknown metadata value type {vtype}")


def fmt_bytes(n: float) -> str:
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024
    return f"{n:.1f} TiB"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: gguf-inspect.py <model.gguf>", file=sys.stderr)
        return 2
    path = argv[1]

    try:
        r = Reader(path)
        magic = r.read(4)
        if magic != MAGIC:
            print(f"{path}: not a GGUF (magic {magic!r})", file=sys.stderr)
            return 1
        version = r.u32()
        n_tensors = r.u64()
        n_kv = r.u64()

        meta: dict[str, object] = {}
        for _ in range(n_kv):
            key = r.string()
            vtype = r.u32()
            meta[key] = r.value(vtype)

        tensors = []
        for _ in range(n_tensors):
            name = r.string()
            n_dims = r.u32()
            dims = [r.u64() for _ in range(n_dims)]
            ttype = r.u32()
            _offset = r.u64()                   # relative data offset, unused here
            tensors.append((name, dims, ttype))
    except EOFError as e:
        print(f"{path}: {e}", file=sys.stderr)
        return 1
    except (ValueError, struct.error) as e:
        print(f"{path}: malformed GGUF — {e}", file=sys.stderr)
        return 1

    arch = meta.get("general.architecture", "?")
    print(f"file        {path}")
    print(f"gguf        v{version}, {n_tensors} tensors, {n_kv} metadata keys")
    print(f"arch        {arch}")

    for key in INTERESTING:
        if key in meta and key != "general.architecture":
            val = meta[key]
            if key == "general.file_type":
                names = {0: "ALL_F32", 1: "MOSTLY_F16", 2: "MOSTLY_Q4_0", 3: "MOSTLY_Q4_1",
                         7: "MOSTLY_Q8_0", 8: "MOSTLY_Q5_0", 9: "MOSTLY_Q5_1",
                         10: "MOSTLY_Q2_K", 11: "MOSTLY_Q3_K", 12: "MOSTLY_Q4_K",
                         13: "MOSTLY_Q5_K", 14: "MOSTLY_Q6_K"}
                val = f"{val} ({names.get(val, 'ggml file-type enum')})"
            print(f"{'':12}{key:26} {val}")

    # architecture-scoped keys use the architecture as a prefix
    for suffix in ("context_length", "block_count", "embedding_length",
                   "expert_count", "expert_used_count", "attention.head_count",
                   "attention.head_count_kv"):
        key = f"{arch}.{suffix}"
        if key not in meta:
            continue
        val = meta[key]
        if isinstance(val, list):                 # per-layer arrays can be huge
            uniq = sorted({v for v in val if isinstance(v, int)})
            head = ", ".join(str(v) for v in val[:8])
            val = (f"per-layer list[{len(val)}] {head}… (distinct: {uniq})")
        print(f"{'':12}{suffix:26} {val}")

    split_count = meta.get("split.count")
    split_no = meta.get("split.no")
    if not split_count:
        # llama.cpp split files also name the shard: model-00002-of-00005.gguf
        m = re.search(r"-(\d{5})-of-(\d{5})", os.path.basename(path))
        if m:
            split_no, split_count = int(m.group(1)) - 1, int(m.group(2))
    if split_count:
        print(f"{'':12}{'split':26} shard {int(split_no or 0) + 1} of {split_count} — "
              f"the stanza needs every shard")

    tmpl = meta.get("tokenizer.chat_template")
    if isinstance(tmpl, str):
        hints = [h for h in ("enable_thinking", "reasoning_effort", "/think", "thinking")
                 if h in tmpl]
        print(f"{'':12}{'chat_template':26} {len(tmpl)} chars"
              + (f"; mentions {', '.join(hints)}" if hints else "; no thinking controls"))
    else:
        print(f"{'':12}{'chat_template':26} MISSING — reasoning controls won't work")

    if "tokenizer.ggml.model" in meta:
        print(f"{'':12}{'tokenizer':26} {meta['tokenizer.ggml.model']}")

    # tensor summary: dtype histogram + parameter estimate
    by_type: dict[int, int] = {}
    params = 0
    for _name, dims, ttype in tensors:
        by_type[ttype] = by_type.get(ttype, 0) + 1
        n = 1
        for d in dims:
            n *= d
        params += n

    print(f"\ntensors     {len(tensors)}, ~{params / 1e9:.2f} B parameters")
    for ttype, count in sorted(by_type.items(), key=lambda kv: -kv[1]):
        name, size, block = GGML_TYPES.get(ttype, (f"type{ttype}", 0, 1))
        share = ""
        if block:
            # bytes-per-element for this quant, useful for sanity checks
            share = f"  {size / block:.2f} B/param"
        print(f"  {name:<10} {count:>5} tensors{share}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
