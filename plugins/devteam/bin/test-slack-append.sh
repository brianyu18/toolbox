#!/bin/sh
# Smoke test for slack-append.sh — verifies sequential + concurrent appends.
set -eu

TMPROOT=$(mktemp -d)
export DEVTEAM_STATE_DIR="$TMPROOT/state"
mkdir -p "$DEVTEAM_STATE_DIR" "$TMPROOT/.devteam"
cd "$TMPROOT"

HELPER="$OLDPWD/plugins/devteam/bin/slack-append.sh"
[ -x "$HELPER" ] || { echo "FAIL: helper not executable: $HELPER"; exit 1; }

"$HELPER" "[TEST] INFO  hello" || { echo "FAIL: single append"; exit 1; }
LINES=$(wc -l < "$DEVTEAM_STATE_DIR/slack.md")
[ "$LINES" -eq 1 ] || { echo "FAIL: expected 1 line, got $LINES"; exit 1; }

i=0
while [ $i -lt 20 ]; do
  "$HELPER" "[CONCURRENT$i] INFO  msg" &
  i=$((i+1))
done
wait
LINES=$(wc -l < "$DEVTEAM_STATE_DIR/slack.md")
[ "$LINES" -eq 21 ] || { echo "FAIL: expected 21 lines, got $LINES"; exit 1; }

BAD=$(grep -cv "^#" "$DEVTEAM_STATE_DIR/slack.md" || true)
[ "$BAD" -eq 0 ] || { echo "FAIL: $BAD malformed lines"; exit 1; }

echo "OK: all slack-append smoke tests passed"
rm -rf "$TMPROOT"
