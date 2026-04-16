#!/bin/bash

VAULT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/elBrain"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
INBOX="$HOME/Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/audio"
OUTPUT="$VAULT/voice-memos"
MEDIA="$VAULT/media"
LOCKFILE="/tmp/voice-transcribe.lock"
LOG="/tmp/voice-transcribe.log"
MODEL="mlx-community/whisper-large-v3-turbo"
PYTHON="/usr/local/bin/python3"
CLAUDE="$HOME/.local/bin/claude"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"; }

# prevent concurrent runs
if [ -f "$LOCKFILE" ]; then
    pid=$(cat "$LOCKFILE")
    if kill -0 "$pid" 2>/dev/null; then
        log "already running (pid $pid), exiting"
        exit 0
    fi
fi
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

mkdir -p "$INBOX" "$OUTPUT" "$MEDIA"

export PATH="/opt/homebrew/bin:$HOME/Library/Python/3.11/bin:$HOME/.local/bin:$PATH"

shopt -s nullglob
files=("$INBOX"/*.m4a "$INBOX"/*.mp4 "$INBOX"/*.wav "$INBOX"/*.mp3 "$INBOX"/*.caf)
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
    log "no audio files found"
    exit 0
fi

for audio_file in "${files[@]}"; do
    filename=$(basename "$audio_file")
    stem="${filename%.*}"
    md_file="$OUTPUT/${stem}.md"

    # avoid collisions
    counter=1
    while [ -f "$md_file" ]; do
        md_file="$OUTPUT/${stem}_${counter}.md"
        counter=$((counter + 1))
    done

    # skip files still syncing via iCloud
    size1=$(stat -f%z "$audio_file" 2>/dev/null || echo 0)
    sleep 2
    size2=$(stat -f%z "$audio_file" 2>/dev/null || echo 0)
    if [ "$size1" != "$size2" ]; then
        log "file still syncing: $filename, will retry next run"
        continue
    fi

    log "transcribing: $filename"

    duration=$(ffprobe -v quiet -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$audio_file" 2>/dev/null)
    duration_formatted=$(printf '%02d:%02d' $(( ${duration%.*} / 60 )) $(( ${duration%.*} % 60 )) 2>/dev/null || echo "unknown")

    transcript=$($PYTHON -c "
import mlx_whisper, sys
result = mlx_whisper.transcribe(sys.argv[1], path_or_hf_repo='$MODEL')
print(result['text'].strip())
" "$audio_file" 2>> "$LOG")

    if [ -z "$transcript" ]; then
        log "FAILED: empty transcript for $filename"
        continue
    fi

    file_date=$(stat -f '%Sm' -t '%Y-%m-%d' "$audio_file" 2>/dev/null || date '+%Y-%m-%d')
    file_time=$(stat -f '%Sm' -t '%H:%M' "$audio_file" 2>/dev/null || date '+%H:%M')
    now=$(date '+%Y-%m-%dT%H:%M:%S')

    moved_audio="$MEDIA/$filename"
    mv "$audio_file" "$moved_audio"
    log "moved source: $filename -> media/"

    audio_link="[audio](media/$filename)"

    cat > "$md_file" << MARKDOWN
---
type: voice-memo
source: $filename
recorded: ${file_date}T${file_time}
transcribed: $now
duration: $duration_formatted
tags:
  - voice-memo
---

# $stem

$audio_link

$transcript
MARKDOWN

    log "saved: $md_file"

    # rename based on content
    file_date_dot=$(stat -f '%Sm' -t '%Y.%m.%d' "$moved_audio" 2>/dev/null || date '+%Y.%m.%d')
    ext="${filename##*.}"
    new_name=$($CLAUDE -p --model haiku "Read this transcript and suggest a short descriptive filename (2-3 lowercase words, separated by dashes, no extension, no date, no quotes). Just output the name, nothing else." < "$md_file" 2>> "$LOG" | tr -d '[:space:]')

    if [ -n "$new_name" ]; then
        new_stem="${new_name}_${file_date_dot}"
        new_md="$OUTPUT/${new_stem}.md"
        new_audio="$MEDIA/${new_stem}.${ext}"

        # avoid collisions
        counter=1
        while [ -f "$new_md" ] || [ -f "$new_audio" ]; do
            new_md="$OUTPUT/${new_stem}_${counter}.md"
            new_audio="$MEDIA/${new_stem}_${counter}.${ext}"
            counter=$((counter + 1))
        done

        new_audio_basename=$(basename "$new_audio")
        sed -i '' "s|\[audio\](media/.*)|[audio](media/$new_audio_basename)|" "$md_file"
        sed -i '' "s|^# .*|# ${new_stem}|" "$md_file"
        mv "$md_file" "$new_md"
        mv "$moved_audio" "$new_audio"
        md_file="$new_md"
        log "renamed: ${new_stem}.md + ${new_stem}.${ext}"
    else
        log "rename failed, keeping original name"
    fi

    log "formatting with claude: $md_file"
    $CLAUDE -p --model sonnet "Format this voice memo transcription. Fix punctuation, add paragraphs, fix grammar but keep original meaning and wording. Keep the YAML frontmatter and audio link exactly as they are. Output the entire file." < "$md_file" > "${md_file}.tmp" 2>> "$LOG"
    if [ -s "${md_file}.tmp" ]; then
        mv "${md_file}.tmp" "$md_file"
        log "formatted: $md_file"
    else
        rm -f "${md_file}.tmp"
        log "formatting failed, keeping raw transcript: $md_file"
    fi
done

log "batch complete"
