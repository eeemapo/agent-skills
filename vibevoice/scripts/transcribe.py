#!/usr/bin/env python3
import argparse, base64, json, os, sys, urllib.request, urllib.error, re, configparser

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(SCRIPT_DIR, 'config.ini')

def load_config():
    if not os.path.isfile(CONFIG_PATH):
        sys.stderr.write(f"Config file not found: {CONFIG_PATH}\n")
        sys.exit(1)
    cfg = configparser.ConfigParser()
    cfg.read(CONFIG_PATH)
    if 'SERVER' not in cfg:
        sys.stderr.write("Config error: [SERVER] section missing in config.ini\n")
        sys.exit(1)
    url = cfg.get('SERVER', 'URL', fallback='').strip()
    api_key = cfg.get('SERVER', 'API_KEY', fallback='').strip()
    if not url:
        sys.stderr.write("Config error: SERVER.URL is empty in config.ini\n")
        sys.exit(1)
    if not api_key:
        sys.stderr.write("Config error: SERVER.API_KEY is empty in config.ini\n")
        sys.exit(1)
    return url, api_key

def transcribe_audio(audio_path, context_info, server_url, api_key):
    with open(audio_path, 'rb') as f:
        b64 = base64.b64encode(f.read()).decode()
    payload = {
        "audio_base64": b64,
        "context_info": context_info,
        "max_tokens": 256,
        "temperature": 0.0,
        "top_p": 1.0,
        "repetition_penalty": 1.0
    }
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        server_url.rstrip('/') + '/v1/transcribe',
        data=data,
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_key}'
        },
        method='POST'
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        err = e.read().decode(errors='ignore')
        sys.stderr.write(f"Server error {e.code}: {err}\n")
        sys.exit(1)
    except urllib.error.URLError as e:
        reason = e.reason
        if isinstance(reason, TimeoutError):
            sys.stderr.write("Server error: request timed out\n")
        else:
            sys.stderr.write(f"Server error: {reason}\n")
        sys.exit(1)
    except TimeoutError:
        sys.stderr.write("Server error: request timed out\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"Server error: {e}\n")
        sys.exit(1)

def write_markdown(data, out_path):
    total_chunks = data.get('total_chunks', 'N/A')
    audio_duration = data.get('audio_duration', 'N/A')
    generate_time = data.get('generate_time', 'N/A')
    rtf = data.get('rtf', 'N/A')
    lines = []
    lines.append('# Transcript Report')
    lines.append('')
    lines.append('## INFO')
    lines.append(f"- **File**: {os.path.basename(out_path)}")
    lines.append(f"- **Total chunks**: {total_chunks}")
    lines.append(f"- **Audio duration**: {audio_duration} s")
    lines.append(f"- **Generate time**: {generate_time} s")
    lines.append(f"- **RTF**: {rtf}")
    lines.append('')
    lines.append('## TRANSCRIPT')
    lines.append('')
    segments = data.get('segments')
    if segments and isinstance(segments, list):
        for seg in segments:
            speaker = seg.get('Speaker', '?')
            start = seg.get('Start', 0)
            end = seg.get('End', 0)
            content = seg.get('Content', '').strip()
            lines.append(f"**Speaker {speaker}** - {start:.2f}-{end:.2f}s: {content}")
    else:
        # Integrated gen_md.py logic for chunk-based transcripts
        chunk_texts = data.get('chunk_texts', [])
        total = total_chunks if isinstance(total_chunks, int) else len(chunk_texts)
        if total > 0 and isinstance(audio_duration, (int, float)):
            chunk_dur = audio_duration / total
        else:
            chunk_dur = 2.933333

        # Use gen_md style when full text is available
        if data.get('text'):
            text = data['text']
            pat_text = re.compile(r"Speaker\s*(\d+):\s*(.*?)(?=\n\s*Speaker\s*\d+:|$)", re.DOTALL)
            turns = []
            for m in pat_text.finditer(text):
                spk = m.group(1)
                txt = " ".join(m.group(2).split())
                if txt:
                    turns.append((spk, txt))
            pat_chunk = re.compile(r"Speaker\s*(\d+):")
            markers = []
            for i, c in enumerate(chunk_texts):
                for m in pat_chunk.finditer(c):
                    markers.append(i)
            if turns and markers:
                for (spk, txt), i in zip(turns, markers):
                    t = i * chunk_dur
                    lines.append(f"[{t:.2f}s] **Speaker {spk}** : {txt}")
            else:
                lines.append('*No transcript data found*')
        else:
            # Fallback: simple per-chunk first speaker extraction
            speaker_pat = re.compile(r'Speaker\s*(\d+):\s*(.*?)(?=\s*Speaker\s*\d+:|$)', re.DOTALL)
            if chunk_texts:
                for i, chunk in enumerate(chunk_texts):
                    segs = list(speaker_pat.finditer(chunk))
                    if segs:
                        spk = segs[0].group(1)
                        txt = " ".join(segs[0].group(2).split())
                        if txt:
                            t = i * chunk_dur
                            lines.append(f"[{t:.2f}s] **Speaker {spk}** : {txt}")
            else:
                lines.append('*No transcript data found*')
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

def build_context(speakers, hotwords, scene):
    speaker_part = ""
    if speakers:
        s = speakers.strip()
        if re.fullmatch(r'\d+', s):
            n = int(s)
            speaker_part = f"{n} speakers"
        else:
            names = [n.strip() for n in s.split(',') if n.strip()]
            if len(names) > 0:
                # Drop count prefix, use names only as requested
                speaker_part = ', '.join(names)
    parts = []
    if speaker_part:
        parts.append(speaker_part)
    if scene:
        parts.append(scene.strip())
    if hotwords:
        parts.append(f"Hotwords: {hotwords}")
    return '. '.join(parts)

def main():
    parser = argparse.ArgumentParser(
        description='Transcribe audio via VibeVoice streaming ASR',
        prog='transcribe.py'
    )
    parser.add_argument('audio', help='Audio file path to transcribe')
    parser.add_argument('--speakers', '-s', default='', help='Speaker count e.g. 2 or names comma separated e.g. Interviewer,Interviewee')
    parser.add_argument('--hotwords', '-w', default='', help='Comma separated hotwords to bias recognition')
    parser.add_argument('--context', '-c', default='', help='Context description to provide context')
    parser.add_argument('--url', '-u', default=None, help='Override server base URL from config.ini')
    parser.add_argument('--api-key', '-k', default=None, help='Override API key from config.ini')
    parser.add_argument('--output', '-o', choices=['json','markdown','raw'], help='Output format. json -> <name>.json file, markdown -> <name>.md file, raw -> print raw server JSON to stdout. If omitted, raw JSON is printed to stdout')
    args = parser.parse_args()

    if not os.path.isfile(args.audio):
        sys.stderr.write(f"Audio file not found: {args.audio}\n")
        sys.exit(1)

    cfg_url, cfg_key = load_config()
    server_url = args.url or cfg_url
    api_key = args.api_key or cfg_key

    if not server_url:
        sys.stderr.write("Config error: server URL is empty\n")
        sys.exit(1)
    if not api_key:
        sys.stderr.write("Config error: API key is empty\n")
        sys.exit(1)

    context_info = build_context(args.speakers, args.hotwords, args.context)

    print(f"Transcribing {args.audio} ...", file=sys.stderr)
    print(f"Server: {server_url}", file=sys.stderr)
    if context_info:
        print(f"Context: {context_info}", file=sys.stderr)

    data = transcribe_audio(args.audio, context_info, server_url, api_key)

    if args.output is None:
        json.dump(data, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write('\n')
    elif args.output == 'raw':
        json.dump(data, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write('\n')
    elif args.output == 'json':
        base_name = os.path.splitext(os.path.basename(args.audio))[0]
        out_dir = os.path.dirname(args.audio) or '.'
        out_path = os.path.join(out_dir, f"{base_name}.json")
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Done -> {out_path}")
    else:
        base_name = os.path.splitext(os.path.basename(args.audio))[0]
        out_dir = os.path.dirname(args.audio) or '.'
        out_path = os.path.join(out_dir, f"{base_name}.md")
        write_markdown(data, out_path)
        print(f"Done -> {out_path}")

if __name__ == '__main__':
    main()
