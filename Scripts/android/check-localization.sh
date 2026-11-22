#!/usr/bin/env bash
# check-localization.sh — Android sibling of Scripts/check-localization.sh
# (ANDROID_SPINE.md §2 D-318, §3 house-pattern reference; work item 1.1).
#
# Why this exists (same rationale as the iOS ratchet, restated for Compose):
# Makhtoot is Arabic-only by design; every user-facing Android string routes
# through a strings.xml resource from work item 1.1 (spine §11) or a
# Compose call referencing R.string.*. This script flags a Latin-lettered,
# non-Arabic-script string LITERAL sitting directly inside a shipping Composable
# call (Text(...), Button(...) with an inline label, TopAppBar title, etc.) — a
# proxy for an English string leaking into an Arabic-only UI instead of being
# routed through stringResource(R.string.*).
#
# A "violation" is a `Text(`/`Button(`/`TopAppBar(`/`AlertDialog(` call whose
# first string-literal argument contains at least one Latin letter [A-Za-z] and
# NO Arabic-script codepoint (U+0600-U+06FF, U+0750-U+077F, U+08A0-U+08FF,
# U+FB50-U+FDFF, U+FE70-U+FEFF). String-template literals (containing `${`) are
# skipped — the check cannot judge runtime-substituted content, same limitation
# the iOS script documents for Swift string interpolation.
#
# Scope: android/app/src/main/kotlin/** and android/app/src/debug/kotlin/**
# (the :app Compose screens — the only place literal UI calls are expected to
# exist; every mk-* engine module is UI-free by construction). Excludes
# android/*/src/test/** and android/*/src/androidTest/** (test code, never
# ships).
#
# BASELINE = 0: no Android Compose source exists yet as of Batch 1 (Agent 1.4's
# :app stub scope is Kotlin-only signatures/data classes this batch, not
# Composables) — this ratchet starts at zero and must never rise.
#
# Usage:
#   Scripts/android/check-localization.sh          # ratchet check (CI)
#   Scripts/android/check-localization.sh --list   # print every flagged literal with file:line

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BASELINE=0
SOURCE_DIRS="android/app/src/main/kotlin android/app/src/debug/kotlin"

if ! command -v python3 >/dev/null 2>&1; then
    echo "SKIP: python3 not found (needed for Unicode script detection)." >&2
    exit 0
fi

out=$(python3 - "$SOURCE_DIRS" <<'PYEOF'
import re, sys, os

roots = sys.argv[1].split()
pattern = re.compile(r'\b(Text|Button|TopAppBar|AlertDialog|SmallTopAppBar|LargeTopAppBar)\(\s*"((?:[^"\\]|\\.)*)"')

def is_arabic(ch):
    cp = ord(ch)
    return (
        0x0600 <= cp <= 0x06FF or
        0x0750 <= cp <= 0x077F or
        0x08A0 <= cp <= 0x08FF or
        0xFB50 <= cp <= 0xFDFF or
        0xFE70 <= cp <= 0xFEFF
    )

violations = []
for root in roots:
    if not os.path.isdir(root):
        continue
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            if not fn.endswith('.kt'):
                continue
            path = os.path.join(dirpath, fn)
            with open(path, encoding='utf-8', errors='ignore') as f:
                for lineno, line in enumerate(f, start=1):
                    if '${' in line:
                        continue
                    for m in pattern.finditer(line):
                        literal = m.group(2)
                        has_latin = re.search(r'[A-Za-z]', literal)
                        has_arabic = any(is_arabic(c) for c in literal)
                        if has_latin and not has_arabic:
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
    echo "FAIL: check-localization.sh found ${count} violation(s), BASELINE is ${BASELINE}." >&2
    echo "Run with --list to see them. Route every literal through stringResource(R.string.*)." >&2
    exit 1
fi

echo "check-localization: ${count} violation(s), within BASELINE=${BASELINE}."
exit 0
