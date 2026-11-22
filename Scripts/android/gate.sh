#!/usr/bin/env bash
# gate.sh — the only stopping point between batches (ANDROID_SPINE.md §5.4,
# §6; work item 1.1).
#
# Usage:
#   bash Scripts/android/gate.sh <N>      # N = 0..9
#
# Every run does two things, in order:
#   1. Apply pending contract changes — check android/docs/CONTRACT_CHANGES.md
#      for any row with status `pending`. This script does not (cannot, safely)
#      auto-edit a build.gradle.kts on an agent's behalf; "applying" means the
#      operator running the gate has, between the batch finishing and the gate
#      running, made the requested Gradle edit and flipped the row's status to
#      `applied` or `rejected`. The gate's job is to REFUSE to pass while any
#      row is still `pending` — spine §4 ground rule 5's "explicit apply step
#      performed before the gate's own checks re-run".
#   2. Run gate N's specific checks per spine §6's table.
#
# Exit code 0 = gate passes. Non-zero = gate fails; fix within the batch's
# scope before moving on (spine §5.4 — never carry a broken build forward).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

GATE="${1:-}"
if [ -z "$GATE" ]; then
    echo "usage: $0 <gate-number 0-9>" >&2
    exit 2
fi

FAIL=0
fail() {
    echo "FAIL: $1" >&2
    FAIL=1
}
ok() {
    echo "OK: $1"
}

# ---------------------------------------------------------------------------
# Step 1: apply pending contract changes.
# ---------------------------------------------------------------------------
echo "=== gate.sh $GATE : contract-changes step ==="
CONTRACT_CHANGES="android/docs/CONTRACT_CHANGES.md"
if [ -f "$CONTRACT_CHANGES" ]; then
    pending=$(grep -E '\|\s*pending\s*\|?\s*$' "$CONTRACT_CHANGES" || true)
    if [ -n "$pending" ]; then
        fail "android/docs/CONTRACT_CHANGES.md has pending entries — apply them (edit the target build.gradle.kts, flip status to applied/rejected) before re-running the gate:"
        echo "$pending" >&2
    else
        ok "CONTRACT_CHANGES.md has no pending entries."
    fi
else
    fail "android/docs/CONTRACT_CHANGES.md does not exist."
fi

if [ "$FAIL" -ne 0 ]; then
    echo "=== gate.sh $GATE : ABORTED at contract-changes step ===" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: gate-specific checks.
# ---------------------------------------------------------------------------

check_g0() {
    echo "--- G0: parity matrix / fixtures / API surface / strings / decisions ---"

    # 318 R-ids covered (spine §0 — 318, not 319).
    if [ -f android/PARITY_MATRIX.md ]; then
        count=$(grep -oE '^\| R-[0-9]+\.[0-9]+[a-z]?' android/PARITY_MATRIX.md | sed 's/| //' | sort -u | wc -l | tr -d ' ')
        if [ "$count" = "318" ]; then
            ok "PARITY_MATRIX.md covers exactly 318 R-ids."
        else
            fail "PARITY_MATRIX.md covers ${count} R-ids, expected 318."
        fi
    else
        fail "android/PARITY_MATRIX.md missing."
    fi

    # D-300..D-325 present in DECISIONS_LOG.md.
    if [ -f DECISIONS_LOG.md ]; then
        missing=""
        for d in $(seq 300 325); do
            grep -q "D-${d}\b" DECISIONS_LOG.md || missing="${missing} D-${d}"
        done
        if [ -z "$missing" ]; then
            ok "D-300..D-325 all present in DECISIONS_LOG.md."
        else
            fail "DECISIONS_LOG.md missing:${missing}"
        fi
    else
        fail "DECISIONS_LOG.md missing."
    fi

    # API_SURFACE.md lists all 16 targets.
    if [ -f android/API_SURFACE.md ]; then
        target_count=$(grep -cE '^\| MK[A-Za-z]+ \|' android/API_SURFACE.md || true)
        if [ "$target_count" = "16" ]; then
            ok "API_SURFACE.md lists all 16 targets."
        else
            fail "API_SURFACE.md lists ${target_count} targets, expected 16."
        fi
    else
        fail "android/API_SURFACE.md missing."
    fi

    # strings.xml staging output non-empty.
    if [ -f android/strings/strings.xml ]; then
        n=$(grep -c '<string ' android/strings/strings.xml || true)
        if [ "$n" -gt 0 ]; then
            ok "android/strings/strings.xml has ${n} entries."
        else
            fail "android/strings/strings.xml has zero <string> entries."
        fi
    else
        fail "android/strings/strings.xml missing."
    fi

    # The golden-export tool regenerates fixtures. This gate verifies the
    # exclusion-list contract this script must honor if/when a regeneration
    # command is wired in (spine §6 G0: "consume
    # android/fixtures/DETERMINISM_EXCLUSIONS.json rather than hard-coding an
    # exclusion list").
    excl="android/fixtures/DETERMINISM_EXCLUSIONS.json"
    if [ -f "$excl" ]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "import json; json.load(open('$excl'))" \
                && ok "DETERMINISM_EXCLUSIONS.json is valid JSON." \
                || fail "DETERMINISM_EXCLUSIONS.json is not valid JSON."
        fi
        echo "NOTE: byte-identical-regeneration diff itself requires re-running the" \
             "Swift golden-export tool per android/docs/impl-log/BATCH-0.2.md" \
             "and diff against android/fixtures/** excluding the globs in" \
             "$excl before treating this sub-check as fully green."
    else
        fail "$excl missing (spine §6 G0 requires it as the exclusion-list source, not a hard-coded list in this script)."
    fi
}

