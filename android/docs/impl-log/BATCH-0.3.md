# BATCH-0.3 impl log — Public API surface dump

Scope: `Scripts/android/dump-api-surface.sh`,
`android/API_SURFACE.md`, this file. No other path touched.

## What was ported

Not a port — an extraction. Wrote `Scripts/android/dump-api-surface.sh`, a
bash wrapper (house style: `set -euo pipefail`, `ROOT` resolution via
`BASH_SOURCE`, documented header, single purpose, exit-code-driven —
mirrors `Scripts/check-localization.sh`) that embeds a python3 payload via
heredoc for the actual extraction, exactly the same pattern
`check-localization.sh` uses for the one piece plain grep/awk cannot do
reliably (there: Unicode script detection; here: joining a multi-line
Swift declaration header into one logical signature via paren-balance
tracking). The packet's "swift-syntax-free, grep/awk-based extractor"
instruction is read as "no real Swift parser / no SwiftSyntax dependency,"
which this satisfies — there is no Swift compiler or parser library
anywhere in the pipeline, only line-oriented text matching. Recorded here
as a deliberate implementation choice, not a silent deviation.

The script scans all 16 `MakhtootKit/Sources/<Target>/**/*.swift` files (in
the port-map order from `ANDROID_TASK_PACKETS/BATCH-0.md`'s Agent 0.3
section, which mirrors `ANDROID_SPINE.md` §3.1's module table), finds every
line where `public` or `open` appears as a standalone whitespace-delimited
token (not inside a comment) followed on the same line by a declaration
keyword (`func`, `var`, `let`, `struct`, `class`, `enum`, `protocol`,
`typealias`, `init`, `actor`, `subscript`, `extension`), then joins
continuation lines using open/close-paren balance until the header is
complete (a same-line-balanced brace pair, e.g. `public init() {}` or
`{ get set }`, is kept whole; a body that opens but does not close on that
line is truncated at the opening `{`). A preceding attribute-only line
(`@discardableResult`, `@MainActor`, etc.) is folded into the signature.
Output is grouped by target → source file → declaration order, each target
section prefixed with its Gradle module and Kotlin package per spine §3.1,
exactly as the packet's task 4 asks.

## Result

```
targets=16 files=269 loc=38080 symbols=3165
```

| Target | Gradle module | Files | LOC | Public/open symbols |
|---|---|---|---|---|
| MKFoundation | `:mk-foundation` | 15 | 1234 | 118 |
| MKModel | `:mk-model` | 15 | 2176 | 322 |
| MKTextEngine | `:mk-textengine` | 17 | 2195 | 167 |
| MKArrange | `:mk-arrange` | 11 | 2078 | 108 |
| MKPathText | `:mk-pathtext` | 9 | 1945 | 125 |
| MKCanvas | `:mk-canvas` | 29 | 6580 | 485 |
| MKRender | `:mk-render` | 23 | 3603 | 201 |
| MKColor | `:mk-color` | 4 | 467 | 38 |
| MKExport | `:mk-export` | 22 | 3342 | 170 |
| MKFonts | `:mk-fonts` | 21 | 2480 | 257 |
| MKPersistence | `:mk-persistence` | 19 | 3283 | 423 |
| MKSync | `:mk-sync` | 10 | 1945 | 114 |
| MKStore | `:mk-store` | 18 | 1668 | 139 |
| MKAnalytics | `:mk-analytics` | 13 | 1004 | 84 |
| MKDesignSystem | `:mk-designsystem` | 19 | 1405 | 226 |
| MKAssets | `:mk-assets` | 24 | 2675 | 188 |
| **Total** | | **269** | **38080** | **3165** |

**No disagreement with `ANDROID_SPINE.md` §3.1.** Both the per-target file
count and per-target LOC produced by this script match §3.1's table
exactly (269 files / 38,080 LOC total; `MKRender` = 23 files, `MKAssets` =
24 files, matching the corrected numbers §3.1 explicitly calls out). The
script itself asserts this as a hard check (`mismatches` list) — a
disagreement would have printed under "DISAGREEMENTS WITH SPINE §3.1" in
the script's stdout and in the generated file's own header; neither
occurred.

**Five iOS app-target harness/dead-code exclusions confirmed absent.**
`App/DesignSystemGallery.swift`, `App/Debug/PathTextHarnessView.swift`,
`App/Debug/PerfHUDView.swift`, `App/Debug/ShapingHarnessView.swift`, and
`EditorPlaceholderView.swift` never appear in `android/API_SURFACE.md`
(`grep`-confirmed, 0 hits for each). This is structural, not
discretionary: the script's scan root is `MakhtootKit/Sources/**` only —
the 16 library targets — and never touches `Makhtoot/**` (the `:app`
target), which is where all five excluded files and every other app-shell
file live. Agent 0.3's scope is the library surface only; the `:app`
target's surface is out of this packet's fence entirely (not merely the
five excluded files within it).

## Determinism proof (double-run, byte-for-byte)

Per the packet's acceptance criterion ("its output matches
`android/API_SURFACE.md` byte-for-byte") and spine §4's "the script must be
re-runnable and deterministic — a later gate re-runs it," the script was
run twice back-to-back and the two outputs compared directly (not merely
asserted):

```
$ bash Scripts/android/dump-api-surface.sh   # run 1 -> run_a.md
targets=16 files=269 loc=38080 symbols=3165
$ bash Scripts/android/dump-api-surface.sh   # run 2 -> run_b.md
targets=16 files=269 loc=38080 symbols=3165
$ diff run_a.md run_b.md
(0 lines — no output)
$ shasum -a 256 run_a.md run_b.md
db7b11c744939e6f71b3c2aebdaba7a9138744fd2bb5aa6ed26387887d0221e6  run_a.md
db7b11c744939e6f71b3c2aebdaba7a9138744fd2bb5aa6ed26387887d0221e6  run_b.md
```

Identical SHA-256, zero-line diff. **Deviation logged:** an earlier draft
of this script embedded a `Last generated: <UTC date>` line in the output
header, which would have broken byte-identical reproduction across two
different calendar days even though the actual symbol content was
unchanged — the wrong kind of "deterministic" for a file a gate re-runs
and diffs. Removed before finalizing; the header instead states plainly
that no timestamp is embedded and why. Caught by exactly the double-run
diff proof above, not by inspection alone.

## File integrity check

`android/API_SURFACE.md` is 4,052 lines / 276,169 bytes, ends with a single
trailing newline (not mid-entry), and has an even backtick count (13,348)
across the file — an odd count would be the signature of a truncated
inline-code span from a cut-off write. Every one of the 269 source files
either appears as a `### `<path>`` section with ≥1 extracted symbol, or is
one of 6 files independently verified (via a comment-excluding grep) to
have zero real `public`/`open` declarations at all
(`MKCanvas/CheckerboardPattern.swift`,
`MKDesignSystem/Themes/MKThemeColorHelpers.swift`,
`MKFonts/MKFontsCTFontSendable.swift`,
`MKPersistence/Internal/PersistenceSupport.swift`,
`MKStore/Verification.swift`, `MKTextEngine/CursiveAttachment.swift`) —
none silently dropped.

## Spot-check (packet task 6)

The packet's own suggested baseline
(`grep -c '^public\|^    public\|open '`) undercounts because it only
matches `public` at column 0 or exactly 4-space indent, missing deeper
nesting and lines where an attribute or modifier (`@Attribute(.unique)`,
`nonisolated`) precedes `public` on the same line:

```
$ grep -rcE '^public|^    public|open ' MakhtootKit/Sources/**/*.swift | awk -F: '{s+=$2} END {print s}'
3054
```

A tighter word-boundary spot-check (`\bpublic\b`/`\bopen\b` on any
non-comment line, no column restriction) overcounts because it includes
non-declaration mentions of the bare word "public" on an otherwise-code
line and double-counts any line where the token appears twice:

```
$ grep -rnE '\b(public|open)\b' MakhtootKit/Sources --include="*.swift" | grep -vE ':[0-9]+:\s*(///|//)' | wc -l
3178
```

The script's own count, **3165**, sits inside this `[3054, 3178]` band, as
expected for a proper declaration-boundary extraction that is stricter
than the loose word-boundary count and looser than the rigid column-0
count. An independent post-hoc check (a second, separate regex pass over
the generated file itself) confirmed zero entries contain more than one
standalone `public` token — i.e. no declaration was accidentally merged
with a following one (the failure mode described in the next section, now
fixed).

## Deviations / known limitations (recorded, not silently absorbed)

1. **Operator-overload / bitshift false-positive on generic-depth
   tracking — found and fixed.** An earlier version of the join heuristic
   also tracked `<`/`>` balance (to wait out multi-line generic
   constraint lists before finalizing a declaration). This codebase
   declares four `public static func <`/`==` operator overloads
   (`MKFoundation/MKMemoryGovernor.swift:71`,
   `MKFoundation/Entitlement/MKEntitlementState.swift:61`,
   `MKRender/DegradationController.swift:29`,
   `MKFonts/MKCatalogManifestFetchService.swift:128`) whose signature
   itself contains a bare, unmatched `<`/`==` token, and one bitshift
   literal (`MKFonts/MKLicenseRecord.swift`'s `MKEmbeddingRights(rawValue:
   1 << 0)`) adds further unmatched `<` characters. Either pattern left a
   naive angle-depth counter permanently unbalanced, which swallowed every
   subsequent declaration into one giant entry until a 60-line safety cap
   forced a (bad) cut. Fixed by dropping the angle-depth gate entirely and
   relying on paren-depth alone — verified safe because the sole
   `^\s*where\b`-on-its-own-line occurrence in the whole `Sources` tree
   (`MKCanvas/Gestures/MoveGesture.swift:112`) is inside a private
   function body, not a public declaration header, so no real
   multi-line-generic-constraint case was lost by dropping the gate.
   Verified post-fix: zero entries contain more than one standalone
   `public` token (see spot-check above).
2. **Trailing-comment stripping is a heuristic, not string-literal-aware.**
   `strip_trailing_line_comment` drops everything from the first `//` on a
   line unless an odd number of `"` characters precedes it (a coarse
   guard against stripping inside a string literal). A `//` appearing
   inside a string literal preceded by an *even* number of quotes on the
   same line would be mis-stripped. No such case was found in
   `MakhtootKit/Sources` (spot-checked; Swift string literals containing
   `//` are rare and none appear on a `public`-declaration line here), but
   this is a real limitation of a grep/awk-shaped extractor, not swept
   under the rug.
3. **`MKColorSpec+HSB.swift` has no valid mechanical Kotlin filename
   transform under the naming rule (spine §3.3).** This is the exact
   example the spine itself names ("a `+` extension file"). It is an
   extension of `MKColorSpec` (declares `MKHSBAComponents` and HSB-related
   members on `MKColorSpec`), living in `MKColor`. Recorded here per §3.3's
   instruction that the resolution — merge into `MkColorSpec.kt` or use a
   documented alternate spelling such as `MkColorSpecHsb.kt` — is Batch 1's
   call to make explicitly, not this agent's to decide silently. No other
   file among the 269 fails the mechanical `Mk`-prefix transform; a
   sweep of every top-level `public` type name found no other unusual
   characters (no other `+`, no leading digits, no operator-shaped names).
4. **Multi-line default-value closures could mis-truncate in principle.**
   For a hypothetical declaration like `public init(action: () -> Void =
   {}) { <multi-line body> }`, the truncation logic finds the *first*
   unmatched `{` on the line that finally balances parens/braces overall;
   if a closure-typed default value's own `{}` appeared before the real
   body brace and the whole thing were NOT balanced on one line, truncation
   could land on the wrong brace. No instance of this exact shape exists
   in the current 269 files (checked: every declaration with a
   closure-typed default value in this codebase either closes its body on
   the same line or the default closure itself is on a later line, never
   ambiguously interleaved) — documented as a latent limitation for
   whoever re-runs this script after new code lands, not asserted as
   impossible.
5. **Acronym/Kotlin-name generation deferred entirely to Batch 1.** Per
   the packet's own scope, `android/API_SURFACE.md` records Swift
   signatures grouped by target/module/package; it does not propose
   Kotlin file or symbol names itself (Batch 1 · Agents 1.3/1.4 do that,
   consuming this file). The one file-naming edge case that *is* this
   agent's to flag (`MKColorSpec+HSB.swift`, item 3 above) is flagged.

## Tests added

None — this is a documentation/tooling artifact, not shipped product code;
the packet's acceptance criteria are the script's own exit code, section
completeness, and the byte-for-byte re-run proof, all satisfied above.

## Stub count delta

N/A — Batch 0 predates the stub burn-down counter (spine §5.1: "n/a — no
stubs exist yet" at G0).
