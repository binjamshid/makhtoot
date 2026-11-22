#!/usr/bin/env bash
# stub-count.sh — the stub burn-down counter (ANDROID_SPINE.md §4 ground rule 4,
# §11; work item 1.1).
#
# Why this exists: Batch 1 lands every public API of all 16 ported modules plus
# `:app` as a compiling stub whose body is `throw MkNotYetPorted("<module>.<symbol>")`
# (spine §4 mechanism (b)). This script prints how many such throws remain across
# the tree. It is published at every gate (Scripts/android/gate.sh) and must read
# exactly 0 at G8, with no exception and no escalation path — there is no
# "0 or every remainder is a named, escalated gap" clause.
#
# The count is expected to be LARGE right after Batch 1 (peak, ~all public API
# surface) and to fall monotonically as Batches 2-8 port real implementations
# over the stubs. It is correct — not a bug — for this script to print a large
# positive number today; it only needs to be 0 once, at G8.
#
# Ordering note: this script runs without error even before any Kotlin source
# exists at all (i.e. before Agent 1.3/1.4 land their contract stubs later in
# this same batch) — it prints 0 in that state, which is NOT the same claim as
# "stub count is 0 at G8": at G1 a count of 0 would mean no stubs were written
# yet, which is a Batch 1 failure, not success. Batch 1's acceptance checks this
# distinction explicitly (see android/docs/impl-log/BATCH-1.1.md).
#
# Usage:
#   Scripts/android/stub-count.sh          # prints the count only
#   Scripts/android/stub-count.sh --list    # also prints every matching file:line

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PATTERN='throw MkNotYetPorted\('
SEARCH_GLOB='android/*/src/main/kotlin'

matches=""
for dir in $SEARCH_GLOB; do
    [ -d "$dir" ] || continue
    hits=$(grep -rn -E "$PATTERN" "$dir" --include='*.kt' 2>/dev/null || true)
    if [ -n "$hits" ]; then
        matches="${matches}${hits}
"
    fi
done

count=$(printf '%s' "$matches" | grep -c . || true)

if [ "${1:-}" = "--list" ]; then
    printf '%s' "$matches"
fi

echo "stub-count: ${count}"
exit 0
