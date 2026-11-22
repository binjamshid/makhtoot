import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
@testable import MKCanvas

// Test scaffolding for the packet-task-15 Arrange Mode interaction layer ،
// same architectural role `CanvasTestSupport.swift`'s `FakeGeometrySource`/
// `RecordingRenderBridge` already play for the P4 slice: `MKCanvas` cannot
// depend on `MKArrange` (see `Sources/MKCanvas/Arrange
// /MKArrangeEngineProviding.swift`'s header for why), so these tests verify
// this module's OWN wiring (mode transitions, selection routing, command
// dispatch, undo coalescing) against a scripted double, not `MKArrange`'s
// actual derivation/join/decompose ALGORITHMS ، those already have their
// own from-first-principles coverage in `MKArrangeTests`.

@MainActor
enum ArrangeFixture {
    /// A small, hand-built composition standing in for a derived "بَر"
    /// (ب + fatha mark, ر) PLUS a composed لا-style ligature group appended
    /// ، enough surface for join/mark/level-mapping/ligature-decompose
    /// tests without needing real shaping. Logical order: باء (glyph,
    /// index 0) → فتحة (mark, attached to باء) → راء (glyph, index 1) →
    /// لا (ligature, index 2, decomposable). All at `bidiLevel = 1` (a
    /// single RTL run) except where a test explicitly wants a bidi
    /// boundary (see `letterLevelSubSelections` test, which builds its own
    /// mixed-level variant).
    static func makeComposition(mixedBidi: Bool = false) -> (composition: ArrangedComposition, baaID: MKNodeID, fathaID: MKNodeID, raaID: MKNodeID, ligatureID: MKNodeID) {
        let baaID = MKNodeID()
        let fathaID = MKNodeID()
        let raaID = MKNodeID()
        let ligatureID = MKNodeID()
        let style = MKStyle.default
        let font = MKGlyphRef(glyphID: 1, font: .systemFallback, fontChecksum: "test")

        let baa = MKGlyphNode(
            id: baaID, glyph: font, outline: nil,
            layout: MKGlyphLayout(position: CGPoint(x: 0, y: 0), advance: CGSize(width: 20, height: 0)),
            style: style,
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x0628], utf16Start: 0, utf16Length: 1, bidiLevel: 1, visualIndex: 0, logicalIndex: 0),
            joining: MKJoiningState(form: .initial, joinsPrevious: false, joinsNext: true))

        let fatha = MKMarkNode(
            id: fathaID, glyph: font, outline: nil,
            attachedTo: baaID, relativeOffset: CGSize(width: 2, height: 8), followsBase: true,
            style: style,
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x064E], utf16Start: 1, utf16Length: 1, bidiLevel: 1, visualIndex: 0, logicalIndex: 0),
            markClass: .tashkeel)

        let raa = MKGlyphNode(
            id: raaID, glyph: font, outline: nil,
            layout: MKGlyphLayout(position: CGPoint(x: 22, y: 0), advance: CGSize(width: 18, height: 0)),
            style: style,
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x0631], utf16Start: 2, utf16Length: 1, bidiLevel: mixedBidi ? 0 : 1, visualIndex: 1, logicalIndex: 1),
            joining: MKJoiningState(form: .final, joinsPrevious: true, joinsNext: false))

        let ligatureComposed = MKComposedLigature(
            glyph: font, outline: nil,
            layout: MKGlyphLayout(position: CGPoint(x: 42, y: 0), advance: CGSize(width: 30, height: 0)),
            decomposable: true)
        let ligature = MKLigatureGroup(
            id: ligatureID, state: .composed(ligatureComposed),
            provenance: MKProvenance(clusterID: MKClusterID(), codepoints: [0x0644, 0x0627], utf16Start: 3, utf16Length: 2, bidiLevel: 1, visualIndex: 2, logicalIndex: 2),
            style: style)

        let composition = ArrangedComposition(
            nodes: [.glyph(baa), .mark(fatha), .glyph(raa), .ligature(ligature)],
            sourceBackup: MKSourceTextBackup(sourceString: "بَرلا", style: MKTextStyle()),
            originFrame: CGRect(x: 0, y: -10, width: 90, height: 30))
        return (composition, baaID, fathaID, raaID, ligatureID)
    }

    /// Inserts a fresh `.arranged` node built from `makeComposition()` into
    /// `session`'s scene via the real command funnel (undo/journal
    /// exercised exactly as production code would, same convention
    /// `CanvasTestSupport.addShapeNode` already follows).
    @discardableResult
    static func addArrangedNode(to session: CanvasSession, mixedBidi: Bool = false) throws -> (nodeID: MKNodeID, baaID: MKNodeID, fathaID: MKNodeID, raaID: MKNodeID, ligatureID: MKNodeID) {
        let (composition, baaID, fathaID, raaID, ligatureID) = makeComposition(mixedBidi: mixedBidi)
        let core = MKNodeCore(name: "تشكيل حر")
        let arranged = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        try session.perform(MKInsertNodeCommand(node: .arranged(arranged), index: nil, parent: nil))
        return (core.id, baaID, fathaID, raaID, ligatureID)
    }

    /// A plain Live Text node ، the "تنسيق" entry-action fixture (derive
    /// path, not already-arranged).
    @discardableResult
    static func addLiveTextNode(to session: CanvasSession, string: String = "بَر") throws -> MKNodeID {
        let core = MKNodeCore(name: "نص")
        let node = MKNode.liveText(MKLiveTextNode(core: core, text: MKSourceText(string: string)))
        try session.perform(MKInsertNodeCommand(node: node, index: nil, parent: nil))
        return core.id
    }
}

