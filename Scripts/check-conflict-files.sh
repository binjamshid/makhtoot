#!/usr/bin/env bash
# Fail if any iCloud sync-conflict copy ("name 2.ext" / "name 3.ext") exists alongside
# its canonical sibling. iCloud Drive creates these when two devices touch a file; they
# silently re-introduce stale or insecure twins (a duplicate .swift source breaks the
# build or shadows the real one; a duplicate .storekit/.json config risks a stale copy
# winning). Precise: only flags a copy when the canonical "name.ext" also exists, so
# legit names like "fixture-100-nodes.makhtoot" or "Artboard 32.svg" are never caught.
#
# Portfolio house standard: this repo sits on Desktop under iCloud Drive exactly like
# ghawazi/badan/masoon/albayyan-rag, so it carries the identical hazard. Adapted from
# ghawazi/scripts/check-conflict-files.sh (~40 lines, same logic, path-adjusted).
#
# Usage: Scripts/check-conflict-files.sh        # scan the whole tree
#        Scripts/check-conflict-files.sh --staged  # only git-staged files (pre-commit)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

list_files() {
  if [ "${1:-}" = "--staged" ]; then
    git diff --cached --name-only --diff-filter=AM
  else
    find . -type f \
      -not -path './.git/*' -not -path '*/build/*' -not -path '*/DerivedData/*' \
      -not -path '*/.build/*' -not -path '*/xcuserdata/*' -print \
      | sed 's|^\./||'
  fi
}

bad=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  base="$(basename "$f")"
  dir="$(dirname "$f")"
  # match "<name> <digits>.<ext>" or "<name> <digits>" (no extension)
  if [[ "$base" =~ ^(.+)\ ([0-9]+)(\.[^.]+)?$ ]]; then
    name="${BASH_REMATCH[1]}"; ext="${BASH_REMATCH[3]:-}"
    canon="$dir/$name$ext"
    if [ -f "$canon" ]; then
      echo "conflict-copy: '$f'  (canonical exists: '$canon')"
      bad=1
    fi
  fi
done < <(list_files "${1:-}")

if [ "$bad" -ne 0 ]; then
  echo ""
  echo "ERROR: iCloud sync-conflict copies found. Delete them (keep the canonical file):"
  echo "  find . -name '* [2-9].*' -o -name '* [2-9]'   # review, then remove"
  exit 1
fi
echo "OK: no sync-conflict copies."
