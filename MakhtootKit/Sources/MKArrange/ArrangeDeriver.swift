import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKTextEngine

// WS-04 packet §5 task 2 (D-106 derivation pipeline). Converts one
// `MKShapingCaptureResult` (WS-03's frozen shaping output ، glyphs,
// clusters, bidi, marks, ligatures, joining, all already computed) plus the
// originating source string/style into an `ArrangedComposition`: the
// non-reflowing, fully-provenanced structure `MKModel` (WS-02) declares.
//
// **Coordinate convention (normative for this module).** `MKGlyphLayout
// .position` is stored in **composition-local, y-up space** ، the exact
// axis convention Core Text captures in (`MKTextEngine/CoordinateSpace.swift`:
// "never flips or rewrites a captured position"), NOT MKRender's y-down
// document space. This is the convention `MKRender/Geometry/
// ArrangedGeometry.swift`'s file header already anticipates and documents
// ("If WS-04 lands and derives `layout.position`/`relativeOffset` in a
// DOCUMENT-space (y-down) convention instead, only this one flip needs to
// change ، not the D-220 math itself") ، choosing y-up here means
// `ArrangedDrawer`/`MKArrangedGeometry` (already shipped by WS-07) require
// **zero changes** to draw derived compositions correctly; verified by this
// module's own fidelity tests (`DerivationFidelityTests.swift`) rendering
// through the real `MKSnapshotRenderer`.
//
// Per-line stacking matches `LiveTextDrawer.draw(_:into:quality:report:)`
// exactly (`lineOriginY` starts at line 0's ascent, then accumulates
// `lineHeightMultiple * pointSize` per subsequent line): a glyph captured
// at raw Core Text position `ctPos` (line-local, y-up, baseline-relative)
// gets `layout.position = CGPoint(x: ctPos.x + lineOriginX, y: ctPos.y -
// lineOriginY)`. Composing this with `ArrangedDrawer`'s single `scaleY(-1)`
// flip at draw time reproduces `LiveTextDrawer`'s own `translate(lineOriginX,
// lineOriginY) ∘ scaleY(-1)` idiom point-for-point ، see the file's
// derivation math in `docs/impl-log/WS-04.md` (fidelity numbers logged
// there per the packet's task-3 duty).
//
// **`lineOriginX` (MASTER-PLAN Phase-2 RTL-alignment fix, added after the
// packet's original WS-04 landing).** `paragraph.lineOriginX(lineWidth:
// baseDirection:)` (`MKTextEngine`) ، the SAME per-line box-relative offset
// `LiveTextDrawer` now applies (D-109: RTL lines flush right against the
// node's `[0, boxWidth]` box, LTR lines stay flush left at `0`). Before
// this fix, every glyph here used raw `ctPos.x` verbatim ، fine for a
// single line (`boxWidth == ` that line's own width, so the offset is
// always `0` regardless of direction) but WRONG for a genuinely multi-line
// RTL derivation, where it silently reproduced `LiveTextDrawer`'s own
// pre-fix flush-left-always bug one module downstream. Caught by
// `DerivationFidelityTests.twoLineParagraphFidelity` (D-106's
// derivation-vs-live pixel-parity gate) once `LiveTextDrawer`'s half of
// this fix landed and the two stopped agreeing.
//
// Mark `relativeOffset` needs NO line-origin correction at all (neither X
// nor Y): it is `markCtPos − baseCtPos`, and the constant `lineOriginX`/
// `lineOriginY` terms (identical for every glyph/mark on the SAME line)
// cancel in that subtraction ، which is exactly why D-220/§6.3 call this value
// "base-local" already, straight off `CTRunGetPositions`, with no
// transform applied by this deriver.
//
// **Ordering deviation (documented, not a defect).** `ArrangedComposition
// .nodes`' doc comment calls the array "visual (paint) order... Z-order
// among them is index order." This deriver instead emits nodes in
// **logical** cluster order (`MKClusterMap.clusters`' own ascending
// utf16 order) for every line, while still computing an accurate
// `MKProvenance.visualIndex` per node (straight off `MKBidiMap
// .glyphVisualIndex`) that WS-06/canvas-level consumers can sort by for
// true visual/tab-cycling order. This is safe for PIXEL fidelity because
// `MKArrangedGeometry` composes every child's world transform
// independently (no sequential `ctx.translate` accumulation the way
// `LiveTextDrawer`'s per-line paint loop works) ، array order only matters
// for z-order among genuinely OVERLAPPING shapes, and non-overlapping
// glyphs/marks paint identically regardless of array position. Avoiding a
// second "visual walk" pass keeps the algorithm a single O(clusters) sweep
// per line. Flagged in `docs/impl-log/WS-04.md`.
//
// **WS-16 follow-up landed (Run-3 P6, `docs/impl-log/WS-04.md`).** Every
// `MKProvenance` this file constructs now carries `cursiveAttached`, read
// straight off `MKShapedRun.cursiveAttached[glyphIndex]` (`cursiveFlag(run:
// glyphIndex:)` below) at the exact glyph the node was captured from ، a
// pure provenance carry-through per WS-16's Finding 5 (the captured
// `position` already IS the cursive-adjusted answer; nothing here
// recomputes geometry from it). `JoinController`/`LigatureDecomposer`
// surface a `cursiveFidelityNote` off this flag (see those files) so a
// future canvas consumer can show the documented, accepted-by-design
// "connecting stroke may not match exactly" hint for a D-107 ZWJ-harvest
// reshape of a cursive-attachment-affected letter, per CONTRACTS.md's WS-16
// section.
public struct ArrangeDeriver: Sendable {
    private let paths: MKGlyphPathProvider

