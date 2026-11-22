#!/bin/sh
# referral-release-grep.sh — Android sibling of Scripts/referral-release-grep.sh
# (T15/D-225 lineage, ANDROID_SPINE.md §2 D-321; work item 1.1).
#
# Proves D-321's compile-time referral exclusion holds on the artifact that
# ships, not just on the source tree — same rationale as the iOS script.
# D-321 mirrors D-225: a `referral` source set present only in the `debug`
# build type of :app, plus `BuildConfig.REFERRAL_ENABLED`; the module and its
# Arabic strings are absent from the release AAB entirely. This script greps
# the BUILT RELEASE ARTIFACT (an unzipped AAB or the APKs produced from it),
# not the source tree, for referral vocabulary.
#
# Usage:
#   Scripts/android/referral-release-grep.sh <path-to-release-aab-or-unzipped-dir>
#
# Exit code 0 = clean (no referral vocabulary found) — expected for every real
#               Release build, and the ONLY expected outcome before Batch 9
#               (see "not runnable pre-archive" below).
# Exit code 1 = referral vocabulary FOUND in a Release artifact — must fail CI;
#               means the flag leaked into Release.
# Exit code 2 = usage error (no path given / path doesn't exist).
#
# Not runnable pre-archive: no signed release AAB exists until Batch 9 · Agent
# 9.2 (spine §5 batch table). Before that, this script is invoked with no
# argument by android-ci.yml as an explicit, documented "no AAB yet" skip
# (exit 0), matching the iOS script's own not-runnable-pre-archive note in
# .github/workflows/ci.yml.

set -eu

TARGET_PATH="${1:-}"

if [ -z "$TARGET_PATH" ]; then
    echo "SKIP: no release artifact path given — not runnable pre-archive (Batch 9)." >&2
    exit 0
fi

if [ ! -e "$TARGET_PATH" ]; then
    echo "usage: $0 <path-to-release-aab-or-unzipped-dir>" >&2
    echo "error: no valid path given (got: '${TARGET_PATH}')" >&2
    exit 2
fi

# Referral vocabulary: the Arabic strings the referral module owns plus the
# Kotlin symbol prefixes (Mk-naming rule, spine §3.3) mirroring the module —
# belt-and-suspenders, same as the iOS script's Mach-O string-table rationale.
PATTERNS='دعوة|إحالة|رمز الدعوة|MkReferralCodeGenerator|MkReferralRedemption|MkReferralLedger|REFERRAL_ENABLED.*true'

echo "referral-release-grep: scanning ${TARGET_PATH} for referral vocabulary..."

if [ -d "$TARGET_PATH" ]; then
    MATCHES=$(grep -rlaE "$PATTERNS" "$TARGET_PATH" 2>/dev/null || true)
else
    MATCHES=$(grep -laE "$PATTERNS" "$TARGET_PATH" 2>/dev/null || true)
fi

if [ -n "$MATCHES" ]; then
    echo "FAIL: referral vocabulary found in Release artifact:" >&2
    echo "$MATCHES" >&2
    echo "" >&2
    echo "This means the referral source set or REFERRAL_ENABLED leaked into a" >&2
    echo "Release build, or referral strings ended up in the merged main string" >&2
    echo "table instead of staying inside the debug-only source set (D-321)." >&2
    exit 1
fi

echo "PASS: no referral vocabulary found. Compile-time exclusion holds."
exit 0
