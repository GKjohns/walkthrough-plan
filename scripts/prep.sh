#!/usr/bin/env bash
#
# prep.sh — extract audio + frames from a walkthrough video and transcribe it.
# Part of the walkthrough-plan skill.
#
# Usage: prep.sh <video> [workdir] [frame_interval_seconds]
#   video      path to the walkthrough video (.mov/.mp4/etc)
#   workdir    output dir (default: <video_dir>/walkthrough_plan)
#   interval   seconds between extracted frames (default: 5)
#
# Requires: ffmpeg, ffprobe, curl, python3, and $OPENAI_API_KEY in the environment.
# Outputs in workdir: audio.mp3, frames/frame_NNN.jpg, transcript.json,
#                     transcript_timestamped.md
#
set -euo pipefail

VIDEO="${1:?usage: prep.sh <video> [workdir] [frame_interval_seconds]}"
[ -f "$VIDEO" ] || { echo "error: video not found: $VIDEO" >&2; exit 1; }
WORKDIR="${2:-$(cd "$(dirname "$VIDEO")" && pwd)/walkthrough_plan}"
INTERVAL="${3:-5}"

for bin in ffmpeg ffprobe curl python3; do
  command -v "$bin" >/dev/null 2>&1 || { echo "error: $bin not installed" >&2; exit 1; }
done
: "${OPENAI_API_KEY:?error: OPENAI_API_KEY not set in environment}"

mkdir -p "$WORKDIR/frames"
echo "→ workdir: $WORKDIR"

DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO")
printf "→ video duration: %.0f s\n" "$DUR"

echo "→ extracting audio (mono 16k mp3)…"
ffmpeg -y -i "$VIDEO" -ac 1 -ar 16000 -b:a 64k "$WORKDIR/audio.mp3" -loglevel error
ASZ=$(du -m "$WORKDIR/audio.mp3" | cut -f1)
if [ "$ASZ" -ge 25 ]; then
  echo "  audio is ${ASZ}MB (Whisper limit is 25MB) — re-encoding lower…"
  ffmpeg -y -i "$VIDEO" -ac 1 -ar 12000 -b:a 32k "$WORKDIR/audio.mp3" -loglevel error
fi

echo "→ extracting frames every ${INTERVAL}s (640px wide)…"
ffmpeg -y -i "$VIDEO" -vf "fps=1/${INTERVAL},scale=640:-1" -q:v 4 \
  "$WORKDIR/frames/frame_%03d.jpg" -loglevel error
NF=$(find "$WORKDIR/frames" -name 'frame_*.jpg' | wc -l | tr -d ' ')
echo "  $NF frames (frame_NNN ≈ (NNN-1)*${INTERVAL} seconds)"

echo "→ transcribing with Whisper…"
curl -s https://api.openai.com/v1/audio/transcriptions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F file=@"$WORKDIR/audio.mp3" \
  -F model=whisper-1 \
  -F response_format=verbose_json \
  -F "timestamp_granularities[]=segment" \
  -o "$WORKDIR/transcript.json"

python3 - "$WORKDIR" "$INTERVAL" <<'PY'
import json, sys
workdir, interval = sys.argv[1], int(sys.argv[2])
d = json.load(open(f"{workdir}/transcript.json"))
if "segments" not in d:
    sys.stderr.write("  ! Whisper returned no segments. transcript.json head:\n   "
                     + str(d)[:300] + "\n")
    sys.exit(1)
mmss = lambda t: f"{int(t//60):02d}:{int(t%60):02d}"
lines = []
for s in d["segments"]:
    frame = int(s["start"] // interval) + 1
    lines.append(f"[{mmss(s['start'])}–{mmss(s['end'])}] (≈frame_{frame:03d}) {s['text'].strip()}")
with open(f"{workdir}/transcript_timestamped.md", "w") as f:
    f.write("# Walkthrough — timestamped transcript\n\n" + "\n".join(lines) + "\n")
print(f"  {len(d['segments'])} segments → transcript_timestamped.md")
PY

echo "✓ prep done."
echo "  Next: run the visual-analysis subagent on frames/ + transcript_timestamped.md"
echo "  workdir: $WORKDIR"
