import CoreText

/// `CTFont` is a Core Foundation opaque type Apple documents as safe to
/// use (read its immutable metrics/glyphs/tables) from any thread once
/// created ، there is no mutable shared state a `CTFont` instance exposes.
/// The Swift 6 concurrency checker has no way to know that (it is not
/// marked `Sendable` upstream), so every actor-isolated API in this module
/// that hands a `CTFont` across an isolation boundary
/// (`MKFontRegistry.ctFont(for:...)`, `MKFontCatalog.previewAttributedString`)
/// needs this retroactive conformance to type-check under strict
/// concurrency. `@unchecked` because the compiler cannot verify the
/// invariant itself ، it is a property of the underlying Core Text API
/// contract, not something this module enforces in code.
extension CTFont: @retroactive @unchecked Sendable {}
