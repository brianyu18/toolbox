#!/bin/sh
# bin/devteam-watchlist.sh
# Analyze .devteam/state/slack.md + archive/*.md for WATCHLIST lines.
# Groups by signal=<id>, counts occurrences in trailing 14 days,
# compares to thresholds. Outputs ALL CLEAR or ALERT lines.
# Ref: WATCHLIST.md (thresholds) + plan-ceo-review additions.
set -eu

STATE_DIR="${DEVTEAM_STATE_DIR:-${PWD}/.devteam/state}"
SLACK="$STATE_DIR/slack.md"
ARCHIVE_GLOB="$STATE_DIR/archive/*.md"

# Thresholds (mirror WATCHLIST.md)
# Format: SIGNAL=THRESHOLD pairs
THRESHOLD_3a_malformed=3
THRESHOLD_3a_tier_override=5
THRESHOLD_3b_manual_log=2

# 14-day cutoff in epoch seconds
CUTOFF=$(python3 -c "import time; print(int(time.time()) - 14 * 86400)")

# ---------------------------------------------------------------------------
# Collect all WATCHLIST lines from slack.md + archive files into a tmp file
# ---------------------------------------------------------------------------
TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT INT TERM

ALL_LINES="$TMPDIR_LOCAL/watchlist_lines.txt"

# Extract WATCHLIST lines from a file (if it exists)
extract_watchlist() {
  file="$1"
  if [ -f "$file" ]; then
    grep ' WATCHLIST ' "$file" 2>/dev/null || true
  fi
}

extract_watchlist "$SLACK" >> "$ALL_LINES" 2>/dev/null || true

# Archive files (glob expansion — use a for loop, handle no-match gracefully)
for archive in "$STATE_DIR/archive/"*.md; do
  if [ -f "$archive" ]; then
    extract_watchlist "$archive" >> "$ALL_LINES" 2>/dev/null || true
  fi
done

# ---------------------------------------------------------------------------
# Count occurrences per signal within the 14-day window
# Line format: #YY-MM-DD-HH-MM-SS  YYYY-MM-DD HH:MM:SS  [ACTOR#NN] WATCHLIST  signal=<id>  ...
# The timestamp is the second field (after the entry-id).
# ---------------------------------------------------------------------------
count_signal() {
  signal_id="$1"
  # Use python3 for robust date parsing (no GNU date -d needed)
  python3 - "$ALL_LINES" "$signal_id" "$CUTOFF" <<'PYEOF'
import sys, re

lines_file = sys.argv[1]
signal_id  = sys.argv[2]
cutoff     = int(sys.argv[3])

try:
    lines = open(lines_file).readlines()
except FileNotFoundError:
    print(0)
    sys.exit(0)

import datetime, calendar

count = 0
for line in lines:
    # Match: #<id>  <YYYY-MM-DD HH:MM:SS>  ... signal=<id> ...
    ts_match = re.search(r'#\S+\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', line)
    sig_match = re.search(r'signal=(\S+)', line)
    if not ts_match or not sig_match:
        continue
    if sig_match.group(1) != signal_id:
        continue
    try:
        dt = datetime.datetime.strptime(ts_match.group(1), '%Y-%m-%d %H:%M:%S')
        epoch = calendar.timegm(dt.timetuple())
        if epoch >= cutoff:
            count += 1
    except ValueError:
        continue

print(count)
PYEOF
}

# ---------------------------------------------------------------------------
# Compare counts to thresholds; collect alerts
# ---------------------------------------------------------------------------
ALERTS=""

# Helper: add an alert line
add_alert() {
  signal="$1"; count="$2"; threshold="$3"; revisit="$4"
  ALERTS="${ALERTS}ALERT: ${signal} (${count} signals in 14 days, threshold met) — ${revisit}
"
}

# 3a-malformed-output
CNT=$(count_signal "3a-malformed-output")
if [ "$CNT" -ge "$THRESHOLD_3a_malformed" ]; then
  add_alert "3a-malformed-output" "$CNT" "$THRESHOLD_3a_malformed" \
    "Pull 'Prompt regression eval suite (3a)' from TODOS.md into a task"
fi

# 3a-tier-flag-override
CNT=$(count_signal "3a-tier-flag-override")
if [ "$CNT" -ge "$THRESHOLD_3a_tier_override" ]; then
  add_alert "3a-tier-flag-override" "$CNT" "$THRESHOLD_3a_tier_override" \
    "Pull 'Prompt regression eval suite (3a)' from TODOS.md into a task"
fi

# 3b-manual-log
CNT=$(count_signal "3b-manual-log")
if [ "$CNT" -ge "$THRESHOLD_3b_manual_log" ]; then
  add_alert "3b-manual-log" "$CNT" "$THRESHOLD_3b_manual_log" \
    "Pull 'Usage telemetry (3b)' from TODOS.md into a task"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [ -z "$ALERTS" ]; then
  echo "ALL CLEAR"
else
  printf "%s" "$ALERTS"
fi
