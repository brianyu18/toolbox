#!/bin/sh
# bin/devteam-detect-stack.sh
# Detect which conventions apply to the project at PWD. Reads
# ${CLAUDE_PLUGIN_ROOT}/conventions-seed/index.json (populated in Stage 8).
# Ref: plan Resolved decisions A4.
#
# Design decision: test layer names are stored inline in each index.json entry
# as a "tests" array field. The --tests flag reads that field instead of
# emitting convention paths. This keeps a single index.json as source of truth.
set -eu

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Detect which convention files apply to the project at PWD (or --project-dir).
Outputs absolute paths under conventions-seed/ (one per line).

OPTIONS:
  --tests              Instead of convention paths, output detected TEST layer
                       names (e.g. jest, vitest, pytest, bun:test, pine).
  --project-dir <dir>  Scan this dir instead of PWD (useful in tests/scripts).
  -h, --help           Show this help

ENV:
  CLAUDE_PLUGIN_ROOT   Plugin install dir. Derived from script location if unset.
EOF
}

MODE=convention
PROJECT_DIR_OVERRIDE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --tests) MODE=tests; shift ;;
    --project-dir) PROJECT_DIR_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Derive CLAUDE_PLUGIN_ROOT from script location if unset
if [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  CLAUDE_PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

INDEX="$CLAUDE_PLUGIN_ROOT/conventions-seed/index.json"

if [ ! -f "$INDEX" ]; then
  echo "devteam-detect-stack: index.json not found at $INDEX (Stage 8 not yet run)" >&2
  exit 0
fi

# Validate JSON (hard fail on malformed — exit 2)
if ! python3 -c "import json, sys; json.load(open('$INDEX'))" 2>/dev/null; then
  echo "devteam-detect-stack: malformed JSON in $INDEX" >&2
  exit 2
fi

if [ -n "$PROJECT_DIR_OVERRIDE" ]; then
  PROJECT_DIR="$PROJECT_DIR_OVERRIDE"
else
  PROJECT_DIR="${PWD}"
fi
CONV_BASE="$CLAUDE_PLUGIN_ROOT/conventions-seed"

# Use Python3 to evaluate signals and emit results.
# We pass MODE and PROJECT_DIR via env so the heredoc stays clean.
python3 - "$INDEX" "$CONV_BASE" "$PROJECT_DIR" "$MODE" <<'PYEOF'
import json, sys, os, re

index_path = sys.argv[1]
conv_base  = sys.argv[2]
project_dir = sys.argv[3]
mode = sys.argv[4]  # "convention" or "tests"

with open(index_path) as f:
    raw = json.load(f)

# Support two formats:
#   - Legacy (tests): raw list of {"convention": "...", "signals": [...], "tests": [...]}
#   - Stage-8 format: {"version": 1, "stacks": [{"name": "...", "convention_files": [...], ...}]}
if isinstance(raw, list):
    entries = raw
    def get_conventions(entry):
        c = entry.get("convention", "")
        return [c] if c else []
else:
    entries = raw.get("stacks", [])
    def get_conventions(entry):
        return entry.get("convention_files", [])

def signal_matches(signal, project_dir):
    """Return True if a single signal dict matches the project at project_dir."""
    if "file_exists" in signal:
        path = os.path.join(project_dir, signal["file_exists"])
        return os.path.exists(path)
    if "file_contains" in signal:
        fc = signal["file_contains"]
        path = os.path.join(project_dir, fc["file"])
        pattern = fc["pattern"]
        if not os.path.exists(path):
            return False
        try:
            content = open(path).read()
            return bool(re.search(pattern, content))
        except Exception:
            return False
    return False

seen_tests = set()

for entry in entries:
    signals = entry.get("signals", [])
    tests   = entry.get("tests", [])

    # Convention matches if ANY signal matches
    matched = any(signal_matches(s, project_dir) for s in signals)
    if not matched:
        continue

    if mode == "convention":
        for convention in get_conventions(entry):
            abs_path = os.path.join(conv_base, convention)
            print(abs_path)
    else:
        for t in tests:
            if t not in seen_tests:
                seen_tests.add(t)
                print(t)
PYEOF
