#!/usr/bin/env bash
# Fails when feature UI code constructs a color outside the `MKTheme` token system.
#
# Why this exists (portfolio house standard / matrix row 8, "token linter — every
# referenced token has a definition"): Makhtoot's tokens are a Swift protocol
# (`MKTheme` in `MakhtootKit/Sources/MKDesignSystem/MKTheme.swift`) with one
# conformer (`InkPaperTheme`), so "every referenced token has a definition" is
# already a compile-time guarantee — the Swift compiler will not build a call site
# that references a protocol member `InkPaperTheme` doesn't implement. A literal
# port of the CSS-custom-property/asset-catalog-name version of this check (which
# exists precisely because THOSE token references are untyped strings the
# compiler can't verify) would be a no-op here.
#
# The faithful adaptation for a compiler-checked token system is the OTHER half of
# the same house-standard obligation, already written down in this repo's own
# decision log and never enforced: D-126's consequences state "token discipline
# must be enforced from P1 (obligation: no literal colors/spacing in feature code —
# lint note in WS-01)." This script is that lint note, finally built. It flags
# feature code that bypasses the token system by constructing a color directly
# (`Color(red:green:blue:...)`, `Color(.sRGB/.displayP3/...)`, `Color("assetName")`)
# or applying a hardcoded system color (`.white`, `.black`, `.red`, ...) via
# `.foregroundColor/.foregroundStyle/.background/.tint/.fill/.stroke`, instead of
# reading `theme.<token>` from the environment (D-126: "every component ... reads
# it via `@Environment(\.mkTheme)`").
#
# Scope: `Makhtoot/App` + `Makhtoot/AppShell` (feature UI). Excluded:
#   - `MakhtootKit/Sources/MKDesignSystem/` — the token module itself must define
#     raw colors; that is its job, not a violation.
#   - `Makhtoot/App/Debug/` — `#if DEBUG` developer-only harnesses (perf HUD etc.),
#     same rationale as check-localization.sh's exclusion.
#   - Comment lines (source line, after trimming leading whitespace, starts with
#     `//`) — a color literal named only in prose (e.g. explaining what the OLD
#     code used to do) is not a live call site.
#   - The exact `file:line` pairs in `EXCLUDE_FILE_LINES` below, each with an
#     inline reason. Hardcoded as individual lines (not whole-file skips) so they
#     stay visible and re-reviewed if the line ever moves and stops matching.
#
# This is definition-completeness/discipline enforcement only — no contrast-ratio
# math (4.5:1 text / 3:1 UI) is performed. `MKTheme` tokens are semantic
# (backgroundPrimary/inkPrimary/accent/...), not raw (fg,bg) hex pairs, so a
# generic WCAG contrast checker has nothing concrete to pair without also encoding
# per-surface semantics this script does not have; flagged as a gap for a future,
# theme-aware follow-up rather than faked here.
#
# It is a RATCHET: BASELINE records known violations. CI fails if the count goes up.
#
# Usage:
#   Scripts/check-design-tokens.sh          # ratchet check (CI)
#   Scripts/check-design-tokens.sh --list   # print every flagged line
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Known-missing count. DO NOT RAISE.
# All 19 violations found as of 2026-07-27 are accounted for: 3 were genuine
# (routed through `theme.primary`/`theme.destructive` in `FontBrowserSheet.swift`),
# 1 was a comment-line false positive (now skipped by the matcher below), and the
# remaining 15 are documented exceptions in `EXCLUDE_FILE_LINES` (user-authored-
# color rendering, color-picker widget internals, the alpha checkerboard, and a
# badge over arbitrary artwork). Net violation count is 0.
BASELINE=0

SOURCE_DIRS=("Makhtoot/App" "Makhtoot/AppShell")