check_g1() {
    echo "--- G1: Gradle scaffold builds, native smoke test, stub count, no pending contracts ---"

    pushd android >/dev/null

    if ./gradlew help >/tmp/mk_gate_g1_help.log 2>&1; then
        ok "./gradlew help succeeded."
    else
        fail "./gradlew help failed — see /tmp/mk_gate_g1_help.log"
    fi

    if ./gradlew assembleDebug >/tmp/mk_gate_g1_assemble.log 2>&1; then
        ok "./gradlew assembleDebug succeeded on all 18 modules."
    else
        fail "./gradlew assembleDebug failed — see /tmp/mk_gate_g1_assemble.log (this is EXPECTED to fail until Agent 1.2's mk-native/CMakeLists.txt and Agent 1.3/1.4's contract stubs all land; a scaffold-only run before those exist is not a G1 pass)."
    fi

    popd >/dev/null

    echo "$(bash Scripts/android/stub-count.sh)"

    bash Scripts/android/check-no-stubs.sh --gate 1 || true
    echo "(check-no-stubs is advisory at G1, per spine ground rule 3 — does not fail this gate)"
}

check_generic_module_tests() {
    modules="$1"
    pushd android >/dev/null
    for m in $modules; do
        if ./gradlew ":${m}:testDebugUnitTest" >/tmp/mk_gate_module_${m}.log 2>&1; then
            ok "${m}:testDebugUnitTest passed."
        else
            fail "${m}:testDebugUnitTest failed — see /tmp/mk_gate_module_${m}.log"
        fi
    done
    popd >/dev/null
}

check_g2() {
    echo "--- G2: mk-foundation mk-model mk-color mk-designsystem tests green; scene round-trip ---"
    check_generic_module_tests "mk-foundation mk-model mk-color mk-designsystem"
    echo "NOTE: the 4-fixture byte-identical round-trip (Tests/Fixtures/*.makhtoot) is asserted inside mk-model's own test suite (Agent 2.2), not re-implemented in this script."
}

check_g3() {
    echo "--- G3: shaping parity (Class-B=0, Class-A<=1%, Class-C signed off), persistence journal, font validator ---"
    if [ -f android/SHAPING_DELTAS.md ]; then
        class_b=$(grep -c '| *B *|' android/SHAPING_DELTAS.md || true)
        if [ "$class_b" = "0" ]; then
            ok "SHAPING_DELTAS.md has zero Class-B rows."
        else
            fail "SHAPING_DELTAS.md has ${class_b} Class-B row(s) — a hard gate failure per spine §12, no exceptions."
        fi
    else
        fail "android/SHAPING_DELTAS.md missing (Agent 1.2/3.x create it on first use, spine §12)."
    fi
    check_generic_module_tests "mk-textengine mk-persistence mk-fonts"
}

