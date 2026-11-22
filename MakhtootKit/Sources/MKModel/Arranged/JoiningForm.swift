import Foundation

// WS-02 packet §5 task 4. Joining-form vocabulary shared by `MKGlyphNode`.
// D-107: "To realize a chosen form for a letter, reshape the single letter
// in a synthetic context using U+200D ZWJ ... through the same font, then
// harvest that glyph ... Store as `JoiningForm` enum + resolved glyph id."

/// Contextual joining form of an Arabic letter ، isolated / initial /
/// medial / final (glossary term "Joining Form").
public enum MKJoiningForm: String, Hashable, Sendable, Codable {
    case isolated, initial, medial, final
}

/// Full joining state of a glyph node: its resolved form plus whether it
/// currently joins its logical neighbors, and whether that join was broken
/// by an explicit user action (§7 join-break/restore).
public struct MKJoiningState: Hashable, Sendable, Codable, Equatable {
    public var form: MKJoiningForm
    public var joinsPrevious: Bool
    public var joinsNext: Bool
    public var brokenByUser: Bool

    public init(form: MKJoiningForm, joinsPrevious: Bool, joinsNext: Bool, brokenByUser: Bool = false) {
        self.form = form
        self.joinsPrevious = joinsPrevious
        self.joinsNext = joinsNext
        self.brokenByUser = brokenByUser
    }

    /// A single, unjoined letter ، the default for a freshly-arranged
    /// isolated glyph before `MKArrange` (WS-04) resolves real join state.
    public static let isolatedDefault = MKJoiningState(form: .isolated, joinsPrevious: false, joinsNext: false)
}
