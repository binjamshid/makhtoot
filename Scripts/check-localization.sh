#!/usr/bin/env bash
# Fails when a shipping SwiftUI view literal contains Latin letters but no Arabic
# script — a proxy for an English string leaking into an Arabic-only UI.
#
# Why this exists (portfolio house standard, matrix row 1 / house-standard "A
# localization ratchet with BASELINE=0 runs in CI"): Makhtoot is Arabic-only by
# design (D-100, D-475 — `ar` is the sole development region and localization;
# every user-facing string routes through `Makhtoot/Resources/Localizable.xcstrings`,
# whose keys ARE the Arabic source text). ghawazi's version of this ratchet guards
# Base/ar key PARITY between two catalogs; Makhtoot has only one catalog, so the
# equivalent failure mode is inverted: an English literal quietly shipping inside
# an otherwise all-Arabic UI. This is the ratchet SHAPE (count violations, pin a
# BASELINE, only let it go down), adapted to a single-catalog app — not a port of
# ghawazi's parser.
#
# A "violation" is a `Text(`/`Label(`/`Button(`/`navigationTitle(`/`Section(` call
# whose first string-literal argument contains at least one Latin letter [A-Za-z]
# and NO Arabic-script codepoint (U+0600-U+06FF, U+0750-U+077F, U+08A0-U+08FF,
# U+FB50-U+FDFF, U+FE70-U+FEFF). Interpolated literals (containing `\(`) are
# skipped — the check cannot judge runtime-substituted content (same limitation
# ghawazi's script documents for its own interpolation case; a real violation
# hiding behind interpolation still needs a human/reviewer, not this script).
#
# Scope: `Makhtoot/` (the app target — the only place literal UI calls exist in
# this repo; `MakhtootKit/Sources` was checked at authoring time and has zero
# Text/Label/Button/navigationTitle/Section literals, so it is not scanned).
# `Makhtoot/App/Debug/` is excluded: everything under it is `#if DEBUG` developer
# harness UI (perf HUD, shaping/path-text harnesses), never a Release artifact —
# same rationale as ghawazi's SampleData.swift/PrivacyBlur.swift exclusion.
#
# BASELINE = 1 today: `Makhtoot/AppShell/Scenes/Settings/SettingsPlaceholderView.swift`
# has one `Text("Debug")` inside a `#if DEBUG` section header — never ships, but it
# sits in an otherwise-shipping file so the file-level Debug/ exclusion above can't
# catch it. Documented and counted rather than silently allowlisted. DO NOT RAISE.
#
# Usage:
#   Scripts/check-localization.sh          # ratchet check (CI)
#   Scripts/check-localization.sh --list   # print every flagged literal with file:line
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASELINE=1

SOURCE_DIR="Makhtoot"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not found (needed for Unicode script detection)." >&2
  exit 0
fi

out=$(python3 - "$SOURCE_DIR" <<'PYEOF'
import re, sys, os

root = sys.argv[1]
pattern = re.compile(r'\b(Text|Label|Button|navigationTitle|Section)\(\s*"((?:[^"\\]|\\.)*)"')

def is_arabic(ch):
    cp = ord(ch)
    ranges = [
        (0x0600, 0x06FF), (0x0750, 0x077F), (0x08A0, 0x08FF),
        (0xFB50, 0xFDFF), (0xFE70, 0xFEFF),
    ]
    return any(lo <= cp <= hi for lo, hi in ranges)

violations = []
for dirpath, dirnames, filenames in os.walk(root):
    # Prune the DEBUG-only harness directory entirely.
    dirnames[:] = [d for d in dirnames if not os.path.join(dirpath, d).endswith(os.path.join("App", "Debug"))]
    for fn in filenames:
        if not fn.endswith(".swift"):
            continue
        path = os.path.join(dirpath, fn)
        if f"{os.sep}App{os.sep}Debug{os.sep}" in path + os.sep:
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            for lineno, line in enumerate(f, 1):
                for m in pattern.finditer(line):
                    content = m.group(2)
                    if "\\(" in content:
                        continue  # interpolated — cannot judge statically
                    has_latin = re.search(r'[A-Za-z]', content)
                    has_arabic = any(is_arabic(c) for c in content)
                    if has_latin and not has_arabic:
                        violations.append(f"{path}:{lineno}: \"{content}\"")

for v in sorted(violations):
    print(v)
print(f"__COUNT__{len(violations)}")
PYEOF
)

count=$(echo "$out" | grep -oE '__COUNT__[0-9]+' | grep -oE '[0-9]+')
list=$(echo "$out" | grep -v '__COUNT__')

if [ "${1:-}" = "--list" ]; then
  echo "$list"
  echo
fi

echo "Likely English literals in Arabic-only UI: $count (baseline $BASELINE)"
if [ "$count" -gt "$BASELINE" ]; then
  echo "FAIL: $((count - BASELINE)) NEW likely-English literal(s) since the baseline."
  echo "Route the string through Localizable.xcstrings in Arabic, or if it is genuinely"
  echo "debug-only, move it under Makhtoot/App/Debug/. Run with --list to see them all."
  exit 1
fi
if [ "$count" -lt "$BASELINE" ]; then
  echo "Baseline is stale: $count < $BASELINE. Lower BASELINE in this script to $count to lock the gain in."
fi
exit 0
