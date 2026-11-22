import Foundation

// WS-02 packet §5 task 2 (font-reference slot of `MKTextStyle`). Stable
// pointer to a font, independent of whether the font is currently
// registered/resolvable ، resolution against an actual `CTFont` happens in
// `MKFonts`/`MKTextEngine` (WS-09/WS-03), never here (`MKModel` imports no
// CoreText, per DEPENDENCY_GRAPH.md's "pure value types" rule for this
// target).
///
/// `fontID` is non-optional so every persisted reference round-trips
/// deterministically even before a real font catalog exists: system/ad hoc
/// fonts get a synthetic `"system.<postScriptName>"` id (see
/// `MKFontRef.system(postScriptName:)`) rather than `nil`, keeping the type
/// "make illegal states unrepresentable" and matching the `scene.json`
/// schema's `fontRef` def (§13.4), which marks `fontID` required.
public struct MKFontRef: Hashable, Sendable, Codable, Equatable {
    /// Catalog id ، `MKFontCatalogRecord.fontID` once WS-09 populates the
    /// real catalog (bundled/premium/user-imported fonts), or a synthetic
    /// `"system.<postScriptName>"` id for fonts resolved outside the
    /// catalog (system fallback, pre-WS-09 fixtures).
    public var fontID: String
    public var postScriptName: String
    /// D-122: true for a user-imported font (locks on premium expiry).
    public var userImported: Bool

    public init(fontID: String, postScriptName: String, userImported: Bool = false) {
        self.fontID = fontID
        self.postScriptName = postScriptName
        self.userImported = userImported
    }

    /// Convenience constructor for fonts with no catalog entry yet.
    public static func system(postScriptName: String) -> MKFontRef {
        MKFontRef(fontID: "system.\(postScriptName)", postScriptName: postScriptName, userImported: false)
    }

    /// The stub-era default: system SF Arabic, matching
    /// `SystemFontStubProvider`'s `CTFontCreateUIFontForLanguage` choice in
    /// `MKFoundation` (WS-01) until WS-09 ships the real catalog.
    public static let systemFallback = MKFontRef.system(postScriptName: ".SFArabic")
}
