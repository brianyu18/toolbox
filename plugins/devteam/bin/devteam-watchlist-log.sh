#!/bin/sh
# bin/devteam-watchlist-log.sh
# User-facing helper to record a manual 3b-manual-log watchlist signal.
# Usage: bash <plugin-path>/bin/devteam-watchlist-log.sh "<one-line observation>"
# Ref: plan Resolved decisions OV-2; WATCHLIST.md Feature 3b.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SLACK_APPEND="$SCRIPT_DIR/slack-append.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") "<one-line observation>"

Record a manual watchlist signal (3b-manual-log) into .devteam/state/slack.md.
The observation must be 1–240 characters.

Example:
  bash \$CLAUDE_PLUGIN_ROOT/bin/devteam-watchlist-log.sh "users confused by tier auto-selection"
EOF
}

if [ "$#" -ne 1 ]; then
  echo "error: exactly one argument required" >&2
  usage >&2
  exit 2
fi

OBSERVATION="$1"

if [ -z "$OBSERVATION" ]; then
  echo "error: observation must not be empty" >&2
  usage >&2
  exit 2
fi

OBS_LEN=$(printf "%s" "$OBSERVATION" | wc -c | tr -d ' ')
if [ "$OBS_LEN" -gt 240 ]; then
  echo "error: observation too long (${OBS_LEN} chars, max 240)" >&2
  exit 2
fi

# Delegate to slack-append.sh; [USER#] placeholder gets counter-substituted.
sh "$SLACK_APPEND" "[USER#] WATCHLIST  signal=3b-manual-log  detail=${OBSERVATION}"

echo "Logged watchlist signal: 3b-manual-log — ${OBSERVATION}"
