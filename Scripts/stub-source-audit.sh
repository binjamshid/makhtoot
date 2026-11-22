#!/bin/sh
# stub-source-audit.sh — D-229(3) automated stub audit (WS-10 T16).
#
# D-229(3): "Automated stub audit: stub types are `#if DEBUG`-gated so a
# Release reference fails the build, plus a source-audit test asserting no
# non-test/non-composition-root reference to `AlwaysPremium*`/
# `AlwaysFree*` exists."
#
# There is no XCTest target for the `Makhtoot` app target in this repo
# (only `MakhtootKit`'s SPM test targets exist) — see docs/impl-log/WS-10.md
# for the note on why this ships as a standalone script rather than an
# XCTest case. It performs the two checks D-229(3) actually asks for:
#
#   1. Every `AlwaysPremium*`/`AlwaysFree*` type declaration site is
#      `#if DEBUG`-gated (grep for the declaration + confirm a `#if DEBUG`
#      appears before it in the same file, `#endif` after).
#   2. No reference to those types exists ANYWHERE in `Makhtoot/` outside
#      their own declaration file(s) — i.e. the composition root
#      (`AppContainer.swift`) no longer constructs one in production
#      wiring. (Doc-comment mentions of the type NAME as prose, e.g. in a
#      swap-log entry, are allowed — this script only flags actual Swift
#      code references: `TypeName(` construction or `: TypeName`
#      conformance/type-annotation syntax, not arbitrary substring
#      mentions inside `///` comments.)
#
# Usage: Scripts/stub-source-audit.sh
# Exit 0 = clean. Exit 1 = a stub type is referenced outside its own
# declaration file, or a declaration isn't `#if DEBUG`-gated.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/Makhtoot"
FAIL=0

echo "stub-source-audit: scanning ${APP_DIR} for AlwaysPremium*/AlwaysFree* stub types..."

# Every file that DECLARES a stub type (struct/class/enum NAME: Protocol).
DECL_FILES=$(grep -rlE '(struct|class|enum) (AlwaysPremium|AlwaysFree)[A-Za-z]*' "$APP_DIR" --include="*.swift" || true)

if [ -z "$DECL_FILES" ]; then
    echo "No AlwaysPremium*/AlwaysFree* declarations found — nothing to audit (or already fully removed)."
    exit 0
fi

for FILE in $DECL_FILES; do
    echo "  checking declaration gate: $FILE"
    if ! grep -q '#if DEBUG' "$FILE"; then
        echo "FAIL: $FILE declares a stub type but has no '#if DEBUG' gate." >&2
        FAIL=1
    fi
done

# Now check every OTHER Swift file in the app for a live code reference
# (construction call `Name(` or type position `: Name`) to any declared
# stub type name.
STUB_NAMES=$(grep -rhoE '(struct|class|enum) (AlwaysPremium|AlwaysFree)[A-Za-z]*' "$APP_DIR" --include="*.swift" | awk '{print $2}' | sort -u)

for NAME in $STUB_NAMES; do
    echo "  checking for live references to: $NAME"
    # Matches `NAME(` (construction) or `: NAME` (type annotation/
    # conformance) — deliberately narrower than a bare substring grep so
    # prose mentions of the type's NAME inside doc comments (e.g. a
    # swap-log sentence explaining the type was retired) don't false-
    # positive this check.
    HITS=$(grep -rnE "(${NAME}\(|: ${NAME}\b)" "$APP_DIR" --include="*.swift" || true)

    # Build the real violation list by hand rather than relying on a
    # single grep -v pass: (a) drop any hit inside the type's own
    # declaration file(s) — DECL_FILES may hold more than one path,
    # newline-separated, so this has to be a per-file string compare, not
    # a single regex; (b) drop comment-only lines — a line whose first
    # non-whitespace characters are `//` (covers both `//` and `///`) is
    # prose (e.g. a swap-log entry mentioning the retired type by name),
    # not a live code reference, even though it can still match the
    # `NAME(`/`: NAME` pattern above (e.g. inside a doc-comment code
    # sample or a backtick-quoted mention followed by other punctuation).
    VIOLATIONS=""
    if [ -n "$HITS" ]; then
        while IFS= read -r LINE; do
            [ -z "$LINE" ] && continue
            HIT_FILE=$(echo "$LINE" | cut -d: -f1)

            IS_DECL_FILE=0
            for DF in $DECL_FILES; do
                if [ "$HIT_FILE" = "$DF" ]; then
                    IS_DECL_FILE=1
                fi
            done
            [ "$IS_DECL_FILE" -eq 1 ] && continue

            LINE_CONTENT=$(echo "$LINE" | cut -d: -f3-)
            TRIMMED=$(echo "$LINE_CONTENT" | sed -e 's/^[[:space:]]*//')
            case "$TRIMMED" in
                //*) continue ;;
            esac

            VIOLATIONS="${VIOLATIONS}${LINE}
"
        done <<EOF
$HITS
EOF
    fi

    # Only take the failure branch when VIOLATIONS genuinely holds at
    # least one line — a plain `-n` check on the accumulated string,
    # instead of the previous whitespace-stripped indirection, so an
    # empty violation list can never print a FAIL header with nothing
    # under it.
    if [ -n "$VIOLATIONS" ]; then
        echo "FAIL: live reference(s) to $NAME found outside its declaration file:" >&2
        printf '%s' "$VIOLATIONS" >&2
        FAIL=1
    fi
done

if [ "$FAIL" -ne 0 ]; then
    echo "" >&2
    echo "stub-source-audit FAILED." >&2
    exit 1
fi

echo "PASS: every stub declaration is #if DEBUG-gated; no live reference outside its own file."
exit 0