/// Scripted `MKArrangeEngineProviding` double. Derivation returns the SAME
/// canned `ArrangeFixture.makeComposition()` regardless of the source
/// node's actual text (this module's own interaction-layer wiring is what
/// these tests verify, not `MKArrange`'s real shaping/derivation pipeline ،
/// see this file's header). Join/decompose/mark operations are small,
/// self-contained re-implementations of the SAME documented semantics
/// `MKArrange`'s real controllers use (e.g. the D-221 recompose dirty
/// check), sufficient to exercise `MKArrangeInteractionModel`'s call
/// pattern end to end.
@MainActor
final class FakeArrangeEngine: MKArrangeEngineProviding {
    private(set) var deriveCallCount = 0
    private(set) var breakJoinCalls: [(MKNodeID, MKNodeID)] = []
    private(set) var restoreJoinCalls: [(MKNodeID, MKNodeID)] = []

    func deriveArrangeCommand(sourceNodeID: MKNodeID, in scene: MKScene) async throws -> (any MKCommand)? {
        deriveCallCount += 1
        guard let node = scene.node(id: sourceNodeID) else { return nil }
        let (composition, _, _, _, _) = ArrangeFixture.makeComposition()
        let arranged = MKArrangedTextNode(core: node.core, composition: composition, derivedFrom: .liveText)
        return MKReplaceNodeCommand(nodeID: sourceNodeID, newNode: .arranged(arranged))
    }

    func revertPreflight(for node: MKArrangedTextNode) -> MKArrangeRevertPreflight {
        let edited = node.composition.nodes.filter { child in
            switch child {
            case .glyph(let g): return g.transform != .identity
            case .mark(let m): return m.transform != .identity || !m.followsBase
            case .ligature(let l): return l.transform != .identity
            }
        }.count
        return MKArrangeRevertPreflight(editedNodeCount: edited)
    }

    func revertCommand(arrangedNodeID: MKNodeID, node: MKArrangedTextNode) throws -> any MKCommand {
        let backup = node.composition.sourceBackup
        let rebuilt = MKNode.liveText(MKLiveTextNode(core: node.core, text: MKSourceText(string: backup.sourceString), style: backup.style))
        return MKReplaceNodeCommand(nodeID: arrangedNodeID, newNode: rebuilt)
    }

    func nodeIDs(forUTF16Range range: Range<Int>, in composition: ArrangedComposition, includeMarks: Bool) -> Set<MKNodeID> {
        var result: Set<MKNodeID> = []
        for child in composition.nodes {
            let (id, r, kind): (MKNodeID, Range<Int>, String)
            switch child {
            case .glyph(let g): (id, r, kind) = (g.id, g.provenance.utf16Start..<(g.provenance.utf16Start + g.provenance.utf16Length), "glyph")
            case .mark(let m): (id, r, kind) = (m.id, m.provenance.utf16Start..<(m.provenance.utf16Start + m.provenance.utf16Length), "mark")
            case .ligature(let l): (id, r, kind) = (l.id, l.provenance.utf16Start..<(l.provenance.utf16Start + l.provenance.utf16Length), "ligature")
            }
            if r.lowerBound < range.upperBound, range.lowerBound < r.upperBound {
                if kind != "mark" || includeMarks { result.insert(id) }
            }
        }
        if includeMarks {
            for child in composition.nodes {
                if case .mark(let m) = child, let base = m.attachedTo, result.contains(base) { result.insert(m.id) }
            }
        }
        return result
    }

