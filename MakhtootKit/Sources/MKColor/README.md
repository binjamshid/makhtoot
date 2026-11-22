# MKColor

Owner: WS-08 (`AGENT_TASK_PACKETS/WS-08-export-pipeline.md`). Color-space
storage and conversion for the export pipeline (D-117).

## Shipped (P10-EARLY + P10-COMPLETION, Run-3)

- `MKColorSpec` — the document/working-space color value (extended sRGB
  components, D-117), plus `cgColor()` (extended sRGB display/export path),
  `cgColorDisplayP3()` (display-only P3, never persisted), and
  `cgColorClampedSRGB()` (the finite `0...1` form raster encoders paint
  with).
- `ICCProfileStore`/`MKICCProfile`/`MKICCProfileProvenance` (task 2) —
  `loadBundled()` resolves `Resources/ICC/PressProfile.icc` if present and
  a valid CMYK-model profile, else the documented Apple Generic CMYK
  fallback (`CGColorSpace(name: .genericCMYK)`). FD-03 is still
  founder-pending — `Resources/ICC/` ships EMPTY this session (only a
  README documenting the drop-in contract), so `loadBundled()` always
  resolves to the fallback today. `MKICCProfileProvenance.mayClaimPDFX`
  gates whether a PDF built against this profile may claim PDF/X
  (`.bundledICC` only, never the fallback) — consumed by `MKExport`'s
  `PDFOutputIntent`.
- `CMYKConverter` (task 3) — `cmyk(from:profile:)` (explicit
  `.relativeColorimetric`, D-226(1)), `cmykPerceptual(from:profile:)`
  (intent-comparison fixture only, never used in a production pipeline),
  `convertWholeImage(_:profile:)` (the raster whole-image conversion site,
  `.none`-alpha per Spike A, `ctx.setRenderingIntent(.relativeColorimetric)`
  set explicitly before redraw).

## D-226 verification protocol — WHAT was actually run, and the two
## empirical findings from doing so

**Tool**: littleCMS `transicc` 5.1 (`/opt/homebrew/bin/transicc`,
Homebrew `little-cms2`) — confirmed present on the implementation
machine; Argyll `xicclu` was checked and NOT found. `transicc` is the
tool of record, per D-226's "exact tool recorded at implementation."

**Profile**: the ONLY CMYK profile available this session — Apple's
built-in Generic CMYK, dumped to a standalone `.icc` file via
`CGColorSpace(name: .genericCMYK).copyICCData()` and fed to `transicc` as
`-o`.

**Ground truth corpus + method**: `Tests/MKColorTests/CMYKConverterTests.swift`'s
header has the exact reproducible commands. 8-bit sRGB input, relative
colorimetric (`-t1`), CMYK-percentage output. `CGColor.converted`'s output
matches `transicc`'s within ±1 percentage point for every swatch tested
EXCEPT pure black, which needed a documented, wider (±1.3pp) tolerance —
see below.

### Finding 1 — pure black: real CMM-engine divergence (not a bug)

CoreGraphics' ColorSync CMM and littleCMS disagree by ~1.21 percentage
points on the C channel for sRGB `(0,0,0)` specifically (M/Y/K all agree
within ±0.5pp) — both engines parse the IDENTICAL profile bytes with the
IDENTICAL intent; the divergence is each CMM's own interpolation near the
profile's black-point extreme, a well-known category of inter-CMM
disagreement. Documented with a wider, explicit tolerance in
`CMYKConverterTests.pureBlackMatchesWithinCMMEngineDivergenceTolerance`
rather than silently loosening the general ±1pp bound.

### Finding 2 — Apple Generic CMYK has NO rendering-intent differentiation
### at all (byte-level verified)

Task 3's out-of-gamut discriminator fixture (`#00FF00` under
`.relativeColorimetric` vs `.perceptual`, "asserted to differ by MORE than
tolerance") is **unsatisfiable** under the only profile available this
session: perceptual and relative-colorimetric conversions are numerically
IDENTICAL for every swatch tested, confirmed independently by BOTH
CoreGraphics (`CGColor.converted`) and littleCMS (`transicc -t0` vs
`-t1`). Byte-level inspection of the profile's own ICC tag table explains
why: the `A2B0` (perceptual), `A2B1` (relative colorimetric), and `A2B2`
(saturation) tags all point at the EXACT SAME byte offset (1928) and size
(21523 bytes) in the profile file — literally one shared LUT reused via
ICC tag-table indirection for all three intents, not merely numerically
similar independent tables. Apple's Generic CMYK profile simply does not
differentiate rendering intent. `CMYKConverterTests` asserts this ACTUAL,
verified behavior (not the packet's literal "must diverge" wording) with
a header explaining the finding — `.relativeColorimetric` is still passed
EXPLICITLY at every call site (correct, required practice for when a real
differentiated profile eventually ships via FD-03), even though it is a
no-op today under the fallback. This is the SAME class of finding as
D-226's own two blocking spikes (empirical, VERIFY-AT-IMPLEMENTATION,
not assumed) — recorded here with the same rigor.

## D-226 spikes A/B — run in P10-EARLY, resolved (regression-locked in
## `Tests/MKColorTests/CMYKSpikeEvidenceTests.swift`)

- **Spike A** (CMYK `CGBitmapContext` creation): **supported** on iOS, but
  **only with `CGImageAlphaInfo.none`** — `.premultipliedLast`/`.alphaOnly`
  both return `nil`. Consequence for the raster CMYK path
  (`CMYKConverter.convertWholeImage`, `PDFPrintCMYKExporter`): opacity/
  transparency compositing happens in an RGBA context FIRST; only the
  final whole-image conversion touches the (no-alpha) CMYK context.
- **Spike B** (`CGPDFContext` OutputIntent aux-key shape): the singular
  `kCGPDFContextOutputIntent` key + single `CFDictionary` is correct;
  `kCGPDFXDestinationOutputProfile` MUST be an ICC-based `CGColorSpaceRef`,
  never a `CGDataProvider` (ARCHITECTURE §16.5's illustrative code was
  wrong about this) — `MKExport/PDFOutputIntent.swift` implements the
  corrected shape.

## Spike D (P10-COMPLETION, `MKExport` territory but recorded here too
## since it's a `CGColorSpace`/ICC-adjacent finding)

`kCGPDFXOutputIntentSubtype` must be the LITERAL string `"GTS_PDFX"` —
CoreGraphics silently discards the WHOLE OutputIntent dictionary for any
other value. Full writeup: `MKExport/PDFOutputIntent.swift`'s header,
`docs/impl-log/WS-08.md`.

## FD-03 integration steps

See `Resources/ICC/README.md` — drop `PressProfile.icc` +
`PressProfile.LICENSE.md` into that directory; `ICCProfileStore
.loadBundled()` picks it up automatically, no code change. Re-run
`CMYKConverterTests`' ground-truth corpus against the new profile (the
discriminator test in particular only becomes MEANINGFUL once a real,
differentiated press profile exists).