# Documented exceptions — colors here are intentionally NOT MKTheme tokens.
# Each carries its own reason. If a line number drifts, this stops matching and
# the ratchet count rises, surfacing exactly the case this script exists to catch.
EXCLUDE_FILE_LINES=(
  # User-authored artwork / user-chosen color rendering — the value comes from
  # the user's own selection (D-117's color pipeline), not the design system.
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:383"   # text-color swatch renders the user's chosen color
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:416"   # highlight-color swatch renders the user's chosen color
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:599"   # color picker's own live preview color (the picker IS the raw-color surface)
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:751"   # favourites swatch renders user-saved colors
  "Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift:240"  # fill-color binding renders the user's chosen color
  "Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift:322"  # highlight display color renders the user's chosen color

  # `MKColorPickerSheet` and its subviews — these render the hue/saturation/
  # brightness/alpha wheel and gradients that ARE the picker UI. Sweeping every
  # possible raw color is the whole job here, so this is content, not chrome.
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:916"   # SB square hue backdrop
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:936"   # SB square thumb fill
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:979"   # hue strip thumb ring (white, universal picker convention)
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:982"   # hue strip thumb border swatch color
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:997"   # alpha strip's opaque reference color
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:1022"  # alpha strip thumb ring (white, universal picker convention)

  # Alpha-transparency checkerboard — a universal design-tool convention that
  # must read as "transparent" in every theme, not a themed surface.
  "Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:1046"

  # Badge over arbitrary user-authored artwork thumbnails (asset browser) —
  # contrast must hold against unpredictable image content, which no theme
  # token can guarantee.
  "Makhtoot/AppShell/Scenes/Editor/MKAssetBrowserSheet.swift:236" # lock badge glyph
  "Makhtoot/AppShell/Scenes/Editor/MKAssetBrowserSheet.swift:238" # lock badge background
)

is_excluded() {
  local key="$1"
  for entry in "${EXCLUDE_FILE_LINES[@]}"; do
    [ "$entry" = "$key" ] && return 0
  done
  return 1
}

is_comment_line() {
  local file="$1" lineno="$2" content trimmed
  content="$(sed -n "${lineno}p" "$file" 2>/dev/null)"
  trimmed="${content#"${content%%[![:space:]]*}"}"
  case "$trimmed" in
    //*) return 0 ;;
    *) return 1 ;;
  esac
}

violations=""
count=0

color_ctor_pattern='\bColor\((\.sRGB|\.sRGBLinear|\.displayP3|red:|hue:|white:|"[^"]*")'
system_color_pattern='\.(foregroundColor|foregroundStyle|background|tint|fill|stroke|overlay)\([[:space:]]*\.(red|blue|green|yellow|orange|purple|pink|gray|black|white)\b'

for dir in "${SOURCE_DIRS[@]}"; do
  [ -d "$dir" ] || continue
  while IFS= read -r match; do
    [ -z "$match" ] && continue
    file="${match%%:*}"
    rest="${match#*:}"
    lineno="${rest%%:*}"
    # Skip the DEBUG-only harness directory.
    case "$file" in */App/Debug/*) continue ;; esac
    # Skip a color literal named only in a comment, not a live call site.
    is_comment_line "$file" "$lineno" && continue
    # Skip documented exceptions.
    is_excluded "$file:$lineno" && continue
    violations="${violations}${match}"$'\n'
    count=$((count + 1))
  done < <(grep -rnE "$color_ctor_pattern" "$dir" --include="*.swift" 2>/dev/null)
  while IFS= read -r match; do
    [ -z "$match" ] && continue
    file="${match%%:*}"
    rest="${match#*:}"
    lineno="${rest%%:*}"
    case "$file" in */App/Debug/*) continue ;; esac
    is_comment_line "$file" "$lineno" && continue
    is_excluded "$file:$lineno" && continue
    violations="${violations}${match}"$'\n'
    count=$((count + 1))
  done < <(grep -rnE "$system_color_pattern" "$dir" --include="*.swift" 2>/dev/null)
done

if [ "${1:-}" = "--list" ]; then
  echo "$violations" | grep -v '^$' | sort
  echo
fi

echo "Raw colors bypassing MKTheme in feature UI: $count (baseline $BASELINE)"
if [ "$count" -gt "$BASELINE" ]; then
  echo "FAIL: $((count - BASELINE)) NEW raw color reference(s) since the baseline."
  echo "Read the color from theme (\`@Environment(\\.mkTheme)\`), or add a documented"
  echo "exception to this script if the color is genuinely not a design-system token"
  echo "(e.g. rendering user-authored artwork content). Run with --list to see them all."
  exit 1
fi
if [ "$count" -lt "$BASELINE" ]; then
  echo "Baseline is stale: $count < $BASELINE. Lower BASELINE in this script to $count to lock the gain in."
fi
exit 0