    func utf16Ranges(forNodeIDs ids: Set<MKNodeID>, in composition: ArrangedComposition) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for child in composition.nodes where ids.contains(child.id) {
            switch child {
            case .glyph(let g): ranges.append(g.provenance.utf16Start..<(g.provenance.utf16Start + g.provenance.utf16Length))
            case .mark(let m): ranges.append(m.provenance.utf16Start..<(m.provenance.utf16Start + m.provenance.utf16Length))
            case .ligature(let l): ranges.append(l.provenance.utf16Start..<(l.provenance.utf16Start + l.provenance.utf16Length))
            }
        }
        return ranges.sorted { $0.lowerBound < $1.lowerBound }
    }

    func clusterSiblings(of id: MKNodeID, in composition: ArrangedComposition) -> Set<MKNodeID> { [id] }

    func breakJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand {
        breakJoinCalls.append((nodeAID, nodeBID))
        return replaceJoining(nodeAID: nodeAID, nodeBID: nodeBID, ownerNode: ownerNode, broken: true, label: "كسر الوصل")
    }

    func restoreJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand {
        restoreJoinCalls.append((nodeAID, nodeBID))
        return replaceJoining(nodeAID: nodeAID, nodeBID: nodeBID, ownerNode: ownerNode, broken: false, label: "إعادة الوصل")
    }

    private func replaceJoining(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode, broken: Bool, label: String) -> any MKCommand {
        var composition = ownerNode.composition
        composition.nodes = composition.nodes.map { child in
            guard case .glyph(var g) = child, g.id == nodeAID || g.id == nodeBID else { return child }
            g.joining.brokenByUser = broken
            return .glyph(g)
        }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: label)
    }

    func formSelectorModel(for nodeID: MKNodeID, ownerNode: MKArrangedTextNode) async -> MKArrangeFormSelectorModel? {
        guard case .glyph(let node)? = ownerNode.composition.child(id: nodeID) else { return nil }
        let options = [MKJoiningForm.isolated, .initial, .medial, .final].map {
            MKArrangeFormOption(form: $0, isValid: true, achieved: true, previewOutline: nil, previewAdvance: .zero, glyphID: 1)
        }
        return MKArrangeFormSelectorModel(nodeID: nodeID, scalar: node.provenance.codepoints.first ?? 0, currentForm: node.joining.form, options: options)
    }

    func formSelectionCommand(selecting form: MKJoiningForm, from model: MKArrangeFormSelectorModel, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        guard case .glyph(var node)? = ownerNode.composition.child(id: model.nodeID) else { return nil }
        node.joining.form = form
        var composition = ownerNode.composition
        composition.nodes = composition.nodes.map { $0.id == model.nodeID ? .glyph(node) : $0 }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "اختيار الشكل")
    }

    func canDecompose(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> Bool {
        guard case .ligature(let g)? = ownerNode.composition.child(id: groupID), case .composed(let composed) = g.state else { return false }
        return composed.decomposable
    }

    func decomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, fidelity: Bool) async throws -> (command: any MKCommand, fidelityAutoRefused: Bool) {
        guard case .ligature(var group)? = ownerNode.composition.child(id: groupID), case .composed(let composed) = group.state else {
            throw MKArrangeInteractionTestError.notDecomposable
        }
        let lam = MKGlyphNode(
            glyph: composed.glyph, outline: nil,
            layout: MKGlyphLayout(position: CGPoint(x: composed.layout.position.x, y: composed.layout.position.y), advance: CGSize(width: 15, height: 0)),
            style: group.style,
            provenance: MKProvenance(clusterID: group.provenance.clusterID, codepoints: [0x0644], utf16Start: group.provenance.utf16Start, utf16Length: 1, bidiLevel: group.provenance.bidiLevel, visualIndex: group.provenance.visualIndex, logicalIndex: group.provenance.logicalIndex))
        let alef = MKGlyphNode(
            glyph: composed.glyph, outline: nil,
            layout: MKGlyphLayout(position: CGPoint(x: composed.layout.position.x + 15, y: composed.layout.position.y), advance: CGSize(width: 15, height: 0)),
            style: group.style,
            provenance: MKProvenance(clusterID: group.provenance.clusterID, codepoints: [0x0627], utf16Start: group.provenance.utf16Start + 1, utf16Length: 1, bidiLevel: group.provenance.bidiLevel, visualIndex: group.provenance.visualIndex, logicalIndex: group.provenance.logicalIndex))
        group.state = .decomposed(MKDecomposedLigature(components: [lam, alef], fidelityMode: fidelity ? .matchOriginal : .defaultForms, original: composed))
        var composition = ownerNode.composition
        composition.nodes = composition.nodes.map { $0.id == groupID ? .ligature(group) : $0 }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return (MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "تفكيك المركّب"), false)
    }

    func recomposePreflight(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> MKArrangeRecomposePreflight {
        guard case .ligature(let group)? = ownerNode.composition.child(id: groupID), case .decomposed(let d) = group.state else {
            return MKArrangeRecomposePreflight(editedComponentCount: 0)
        }
        let edited = d.components.filter { $0.transform != .identity || $0.style != group.style }.count
        return MKArrangeRecomposePreflight(editedComponentCount: edited)
    }

    func recomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, force: Bool) throws -> any MKCommand {
        guard case .ligature(var group)? = ownerNode.composition.child(id: groupID), case .decomposed(let d) = group.state else {
            throw MKArrangeInteractionTestError.notDecomposable
        }
        if !force {
            let edited = d.components.filter { $0.transform != .identity || $0.style != group.style }.count
            if edited > 0 { throw MKArrangeInteractionTestError.recomposeBlocked(edited) }
        }
        group.state = .composed(d.original)
        var composition = ownerNode.composition
        composition.nodes = composition.nodes.map { $0.id == groupID ? .ligature(group) : $0 }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "دمج المركّب")
    }

    func detachMarkCommand(markID: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        guard case .mark(var mark)? = ownerNode.composition.child(id: markID) else { return nil }
        mark.attachedTo = nil
        mark.followsBase = false
        var composition = ownerNode.composition
        composition.nodes = composition.nodes.map { $0.id == markID ? .mark(mark) : $0 }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "فصل الحركة")
    }

    func reattachMarkCommand(markID: MKNodeID, toBase: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)? {
        guard case .mark(var mark)? = ownerNode.composition.child(id: markID) else { return nil }
        mark.attachedTo = toBase
        mark.followsBase = true
        var composition = ownerNode.composition
        composition.nodes = composition.nodes.map { $0.id == markID ? .mark(mark) : $0 }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "إلحاق بالحرف")
    }

    /// Applies `mapTop` to every top-level child in `ids`, and `mapComponent`
    /// to every DECOMPOSED-ligature component in `ids` (nested one level
    /// inside `MKLigatureGroup.state.decomposed`) ، mirrors the real
    /// `MKArrange.ArrangeStyleEditor.mapMatching`'s exact same two-level
    /// reach, since a style/transform edit on a just-decomposed constituent
    /// (D-221's dirty check target) must be visible to this double too.
    private func mapMatching(
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

    func nudgePositionCommand(by delta: CGSize, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        func applyDelta(_ t: MKTransform2D) -> MKTransform2D {
            var t = t
            t.position.x += delta.width
            t.position.y += delta.height
            return t
        }
        let composition = mapMatching(ids, in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.transform = applyDelta(g.transform); return .glyph(g)
            case .mark(var m): m.transform = applyDelta(m.transform); return .mark(m)
            case .ligature(var l): l.transform = applyDelta(l.transform); return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.transform = applyDelta(c.transform)
            return c
        }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "تحريك", coalescingKeySuffix: "move:\(gestureID)")
    }

    func setTransformCommand(_ transform: MKTransform2D, forChildID id: MKNodeID, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        let composition = mapMatching([id], in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.transform = transform; return .glyph(g)
            case .mark(var m): m.transform = transform; return .mark(m)
            case .ligature(var l): l.transform = transform; return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.transform = transform
            return c
        }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "تحويل", coalescingKeySuffix: "transform:\(gestureID)")
    }

    func setStyleCommand(_ style: MKStyle, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        let composition = mapMatching(ids, in: ownerNode.composition) { child in
            switch child {
            case .glyph(var g): g.style = style; return .glyph(g)
            case .mark(var m): m.style = style; return .mark(m)
            case .ligature(var l): l.style = style; return .ligature(l)
            }
        } mappingComponent: { component in
            var c = component
            c.style = style
            return c
        }
        let updated = MKArrangedTextNode(core: ownerNode.core, composition: composition, derivedFrom: ownerNode.derivedFrom)
        return MKReplaceNodesCommand(nodeID: ownerNode.core.id, newNode: .arranged(updated), label: "تنسيق", coalescingKeySuffix: "style:\(gestureID)")
    }

    func setOpacityCommand(_ opacity: Double, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand {
        setStyleCommand(.default, forChildIDs: ids, ownerNode: ownerNode, gestureID: gestureID)
    }
}

