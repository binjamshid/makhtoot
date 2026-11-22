#!/usr/bin/env bash
# check-no-stubs.sh — the "no coming soon, ever" ratchet (ANDROID_SPINE.md §4
# ground rule 3, §11; work item 1.1).
#
# Greps the Android tree for TODO(, NotImplementedError, notYetPorted, قريبًا
# ("coming soon"), "coming soon", Placeholder — every vocabulary item the plan
# treats as evidence of a stubbed/deferred feature. Every hit is checked against
# Scripts/android/no-stubs-allowlist.txt before failing: MkNotYetPorted.kt
# (extends NotImplementedError by construction, spine §3.3) and
# MkSettingsPlaceholderView.kt (the pre-existing iOS placeholder screen's
# Android port) are legitimate, permanent matches, not stub debt — without the
# allowlist this check could never pass even at G8.
#
# Severity: advisory (non-blocking exit code) from G1 through G7; BLOCKING
# (non-zero exit on any un-allowlisted hit) from G8 onward (spine ground rule
# 3). gate.sh passes the batch/gate number so this script knows which mode to
# run in — it is never hand-invoked with the wrong severity by a human running
# it standalone without an argument (defaults to advisory, the safer direction).
#
# Usage:
#   Scripts/android/check-no-stubs.sh              # advisory (prints findings, exit 0)
#   Scripts/android/check-no-stubs.sh --gate 8      # blocking (non-zero exit on any hit)
#   Scripts/android/check-no-stubs.sh --gate 5      # advisory (gate < 8)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ALLOWLIST="Scripts/android/no-stubs-allowlist.txt"
SEARCH_DIR="android"

BLOCKING=0
if [ "${1:-}" = "--gate" ]; then
    gate_num="${2:-0}"
    if [ "$gate_num" -ge 8 ] 2>/dev/null; then
        BLOCKING=1
    fi
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not found." >&2
    exit 0
fi

allowlist_paths=""
if [ -f "$ALLOWLIST" ]; then
    allowlist_paths=$(grep -v '^\s*#' "$ALLOWLIST" | grep -v '^\s*$' || true)
fi

out=$(python3 - "$SEARCH_DIR" <<'PYEOF'
import re, sys, os

root = sys.argv[1]
patterns = [
    r'TODO\(',
    r'NotImplementedError',
    r'notYetPorted',
    r'قريبًا',
    r'[Cc]oming [Ss]oon',
    r'Placeholder',
]
combined = re.compile('|'.join(patterns))

hits = []
for dirpath, dirnames, filenames in os.walk(root):
    # Never scan vendored third-party native source (Agent 1.2) — its own
    # upstream comments/macros are not this repo's stub vocabulary.
    if 'third_party' in dirpath.split(os.sep):
        continue
    for fn in filenames:
        if not (fn.endswith('.kt') or fn.endswith('.kts')):
            continue
        path = os.path.join(dirpath, fn)
        try:
            with open(path, encoding='utf-8', errors='ignore') as f:
                for lineno, line in enumerate(f, start=1):
                    if combined.search(line):
                        hits.append(f"{path}:{lineno}:{line.rstrip()}")
        except OSError:
            continue

print('\n'.join(hits))
PYEOF
)

if [ -z "$out" ]; then
    echo "check-no-stubs: clean (0 hits)."
    exit 0
fi

# Filter allowlisted paths.
filtered=""
while IFS= read -r line; do
    [ -z "$line" ] && continue
    file_path="${line%%:*}"
    skip=0
    if [ -n "$allowlist_paths" ]; then
        while IFS= read -r allowed; do
            [ -z "$allowed" ] && continue
            if [ "$file_path" = "$allowed" ]; then
                skip=1
                break
            fi
        done <<< "$allowlist_paths"
    fi
    if [ "$skip" -eq 0 ]; then
        filtered="${filtered}${line}
"
    fi
done <<< "$out"

if [ -z "$filtered" ]; then
    echo "check-no-stubs: clean after allowlist (only allowlisted matches found)."
    exit 0
fi

echo "check-no-stubs: findings (not all are failures unless --gate 8+):" >&2
printf '%s' "$filtered" >&2

if [ "$BLOCKING" -eq 1 ]; then
    echo "" >&2
    echo "FAIL: check-no-stubs is BLOCKING at this gate (G8+) and found un-allowlisted matches." >&2
    exit 1
fi

echo "" >&2
echo "ADVISORY: check-no-stubs found matches but is not yet blocking (< G8)." >&2
exit 0
