import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import MKTextEngine

// WS-04 packet §5 tasks 9-11 (D-108, the D-221-normative n-ary affine-fit
// placement algorithm, ARCHITECTURE §7.5-7.6). This is the single most
// intricate algorithm in the packet ، see the numbered steps below, each
// annotated with its packet/architecture source.
//
// **Baseline-for-dirty-check design (documented, no MKModel changes
// needed).** Task 11's recompose dirty check needs "the state captured
// immediately after decomposition" to diff against ، but `MKModel`
// (outside this packet's fence) has no dedicated snapshot field for that
// separate from the live, possibly-edited `components` array. This module
// avoids needing one: every freshly-decomposed constituent is initialized
// with `transform == .identity` (all its NEW placement lives in
// `layout.position`/`fidelityOffsets`, never in the "user delta" field) and
// `style == group.style` (the OUTER `MKLigatureGroup.style` field, which is
// a SIBLING of the `state` enum and is therefore left completely untouched
// by decompose/recompose ، nothing in this module ever mutates it while
// `state == .decomposed`). So "the post-decomposition baseline" for ANY
// constituent, at ANY later moment, is simply `(.identity, group.style)` ،
// no snapshot needs to be stored anywhere; the dirty check is a direct
// comparison against those two constants. Logged as ADR WS04-A4 (packet
// §10 duty).
public struct LigatureDecomposer: Sendable {
    private let resolver: MKFormResolver
    private let paths: MKGlyphPathProvider

    /// D-221's normative clamp.
    public static let clampRange: ClosedRange<CGFloat> = 0.85...1.15