enum MKArrangeInteractionTestError: Error {
    case notDecomposable
    case recomposeBlocked(Int)
}

/// Geometry double for arrange-mode child hit-testing: each child occupies
/// a deterministic 10×10 unit box centered at `(childIndex * 20, 0)` in
/// composition-local space (matching `ArrangeFixture.makeComposition`'s own
/// x-spacing) ، enough to make `arrangedChildHit` resolvable to a specific,
/// known id per test point.
@MainActor
final class FakeArrangeGeometrySource: MKCanvasGeometrySource {
    func worldOBB(for nodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect? {
        guard let node = scene.node(id: nodeID) else { return nil }
        return MKOrientedRect(localBounds: CGRect(x: 0, y: 0, width: 1, height: 1), transform: node.core.transform)
    }

    func arrangedChildWorldOBB(childID: MKNodeID, ownerNodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect? {
        guard case .arranged(let node)? = scene.node(id: ownerNodeID), let child = node.composition.child(id: childID) else { return nil }
        let center = Self.center(of: child)
        return MKOrientedRect(center: center, size: CGSize(width: 10, height: 10), rotation: 0)
    }

    /// Two-pass, mirroring the real conformer (`HitTester.arrangedChild`):
    /// an EXACT box hit wins outright, and only a point that lands in no
    /// child's box at all falls through to the `tolerance`-inflated pass.
    /// Getting that order right matters here for the same reason it does
    /// in production ، the fixture's boxes are 10 pt wide and 20 pt apart,
    /// so a single inflated pass would let a neighbour (or an attached
    /// mark sitting a few points above its base) steal a point that is
    /// squarely inside the intended child.
    func arrangedChildHit(
        at worldPoint: CGPoint, ownerNodeID: MKNodeID, in scene: MKScene, tolerance: CGFloat
    ) -> (childID: MKNodeID, distance: CGFloat)? {
        guard case .arranged(let node)? = scene.node(id: ownerNodeID) else { return nil }

        // Topmost-first (paint order reversed), decomposed-ligature
        // components spliced in at their group's position.
        var boxes: [(id: MKNodeID, center: CGPoint)] = []
        for child in node.composition.nodes.reversed() {
            if case .ligature(let group) = child, case .decomposed(let d) = group.state {
                for component in d.components.reversed() {
                    boxes.append((component.id, CGPoint(
                        x: component.layout.position.x + component.transform.position.x,
                        y: component.layout.position.y + component.transform.position.y)))
                }
            }
            boxes.append((child.id, Self.center(of: child)))
        }

        func box(around center: CGPoint, slop: CGFloat) -> CGRect {
            CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10).insetBy(dx: -slop, dy: -slop)
        }
        for entry in boxes where box(around: entry.center, slop: 0).contains(worldPoint) {
            return (entry.id, 0)
        }
        let slop = max(0, tolerance)
        for entry in boxes where box(around: entry.center, slop: slop).contains(worldPoint) {
            return (entry.id, slop)
        }
        return nil
    }

    private static func center(of child: MKArrangedChild) -> CGPoint {
        switch child {
        case .glyph(let g): return CGPoint(x: g.layout.position.x + g.transform.position.x, y: g.layout.position.y + g.transform.position.y)
        case .mark(let m): return CGPoint(x: m.relativeOffset.width + m.transform.position.x, y: m.relativeOffset.height + m.transform.position.y)
        case .ligature(let l):
            switch l.state {
            case .composed(let c): return CGPoint(x: c.layout.position.x + l.transform.position.x, y: c.layout.position.y + l.transform.position.y)
            case .decomposed(let d): return CGPoint(x: d.original.layout.position.x + l.transform.position.x, y: d.original.layout.position.y + l.transform.position.y)
            }
        }
    }
}
