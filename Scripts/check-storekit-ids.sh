#!/usr/bin/env bash
# Contract-mirror equality check (portfolio house standard, matrix row 12): the
# premium product/subscription-group identifiers are hand-duplicated in three
# places with no compiler or runtime check that they agree. See docs/INVARIANTS.md
# INV-1. Adapted from the badan/albayyan-rag "copy the job, edit the canonical
# dict" pattern.
#
# Canonical source: MakhtootKit/Sources/MKStore/MKStoreIDs.swift (Swift — the only
# one of the three the compiler actually checks anything about).
# Mirrors checked against it:
#   1. MakhtootKit/Sources/MKStore/Makhtoot.storekit (package-local StoreKit config
#      used by MakhtootKit's own test target)
#   2. Makhtoot/Config/Makhtoot.storekit (app-target StoreKit config used by the
#      Xcode scheme's StoreKit Testing configuration)
#
# Usage: Scripts/check-storekit-ids.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CANONICAL_SWIFT="MakhtootKit/Sources/MKStore/MKStoreIDs.swift"
MIRROR_A="MakhtootKit/Sources/MKStore/Makhtoot.storekit"
MIRROR_B="Makhtoot/Config/Makhtoot.storekit"

for f in "$CANONICAL_SWIFT" "$MIRROR_A" "$MIRROR_B"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file not found: $f" >&2
    exit 1
  fi
done

# Canonical ids, extracted from the Swift string literals.
canonical=$(grep -oE '"net\.binjamshid\.makhtoot\.premium\.[a-z]+"' "$CANONICAL_SWIFT" | tr -d '"' | sort -u)

fail=0
for mirror in "$MIRROR_A" "$MIRROR_B"; do
  mirror_ids=$(grep -oE '"productID"[[:space:]]*:[[:space:]]*"[^"]*"' "$mirror" | grep -oE '"net\.[^"]*"' | tr -d '"' | sort -u)
  if [ "$canonical" != "$mirror_ids" ]; then
    echo "FAIL: $mirror product ids diverge from $CANONICAL_SWIFT"
    echo "  canonical: $(echo "$canonical" | tr '\n' ' ')"
    echo "  $mirror: $(echo "$mirror_ids" | tr '\n' ' ')"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "OK: StoreKit product ids match across $CANONICAL_SWIFT, $MIRROR_A, $MIRROR_B ($(echo "$canonical" | wc -l | tr -d ' ') ids)."
exit 0
