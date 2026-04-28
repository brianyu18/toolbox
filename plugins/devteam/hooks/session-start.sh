#!/bin/sh
# devteam SessionStart hook — surfaces project status when entering a repo with .devteam/state/
set -eu

STATE_DIR="${PWD}/.devteam/state"
[ -d "$STATE_DIR" ] || exit 0

PROJECT="$(cat "$STATE_DIR/.project-name" 2>/dev/null || echo "unnamed")"
LAST_PHASE="$(cat "$STATE_DIR/.last-phase" 2>/dev/null || echo "?")"
MODE="$(cat "${PWD}/.devteam/mode" 2>/dev/null || echo "work-together")"

cat <<EOF
[devteam] Active project: $PROJECT (mode: $MODE, last phase: $LAST_PHASE)
[devteam] Run /lead-status to inspect, /lead to resume, /lead-abort to stop.
EOF
