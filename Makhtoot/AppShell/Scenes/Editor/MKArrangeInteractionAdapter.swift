import CoreGraphics
import Foundation
import MKArrange
import MKCanvas
import MKFoundation
import MKModel
import MKPersistence
import MKTextEngine

/// Wires WS-04's real `MKArrange` engine into WS-06's `MKArrangeEngineProviding`
/// consumption seam (`MKCanvas/Arrange/MKArrangeEngineProviding.swift`) ، the
/// exact "one-line substitution, not a redesign" promise that file's header
/// makes, mirroring `MKCanvasRenderAdapter`'s own role for
/// `MKCanvasGeometrySource`/`MKCanvasRenderBridge`. Lives in the app target
/// (this session's OTHER fence) because `MKCanvas` cannot depend on
/// `MKArrange` without a `Package.swift` edit (out of fence this run) ،
/// `Makhtoot.xcodeproj` already links the `MKArrange` product directly, so
/// the app is the natural composition root for this bridge (same "app owns
/// the seam" principle D-231 already established for the render adapter).
@MainActor
final class MKArrangeInteractionAdapter: MKArrangeEngineProviding {
    private let deriver: ArrangeDeriver
    private let revertService = RevertService()
    private let joinController: JoinController
    private let ligatureDecomposer: LigatureDecomposer
    private let markController = MarkAttachmentController()
    private let shapingService: MKShapingService
    private let fonts: any MKFontProviding