    public init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.resolver = MKFormResolver(fonts: fonts)
        self.paths = MKGlyphPathProvider(fonts: fonts)
    }

    public struct DecomposeResult: Sendable {
        public var group: MKLigatureGroup
        /// `true` when fidelity mode was requested but D-221's pre-flight
        /// clamp check refused it (natural scale outside `clampRange`),
        /// automatically falling back to default-forms mode ، task 9's
        /// "notice UX" trigger (mirrors R-21.9's low-confidence pattern);
        /// `false` for an explicit opt-out (`DecomposeOptions(fidelity:
        /// false)`, no notice needed ، the user asked for this).
        public var fidelityAutoRefused: Bool
        /// The natural (unclamped) fit ratio `L.width / U.width` ، recorded
        /// for diagnostics/tests (task 9 accept: "record actual number").
        public var naturalScaleFactor: CGFloat
        /// WS-16 follow-up (`docs/impl-log/WS-16-cursive.md` ADR WS16-A4,
        /// `CONTRACTS.md`'s "required `MKArrange` follow-up" item 2):
        /// mirrors `JoinController.JoinEditResult.cursiveFidelityNote`'s
        /// same disposition for decompose ، `true` when the ORIGINAL
        /// composed ligature glyph (`group.provenance.cursiveAttached`, as
        /// captured, before this decompose reshapes its constituents via
        /// the same D-107 ZWJ-harvest technique `JoinController` uses) was
        /// a member of its font's GPOS 'curs' coverage. Same accepted-by-
        /// design, non-blocking disposition ، a hint for a future canvas
        /// consumer, not a correctness requirement.
        public var cursiveFidelityNote: Bool
    }

    // MARK: - Decompose (tasks 9-10)

    /// Decomposes ONE ligature group. `sourceString`/`style` are the
    /// composition's own `sourceBackup` fields (callers typically pass
    /// `composition.sourceBackup.sourceString`/`.style` straight through ،
    /// exposed as parameters rather than requiring a full
    /// `ArrangedComposition` here so this core algorithm is testable in
    /// isolation from mark re-attachment, which the composition-level
    /// `decomposeCommand` below layers on top).
    public func decompose(
        _ group: MKLigatureGroup, sourceString: String, style: MKTextStyle, options: DecomposeOptions = .fidelityDefault
    ) async throws -> DecomposeResult {
        guard case .composed(let composed) = group.state else {
            // Already decomposed ، idempotent no-op (not an error): callers
            // that re-invoke decompose on an already-decomposed group get
            // the current state back unchanged.
            return DecomposeResult(group: group, fidelityAutoRefused: false, naturalScaleFactor: 1, cursiveFidelityNote: group.provenance.cursiveAttached)
        }
        guard composed.decomposable else {
            throw MKArrangeError.ligatureNotDecomposable(group.id)
        }

        // Step (a): constituents in logical order ، non-mark scalars only
        // (marks re-attach separately, step (d) below).
        let spans = Self.codepointSpans(utf16Start: group.provenance.utf16Start, codepoints: group.provenance.codepoints)
        let constituentSpans = spans.filter { Unicode.Scalar($0.scalarValue).map { !MKMarkClassifier.isMark($0) } ?? false }
        guard constituentSpans.count > 1 else {
            throw MKArrangeError.ligatureNotDecomposable(group.id)
        }

        // Step (b): joining-preserving target form per constituent ، "the
        // form it would have INSIDE THE ORIGINAL SEQUENCE": re-running the
        // SAME analyzer over the composition's full source string and
        // looking each constituent up by its OWN (original, pre-fusion)
        // utf16 index reproduces exactly this, first/last naturally bounded
        // by whatever precedes/follows the whole ligature in the full text
        // and interior ones naturally medial (both real-letter neighbors),
        // with no first/interior/last special-casing needed.
        let allJoining = MKJoiningAnalyzer.analyze(text: sourceString)
        var joiningByUTF16: [Int: MKJoiningState] = [:]
        for j in allJoining { joiningByUTF16[j.utf16Index] = j.state }

        // Step (c): resolve each constituent glyph (ZWJ-harvest, D-107).
        var resolved: [MKResolvedForm] = []
        for span in constituentSpans {
            guard let scalar = Unicode.Scalar(span.scalarValue) else {
                throw MKArrangeError.ligatureNotDecomposable(group.id)
            }
            let joining = joiningByUTF16[span.utf16Start] ?? .isolatedDefault
            guard let r = await resolver.resolve(letter: scalar, form: joining.form, style: style) else {
                throw MKArrangeError.ligatureNotDecomposable(group.id)
            }
            resolved.append(r)
        }

        // Step (d)/pre-flight: natural (provisional) pen walk, LEFT-TO-RIGHT
        // cumulative advances starting at 0 ، direction is irrelevant to the
        // fit (only RELATIVE spacing matters, §7.5's own "the fit's uniform
        // scale plus edge alignment determines every interior offset
        // algebraically"); using a fixed LTR walk (rather than literally
        // replicating ARCHITECTURE §7.5's RTL-cursor prose) keeps the
        // implementation direction-agnostic.
        var naiveX: [CGFloat] = [0]
        for r in resolved.dropLast() { naiveX.append(naiveX[naiveX.count - 1] + r.advance.width) }

        // Fit against OUTLINE bounds, not advance boxes (§7.5 literal text:
        // "union bounds U of provisional outlines; original ligature
        // outline bounds L", D-221 normative) ، advance boxes and ink
        // bounds routinely differ (side bearings, overhangs), and the
        // packet's own 2%-of-bounds fidelity accept criterion is about ink
        // bounds, not advance boxes. `bbox(i)` falls back to the glyph's
        // own advance box `[0, advance.width]` when it has no outline
        // (whitespace-like constituent ، degenerate but handled).
        func bbox(_ outline: MKPathData?, advanceWidth: CGFloat) -> CGRect {
            outline?.cgPath(at: style.pointSize).boundingBoxOfPath ?? CGRect(x: 0, y: 0, width: advanceWidth, height: 0)
        }
        let constituentBoxes = resolved.map { bbox($0.outline, advanceWidth: $0.advance.width) }
        let ligatureBox = bbox(composed.outline, advanceWidth: composed.layout.advance.width)

        let naiveAssembledMinX = naiveX[0] + constituentBoxes[0].minX
        let naiveAssembledMaxX = naiveX[naiveX.count - 1] + constituentBoxes[constituentBoxes.count - 1].maxX
        let naturalWidth = naiveAssembledMaxX - naiveAssembledMinX
        let naturalScale: CGFloat = naturalWidth > 0 ? ligatureBox.width / naturalWidth : 1

        let wantsFidelity = options.fidelity
        let withinClamp = Self.clampRange.contains(naturalScale)
        let useFidelity = wantsFidelity && withinClamp
        let fidelityAutoRefused = wantsFidelity && !withinClamp

        // Edge-aligned anchors (§7.5: "the first and last components are
        // edge-aligned to L.minX/L.maxX"): the PEN x that puts constituent
        // 0's own outline left edge exactly at `ligatureBox.minX`, and the
        // PEN x that puts the last constituent's own outline right edge
        // exactly at `ligatureBox.maxX`. Interior constituents interpolate
        // LINEARLY between these two anchors, proportional to their natural
        // (unfitted) pen position ، "the fit's uniform scale plus edge
        // alignment determines every interior offset algebraically": a
        // single affine map (this linear interpolation) from natural pen
        // space to fitted pen space, pinned exactly at both ends.
        let anchorFirst = ligatureBox.minX - constituentBoxes[0].minX
        let anchorLast = ligatureBox.maxX - constituentBoxes[constituentBoxes.count - 1].maxX
        let naiveSpan = naiveX[naiveX.count - 1] - naiveX[0]

        func fittedX(_ i: Int) -> CGFloat {
            guard naiveSpan != 0 else { return anchorFirst }
            let t = (naiveX[i] - naiveX[0]) / naiveSpan
            return anchorFirst + t * (anchorLast - anchorFirst)
        }

        // Absolute composition-local positions: `useFidelity` uses the
        // edge-aligned fit above; default-forms mode uses natural advances
        // unscaled, from the ligature's own origin (task 10).
        var components: [MKGlyphNode] = []
        var fidelityOffsets: [MKNodeID: CGSize] = [:]
        for (i, span) in constituentSpans.enumerated() {
            let r = resolved[i]
            let fittedLocalX = useFidelity ? fittedX(i) : naiveX[i]
            var dy: CGFloat = 0
            // Lam-alif special case (§7.5: "the alef component receives the
            // Δy that best matches the original crossing height") ، a
            // closed-form top-edge alignment (not a generic least-squares
            // solver, documented simplification): align the alef
            // constituent's own outline top to the original ligature
            // outline's top, every other constituent stays baseline-aligned
            // (`dy = 0`).
            if useFidelity, constituentSpans.count == 2, i == 1,
               Self.lamScalars.contains(constituentSpans[0].scalarValue), Self.alefFamily.contains(span.scalarValue),
               let ligTop = composed.outline?.cgPath(at: style.pointSize).boundingBoxOfPath.maxY,
               let alefTop = r.outline?.cgPath(at: style.pointSize).boundingBoxOfPath.maxY {
                dy = ligTop - alefTop
            }

            let position = CGPoint(x: composed.layout.position.x + fittedLocalX, y: composed.layout.position.y + dy)
            let provenance = MKProvenance(
                clusterID: group.provenance.clusterID, codepoints: [span.scalarValue],
                utf16Start: span.utf16Start, utf16Length: span.utf16Length,
                bidiLevel: group.provenance.bidiLevel, visualIndex: group.provenance.visualIndex, logicalIndex: group.provenance.logicalIndex)
            let node = MKGlyphNode(
                glyph: MKGlyphRef(glyphID: r.glyphID, font: group.provenance.clusterID == group.provenance.clusterID ? composed.glyph.font : composed.glyph.font, fontChecksum: composed.glyph.fontChecksum),
                outline: r.outline,
                layout: MKGlyphLayout(position: position, advance: r.advance),
                transform: .identity,
                style: group.style,
                provenance: provenance,
                joining: joiningByUTF16[span.utf16Start] ?? .isolatedDefault)
            components.append(node)
            if useFidelity {
                fidelityOffsets[node.id] = CGSize(width: fittedLocalX - naiveX[i], height: dy)
            }
        }

        var updatedGroup = group
        updatedGroup.state = .decomposed(MKDecomposedLigature(
            components: components, fidelityOffsets: fidelityOffsets,
            fidelityMode: useFidelity ? .matchOriginal : .defaultForms, original: composed))
        return DecomposeResult(
            group: updatedGroup, fidelityAutoRefused: fidelityAutoRefused, naturalScaleFactor: naturalScale,
            cursiveFidelityNote: group.provenance.cursiveAttached)
    }

    // MARK: - Recompose (task 11)

    /// D-221's widened dirty check ، see file header for the
    /// no-extra-storage design. Throws `MKArrangeError.recomposeBlockedByEdits`
    /// unless `force`.
    public func recompose(_ group: MKLigatureGroup, force: Bool = false) throws -> MKLigatureGroup {
        guard case .decomposed(let decomposed) = group.state else { return group }
        if !force {
            let editedCount = decomposed.components.filter { $0.transform != .identity || $0.style != group.style }.count
            if editedCount > 0 {
                throw MKArrangeError.recomposeBlockedByEdits(editedNodeCount: editedCount)
            }
        }
        var updated = group
        updated.state = .composed(decomposed.original)
        return updated
    }

    // MARK: - Composition-level command builders (mark re-attachment/re-absorption)

    /// Task 9 step (d): re-attaches every mark listed in `group
    /// .attachedMarks` to its nearest DECOMPOSED constituent, by horizontal
    /// overlap of the mark's x-center vs. each constituent's advance-box
    /// bounds (tie → later logical index); offsets recomputed to preserve
    /// the mark's absolute composition-local position.
    static func reattachMarks(afterDecomposing group: MKLigatureGroup, in nodes: [MKArrangedChild]) -> [MKArrangedChild] {
        guard case .decomposed(let decomposed) = group.state, !decomposed.components.isEmpty else { return nodes }
        return nodes.map { child in
            guard case .mark(var mark) = child, mark.attachedTo == group.id else { return child }
            let markAbsoluteX = decomposed.original.layout.position.x + mark.relativeOffset.width
            let markAbsoluteY = decomposed.original.layout.position.y + mark.relativeOffset.height

            var bestID = decomposed.components[0].id
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for component in decomposed.components {
                let minX = component.layout.position.x
                let maxX = component.layout.position.x + component.layout.advance.width
                let distance: CGFloat
                if markAbsoluteX >= min(minX, maxX), markAbsoluteX <= max(minX, maxX) {
                    distance = 0
                } else {
                    distance = min(abs(markAbsoluteX - minX), abs(markAbsoluteX - maxX))
                }
                // Tie → later-in-logical-order base (documented, §9 step d):
                // `<=` prefers the LATER component encountered when
                // distances are equal, since `components` is already in
                // logical order.
                if distance <= bestDistance {
                    bestDistance = distance
                    bestID = component.id
                }
            }
            guard let base = decomposed.components.first(where: { $0.id == bestID }) else { return child }
            mark.attachedTo = base.id
            mark.followsBase = true
            mark.relativeOffset = CGSize(width: markAbsoluteX - base.layout.position.x, height: markAbsoluteY - base.layout.position.y)
            return .mark(mark)
        }
    }

    /// Task 11: "Marks re-anchor back to the group on confirm" ، the
    /// inverse of `reattachMarks`, re-pointing any mark currently attached
    /// to a (soon-to-be-removed) decomposed component back to the group id,
    /// recomputing `relativeOffset` against the RECOMPOSED ligature's own
    /// position. Round-trips exactly to the pre-decompose value when no
    /// constituent was moved (dirty check already guarantees this whenever
    /// recompose is allowed to proceed unforced).
    static func reabsorbMarks(recomposing group: MKLigatureGroup, into recomposed: MKComposedLigature, nodes: [MKArrangedChild]) -> [MKArrangedChild] {
        guard case .decomposed(let decomposed) = group.state else { return nodes }
        let componentPositions = Dictionary(uniqueKeysWithValues: decomposed.components.map { ($0.id, $0.layout.position) })
        return nodes.map { child in
            guard case .mark(var mark) = child, let base = mark.attachedTo, let basePosition = componentPositions[base] else { return child }
            let absoluteX = basePosition.x + mark.relativeOffset.width
            let absoluteY = basePosition.y + mark.relativeOffset.height
            mark.attachedTo = group.id
            mark.followsBase = true
            mark.relativeOffset = CGSize(width: absoluteX - recomposed.layout.position.x, height: absoluteY - recomposed.layout.position.y)
            return .mark(mark)
        }
    }

    /// Full composition-level decompose: resolves the group, decomposes,
    /// re-attaches marks, and returns the journal-codable `MKCommand`
    /// (`ArrangeCommands.replaceComposition` → `MKReplaceNodesCommand`;
    /// task 9's actual entry point for callers holding a whole
    /// `ArrangedComposition`).
    public func decomposeCommand(
        groupID: MKNodeID, ownerNode: MKArrangedTextNode, options: DecomposeOptions = .fidelityDefault
    ) async throws -> any MKCommand {
        guard case .ligature(let group) = ownerNode.composition.child(id: groupID) else {
            throw MKArrangeError.childNodeNotFound(groupID)
        }
        let result = try await decompose(group, sourceString: ownerNode.composition.sourceBackup.sourceString, style: ownerNode.composition.sourceBackup.style, options: options)
        var newComposition = ownerNode.composition
        newComposition.nodes = newComposition.nodes.map { $0.id == groupID ? .ligature(result.group) : $0 }
        newComposition.nodes = Self.reattachMarks(afterDecomposing: result.group, in: newComposition.nodes)
        return ArrangeCommands.replaceComposition(of: ownerNode, with: newComposition, label: "تفكيك المركّب")   // decompose ligature
    }

    /// Full composition-level recompose (task 11).
    public func recomposeCommand(
        groupID: MKNodeID, ownerNode: MKArrangedTextNode, force: Bool = false
    ) throws -> any MKCommand {
        guard case .ligature(let group) = ownerNode.composition.child(id: groupID) else {
            throw MKArrangeError.childNodeNotFound(groupID)
        }
        let recomposedGroup = try recompose(group, force: force)
        guard case .composed(let composed) = recomposedGroup.state else {
            return ArrangeCommands.replaceComposition(of: ownerNode, with: ownerNode.composition, label: "دمج المركّب")
        }
        var newComposition = ownerNode.composition
        newComposition.nodes = Self.reabsorbMarks(recomposing: group, into: composed, nodes: newComposition.nodes)
        // Remove the decomposed components (they no longer exist as
        // top-level entries ، they never were; they lived nested inside
        // the group ، so only the group itself needs swapping).
        newComposition.nodes = newComposition.nodes.map { $0.id == groupID ? .ligature(recomposedGroup) : $0 }
        return ArrangeCommands.replaceComposition(of: ownerNode, with: newComposition, label: "دمج المركّب")   // recompose ligature
    }

    // MARK: - Small helpers

    static let lamScalars: Set<UInt32> = [0x0644]
    static let alefFamily: Set<UInt32> = [0x0627, 0x0622, 0x0623, 0x0625, 0x0671]

    static func codepointSpans(utf16Start: Int, codepoints: [UInt32]) -> [(scalarValue: UInt32, utf16Start: Int, utf16Length: Int)] {
        var offset = utf16Start
        var spans: [(UInt32, Int, Int)] = []
        for value in codepoints {
            guard let scalar = Unicode.Scalar(value) else { continue }
            let width = UTF16.width(scalar)
            spans.append((value, offset, width))
            offset += width
        }
        return spans
    }
}
