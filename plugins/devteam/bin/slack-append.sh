#!/bin/sh
# bin/slack-append.sh "<entry-line>"
# Race-safe append using mkdir-mutex (POSIX-portable; no flock dependency).
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 \"<entry-line>\"" >&2
  exit 2
fi

STATE_DIR="${DEVTEAM_STATE_DIR:-${PWD}/.devteam/state}"
LOCKDIR="${PWD}/.devteam/slack.lock.d"
SLACK="$STATE_DIR/slack.md"

mkdir -p "$STATE_DIR" "$(dirname "$LOCKDIR")"
touch "$SLACK"

TRIES=0
while ! mkdir "$LOCKDIR" 2>/dev/null; do
  # OV-3: stale-lock detection. If lockdir is older than 30s, presume the previous
  # holder crashed without releasing. Force-remove and retake.
  if [ -d "$LOCKDIR" ]; then
    # Capture mtime; if stat fails (lockdir vanished between check and stat), skip
    # stale detection — another holder just released it naturally.
    LOCK_MTIME=$(stat -f %m "$LOCKDIR" 2>/dev/null || stat -c %Y "$LOCKDIR" 2>/dev/null || echo "")
    if [ -n "$LOCK_MTIME" ]; then
      LOCK_AGE=$(( $(date +%s) - LOCK_MTIME ))
      if [ "$LOCK_AGE" -gt 30 ]; then
        echo "slack-append: stale lockdir (age ${LOCK_AGE}s) — force-removing" >&2
        rmdir "$LOCKDIR" 2>/dev/null || rm -rf "$LOCKDIR"
        continue
      fi
    fi
  fi
  sleep 0.05
  TRIES=$((TRIES+1))
  if [ "$TRIES" -gt 200 ]; then
    echo "slack-append: lock timeout after 10s, forcing append" >&2
    break
  fi
done
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT INT TERM

# C4: per-actor counter management. Caller's entry-line is expected to contain a
# `[ACTOR#]` placeholder that this script substitutes with the next counter value
# for that actor. Counter files live at $STATE_DIR/.counters/<actor>.
ENTRY_LINE="$1"
if echo "$ENTRY_LINE" | grep -q '\[[^]]*#\]'; then
  ACTOR=$(echo "$ENTRY_LINE" | sed -E 's/.*\[([^]]+)#\].*/\1/')
  CTR_DIR="$STATE_DIR/.counters"
  CTR_FILE="$CTR_DIR/$ACTOR"
  mkdir -p "$CTR_DIR"
  CUR=$(cat "$CTR_FILE" 2>/dev/null || echo 0)
  NXT=$((CUR + 1))
  printf "%d" "$NXT" > "$CTR_FILE"
  ENTRY_LINE=$(echo "$ENTRY_LINE" | sed "s/\[$ACTOR#\]/[$ACTOR#$NXT]/")
fi

TS=$(date -u +"%Y-%m-%d %H:%M:%S")
ID=$(date -u +"%y-%m-%d-%H-%M-%S")
printf "#%s  %s  %s\n" "$ID" "$TS" "$ENTRY_LINE" >> "$SLACK"
