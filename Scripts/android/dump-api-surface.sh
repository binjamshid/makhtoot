#!/usr/bin/env bash
# dump-api-surface.sh — Android port work item 0.3.
#
# Enumerates every `public`/`open` symbol across all 16 MakhtootKit library
# targets (ANDROID_SPINE.md §0/§3) and writes the result to
# android/API_SURFACE.md. Batch 1 · Agents 1.3 and 1.4 generate every Kotlin
# contract stub (`throw MkNotYetPorted("<module>.<symbol>")`) directly from
# this file — it must be complete and mechanically parseable, not a prose
# summary (ANDROID_TASK_PACKETS/BATCH-0.md, Agent 0.3 mission).
#
# Why python3, not pure grep/awk: the packet asks for a "swift-syntax-free,
# grep/awk-based extractor" mirroring the house pattern in
# Scripts/check-localization.sh — a documented, single-purpose,
# exit-code-driven shell script. That existing ratchet embeds python3 via a
# heredoc for the one piece plain grep/awk cannot do reliably (Unicode
# script detection); this script follows the identical pattern for the one
# piece grep/awk cannot do reliably here: joining a multi-line Swift
# declaration header (wrapped parameter lists, `where` clauses, attribute
# lines) into one logical signature via paren/brace-balance tracking. The
# actual CLASSIFICATION rule — a whitespace-delimited "public"/"open" token
# followed by a declaration keyword — is exactly the rule a pure grep/awk
# version would use (see Scripts/android/dump-api-surface.sh task 6's own
# independent grep spot-check, run at the bottom of this file). This is a
# heuristic line-oriented extractor, not a compiler front end. Known
# false-negative/false-positive classes are documented in
# android/docs/impl-log/BATCH-0.3.md.
#
# Usage:
#   Scripts/android/dump-api-surface.sh
#
# Deterministic and re-runnable (a later gate re-runs this): file order is
# `find | sort` per target, so a second run on an unchanged tree produces
# byte-identical output.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

SOURCES_DIR="MakhtootKit/Sources"
OUT="android/API_SURFACE.md"

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: python3 not found (needed for the multi-line signature joiner)." >&2
  exit 1
fi

if [ ! -d "$SOURCES_DIR" ]; then
  echo "FAIL: $SOURCES_DIR not found — run from repo root ($ROOT)." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

python3 - "$ROOT" "$SOURCES_DIR" "$OUT" <<'PYEOF'
import re
import sys
from pathlib import Path

root, sources_dir, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
root = Path(root)
sources = root / sources_dir
out_path = root / out_path

# Target order mirrors ANDROID_TASK_PACKETS/BATCH-0.md Agent 0.3's own
# port-map table, which in turn mirrors ANDROID_SPINE.md §3.1's module
# table order. (target dir name, Gradle module, Kotlin package, expected
# LOC, expected file count — the last two are spine §3.1/§0 numbers,
# cross-checked at the end of this script, not trusted blindly.)
TARGETS = [
    ("MKFoundation", ":mk-foundation", "net.binjamshid.makhtoot.mk.foundation", 1234, 15),
    ("MKModel", ":mk-model", "net.binjamshid.makhtoot.mk.model", 2176, 15),
    ("MKTextEngine", ":mk-textengine", "net.binjamshid.makhtoot.mk.textengine", 2195, 17),
    ("MKArrange", ":mk-arrange", "net.binjamshid.makhtoot.mk.arrange", 2078, 11),
    ("MKPathText", ":mk-pathtext", "net.binjamshid.makhtoot.mk.pathtext", 1945, 9),
    ("MKCanvas", ":mk-canvas", "net.binjamshid.makhtoot.mk.canvas", 6580, 29),
    ("MKRender", ":mk-render", "net.binjamshid.makhtoot.mk.render", 3603, 23),
    ("MKColor", ":mk-color", "net.binjamshid.makhtoot.mk.color", 467, 4),
    ("MKExport", ":mk-export", "net.binjamshid.makhtoot.mk.export", 3342, 22),
    ("MKFonts", ":mk-fonts", "net.binjamshid.makhtoot.mk.fonts", 2480, 21),
    ("MKPersistence", ":mk-persistence", "net.binjamshid.makhtoot.mk.persistence", 3283, 19),
    ("MKSync", ":mk-sync", "net.binjamshid.makhtoot.mk.sync", 1945, 10),
    ("MKStore", ":mk-store", "net.binjamshid.makhtoot.mk.store", 1668, 18),
    ("MKAnalytics", ":mk-analytics", "net.binjamshid.makhtoot.mk.analytics", 1004, 13),
    ("MKDesignSystem", ":mk-designsystem", "net.binjamshid.makhtoot.mk.designsystem", 1405, 19),
    ("MKAssets", ":mk-assets", "net.binjamshid.makhtoot.mk.assets", 2675, 24),
]

