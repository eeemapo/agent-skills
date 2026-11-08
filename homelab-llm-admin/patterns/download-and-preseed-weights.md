# Get the weights: name the quant, land it in the model tree

A stanza needs weights before it can start. llama-swap itself has **no
downloader** — it just runs your command, so the mechanism is whatever the
command implies.

## How weights are referenced today

Both nodes mount one tree, `/opt/ai/models` → `/models` (read-only on `lax`,
writable on `phx`), and **every stanza passes absolute paths**:

    -m       /models/llama-cpp/<model>/<main>.gguf
    --mmproj /models/llama-cpp/<model>/<mmproj>.gguf     # vision
    -md      /models/llama-cpp/<model>/<drafter>.gguf    # speculative decoding

There is **no `/hf-cache` mount and no `/custom` mount** (retired 2026-11-04),
so `-hf`/`-hff` stanzas are gone: llama.cpp would have nowhere to resolve the
repo. Do not reintroduce one — download to disk and point at the file.

## Name the quant. Always.

A GGUF repo typically holds several quants times several shards. `hf download
<repo>` with no filename pulls **all of them** — routinely hundreds of GB — and
you will not notice until the disk is full.

    # one file, the only form you normally want
    hf download unsloth/Some-Model-GGUF Some-Model-UD-Q4_K_XL.gguf

    # a split model: every shard of ONE quant
    hf download unsloth/Some-Model-GGUF --include "*UD-Q4_K_XL*"

    # split model + vision projector + drafter (only if the stanza passes them)
    hf download unsloth/Some-Model-GGUF --include "*UD-Q4_K_XL*" \
        --include "*mmproj*" --include "*dflash*"

Rules:

- **Pick the quant by fit, not by size.** Weigh file size + KV cache + context
  against VRAM and RAM; a bigger quant that spills to CPU is slower than a
  smaller one that stays resident.
- **Split models need every shard.** A partial set fails at load with a missing
  shard, not a friendly message.
- **Vision needs its `mmproj`.** Without it, `capabilities.in: [image]` lies.
- **MTP/DFlash/draft heads are separate files** when the stanza passes one.
- Long pulls: background them and keep the log —
  `setsid nohup hf download … > /opt/ai/download-<name>.log 2>&1 &`
- Download **as `sysops`**, never as root, or the container cannot read the file.

## Where weights go

    /opt/ai/models/llama-cpp/<model>/       one directory per model, all its GGUFs
    /opt/ai/models/audio-cpp/               audio.cpp trees + _framework (lax)
    /opt/ai/models/vllm/<model>/            vLLM weights (lax)
    /opt/ai/models/onnx/                    reserved for the doc-models image

Download into a staging directory on the same filesystem, then move the files in,
so an interrupted pull never leaves a half-file where a stanza points:

    ssh phx
    hf download <repo> --local-dir /opt/ai/_dl/<model> --include "<file>.gguf"
    mkdir -p /opt/ai/models/llama-cpp/<model>
    mv /opt/ai/_dl/<model>/*.gguf /opt/ai/models/llama-cpp/<model>/
    rm -rf /opt/ai/_dl

`--local-dir` also writes a `.cache/huggingface` metadata directory; throwing
the staging dir away keeps the model tree to plain `.gguf` files, like the
existing ones.

Check free space on the *right* filesystem first (`df -h /`; `lax` and `phx` both
load from the root volume, and `/tank` on `lax` is a separate 1.8 TB spinner).

## Verify before wiring it up

- **Size**: `ls -lh`, compare with the repo's file listing
  (`https://huggingface.co/api/models/<repo>/tree/main?recursive=true`).
- **It is the file it claims to be**: read the GGUF metadata — architecture,
  layer count, context, and for an mmproj `general.type: mmproj`
  (`references/topology.md` and `patterns/inspect-a-gguf.md`).
- **Reachability**: after the stanza points at it, the first request should be a
  load, not a download. A minute-plus with the network busy means it is not the
  file you think it is.

## Traps

| Symptom | Cause |
|---|---|
| first request hangs, then `health check timed out` | cold 20 GB load outlasted the global 300 s — raise the stanza's `healthCheckTimeout` |
| `failed to load model` / file not found | path is host-absolute (`/opt/ai/...`) instead of container (`/models/...`) |
| `hf download` filled the disk | repo-wide pull; you wanted one filename |
| permission denied on a mounted file | downloaded as root |
| weights load at ~50 MB/s | sitting on `/tank` (spinning) instead of the root NVMe |
| 401/403 from `hf` | no token on the host; the containers get one at deploy, the host may not |
