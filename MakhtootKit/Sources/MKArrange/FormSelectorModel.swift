import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import MKTextEngine

// WS-04 packet §5 task 8 (D-106/D-107, BRIEF "offer a visual selector for
// isolated/initial/medial/final"). A pure, UI-free model WS-06's popover
// binds to ، this module never renders anything (packet mission: "you
// expose pure models... they bind to").

/// One offered contextual form (packet task 8: "per-form preview path +
/// advance... isValid... current selection").
public struct MKFormOption: Sendable, Equatable {
    public var form: MKJoiningForm
    /// `false` when the letter's joining type structurally cannot realize
    /// this form (right-joining letters: initial/medial invalid,
    /// `MKJoiningTypeTable.validForms` ، task 8 accept: "for د exactly
    /// isolated+final enabled"). Disabled options still carry a preview
    /// (the coerced nearest-valid glyph) so a disabled chip can still show
    /// SOMETHING in a greyed-out state, matching `MKResolvedForm
    /// .wasCoerced`'s own "disable, don't hide" intent (§7.2.1).
    public var isValid: Bool
    /// `false` when the font has no distinct glyph for this form (§7.2.1:
    /// "harvested glyph differs from the isolated-form glyph... if
    /// identical, `achieved = false`" ، surfaced here so WS-06 can show the
    /// "الخط لا يوفر هذا الشكل" tooltip).
    public var achieved: Bool
    public var previewOutline: MKPathData?
    public var previewAdvance: CGSize
    public var glyphID: UInt16

    public init(form: MKJoiningForm, isValid: Bool, achieved: Bool, previewOutline: MKPathData?, previewAdvance: CGSize, glyphID: UInt16) {
        self.form = form
        self.isValid = isValid
        self.achieved = achieved
        self.previewOutline = previewOutline
        self.previewAdvance = previewAdvance
        self.glyphID = glyphID
    }
}

/// The full picker model for one broken letter (packet task 8). Immutable
/// value; `select(form:)`-equivalent is `command(selecting:)` below, which
/// RETURNS the `MKCommand` to apply rather than mutating anything itself
/// (this module stays UI-free and side-effect-free ، WS-06 calls
/// `CanvasSession.perform(_:)` with the returned command).
public struct FormSelectorModel: Sendable, Equatable {
    public var nodeID: MKNodeID
    public var scalar: UInt32
    public var currentForm: MKJoiningForm
    /// Always length 4, one entry per `MKJoiningForm` case, in
    /// isolated/initial/medial/final order (task 8 accept: "model for ح
    /// lists 4 valid options with distinct previews").
    public var options: [MKFormOption]

    public init(nodeID: MKNodeID, scalar: UInt32, currentForm: MKJoiningForm, options: [MKFormOption]) {
        self.nodeID = nodeID
        self.scalar = scalar
        self.currentForm = currentForm
        self.options = options
    }

    /// Builds the model for `nodeID` (must resolve to a top-level
    /// `MKGlyphNode` in `composition` whose `provenance.codepoints.first`
    /// is a single letter) by resolving all 4 forms via `MKFormResolver`.
    public static func build(
        for nodeID: MKNodeID, in composition: ArrangedComposition, style: MKTextStyle, fonts: any MKFontProviding = SystemFontStubProvider()
    ) async -> FormSelectorModel? {
        guard case .glyph(let node)? = composition.child(id: nodeID),
              let scalar = node.provenance.codepoints.first.flatMap(Unicode.Scalar.init)
        else { return nil }

        let resolver = MKFormResolver(fonts: fonts)
        let validForms = MKJoiningTypeTable.validForms(for: scalar)
        // Isolated-form baseline for the `achieved` comparison (§7.2.1):
        // resolved once, reused for every non-isolated option.
        let isolatedResolved = await resolver.resolve(letter: scalar, form: .isolated, style: style)

        var options: [MKFormOption] = []
        for form in [MKJoiningForm.isolated, .initial, .medial, .final] {
            guard let resolved = await resolver.resolve(letter: scalar, form: form, style: style) else {
                options.append(MKFormOption(form: form, isValid: false, achieved: false, previewOutline: nil, previewAdvance: .zero, glyphID: 0))
                continue
            }
            let achieved = form == .isolated || resolved.glyphID != isolatedResolved?.glyphID
            options.append(MKFormOption(
                form: form, isValid: validForms.contains(form), achieved: achieved,
                previewOutline: resolved.outline, previewAdvance: resolved.advance, glyphID: resolved.glyphID))
        }

        return FormSelectorModel(nodeID: nodeID, scalar: scalar.value, currentForm: node.joining.form, options: options)
    }

    /// Task 8's `select(form:)`: swaps the node's glyph id/outline/advance
    /// to the chosen option (`chosenForm` recorded via `MKJoiningState
    /// .form`), position unchanged (same no-reflow contract as
    /// `JoinController`), undoable + journal-codable
    /// (`ArrangeCommands.replaceComposition`, `MKReplaceNodesCommand`).
    /// Returns `nil` if `form` isn't among this model's resolved options
    /// (shouldn't happen ، `options` always has all 4 ، defensive).
    public func command(selecting form: MKJoiningForm, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        guard let option = options.first(where: { $0.form == form }),
              case .glyph(var node)? = ownerNode.composition.child(id: nodeID)
        else { return nil }

        node.glyph.glyphID = option.glyphID
        node.outline = option.previewOutline
        node.joining.form = form
        // A user-chosen form outside the letter's natural joining state
        // (rare ، usually the picker only offers valid forms, but an
        // explicit user override is still legal per BRIEF "offer a visual
        // selector") is recorded as a break, same flag JoinController uses.
        node.joining.brokenByUser = true

        var copy = ownerNode.composition
        copy.nodes = copy.nodes.map { $0.id == nodeID ? .glyph(node) : $0 }
        return ArrangeCommands.replaceComposition(of: ownerNode, with: copy, label: "اختيار الشكل")   // choose form
    }
}