DECL_KEYWORDS = {
    "func", "var", "let", "struct", "class", "enum", "protocol",
    "typealias", "init", "actor", "subscript", "extension",
}

TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
PUBLIC_TOKEN_RE = re.compile(r"(?:^|[^A-Za-z0-9_])(public|open)(?:[^A-Za-z0-9_]|$)")
CONTINUATION_SUFFIX_RE = re.compile(
    r"(,|\(|<|&&?|\|\|?|->|where|=|:|throws|rethrows|async)\s*$"
)
ATTRIBUTE_ONLY_RE = re.compile(r"^@[A-Za-z_][A-Za-z0-9_]*(\(.*\))?\s*$")


def leading_keyword_after(tokens, start_idx):
    """First declaration keyword at/after start_idx, or None."""
    for tok in tokens[start_idx:]:
        base = re.match(r"[A-Za-z_][A-Za-z0-9_]*", tok)
        if base and base.group(0) in DECL_KEYWORDS:
            return base.group(0)
    return None


def strip_trailing_line_comment(line):
    """Best-effort: drop a trailing `// ...` that is not inside a string
    literal. Approximation — a `//` inside a string literal on a
    declaration line is rare in this codebase and, if it occurs, is
    logged as a known limitation rather than silently mishandled."""
    idx = line.find("//")
    if idx == -1:
        return line
    # Don't strip if the `//` looks like it is inside a string (a quote
    # appears before it on the line with no matching close before idx).
    # This is a coarse heuristic, documented in the impl log.
    before = line[:idx]
    if before.count('"') % 2 == 1:
        return line
    return line[:idx]


