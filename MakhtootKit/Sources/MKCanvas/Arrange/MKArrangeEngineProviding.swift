import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 15 ("Arrange mode UX", deferred from the P4
// CANVAS-LANE session ، see `docs/impl-log/WS-06.md`'s task table). This
// file is the `MKArrange` consumption seam, mirroring the EXACT precedent
// `Geometry/MKCanvasGeometrySource.swift` already set for `MKRender`
// before that module's real types existed: `Package.swift`'s `MKCanvas`
// target does not (and per this run's fence may not) declare a dependency
// edge on `MKArrange` ، WS-04 shipped `MKArrange` as a module downstream of
// `MKModel`/`MKPersistence` only (`CONTRACTS.md`'s "WS-04 (`MKArrange`) ،
// arrange-engine contract"), with no edge back into `MKCanvas`, and adding
// one is a `Package.swift` change outside this session's fence (additive
// dependency edges are logged, not silently added, per WS-03/WS-06/WS-07's
// own precedent in this exact file's sibling).
//
// So: `MKCanvas` declares its OWN protocol seam here, spelled entirely in
// terms of types it ALREADY has access to (`MKModel`'s arranged-node types
// ، `MKArrangedTextNode`, `ArrangedComposition`, `MKArrangedChild`,
// `MKGlyphNode`, `MKMarkNode`, `MKJoiningForm` ، are all `MKModel`
// declarations, not `MKArrange` ones, per `MKModel/Arranged/*.swift`; only
// a handful of small result/option types ، `MKFormOption`,
// `FormSelectorModel`, `RevertService.RevertPreflight` ، are genuinely
// `MKArrange`-owned and get small structural mirrors below) plus
// `MKPersistence.MKCommand` (already used the same undeclared-but-working
// way by every other file in this module, e.g. `CanvasSession.perform`).
// The app target (`Makhtoot/`, this same run's OTHER fence) already links
// the `MKArrange` product directly (`Makhtoot.xcodeproj`'s
// `packageProductDependencies`), so `MKArrangeInteractionAdapter`
// (`Makhtoot/AppShell/Scenes/Editor/`) is the real conformer ، every method
// here is a near-verbatim pass-through to the matching `MKArrange` API
// (`ArrangeDeriver`, `RevertService`, `LevelMapping`, `JoinController`,
// `FormSelectorModel`, `LigatureDecomposer`, `MarkAttachmentController`,
// `ArrangeStyleEditor`), the same "one-line substitution, not a redesign"
// promise `MKCanvasRenderAdapter` already delivers for `MKCanvasGeometrySource`
// /`MKCanvasRenderBridge`.

/// Structural mirror of `MKArrange.MKFormOption` (packet task 8) ، carries
/// enough for a popover to render 4 live previews in the composition's own
/// font without `MKCanvas` needing to import `MKArrange` for the type.
public struct MKArrangeFormOption: Sendable, Equatable {
    public var form: MKJoiningForm
    public var isValid: Bool
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

/// Structural mirror of `MKArrange.FormSelectorModel` (packet task 8, R-8.3).
public struct MKArrangeFormSelectorModel: Sendable, Equatable {
    public var nodeID: MKNodeID
    public var scalar: UInt32
    public var currentForm: MKJoiningForm
    /// Always length 4, isolated/initial/medial/final order.
    public var options: [MKArrangeFormOption]

    public init(nodeID: MKNodeID, scalar: UInt32, currentForm: MKJoiningForm, options: [MKArrangeFormOption]) {
        self.nodeID = nodeID
        self.scalar = scalar
        self.currentForm = currentForm
        self.options = options
    }
}

/// Structural mirror of `MKArrange.RevertService.RevertPreflight` (packet
/// task 14, R-6.12/FL-13) ، the exact PRD confirmation copy lives here too
/// so the app layer's alert can bind it without importing `MKArrange`.
public struct MKArrangeRevertPreflight: Sendable, Equatable {
    public var editedNodeCount: Int
    public var willDiscard: Bool

    public init(editedNodeCount: Int, willDiscard: Bool = true) {
        self.editedNodeCount = editedNodeCount
        self.willDiscard = willDiscard
    }

    /// PRD FL-13 step 2's exact confirmation body copy (also the D-106
    /// §5.4 preflight message `RevertService.RevertPreflight` carries).
    public static let confirmationTitle = "العودة إلى النص؟"
    public static let confirmationBody = "سيؤدي هذا إلى حذف جميع التعديلات اليدوية على الحروف والحركات. النص الأصلي سيُستعاد كما كان."
    public static let confirmAction = "العودة"
    public static let cancelAction = "إلغاء"
}

/// Structural mirror of the D-221 recompose dirty-check result
/// (`MKArrange.LigatureDecomposer.recompose`'s `editedNodeCount` throw
/// payload, packet task 11, R-8.12's exact confirmation copy).
public struct MKArrangeRecomposePreflight: Sendable, Equatable {
    public var editedComponentCount: Int
    public var requiresConfirmation: Bool { editedComponentCount > 0 }

    public init(editedComponentCount: Int) {
        self.editedComponentCount = editedComponentCount
    }

    /// R-8.12's exact confirmation copy.
    public static let confirmationBody = "ستفقد تعديلات مكوّنات الوصلة"
}

/// R-6.11's exact choice-sheet copy (arrange-then-edit-source conflict).
public enum MKArrangeSourceEditConflict {
    public static let title = "تعديل النص يتطلب العودة إلى النص ، ستفقد التنسيق اليدوي"
    public static let revertAndEdit = "العودة والتعديل"
    public static let duplicateThenEdit = "نسخ ثم تعديل"
    public static let cancel = "إلغاء"
}

/// The `MKArrange` consumption seam (see file header). Every method name/
/// parameter shape mirrors its `MKArrange` counterpart as closely as the
/// "no `MKArrange` import" constraint allows ، `ownerNode:` (the owner's
/// FULL `MKArrangedTextNode`, matching `ArrangeCommands.replaceComposition`'s
/// own post-WS-02-session-3 signature) is the consistent shape every
/// composition-internal mutation takes, same as the real
/// `JoinController`/`FormSelectorModel`/`LigatureDecomposer`/
/// `MarkAttachmentController`/`ArrangeStyleEditor` APIs already documented
/// in `CONTRACTS.md`.
@MainActor
public protocol MKArrangeEngineProviding: AnyObject {
    // MARK: - Entry & derivation (R-6.1, R-6.2)

    /// Derives an Arranged Composition from `sourceNodeID` (must be
    /// `.liveText`/`.pathText` in `scene`) and returns the undoable
    /// `MKCommand` swapping it in place (same node id ، `ArrangeCommands
    /// .arrangeCommand`'s contract). `nil` if `sourceNodeID` cannot be
    /// found/derived.
    func deriveArrangeCommand(sourceNodeID: MKNodeID, in scene: MKScene) async throws -> (any MKCommand)?

    // MARK: - Revert (R-6.12, FL-13)

    func revertPreflight(for node: MKArrangedTextNode) -> MKArrangeRevertPreflight
    func revertCommand(arrangedNodeID: MKNodeID, node: MKArrangedTextNode) throws -> any MKCommand

    // MARK: - Level mapping (R-6.4, R-6.14)

    func nodeIDs(forUTF16Range range: Range<Int>, in composition: ArrangedComposition, includeMarks: Bool) -> Set<MKNodeID>
    func utf16Ranges(forNodeIDs ids: Set<MKNodeID>, in composition: ArrangedComposition) -> [Range<Int>]
    func clusterSiblings(of id: MKNodeID, in composition: ArrangedComposition) -> Set<MKNodeID>

    // MARK: - Join break/restore + form selector (§8.1)

    func breakJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand
    func restoreJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand
    func formSelectorModel(for nodeID: MKNodeID, ownerNode: MKArrangedTextNode) async -> MKArrangeFormSelectorModel?
    /// Builds the command from an ALREADY-LOADED `model`
    /// (`formSelectorModel(for:ownerNode:)`'s result ، the popover always
    /// loads one before the user can tap an option, so a synchronous
    /// signature here never needs its own re-resolve).
    func formSelectionCommand(selecting form: MKJoiningForm, from model: MKArrangeFormSelectorModel, ownerNode: MKArrangedTextNode) -> (any MKCommand)?

    // MARK: - Ligature decompose/recompose (§8.2)

    /// `false` when the target isn't a composed, decomposable ligature
    /// group (drives the "فك الوصلة" affordance's enabled state).
    func canDecompose(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> Bool
    /// Returns the undoable command plus whether D-221's fidelity clamp
    /// auto-refused fidelity mode (R-8.10's notice-UX trigger).
    func decomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, fidelity: Bool) async throws -> (command: any MKCommand, fidelityAutoRefused: Bool)
    func recomposePreflight(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> MKArrangeRecomposePreflight
    func recomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, force: Bool) throws -> any MKCommand

    // MARK: - Marks (§7)

    func detachMarkCommand(markID: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)?
    func reattachMarkCommand(markID: MKNodeID, toBase: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)?

    // MARK: - Per-child style/transform edit helpers (task 13, R-6.5)

    /// Nudges every child in `ids` (glyph and/or mark, including decomposed-
    /// ligature components) by the SAME composition-space `delta` in ONE
    /// command ، the drag-move primitive (mark move-while-attached and
    /// glyph move share this exact "add delta to `transform.position`"
    /// semantics per `MarkAttachmentController.move`'s own doc comment, so
    /// one call covers both R-6.5's glyph move and R-7.4's mark move).
    func nudgePositionCommand(by delta: CGSize, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
    func setTransformCommand(_ transform: MKTransform2D, forChildID id: MKNodeID, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
    func setStyleCommand(_ style: MKStyle, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
    func setOpacityCommand(_ opacity: Double, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
}
