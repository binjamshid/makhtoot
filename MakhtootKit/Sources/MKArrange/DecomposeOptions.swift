import Foundation

// WS-04 packet §5 task 10 (D-108 "user opt-out switches to default
// spacing/forms"). A tiny options struct kept in its own file per the
// packet's deliverable list.

/// Options for `LigatureDecomposer.decompose(_:in:style:options:)`.
public struct DecomposeOptions: Sendable, Equatable {
    /// `true` (default, Q71): place constituents to match the original
    /// ligature's visual bounds (`MKFidelityMode.matchOriginal`, D-221's
    /// affine fit). `false`: explicit opt-out ، constituents at natural
    /// standalone advances, no fit (`MKFidelityMode.defaultForms`).
    public var fidelity: Bool

    public init(fidelity: Bool = true) {
        self.fidelity = fidelity
    }

    public static let fidelityDefault = DecomposeOptions(fidelity: true)
    public static let defaultForms = DecomposeOptions(fidelity: false)
}
