#!/usr/bin/env bash
# check-design-tokens.sh — Android sibling of Scripts/check-design-tokens.sh
# (ANDROID_SPINE.md §2 D-317; work item 1.1).
#
# Why this exists: D-317 ports `MkTheme` as a Compose `CompositionLocal` system
# (NOT MaterialTheme) carrying all 5 themes (Hibr, Kufi, Naqsh, Raml, Tayf) with
# identical tokens to iOS. A raw `Color(0x...)`/hex literal or a bare
# `androidx.compose.ui.graphics.Color(...)` call inside a Composable bypasses
# that system exactly the way a raw UIColor literal would bypass MKTheme on
# iOS. This script flags:
#   - `Color(0x` / `Color(0xFF...)` hex-literal construction,
#   - `Color(red = ` / `Color(r = ` component-literal construction,
# outside of `mk-designsystem`'s own token-definition files (which are
# necessarily where the literal RGB values for the 5 themes are defined once,
# by design — MkTheme's own source is the exemption, not a leak).
#
# BASELINE = 0: no Compose UI source exists yet as of Batch 1.
#
# Usage:
#   Scripts/android/check-design-tokens.sh          # ratchet check (CI)
#   Scripts/android/check-design-tokens.sh --list   # print every flagged literal with file:line

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASELINE=0

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not found." >&2
    exit 0
fi

out=$(python3 - <<'PYEOF'
import re, os

pattern = re.compile(r'\bColor\s*\(\s*(0x|red\s*=|r\s*=)')

# mk-designsystem's own token-definition source is the one legitimate place
# raw Color(...) literals are defined (the 5 themes' token tables) — every
# other module/screen must reference MkTheme's CompositionLocal instead.
EXEMPT_MODULE = os.path.join("android", "mk-designsystem")

violations = []
for dirpath, dirnames, filenames in os.walk("android"):
    if dirpath.startswith(EXEMPT_MODULE):
        continue
    if os.sep + "third_party" + os.sep in dirpath + os.sep:
        continue
    for fn in filenames:
        if not fn.endswith('.kt'):
            continue
        path = os.path.join(dirpath, fn)
        with open(path, encoding='utf-8', errors='ignore') as f:
            for lineno, line in enumerate(f, start=1):
                if pattern.search(line):
                    violations.append(f"{path}:{lineno}: {line.strip()}")

print('\n'.join(violations))
PYEOF
)

count=0
if [ -n "$out" ]; then
    count=$(printf '%s\n' "$out" | grep -c .)
fi

if [ "${1:-}" = "--list" ] && [ "$count" -gt 0 ]; then
    printf '%s\n' "$out"
fi

if [ "$count" -gt "$BASELINE" ]; then
    echo "FAIL: check-design-tokens.sh found ${count} raw Color(...) literal(s) outside mk-designsystem, BASELINE is ${BASELINE}." >&2
    echo "Run with --list to see them. Reference MkTheme's CompositionLocal instead." >&2
    exit 1
fi

echo "check-design-tokens: ${count} violation(s), within BASELINE=${BASELINE}."
exit 0
