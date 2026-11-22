#!/bin/sh
# referral-release-grep.sh — CI job `referral-removal-check` (T15, D-225),
# INVERTED by D-327 (founder, 2026-08-07).
#
# ## History
#
# D-225 (founder-confirmed 2026-07-17) excluded the referral module from
# Release builds and this script proved the ABSENCE of referral vocabulary in
# the built product. D-327 granted FD-05 for iOS, defined
# MAKHTOOT_REFERRAL_ENABLED in the Release configuration, and built the
# missing UI — so absence is now a failure, not a pass.
#
# The script is inverted rather than deleted because the interesting failure
# is no longer "did referral leak in?" but "did referral ship HALF-BUILT?".
# A Release binary containing the referral engine but not the user-facing
# strings would mean the compile flag was set while the UI was excluded ،
# code with no way to reach it, which is precisely the Guideline 2.3.1
# dormant-feature exposure D-225 existed to prevent. That state is worse than
# either clean extreme, and nothing else in CI would catch it.
#
# ## Usage
#
#   Scripts/referral-release-grep.sh <path-to-built-.app-or-binary>
#
# Exit code 0 = referral feature present AND user-reachable — expected for
#               every Release build under D-327.
# Exit code 1 = referral ABSENT, or present but INCOMPLETE (engine without UI)
#               — must fail CI.
# Exit code 2 = usage error (no path given / path doesn't exist).
#
# ## TO REVERT to D-225 behaviour
#
# Remove the two MAKHTOOT_REFERRAL_ENABLED definitions (MakhtootKit/
# Package.swift MKStore + MKStoreTests targets; Makhtoot.xcodeproj app-target
# Debug and Release configs), then restore this script from git history at
# commit-before-D-327. Both halves must move together, which is why this
# comment names them explicitly.

set -eu

TARGET_PATH="${1:-}"

if [ -z "$TARGET_PATH" ] || [ ! -e "$TARGET_PATH" ]; then
    echo "usage: $0 <path-to-built-.app-or-binary>" >&2
    echo "error: no valid path given (got: '${TARGET_PATH}')" >&2
    exit 2
fi

# The GATING signal is the Arabic UI vocabulary. String literals reliably
# survive into __TEXT/__cstring in a Release build; Swift symbol names may or
# may not, depending on whole-module optimization and stripping. Gating on
# symbols would make this check flaky for reasons unrelated to the feature,
# so symbols are reported as INFORMATIONAL only, below.
UI_PATTERNS='الدعوات|رمز الدعوة|تفعيل الرمز'

# Informational only — never gates. See above.
SYMBOL_PATTERNS='MKReferralCodeGenerator|MKReferralLedger|MKReferralRedemption|MKReferralIdentity'

echo "referral-release-grep (D-327, inverted): scanning ${TARGET_PATH}..."

# `-a` treats binaries as text so the Mach-O string table is searched; we
# deliberately do NOT pass `-I`, which would skip binaries.
if [ -d "$TARGET_PATH" ]; then
    UI_MATCHES=$(grep -rlaE "$UI_PATTERNS" "$TARGET_PATH" 2>/dev/null || true)
    SYMBOL_MATCHES=$(grep -rlaE "$SYMBOL_PATTERNS" "$TARGET_PATH" 2>/dev/null || true)
else
    UI_MATCHES=$(grep -laE "$UI_PATTERNS" "$TARGET_PATH" 2>/dev/null || true)
    SYMBOL_MATCHES=$(grep -laE "$SYMBOL_PATTERNS" "$TARGET_PATH" 2>/dev/null || true)
fi

if [ -z "$UI_MATCHES" ]; then
    echo "FAIL: no referral UI vocabulary found in the Release artifact." >&2
    echo "" >&2
    if [ -n "$SYMBOL_MATCHES" ]; then
        echo "The referral ENGINE symbols ARE present:" >&2
        echo "$SYMBOL_MATCHES" >&2
        echo "" >&2
        echo "This is the half-shipped case this check exists to catch:" >&2
        echo "referral code is compiled into the binary but no user-facing" >&2
        echo "strings are, so the feature is unreachable — a Guideline 2.3.1" >&2
        echo "dormant-feature exposure. Either finish wiring ReferralSection" >&2
        echo "into the Settings root, or remove MAKHTOOT_REFERRAL_ENABLED" >&2
        echo "from BOTH Package.swift and the app target (see header)." >&2
    else
        echo "No referral engine symbols either — the feature is fully absent." >&2
        echo "That was correct under D-225 but is a failure under D-327, which" >&2
        echo "activated referral for iOS. If you intended to deactivate it," >&2
        echo "revert this script alongside the flags (see header)." >&2
    fi
    exit 1
fi

echo "PASS: referral UI vocabulary present — the feature is user-reachable."
if [ -n "$SYMBOL_MATCHES" ]; then
    echo "      (informational: engine symbols also present, as expected)"
else
    echo "      (informational: engine symbols not visible — expected when"
    echo "       whole-module optimization strips them; not a failure)"
fi
exit 0
