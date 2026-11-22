# `MKColor/Resources/ICC/` — bundled CMYK profile slot (FD-03)

**Status as of this session: EMPTY.** FD-03 (DECISIONS_LOG.md) is
**founder-pending**. This directory ships with no third-party ICC profile —
`ICCProfileStore.loadBundled()` always resolves to the documented fallback,
Apple's built-in Generic CMYK profile (`CGColorSpace(name: .genericCMYK)`),
per D-117's explicit "no invented licenses" rule.

## Drop-in contract (task 2 accept: "dropping in a profile file switches
output with no code change")

Once FD-03 resolves (founder selects a profile and its redistribution
license is verified — candidates: eciRGB/ISO-Coated-v2-class press
profiles):

1. Place the `.icc` file here as `PressProfile.icc` (the literal name
   `ICCProfileStore.bundledProfileResourceName` looks for).
2. Place the license/verification evidence alongside it as
   `PressProfile.LICENSE.md` (same D-120 evidence-capture pattern already
   used for bundled fonts — `Sources/MKFonts/Resources/LicenseRecords/`).
3. No Swift code changes are required: `ICCProfileStore.loadBundled()`
   already prefers a present, valid (CMYK-model) bundled file over the
   fallback — see that file's `loadBundledFile(bundle:)`.
4. Re-run `swift test --filter MKColorTests` — the CMYK ground-truth
   fixtures in `CMYKConverterTests.swift` were computed against the Apple
   Generic CMYK fallback (this session's only available profile, see that
   file's header); they will need a fresh ground-truth pass against the
   newly-bundled profile using the same external-tool protocol
   (`docs/impl-log/WS-08.md`'s "CMYK verification protocol" section)
   before they're meaningful for the new profile — the discriminator test
   (`perceptualVsRelativeColorimetricDivergeOnOutOfGamutColor` /
   equivalent) in particular is expected to become MEANINGFUL only once a
   real, differentiated press profile lands (see that test's own doc
   comment for why the Apple Generic CMYK fallback does not exercise it).

## Why this file exists

`Bundle.module`-relative resource loading needs an actual (even if empty
of profiles) `Resources/ICC/` directory declared in `Package.swift`'s
`resources:` array for `MKColor` — see that file's target declaration.