    init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.fonts = fonts
        self.deriver = ArrangeDeriver(fonts: fonts)
        self.joinController = JoinController(fonts: fonts)
        self.ligatureDecomposer = LigatureDecomposer(fonts: fonts)
        self.shapingService = MKShapingService(fonts: fonts)
    }

    // MARK: - Entry & derivation (R-6.1, R-6.2)

    func deriveArrangeCommand(sourceNodeID: MKNodeID, in scene: MKScene) async throws -> (any MKCommand)? {
        let (core, string, style, frame, pathData): (MKNodeCore, String, MKTextStyle, MKTextFrameSpec, MKBezierPathData?)
        switch scene.node(id: sourceNodeID) {
        case .liveText(let n): (core, string, style, frame, pathData) = (n.core, n.text.string, n.style, n.frame, nil)
        case .pathText(let n): (core, string, style, frame, pathData) = (n.core, n.text.string, n.style, .singleLine, n.path)
        default: return nil
        }
        let capture = await shapingService.captureResult(MKShapingRequest(string: string, style: style, frame: frame))
        let composition = await deriver.derive(sourceText: string, style: style, capture: capture, paintStyle: core.style, pathData: pathData)
        let origin: MKArrangeOrigin = pathData != nil ? .pathText(pathData!) : .liveText
        return ArrangeCommands.arrangeCommand(sourceNodeID: sourceNodeID, core: core, composition: composition, derivedFrom: origin)
    }

    // MARK: - Revert (R-6.12, FL-13)

    func revertPreflight(for node: MKArrangedTextNode) -> MKArrangeRevertPreflight {
        let real = revertService.preflight(for: node.composition)
        return MKArrangeRevertPreflight(editedNodeCount: real.editedNodeCount, willDiscard: real.willDiscard)
    }

    func revertCommand(arrangedNodeID: MKNodeID, node: MKArrangedTextNode) throws -> any MKCommand {
        try revertService.revertCommand(arrangedNodeID: arrangedNodeID, node: node)
    }

    // MARK: - Level mapping (R-6.4, R-6.14)

    func nodeIDs(forUTF16Range range: Range<Int>, in composition: ArrangedComposition, includeMarks: Bool) -> Set<MKNodeID> {
        LevelMapping.nodeIDs(forUTF16Range: range, in: composition, includeMarks: includeMarks)
    }

    func utf16Ranges(forNodeIDs ids: Set<MKNodeID>, in composition: ArrangedComposition) -> [Range<Int>] {
        LevelMapping.utf16Ranges(forNodeIDs: ids, in: composition)
    }

    func clusterSiblings(of id: MKNodeID, in composition: ArrangedComposition) -> Set<MKNodeID> {
        LevelMapping.clusterSiblings(of: id, in: composition)
    }

    // MARK: - Join break/restore + form selector (§8.1)

    func breakJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand {
        guard case .glyph(let a)? = ownerNode.composition.child(id: nodeAID), case .glyph(let b)? = ownerNode.composition.child(id: nodeBID) else {
            throw MKArrangeAdapterError.notAGlyph
        }
        let result = try await joinController.breakJoin(a, b, style: ownerNode.composition.sourceBackup.style)
        return joinController.command(applying: result, ownerNode: ownerNode, isBreak: true)
    }

    func restoreJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand {
        guard case .glyph(let a)? = ownerNode.composition.child(id: nodeAID), case .glyph(let b)? = ownerNode.composition.child(id: nodeBID) else {
            throw MKArrangeAdapterError.notAGlyph
        }
        let result = try await joinController.restoreJoin(a, b, style: ownerNode.composition.sourceBackup.style)
        return joinController.command(applying: result, ownerNode: ownerNode, isBreak: false)
    }

    func formSelectorModel(for nodeID: MKNodeID, ownerNode: MKArrangedTextNode) async -> MKArrangeFormSelectorModel? {
        guard let real = await FormSelectorModel.build(for: nodeID, in: ownerNode.composition, style: ownerNode.composition.sourceBackup.style, fonts: fonts) else { return nil }
        let options = real.options.map {
            MKArrangeFormOption(form: $0.form, isValid: $0.isValid, achieved: $0.achieved, previewOutline: $0.previewOutline, previewAdvance: $0.previewAdvance, glyphID: $0.glyphID)
        }
        return MKArrangeFormSelectorModel(nodeID: real.nodeID, scalar: real.scalar, currentForm: real.currentForm, options: options)
    }

    /// Builds the command directly from `model`'s already-resolved options
    /// (no re-resolve needed ، same "swap glyph id/outline, position
    /// unchanged" mechanics as the real `MKArrange.FormSelectorModel
    /// .command(selecting:ownerNode:)`, expressed against the SEAM's own
    /// `MKArrangeFormOption` mirror instead of importing that exact type).
    func formSelectionCommand(selecting form: MKJoiningForm, from model: MKArrangeFormSelectorModel, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        guard let option = model.options.first(where: { $0.form == form }),
              case .glyph(var node)? = ownerNode.composition.child(id: model.nodeID)
        else { return nil }
        node.glyph.glyphID = option.glyphID
        node.outline = option.previewOutline
        node.joining.form = form
        node.joining.brokenByUser = true
        var composition = ownerNode.composition
        composition.nodes = composition.nodes.map { $0.id == model.nodeID ? .glyph(node) : $0 }
        return ArrangeCommands.replaceComposition(of: ownerNode, with: composition, label: "اختيار الشكل")   // choose form
    }

    // MARK: - Ligature decompose/recompose (§8.2)

    func canDecompose(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> Bool {
        guard case .ligature(let group)? = ownerNode.composition.child(id: groupID), case .composed(let composed) = group.state else { return false }
        return composed.decomposable
    }

    func decomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, fidelity: Bool) async throws -> (command: any MKCommand, fidelityAutoRefused: Bool) {
        let command = try await ligatureDecomposer.decomposeCommand(groupID: groupID, ownerNode: ownerNode, options: DecomposeOptions(fidelity: fidelity))
        // `decomposeCommand`'s own `DecomposeResult.fidelityAutoRefused`
        // (R-8.10's notice-UX trigger) is folded into the built command
        // rather than returned separately by that API ، re-derive it here
        // by peeking at the LOW-LEVEL `decompose(_:sourceString:style:options:)`
        // once more (cheap: pure value-type recomputation, no I/O), which
        // is the ONLY place that flag is surfaced.
        guard case .ligature(let group)? = ownerNode.composition.child(id: groupID), case .composed = group.state else {
            return (command, false)
        }
        let result = try await ligatureDecomposer.decompose(group, sourceString: ownerNode.composition.sourceBackup.sourceString, style: ownerNode.composition.sourceBackup.style, options: DecomposeOptions(fidelity: fidelity))
        return (command, result.fidelityAutoRefused)
    }

    func recomposePreflight(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> MKArrangeRecomposePreflight {
        guard case .ligature(let group)? = ownerNode.composition.child(id: groupID), case .decomposed(let d) = group.state else {
            return MKArrangeRecomposePreflight(editedComponentCount: 0)
        }
        let edited = d.components.filter { $0.transform != .identity || $0.style != group.style }.count
        return MKArrangeRecomposePreflight(editedComponentCount: edited)
    }

    func recomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, force: Bool) throws -> any MKCommand {
        try ligatureDecomposer.recomposeCommand(groupID: groupID, ownerNode: ownerNode, force: force)
    }

    // MARK: - Marks (§7)

    func detachMarkCommand(markID: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        markController.detachCommand(markID: markID, ownerNode: ownerNode)
    }

    func reattachMarkCommand(markID: MKNodeID, toBase: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        markController.reattachCommand(markID: markID, toBase: toBase, ownerNode: ownerNode)
    }

    // MARK: - Per-child style/transform edit helpers (task 13, R-6.5)

    /// `ArrangeStyleEditor.nudgePosition` only takes a SINGLE `forChildID:`
    /// ، this seam's `forChildIDs:` (plural, R-6.6's "multi-select... group
    /// transforms" + the drag-move primitive covering a multi-glyph
    /// selection in one step) is realized directly against
    /// `ArrangeCommands.replaceComposition` (also public `MKArrange` API)
    /// rather than looping the single-id helper N times (which would
    /// require N separate `MKReplaceNodesCommand`s instead of one).
    func nudgePositionCommand(by delta: CGSize, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        let composition = Self.mapMatching(ids, in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.transform.position.x += delta.width; g.transform.position.y += delta.height; return .glyph(g)
            case .mark(var m): m.transform.position.x += delta.width; m.transform.position.y += delta.height; return .mark(m)
            case .ligature(var l): l.transform.position.x += delta.width; l.transform.position.y += delta.height; return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.transform.position.x += delta.width
            c.transform.position.y += delta.height
            return c
        }
        return ArrangeCommands.replaceComposition(of: ownerNode, with: composition, label: "تحريك", coalescingKeySuffix: "move:\(gestureID)")
    }

    func setTransformCommand(_ transform: MKTransform2D, forChildID id: MKNodeID, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        ArrangeStyleEditor.setTransform(transform, forChildID: id, ownerNode: ownerNode, gestureID: gestureID)
    }

    func setStyleCommand(_ style: MKStyle, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        ArrangeStyleEditor.setStyle(style, forChildIDs: ids, ownerNode: ownerNode, gestureID: gestureID)
    }

    func setOpacityCommand(_ opacity: Double, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        ArrangeStyleEditor.setOpacity(opacity, forChildIDs: ids, ownerNode: ownerNode, gestureID: gestureID)
    }

    // MARK: - Small helpers

    /// Same two-level (top-level child + decomposed-ligature component)
    /// reach as `MKArrange.ArrangeStyleEditor`'s own private `mapMatching`
    /// ، duplicated here (small, self-contained) since that helper isn't
    /// part of `MKArrange`'s public surface and this adapter needs it for
    /// the plural `forChildIDs:` nudge primitive above.
    private static func mapMatching(
        _ ids: Set<MKNodeID>, in composition: ArrangedComposition,
        _ mapTop: (MKArrangedChild) -> MKArrangedChild,
        mappingComponent mapComponent: (MKGlyphNode) -> MKGlyphNode
    ) -> ArrangedComposition {
        var copy = composition
        copy.nodes = copy.nodes.map { child -> MKArrangedChild in
            if ids.contains(child.id) { return mapTop(child) }
            if case .ligature(var group) = child, case .decomposed(var decomposed) = group.state {
                var touched = false
                decomposed.components = decomposed.components.map { component in
                    guard ids.contains(component.id) else { return component }
                    touched = true
                    return mapComponent(component)
                }
                if touched { group.state = .decomposed(decomposed); return .ligature(group) }
            }
            return child
        }
        return copy
    }
}

enum MKArrangeAdapterError: Error {
    case notAGlyph
}