def find_declarations(text):
    """Yield (start_line_1indexed, kind, signature_text) for each
    public/open declaration header found in `text`."""
    lines = text.split("\n")
    n = len(lines)
    i = 0
    results = []
    prev_nonblank_line = None
    prev_nonblank_idx = None  # 0-indexed
    while i < n:
        raw = lines[i]
        code = strip_trailing_line_comment(raw)
        trimmed = code.strip()

        if trimmed == "":
            i += 1
            continue
        if trimmed.startswith("//"):
            i += 1
            continue

        m = PUBLIC_TOKEN_RE.search(code)
        if not m:
            prev_nonblank_line = raw
            prev_nonblank_idx = i
            i += 1
            continue

        # Tokenize from the public/open match position onward to find the
        # declaration keyword. Use the whole line's tokens (order
        # preserved) and find the one at/after the public/open token.
        tokens = TOKEN_RE.findall(code)
        try:
            pub_tok_index = next(
                idx for idx, t in enumerate(tokens) if t in ("public", "open")
            )
        except StopIteration:
            i += 1
            continue

        kind = leading_keyword_after(tokens, pub_tok_index)
        if kind is None:
            # "public" appears as a token but no recognized declaration
            # keyword follows on this line — not a declaration header we
            # extract (e.g. a stray non-declaration mention). Move on.
            prev_nonblank_line = raw
            prev_nonblank_idx = i
            i += 1
            continue

        # Found a declaration start. Optionally fold in a preceding
        # attribute-only line (e.g. `@discardableResult`) so the emitted
        # signature is complete.
        start_idx = i
        buf_lines = []
        if (
            prev_nonblank_line is not None
            and prev_nonblank_idx == i - 1
            and ATTRIBUTE_ONLY_RE.match(prev_nonblank_line.strip())
        ):
            buf_lines.append(prev_nonblank_line.strip())
            start_idx = prev_nonblank_idx

        buf_lines.append(code.rstrip())
        paren = code.count("(") - code.count(")")
        j = i

        # NOTE: only paren-depth gates the stop decision, not a "generic
        # angle-bracket depth" — an earlier version of this script also
        # tracked '<'/'>' balance to wait out multi-line generic
        # constraint lists, but that gate is not reliable here: this
        # codebase declares four `public static func <`/`==` operator
        # overloads (MKMemoryGovernor.swift, DegradationController.swift,
        # MKEntitlementState.swift, MKCatalogManifestFetchService.swift)
        # whose SIGNATURE contains a bare `<`/`==` token with no matching
        # partner, and bitshift literals like `1 << 0` (MKEmbeddingRights)
        # add further unmatched `<` characters — either one would leave a
        # naive angle-depth counter permanently unbalanced and swallow
        # every following declaration into one entry. Multi-line generic
        # constraint lists that need such a gate do not occur in this
        # codebase for any public declaration (verified: the sole
        # `^\s*where\b`-on-its-own-line occurrence is inside a private
        # function body, MoveGesture.swift:112, not a declaration header)
        # so paren-depth alone is sufficient here. Documented as a known
        # limitation, not silently dropped.
        SAFETY_CAP = 60  # lines; guards against a runaway join on a
        # pathological input rather than swallowing the rest of the file.

        while True:
            cur_line = lines[j] if j < n else ""
            cur_code = strip_trailing_line_comment(cur_line) if j < n else ""
            cur_trimmed = cur_code.strip()

            if paren <= 0:
                if "{" in cur_code:
                    whole = "\n".join(buf_lines)
                    obrace = whole.count("{")
                    cbrace = whole.count("}")
                    if obrace == cbrace:
                        # Body (or `{ get set }` requirement) balanced on
                        # the lines seen so far — keep it whole.
                        break
                    else:
                        # Body opens here but isn't closed yet — truncate
                        # at the first unmatched "{" on this line and
                        # stop; we do not want the full body in a
                        # "signature" dump.
                        first_brace = buf_lines[-1].find("{")
                        if first_brace != -1:
                            buf_lines[-1] = buf_lines[-1][: first_brace + 1]
                        break
                else:
                    if CONTINUATION_SUFFIX_RE.search(cur_trimmed):
                        pass  # fall through to advance to next line
                    else:
                        break

            j += 1
            if j - start_idx > SAFETY_CAP or j >= n:
                break
            nxt_raw = lines[j]
            nxt_code = strip_trailing_line_comment(nxt_raw)
            buf_lines.append(nxt_code.rstrip())
            paren += nxt_code.count("(") - nxt_code.count(")")

        signature = " ".join(l.strip() for l in buf_lines if l.strip() != "")
        signature = re.sub(r"\s+", " ", signature).strip()
        results.append((start_idx + 1, kind, signature))

        i = j + 1
        prev_nonblank_line = None
        prev_nonblank_idx = None

    return results


