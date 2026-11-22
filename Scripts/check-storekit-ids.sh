# Check that the standalone StoreKit package and its test configuration agree.
# The app target does not link StoreKit.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CANONICAL_SWIFT="MakhtootKit/Sources/MKStore/MKStoreIDs.swift"
FIXTURE="MakhtootKit/Sources/MKStore/Makhtoot.storekit"

for f in "$CANONICAL_SWIFT" "$FIXTURE"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file not found: $f" >&2
    exit 1
  fi
done

# Canonical ids, extracted from the Swift string literals.
canonical=$(grep -oE '"net\.binjamshid\.makhtoot\.premium\.[a-z]+"' "$CANONICAL_SWIFT" | tr -d '"' | sort -u)

fixture_ids=$(grep -oE '"productID"[[:space:]]*:[[:space:]]*"[^"]*"' "$FIXTURE" | grep -oE '"net\.[^"]*"' | tr -d '"' | sort -u)
if [ -z "$canonical" ] || [ "$canonical" != "$fixture_ids" ]; then
  echo "FAIL: $FIXTURE product ids diverge from $CANONICAL_SWIFT" >&2
  exit 1
fi

echo "OK: legacy package StoreKit product ids match."