check_g4() {
    echo "--- G4: arrange round-trip, path-text placement, render tolerance ---"
    if [ ! -f android/docs/RENDER_TOLERANCE.md ]; then
        fail "android/docs/RENDER_TOLERANCE.md missing (spine §12 requires a justified, concrete tolerance)."
    else
        ok "android/docs/RENDER_TOLERANCE.md present."
    fi
    check_generic_module_tests "mk-arrange mk-pathtext mk-render"
}

check_g5() {
    echo "--- G5: canvas gestures, export goldens, PDF structural validation (agent-run); Acrobat/Preview check is a FOUNDER task ---"
    check_generic_module_tests "mk-canvas mk-export mk-assets"
    echo "REMINDER: opening the PDF in Adobe Acrobat and macOS Preview (spine §6 G5, §7) is explicitly a founder task this script cannot perform."
}

check_g6() {
    echo "--- G6: Play Billing sandbox scenarios, Drive sync round-trip incl. conflict copy, trial clock-rollback guard ---"
    check_generic_module_tests "mk-store mk-sync mk-analytics"
    echo "REMINDER: exercising Credential Manager + GIS AuthorizationClient (D-310) and the two-emulator conflict-copy path (spine §7) needs the external Google Cloud OAuth prerequisite — cannot run headless in this script."
}

check_g7() {
    echo "--- G7: app runs end-to-end, every screen reachable, zero Placeholder composables ---"
    bash Scripts/android/check-no-stubs.sh --gate 7 || true
    echo "REMINDER: emulator + physical-device end-to-end walk (spine §7) is a manual/instrumented-test step, not reproduced here."
}

check_g8() {
    echo "--- G8: stub count = 0 exactly, check-no-stubs BLOCKING, all 318 R-ids covered, perf budgets, TalkBack ---"
    stub_out="$(bash Scripts/android/stub-count.sh)"
    echo "$stub_out"
    stub_n=$(echo "$stub_out" | grep -oE '[0-9]+' | tail -1)
    if [ "$stub_n" = "0" ]; then
        ok "stub count is exactly 0."
    else
        fail "stub count is ${stub_n}, must be exactly 0 at G8 — no exception, no escalation path (spine ground rule 4)."
    fi

    if bash Scripts/android/check-no-stubs.sh --gate 8; then
        ok "check-no-stubs.sh clean (blocking mode)."
    else
        fail "check-no-stubs.sh found un-allowlisted matches (blocking mode)."
    fi

    if [ -f android/PARITY_MATRIX.md ]; then
        unshipped=$(grep -cE '⬜\s*$' android/PARITY_MATRIX.md || true)
        if [ "$unshipped" = "0" ]; then
            ok "PARITY_MATRIX.md: no unchecked (⬜) R-ids remaining."
        else
            fail "PARITY_MATRIX.md still has ${unshipped} unchecked R-id row(s)."
        fi
    fi
    echo "REMINDER: performance budgets, full TalkBack sweep, and the API 30 MkFloatingBar visual check (FDA-07) are manual/instrumented steps not reproduced here."
}

check_g9() {
    echo "--- G9: signed AAB to internal track, Data Safety complete, referral grep of release AAB clean ---"
    bash Scripts/android/referral-release-grep.sh "${2:-}" || fail "referral-release-grep.sh reported referral vocabulary in the release artifact."
    echo "REMINDER: Play Console upload / Data Safety form completion (FDA-06) are founder-only external steps."
}

case "$GATE" in
    0) check_g0 ;;
    1) check_g1 ;;
    2) check_g2 ;;
    3) check_g3 ;;
    4) check_g4 ;;
    5) check_g5 ;;
    6) check_g6 ;;
    7) check_g7 ;;
    8) check_g8 ;;
    9) check_g9 ;;
    *)
        echo "usage: $0 <gate-number 0-9>" >&2
        exit 2
        ;;
esac

echo "=== gate.sh $GATE : $([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL) ==="
exit "$FAIL"