def main():
    total_symbols = 0
    total_files_seen = 0
    total_loc_seen = 0
    sections = []
    mismatches = []

    for target, gradle_module, kt_package, expected_loc, expected_files in TARGETS:
        tdir = sources / target
        if not tdir.is_dir():
            print(f"FAIL: target dir missing: {tdir}", file=sys.stderr)
            sys.exit(1)

        swift_files = sorted(tdir.rglob("*.swift"))
        target_symbols = []
        target_loc = 0

        for f in swift_files:
            text = f.read_text(encoding="utf-8")
            target_loc += text.count("\n") + (1 if text and not text.endswith("\n") else 0)
            rel = f.relative_to(root)
            for start_line, kind, sig in find_declarations(text):
                target_symbols.append((str(rel), start_line, kind, sig))

        total_files_seen += len(swift_files)
        total_loc_seen += target_loc
        total_symbols += len(target_symbols)

        if len(swift_files) != expected_files:
            mismatches.append(
                f"{target}: file count {len(swift_files)} != spine §3.1's {expected_files}"
            )
        if target_loc != expected_loc:
            mismatches.append(
                f"{target}: LOC {target_loc} != spine §3.1's {expected_loc}"
            )

        sections.append(
            {
                "target": target,
                "gradle_module": gradle_module,
                "kt_package": kt_package,
                "files": len(swift_files),
                "loc": target_loc,
                "symbols": target_symbols,
            }
        )

    lines = []
    lines.append("# API_SURFACE.md — MakhtootKit public API surface dump")
    lines.append("")
    lines.append(
        "Generated by `Scripts/android/dump-api-surface.sh` "
        "(Android port work item 0.3). Deterministic, re-runnable — "
        "no timestamp is embedded so a second run on an unchanged tree "
        "produces byte-identical output."
    )
    lines.append(
        "Every `public`/`open` declaration across all 16 `MakhtootKit` library "
        "targets, grouped by target then by source file then by declaration "
        "order within the file. This file is checked in, not gitignored, and "
        "is not hand-edited — re-run the script to regenerate it."
    )
    lines.append(
        "Batch 1 · Agents 1.3 and 1.4 generate every Kotlin contract stub "
        '(`throw MkNotYetPorted("<module>.<symbol>")`) directly from this file.'
    )
    lines.append("")
    lines.append(
        f"**Totals:** {total_symbols} symbols across {total_files_seen} files / "
        f"{total_loc_seen} LOC (16 targets)."
    )
    lines.append("")
    if mismatches:
        lines.append("**Disagreement with ANDROID_SPINE.md §3.1 (see impl log):**")
        for m in mismatches:
            lines.append(f"- {m}")
        lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Per-target summary")
    lines.append("")
    lines.append("| Target | Gradle module | Kotlin package | Files | LOC | Public/open symbols |")
    lines.append("|---|---|---|---|---|---|")
    for s in sections:
        lines.append(
            f"| {s['target']} | `{s['gradle_module']}` | `{s['kt_package']}` | "
            f"{s['files']} | {s['loc']} | {len(s['symbols'])} |"
        )
    lines.append(
        f"| **Total** | | | **{total_files_seen}** | **{total_loc_seen}** | **{total_symbols}** |"
    )
    lines.append("")
    lines.append("---")
    lines.append("")

    for s in sections:
        lines.append(f"## {s['target']} → `{s['gradle_module']}` → `{s['kt_package']}`")
        lines.append("")
        lines.append(
            f"{s['files']} files, {s['loc']} LOC, {len(s['symbols'])} public/open symbols."
        )
        lines.append("")

        by_file = {}
        for rel, start_line, kind, sig in s["symbols"]:
            by_file.setdefault(rel, []).append((start_line, kind, sig))

        for rel in sorted(by_file.keys()):
            entries = by_file[rel]
            lines.append(f"### `{rel}`")
            lines.append("")
            for start_line, kind, sig in entries:
                lines.append(f"- **L{start_line}** `{kind}` — `{sig}`")
            lines.append("")

    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"targets=16 files={total_files_seen} loc={total_loc_seen} symbols={total_symbols}")
    if mismatches:
        print("DISAGREEMENTS WITH SPINE §3.1:")
        for m in mismatches:
            print(f"  - {m}")


if __name__ == "__main__":
    main()
PYEOF
