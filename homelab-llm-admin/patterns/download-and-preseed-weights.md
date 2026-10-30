# Get the weights: cache, preseed, or a named file

A stanza needs weights before it can start. There are two mechanisms, and
llama-swap itself has **no downloader** — it just runs your command, so the
mechanism is whatever the command implies.

| Mechanism | Stanza says | Download happens | First load |
|---|---|---|---|
| HF cache | `-hf <repo> -hff <file.gguf>` | llama.cpp, **at load time**, into `/hf-cache` | may fetch tens of GB; can outlast the health check |
| Preseeded file | `-m /models/<file.gguf>` or a `-hf` whose cache you already warmed | you, beforehand | reads from disk |

**Default to the cache — but warm it first.** Both nodes mount the host HF cache
into the container (`HF_HUB_CACHE=/hf-cache`, host
`~/.cache/huggingface/hub`), so a host-side download populates exactly what
`-hf` reads. Keep the stanza as `-hf`, and preseed with `hf` on the host:

    ssh phx
    hf download <org>/<repo>-GGUF <exact-file.gguf> --quiet

That converts a lazy network fetch into a local read without changing the stanza.

## Name the quant. Always.

A GGUF repo typically holds several quants times several shards. `hf download
<repo>` with no filename pulls **all of them** — routinely hundreds of GB — and
you will not notice until the disk is full.

    # one file, the only form you normally want
    hf download unsloth/Some-Model-GGUF Some-Model-UD-Q4_K_XL.gguf

    # a split model: every shard of ONE quant
    hf download unsloth/Some-Model-GGUF --include "*UD-Q4_K_XL*"

    # split model + vision projector (only if the stanza passes one)
    hf download unsloth/Some-Model-GGUF --include "*UD-Q4_K_XL*" --include "*mmproj*"

Rules:

- **Pick the quant by fit, not by size.** Weigh file size + KV cache + context
  against VRAM and RAM; a bigger quant that spills to CPU is slower than a
  smaller one that stays resident.
- **Split models need every shard.** A partial set fails at load with a missing
  shard, not a friendly message.
- **Vision needs its `mmproj`.** Without it, `capabilities.in: [image]` lies.
- **MTP/draft heads are separate files** when the stanza passes one.
- Long pulls: background them and keep the log —
  `setsid nohup hf download … > /opt/ai/download-<name>.log 2>&1 &`

## When to preseed into a model directory instead

Sibling-container backends (Strata, vLLM/HyperQwen, Momoe) do **not** read the HF
cache and do **not** inherit `HF_TOKEN` — their weights must exist on the host and
be mounted `:ro`. Use `--local-dir`:

    hf download <repo> <file> --local-dir /opt/ai/<tree>/models/<name>

`--local-dir` lands **outside** the cache, so `-hf` will not find it — the stanza
must mount and reference the path explicitly.

### Where weights go

| Node | Preferred | Notes |
|---|---|---|
| `phx` | `/opt/ai/strata/models/…`, `/opt/ai/hyperqwen/models`, `/opt/ai/nemotron/models` | NVMe root. **Not `/tank`** — spinning rust, and load time is disk-bound |
| `lax` | `/opt/ai/models/<name>` (bulk), `/opt/ai/custom` (one-offs) | root is the tighter filesystem here |

Check free space on the *right* filesystem before committing to a pull
(`df -h /` vs `df -h /tank`) — a 100 GB model on the tighter root is a bad
afternoon. Ownership matters too: download as `sysops`, never as root, or the
container cannot read the file.

## Verify before wiring it up

- **Size**: `ls -lh`, compare with the repo's blob size.
- **Hash**: `sha256sum` when the repo or your notes carry a pin.
- **Reachability**: after the stanza points at it, the first request should be
  fast. A minute-plus first load means it is still downloading, not loading.

## Traps

| Symptom | Cause |
|---|---|
| first request hangs, then `health check timed out` | lazy `-hf` download outlasted the timeout — preseed it |
| `hf download` filled the disk | repo-wide pull; you wanted one filename |
| `failed to load model` after `--local-dir` | `-hf` looks in the cache, `--local-dir` is not there — mount the path instead |
| permission denied on a mounted file | downloaded as root |
| weights load at ~50 MB/s | sitting on `/tank` (spinning) instead of the NVMe root |
| 401/403 from `hf` | no token on the host; the containers get one at deploy, the host may not |