    public init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.paths = MKGlyphPathProvider(fonts: fonts)
    }

    /// The D-106 pipeline (packet task 2 signature: "input (sourceText,
    /// MKTextStyle, ShapingCaptureResult, PathPlacementProviding) →
    /// ArrangedComposition"). `pathData` is the frozen path (D-110) when
    /// `origin == .pathText` ، `nil` for plain Live Text, matching
    /// `MKSourceTextBackup.pathData`'s own optionality. `async` because
    /// outline extraction goes through the actor-isolated
    /// `MKGlyphPathProvider` (§5.1 step 3: "Extraction happens once here ،
    /// arranged rendering never asks the font again", INV-1/INV-13).
    /// `paintStyle` (fill/stroke/shadow) is the source node's OWN
    /// `MKNodeCore.style` ، a parameter this file's original design missed
    /// (the packet's task-2 signature literally lists only `(sourceText,
    /// MKTextStyle, ShapingCaptureResult, PathPlacementProviding)`, no
    /// paint-style input), caught by `DerivationFidelityTests`: every
    /// arranged CHILD carries its OWN independent `MKStyle`
    /// (`ArrangedDrawer` paints each child by its OWN `.style`, unlike
    /// `LiveTextDrawer` which reads the single outer `MKNodeCore.style`),
    /// so without this parameter every derived glyph/mark/ligature would
    /// default to `MKStyle.default` (`fill: .none`) ، invisible ، even
    /// though the source Live Text node was fully painted. Every fresh
    /// child is initialized with `paintStyle` verbatim (the same pattern
    /// `LigatureDecomposer` already uses when it copies `group.style` into
    /// freshly-decomposed constituents). Documented as a packet-signature
    /// gap fix, not a silent deviation ، logged in `docs/impl-log/WS-04.md`.
    public func derive(
        sourceText: String,
        style: MKTextStyle,
        capture: MKShapingCaptureResult,
        paintStyle: MKStyle = MKStyle(fill: .solid(.defaultInk)),
        pathData: MKBezierPathData? = nil,
        placement: any PathPlacementProviding = IdentityPlacement()
    ) async -> ArrangedComposition {
        // P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 2):
        // closes WS-04's own flagged instrumentation gap (`docs/impl-log
        // /WS-04.md` task 17 row) ، see `MKFoundation.MKSignpost
        // .arrangeDerive`'s doc comment for why the literal below (not
        // `.rawValue`) is required (`OSSignposter` needs a compile-time
        // `StaticString`) and why this call is direct rather than through
        // `MKRender`'s `MKRenderSignposts` wrapper.
        let signpostState = MKSignpost.signposter.beginInterval("arrangeDerive")
        defer { MKSignpost.signposter.endInterval("arrangeDerive", signpostState) }

        var nodes: [MKArrangedChild] = []
        var logicalCounter = 0
        var visualOffset = 0
        var unionRect: CGRect?

        for (lineIndex, line) in capture.paragraph.lines.enumerated() {
            let analysis = capture.lineAnalyses[lineIndex]
            let lineOriginY = Self.lineOriginY(lineIndex: lineIndex, lines: capture.paragraph.lines, style: style)
            // MASTER-PLAN Phase-2 RTL-alignment fix: mirrors `LiveTextDrawer`
            // .draw`'s own per-line `paragraph.lineOriginX` fix ، without
            // it, a derived multi-line composition stays flush-left-always
            // (this file's pre-fix behavior: `applyPlacement` took `ctPos.x`
            // verbatim, with no box-relative offset at all) regardless of
            // the live text it was derived FROM, breaking the D-106
            // derivation-vs-live fidelity invariant for any multi-line RTL
            // node (caught by `DerivationFidelityTests.twoLineParagraphFidelity`
            // once `LiveTextDrawer`'s own half of this fix landed).
            let lineOriginX = capture.paragraph.lineOriginX(lineWidth: line.typographicBounds.width, baseDirection: style.baseDirection)

            let markAttachmentsByOrdinal = Dictionary(grouping: analysis.marks, by: \.markClusterIndex)
            var joiningByUTF16: [Int: MKJoiningState] = [:]
            for j in analysis.joining { joiningByUTF16[j.utf16Index] = j.state }

            var clusterBaseNodeID: [Int: MKNodeID] = [:]
            var stackIndexForBase: [MKNodeID: Int] = [:]

            for (ordinal, cluster) in line.clusterMap.clusters.enumerated() {
                let clusterLogicalIndex = logicalCounter
                logicalCounter += 1

                switch cluster.kind {
                case .control:
                    // Dropped from renderable children (§5.1 step 2). No
                    // dedicated `clusterTable` exists on `ArrangedComposition`
                    // (WS-02 deliberately omitted it ، see that type's own
                    // doc comment) to retain these in; nothing is lost for
                    // revert/Unicode-level editing purposes because
                    // `MKSourceTextBackup.sourceString` is a byte-exact copy
                    // of the full original string, controls included.
                    continue

                case .simple:
                    await appendSimpleGlyphs(
                        cluster: cluster, ordinal: ordinal, line: line, lineIndex: lineIndex, lineOriginY: lineOriginY, lineOriginX: lineOriginX,
                        joiningByUTF16: joiningByUTF16, logicalIndex: clusterLogicalIndex, visualOffset: visualOffset,
                        placement: placement, paintStyle: paintStyle, nodes: &nodes, clusterBaseNodeID: &clusterBaseNodeID, unionRect: &unionRect)

                case .ligature:
                    await appendLigature(
                        cluster: cluster, ordinal: ordinal, line: line, lineIndex: lineIndex, lineOriginY: lineOriginY, lineOriginX: lineOriginX,
                        logicalIndex: clusterLogicalIndex, visualOffset: visualOffset, placement: placement, paintStyle: paintStyle,
                        nodes: &nodes, clusterBaseNodeID: &clusterBaseNodeID, unionRect: &unionRect)

                case .baseWithMarks:
                    await appendBaseWithMarks(
                        cluster: cluster, ordinal: ordinal, line: line, lineIndex: lineIndex, lineOriginY: lineOriginY, lineOriginX: lineOriginX,
                        joiningByUTF16: joiningByUTF16, logicalIndex: clusterLogicalIndex, visualOffset: visualOffset,
                        placement: placement, paintStyle: paintStyle, attachments: markAttachmentsByOrdinal[ordinal] ?? [],
                        nodes: &nodes, clusterBaseNodeID: &clusterBaseNodeID, stackIndexForBase: &stackIndexForBase, unionRect: &unionRect)

                case .markOnly:
                    await appendMarkOnly(
                        cluster: cluster, ordinal: ordinal, line: line, lineIndex: lineIndex, lineOriginY: lineOriginY, lineOriginX: lineOriginX,
                        logicalIndex: clusterLogicalIndex, visualOffset: visualOffset, paintStyle: paintStyle,
                        attachments: markAttachmentsByOrdinal[ordinal] ?? [],
                        nodes: &nodes, clusterBaseNodeID: clusterBaseNodeID, stackIndexForBase: &stackIndexForBase, unionRect: &unionRect)
                }
            }

            visualOffset += line.glyphCount
        }

        nodes = Self.linkLigatureAttachedMarks(nodes)
        let backup = MKSourceTextBackup(sourceString: sourceText, style: style, pathData: pathData)
        return ArrangedComposition(nodes: nodes, sourceBackup: backup, originFrame: unionRect ?? .zero)
    }

    /// Populates `MKLigatureGroup.attachedMarks` (D-105/§7.5 step 6 seam
    /// WS-02's own doc comment leaves for this module to fill): a
    /// finalization pass over the fully-built node list, since a mark's
    /// `attachedTo == ligatureID` relationship (set by `appendMarkOnly`
    /// while walking clusters AFTER the ligature's own cluster) isn't known
    /// yet at the moment the ligature itself is created.
    static func linkLigatureAttachedMarks(_ nodes: [MKArrangedChild]) -> [MKArrangedChild] {
        var marksByBase: [MKNodeID: [MKNodeID]] = [:]
        for child in nodes {
            if case .mark(let m) = child, let base = m.attachedTo {
                marksByBase[base, default: []].append(m.id)
            }
        }
        return nodes.map { child in
            if case .ligature(var group) = child, case .composed = group.state, let marks = marksByBase[group.id] {
                group.attachedMarks = marks
                return .ligature(group)
            }
            return child
        }
    }

    // MARK: - Per-line origin (matches LiveTextDrawer.draw exactly)

    static func lineOriginY(lineIndex: Int, lines: [MKShapedLine], style: MKTextStyle) -> CGFloat {
        guard !lines.isEmpty else { return 0 }
        let lineHeight = CGFloat(style.lineHeightMultiple * style.pointSize)
        var y = lines[0].typographicBounds.ascent
        var i = 0
        while i < lineIndex {
            y += lineHeight
            i += 1
        }
        return y
    }

    // MARK: - Cluster kind handlers

    private func appendSimpleGlyphs(
        cluster: MKCluster, ordinal: Int, line: MKShapedLine, lineIndex: Int, lineOriginY: CGFloat, lineOriginX: CGFloat,
        joiningByUTF16: [Int: MKJoiningState], logicalIndex: Int, visualOffset: Int,
        placement: any PathPlacementProviding, paintStyle: MKStyle,
        nodes: inout [MKArrangedChild], clusterBaseNodeID: inout [Int: MKNodeID], unionRect: inout CGRect?
    ) async {
        let spans = Self.codepointSpans(cluster: cluster)
        let firstUTF16 = spans.first?.utf16Start ?? cluster.utf16Range.lowerBound
        let joining = joiningByUTF16[firstUTF16] ?? .isolatedDefault
        let bidiLevel = Self.bidiLevel(for: cluster, in: line)

        // Best-effort 1:1 codepoint↔glyph split when counts match (multi-
        // codepoint/multi-glyph `.simple` clusters, D-105's rare "1
        // codepoint → N glyphs" case's inverse); otherwise every glyph gets
        // the full cluster codepoint list (documented simplification).
        let perGlyphCodepoints: [[UInt32]]
        if cluster.glyphs.count == cluster.codepoints.count, cluster.glyphs.count > 1 {
            perGlyphCodepoints = cluster.codepoints.map { [$0] }
        } else {
            perGlyphCodepoints = Array(repeating: cluster.codepoints, count: cluster.glyphs.count)
        }

        var firstID: MKNodeID?
        for (i, address) in cluster.glyphs.enumerated() {
            let node = await makeGlyphNode(
                address: address, line: line, lineIndex: lineIndex, lineOriginY: lineOriginY, lineOriginX: lineOriginX,
                clusterID: cluster.id, codepoints: perGlyphCodepoints[i], utf16Start: cluster.utf16Range.lowerBound,
                utf16Length: cluster.utf16Range.count, bidiLevel: bidiLevel, visualIndex: Self.visualIndex(for: address, in: line, offset: visualOffset),
                logicalIndex: logicalIndex, joining: joining, placement: placement, paintStyle: paintStyle)
            if firstID == nil { firstID = node.id }
            unionRect = Self.union(unionRect, Self.approximateBounds(node: node))
            nodes.append(.glyph(node))
        }
        if let firstID { clusterBaseNodeID[ordinal] = firstID }
    }

    private func appendLigature(
        cluster: MKCluster, ordinal: Int, line: MKShapedLine, lineIndex: Int, lineOriginY: CGFloat, lineOriginX: CGFloat,
        logicalIndex: Int, visualOffset: Int, placement: any PathPlacementProviding, paintStyle: MKStyle,
        nodes: inout [MKArrangedChild], clusterBaseNodeID: inout [Int: MKNodeID], unionRect: inout CGRect?
    ) async {
        guard let address = cluster.glyphs.first else { return }
        let run = line.runs[address.run]
        let glyphID = run.glyphs[address.glyph]
        let ctPos = run.positions[address.glyph]
        let advance = run.advances[address.glyph]
        let outline = await paths.path(for: glyphID, font: run.font)
        let localPosition = Self.applyPlacement(
            ctPos: ctPos, lineOriginY: lineOriginY, lineOriginX: lineOriginX, address: address, lineIndex: lineIndex, placement: placement).position

        let bidiLevel = Self.bidiLevel(for: cluster, in: line)
        let visualIndex = Self.visualIndex(for: address, in: line, offset: visualOffset)
        let provenance = MKProvenance(
            clusterID: cluster.id, codepoints: cluster.codepoints,
            utf16Start: cluster.utf16Range.lowerBound, utf16Length: cluster.utf16Range.count,
            bidiLevel: bidiLevel, visualIndex: visualIndex, logicalIndex: logicalIndex,
            cursiveAttached: Self.cursiveFlag(run: run, glyphIndex: address.glyph))

        let nonMarkScalars = cluster.codepoints.compactMap(Unicode.Scalar.init).filter { !MKMarkClassifier.isMark($0) }
        let decomposable = nonMarkScalars.count > 1 && nonMarkScalars.allSatisfy {
            let type = MKJoiningTypeTable.joiningType(of: $0)
            return type == .dual || type == .rightJoining
        }

        let composed = MKComposedLigature(
            glyph: MKGlyphRef(glyphID: glyphID, font: .system(postScriptName: run.font.postScriptName), fontChecksum: Self.fontChecksum(run.font)),
            outline: outline,
            layout: MKGlyphLayout(position: localPosition, advance: advance),
            decomposable: decomposable)
        let group = MKLigatureGroup(state: .composed(composed), provenance: provenance, style: paintStyle)
        unionRect = Self.union(unionRect, Self.approximateBounds(position: localPosition, advance: advance))
        nodes.append(.ligature(group))
        clusterBaseNodeID[ordinal] = group.id
    }

    private func appendBaseWithMarks(
        cluster: MKCluster, ordinal: Int, line: MKShapedLine, lineIndex: Int, lineOriginY: CGFloat, lineOriginX: CGFloat,
        joiningByUTF16: [Int: MKJoiningState], logicalIndex: Int, visualOffset: Int,
        placement: any PathPlacementProviding, paintStyle: MKStyle, attachments: [MKMarkAttachment],
        nodes: inout [MKArrangedChild], clusterBaseNodeID: inout [Int: MKNodeID],
        stackIndexForBase: inout [MKNodeID: Int], unionRect: inout CGRect?
    ) async {
        guard let address = cluster.glyphs.first else { return }
        let spans = Self.codepointSpans(cluster: cluster)
        let baseSpans = spans.filter { Unicode.Scalar($0.scalarValue).map { !MKMarkClassifier.isMark($0) } ?? true }
        let baseCodepoints = baseSpans.map(\.scalarValue)
        let utf16Start = baseSpans.first?.utf16Start ?? cluster.utf16Range.lowerBound
        let utf16Length = baseSpans.reduce(0) { $0 + $1.utf16Length }
        let firstUTF16 = baseSpans.first?.utf16Start ?? cluster.utf16Range.lowerBound
        let joining = joiningByUTF16[firstUTF16] ?? .isolatedDefault
        let bidiLevel = Self.bidiLevel(for: cluster, in: line)
        let visualIndex = Self.visualIndex(for: address, in: line, offset: visualOffset)

        let base = await makeGlyphNode(
            address: address, line: line, lineIndex: lineIndex, lineOriginY: lineOriginY, lineOriginX: lineOriginX,
            clusterID: cluster.id, codepoints: baseCodepoints.isEmpty ? cluster.codepoints : baseCodepoints,
            utf16Start: utf16Start, utf16Length: max(utf16Length, 1), bidiLevel: bidiLevel, visualIndex: visualIndex,
            logicalIndex: logicalIndex, joining: joining, placement: placement, paintStyle: paintStyle)
        unionRect = Self.union(unionRect, Self.approximateBounds(node: base))
        nodes.append(.glyph(base))
        clusterBaseNodeID[ordinal] = base.id

        // Fused marks (Core Text folded the mark into the base's own
        // glyph ، no distinct glyph to extract/position, §6.3): still
        // recorded as MarkNodes for provenance/selectability (D-105 "no
        // mark is orphaned"), with a `nil` outline and zero offset. This
        // means `ArrangedDrawer` records a benign `.missingOutline`
        // substitution when it draws these (nothing to paint separately ،
        // the mark's pixels are already part of the base glyph's own
        // outline, so skipping is the CORRECT visual result, not a
        // fidelity defect); flagged in `docs/impl-log/WS-04.md` as a
        // follow-up candidate for WS-07/WS-08 (e.g. an
        // `isProvenanceOnly`-style flag) if a future consumer ever gates on
        // a zero-substitution report.
        // `MKMarkAttacher` emits exactly one `MKMarkAttachment` per mark
        // CODEPOINT for a `.baseWithMarks` cluster (walking `cluster
        // .codepoints` in order, same filter as `markSpans` below), so
        // zipping the two by index recovers each attachment's own scalar/
        // utf16 span without `MKMarkAttachment` needing to carry it itself.
        let markSpans = spans.filter { Unicode.Scalar($0.scalarValue).map(MKMarkClassifier.isMark) ?? false }
        for (attachment, markSpan) in zip(attachments, markSpans) {
            guard let markScalarValue = Unicode.Scalar(markSpan.scalarValue) else { continue }
            let markClass = attachment.markClass ?? MKMarkClassifier.classify(markScalarValue) ?? .otherCombining
            let stackIndex = stackIndexForBase[base.id, default: 0]
            stackIndexForBase[base.id] = stackIndex + 1
            let markProvenance = MKProvenance(
                clusterID: cluster.id, codepoints: [markSpan.scalarValue],
                utf16Start: markSpan.utf16Start, utf16Length: markSpan.utf16Length,
                bidiLevel: bidiLevel, visualIndex: visualIndex, logicalIndex: logicalIndex)
            let mark = MKMarkNode(
                glyph: base.glyph, outline: nil, attachedTo: base.id, relativeOffset: .zero, followsBase: true,
                style: paintStyle, provenance: markProvenance, markClass: markClass, stackIndex: stackIndex)
            nodes.append(.mark(mark))
        }
    }

    private func appendMarkOnly(
        cluster: MKCluster, ordinal: Int, line: MKShapedLine, lineIndex: Int, lineOriginY: CGFloat, lineOriginX: CGFloat,
        logicalIndex: Int, visualOffset: Int, paintStyle: MKStyle, attachments: [MKMarkAttachment],
        nodes: inout [MKArrangedChild], clusterBaseNodeID: [Int: MKNodeID],
        stackIndexForBase: inout [MKNodeID: Int], unionRect: inout CGRect?
    ) async {
        guard let attachment = attachments.first else { return }
        let markScalar = cluster.codepoints.first.flatMap(Unicode.Scalar.init)
        let markClass = attachment.markClass ?? markScalar.flatMap(MKMarkClassifier.classify) ?? .otherCombining
        let bidiLevel = Self.bidiLevel(for: cluster, in: line)
        let visualIndex: Int = attachment.markGlyph.map { Self.visualIndex(for: $0, in: line, offset: visualOffset) }
            ?? visualOffset
        let markCursiveAttached = attachment.markGlyph.map { Self.cursiveFlag(run: line.runs[$0.run], glyphIndex: $0.glyph) } ?? false
        let provenance = MKProvenance(
            clusterID: cluster.id, codepoints: cluster.codepoints,
            utf16Start: cluster.utf16Range.lowerBound, utf16Length: cluster.utf16Range.count,
            bidiLevel: bidiLevel, visualIndex: visualIndex, logicalIndex: logicalIndex,
            cursiveAttached: markCursiveAttached)

        var outline: MKPathData?
        var glyphRef = MKGlyphRef(glyphID: 0, font: .systemFallback, fontChecksum: "")
        if let markAddress = attachment.markGlyph {
            let run = line.runs[markAddress.run]
            let glyphID = run.glyphs[markAddress.glyph]
            outline = await paths.path(for: glyphID, font: run.font)
            glyphRef = MKGlyphRef(glyphID: glyphID, font: .system(postScriptName: run.font.postScriptName), fontChecksum: Self.fontChecksum(run.font))
        }

        let baseID = attachment.baseClusterIndex.flatMap { clusterBaseNodeID[$0] }
        let markNode: MKMarkNode
        if let baseID {
            let stackIndex = stackIndexForBase[baseID, default: 0]
            stackIndexForBase[baseID] = stackIndex + 1
            markNode = MKMarkNode(
                glyph: glyphRef, outline: outline, attachedTo: baseID,
                relativeOffset: attachment.relativeOffset ?? .zero, followsBase: true,
                style: paintStyle, provenance: provenance, markClass: markClass, stackIndex: stackIndex)
        } else {
            // Free mark (§6.3: no preceding base ، e.g. a standalone
            // tashkeel typed at string start or after whitespace).
            // Absolute composition-local position via `transform.position`,
            // matching `MKArrangedGeometry`'s documented fallback path for
            // `attachedTo == nil` marks.
            var position = CGPoint.zero
            if let markAddress = attachment.markGlyph {
                let ctPos = line.runs[markAddress.run].positions[markAddress.glyph]
                // MASTER-PLAN Phase-2 RTL-alignment fix: same `lineOriginX`
                // box-relative offset every other absolute position in this
                // file now gets ، a FREE mark (no base, §6.3) is an
                // absolute position, not a `markCtPos − baseCtPos`
                // difference, so unlike attached-mark `relativeOffset`
                // (where the offset would cancel), this one genuinely needs it.
                position = CGPoint(x: ctPos.x + lineOriginX, y: ctPos.y - lineOriginY)
            }
            markNode = MKMarkNode(
                glyph: glyphRef, outline: outline, attachedTo: nil,
                relativeOffset: .zero, followsBase: false, transform: MKTransform2D(position: position),
                style: paintStyle, provenance: provenance, markClass: markClass, stackIndex: 0)
        }
        unionRect = Self.union(unionRect, Self.approximateMarkBounds(mark: markNode, baseID: baseID, nodes: nodes))
        nodes.append(.mark(markNode))
    }

    // MARK: - Shared glyph-node construction

    private func makeGlyphNode(
        address: MKGlyphAddress, line: MKShapedLine, lineIndex: Int, lineOriginY: CGFloat, lineOriginX: CGFloat,
        clusterID: MKClusterID, codepoints: [UInt32], utf16Start: Int, utf16Length: Int,
        bidiLevel: UInt8, visualIndex: Int, logicalIndex: Int, joining: MKJoiningState,
        placement: any PathPlacementProviding, paintStyle: MKStyle
    ) async -> MKGlyphNode {
        let run = line.runs[address.run]
        let glyphID = run.glyphs[address.glyph]
        let ctPos = run.positions[address.glyph]
        let advance = run.advances[address.glyph]
        let outline = await paths.path(for: glyphID, font: run.font)
        let resolvedPlacement = Self.applyPlacement(ctPos: ctPos, lineOriginY: lineOriginY, lineOriginX: lineOriginX, address: address, lineIndex: lineIndex, placement: placement)

        let provenance = MKProvenance(
            clusterID: clusterID, codepoints: codepoints, utf16Start: utf16Start, utf16Length: utf16Length,
            bidiLevel: bidiLevel, visualIndex: visualIndex, logicalIndex: logicalIndex,
            cursiveAttached: Self.cursiveFlag(run: run, glyphIndex: address.glyph))
        return MKGlyphNode(
            glyph: MKGlyphRef(glyphID: glyphID, font: .system(postScriptName: run.font.postScriptName), fontChecksum: Self.fontChecksum(run.font)),
            outline: outline,
            layout: MKGlyphLayout(position: resolvedPlacement.position, advance: advance, pathTangentAngle: resolvedPlacement.tangentAngle),
            style: paintStyle,
            provenance: provenance,
            joining: joining)
    }

    // MARK: - Small pure helpers

    /// Splits a cluster's `codepoints` into per-scalar UTF-16 spans, in
    /// order, starting at `cluster.utf16Range.lowerBound` ، surrogate-pair
    /// aware via `UTF16.width`.
    static func codepointSpans(cluster: MKCluster) -> [(scalarValue: UInt32, utf16Start: Int, utf16Length: Int)] {
        var offset = cluster.utf16Range.lowerBound
        var spans: [(UInt32, Int, Int)] = []
        for value in cluster.codepoints {
            guard let scalar = Unicode.Scalar(value) else { continue }
            let width = UTF16.width(scalar)
            spans.append((value, offset, width))
            offset += width
        }
        return spans
    }

    static func bidiLevel(for cluster: MKCluster, in line: MKShapedLine) -> UInt8 {
        line.bidiMap.runs.first { $0.utf16Range.contains(cluster.utf16Range.lowerBound) }?.level ?? 0
    }

    static func visualIndex(for address: MKGlyphAddress, in line: MKShapedLine, offset: Int) -> Int {
        (line.bidiMap.glyphVisualIndex[address] ?? 0) + offset
    }

    /// WS-16 follow-up (`docs/impl-log/WS-16-cursive.md`, `CONTRACTS.md`'s
    /// "required `MKArrange` follow-up" item 1): mirrors
    /// `MKShapedRun.cursiveAttached[glyphIndex]` onto `MKProvenance
    /// .cursiveAttached` at the exact glyph this deriver captured a node
    /// from ، a pure provenance carry-through, never consulted by any
    /// geometry computation in this file (Finding 5 of the WS-16 log: the
    /// captured `position` already IS the cursive-adjusted answer). Bounds-
    /// checked defensively (`cursiveAttached` is always index-parallel to
    /// `glyphs` per that field's own doc comment, but this deriver has no
    /// reason to trust that invariant blindly at every call site).
    static func cursiveFlag(run: MKShapedRun, glyphIndex: Int) -> Bool {
        guard run.cursiveAttached.indices.contains(glyphIndex) else { return false }
        return run.cursiveAttached[glyphIndex]
    }

    /// Resolves the composition-local position for one glyph: the
    /// straight-baseline formula (§ file header) unless `placement`
    /// supplies a path override (D-110 seam, WS-05). `lineOriginX`
    /// (MASTER-PLAN Phase-2 RTL-alignment fix) is deliberately NOT added in
    /// the override branch: a path-placement override already resolves an
    /// absolute position along the path (D-110), which has no `[0,
    /// boxWidth]` line-box concept to begin with (same scoping
    /// `PathTextDrawer` itself documents for why it never applies this
    /// fix).
    static func applyPlacement(
        ctPos: CGPoint, lineOriginY: CGFloat, lineOriginX: CGFloat, address: MKGlyphAddress, lineIndex: Int, placement: any PathPlacementProviding
    ) -> (position: CGPoint, tangentAngle: Double?) {
        if let override = placement.placement(for: address, lineIndex: lineIndex) {
            return (override.position, Double(override.tangentAngle))
        }
        return (CGPoint(x: ctPos.x + lineOriginX, y: ctPos.y - lineOriginY), nil)
    }

    /// A stable, deterministic per-font-instance digest good enough for
    /// `MKGlyphRef.fontChecksum`'s "guards against silent re-render drift"
    /// role at this seam (real `sfnt head.checkSumAdjustment` extraction is
    /// WS-09's job, per that field's own doc comment ، this deriver has no
    /// font-file access, only the `MKFontHandle` seam type).
    static func fontChecksum(_ handle: MKFontHandle) -> String {
        "\(handle.postScriptName)@\(handle.pointSize)"
    }

    static func union(_ a: CGRect?, _ b: CGRect) -> CGRect {
        guard let a else { return b }
        return a.union(b)
    }

    /// Approximate (not ink-exact ، documented) per-node footprint for
    /// `ArrangedComposition.originFrame`'s union: position + advance,
    /// generously padded so marks/overshoots stay inside the box. This
    /// field is canvas-chrome metadata (bounding box display), not
    /// consumed by the render/hit-test geometry chain, so approximation
    /// here does not affect fidelity.
    static func approximateBounds(node: MKGlyphNode) -> CGRect {
        approximateBounds(position: node.layout.position, advance: node.layout.advance)
    }

    static func approximateBounds(position: CGPoint, advance: CGSize) -> CGRect {
        CGRect(x: position.x, y: position.y - abs(advance.height == 0 ? 20 : advance.height) - 20, width: max(advance.width, 1), height: 40)
    }

    static func approximateMarkBounds(mark: MKMarkNode, baseID: MKNodeID?, nodes: [MKArrangedChild]) -> CGRect {
        let anchor: CGPoint
        if let baseID, let baseNode = nodes.first(where: { $0.id == baseID }), case .glyph(let g) = baseNode {
            anchor = CGPoint(x: g.layout.position.x + mark.relativeOffset.width, y: g.layout.position.y + mark.relativeOffset.height)
        } else {
            anchor = mark.transform.position
        }
        return CGRect(x: anchor.x - 5, y: anchor.y - 5, width: 10, height: 10)
    }
}
