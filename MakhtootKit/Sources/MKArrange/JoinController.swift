import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import MKTextEngine

// WS-04 packet §5 tasks 6-7 (D-107, ARCHITECTURE §7.3). Explicit join
// break/restore between two adjacent arranged `MKGlyphNode`s.
//
// **Restore mechanism (documented deviation from the packet's literal task
// 7 wording).** Task 7 describes restore as "restore stored original glyph
// ids (kept in `preBreakSnapshot` inside the node)" ، but `MKGlyphNode`
// (WS-02/`MKModel`, outside this packet's fence) has no such field.
// ARCHITECTURE.md §7.3 ، the higher-authority source per FOUNDATION.md's
// own precedence rule ("If a deliverable contradicts FOUNDATION.md, the
// deliverable is wrong"; ARCHITECTURE is itself downstream of FOUNDATION,
// but is more specific and more recently written than this packet's own
// prose) ، describes restore differently and without needing extra model
// state: "Restoring a join re-resolves both letters' forms the same way
// and clears `brokenByUser`." This controller follows §7.3 literally: a
// restore is computed via the SAME `MKFormResolver` ZWJ-harvest path used
// for a break, with the join reconnected (`joinsNext(A) = true`,
// `joinsPrevious(B) = true`) before re-deriving each letter's form off the
// §7.3 truth table. Because D-107's harvest is *designed* to reproduce
// exactly the glyph Core Text would have chosen in true context, this
// still satisfies the packet's own accept criterion ("break→restore
// round-trips to Equatable-identical nodes") ، verified in
// `JoinControllerTests.breakThenRestoreRoundTrips`.
public struct JoinController: Sendable {
    private let resolver: MKFormResolver

    public init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.resolver = MKFormResolver(fonts: fonts)
    }

    /// ARCHITECTURE §7.3's truth table.
    public static func defaultForm(joinsPrevious: Bool, joinsNext: Bool) -> MKJoiningForm {
        switch (joinsPrevious, joinsNext) {
        case (true, true): return .medial
        case (false, true): return .initial
        case (true, false): return .final
        case (false, false): return .isolated
        }
    }

    /// The result of a break/restore: the two updated glyph nodes plus the
    /// advance-width delta each incurred (packet task 6: "width delta is
    /// recorded in `formDelta` metadata but not auto-applied" ، geometry,
    /// i.e. `layout.position`/`layout.advance`, is left untouched by this
    /// controller; `formDeltaA`/`formDeltaB` are purely informational for a
    /// caller that wants to offer the opt-in "إزاحة تلقائية" auto-nudge
    /// gap ARCHITECTURE §7.3 describes as a separate, optional step).
    public struct JoinEditResult: Sendable {
        public var updatedA: MKGlyphNode
        public var updatedB: MKGlyphNode
        public var formDeltaA: CGFloat
        public var formDeltaB: CGFloat
        /// WS-16 follow-up (`docs/impl-log/WS-16-cursive.md` ADR WS16-A4,
        /// `CONTRACTS.md`'s "required `MKArrange` follow-up" item 2): `true`
        /// when EITHER original node (`nodeA`/`nodeB`, as captured ، before
        /// this reshape) was `provenance.cursiveAttached`. This D-107
        /// ZWJ-synthetic-context harvest cannot trigger the contextual GSUB
        /// substitution a real neighboring letter would ، confirmed
        /// empirically (WS-16 Finding 6) to sometimes choose a different
        /// glyph than the one Core Text would pick in true context. Same
        /// accepted-by-design, documented class D-222 already establishes
        /// for single-glyph scale inside a joined word (T-AR-60): the
        /// operation completes and produces a valid, non-corrupting result
        /// either way ، this flag exists only so a future WS-06/canvas
        /// consumer can show an honest "قد لا يتطابق شكل الاتصال تمامًا"
        /// (the connecting stroke may not match exactly) hint for these
        /// specific letters, not to block or auto-fix anything.
        public var cursiveFidelityNote: Bool
    }

    /// Task 6: breaks the join between adjacent letters `nodeA` (earlier in
    /// logical order) and `nodeB` (later). Re-resolves A as if its NEXT
    /// join is broken (keeping A's existing `joinsPrevious`) and B as if
    /// its PREVIOUS join is broken (keeping B's existing `joinsNext`);
    /// glyph id/outline/advance are swapped in place, POSITION is
    /// untouched (D-106 "arranged geometry is user-owned"; INV: no
    /// implicit reshape/reflow), and `joining.brokenByUser` is set on both.
    public func breakJoin(_ nodeA: MKGlyphNode, _ nodeB: MKGlyphNode, style: MKTextStyle) async throws -> JoinEditResult {
        try await edit(nodeA, nodeB, style: style, joinsNextForA: false, joinsPreviousForB: false)
    }

    /// Task 7: the inverse ، reconnects the join (see file header for the
    /// re-resolve-based mechanism) and clears `brokenByUser` on both.
    public func restoreJoin(_ nodeA: MKGlyphNode, _ nodeB: MKGlyphNode, style: MKTextStyle) async throws -> JoinEditResult {
        try await edit(nodeA, nodeB, style: style, joinsNextForA: true, joinsPreviousForB: true)
    }

    private func edit(
        _ nodeA: MKGlyphNode, _ nodeB: MKGlyphNode, style: MKTextStyle, joinsNextForA: Bool, joinsPreviousForB: Bool
    ) async throws -> JoinEditResult {
        guard let scalarA = nodeA.provenance.codepoints.first.flatMap(Unicode.Scalar.init),
              let scalarB = nodeB.provenance.codepoints.first.flatMap(Unicode.Scalar.init)
        else {
            throw MKArrangeError.invalidJoinTarget(nodeA.id)
        }

        let formA = Self.defaultForm(joinsPrevious: nodeA.joining.joinsPrevious, joinsNext: joinsNextForA)
        let formB = Self.defaultForm(joinsPrevious: joinsPreviousForB, joinsNext: nodeB.joining.joinsNext)

        guard let resolvedA = await resolver.resolve(letter: scalarA, form: formA, style: style) else {
            throw MKArrangeError.invalidJoinTarget(nodeA.id)
        }
        guard let resolvedB = await resolver.resolve(letter: scalarB, form: formB, style: style) else {
            throw MKArrangeError.invalidJoinTarget(nodeB.id)
        }

        var updatedA = nodeA
        updatedA.glyph.glyphID = resolvedA.glyphID
        updatedA.outline = resolvedA.outline
        updatedA.joining = MKJoiningState(form: resolvedA.form, joinsPrevious: nodeA.joining.joinsPrevious, joinsNext: joinsNextForA, brokenByUser: !joinsNextForA)
        let deltaA = resolvedA.advance.width - nodeA.layout.advance.width

        var updatedB = nodeB
        updatedB.glyph.glyphID = resolvedB.glyphID
        updatedB.outline = resolvedB.outline
        updatedB.joining = MKJoiningState(form: resolvedB.form, joinsPrevious: joinsPreviousForB, joinsNext: nodeB.joining.joinsNext, brokenByUser: !joinsPreviousForB)
        let deltaB = resolvedB.advance.width - nodeB.layout.advance.width

        let cursiveFidelityNote = nodeA.provenance.cursiveAttached || nodeB.provenance.cursiveAttached
        return JoinEditResult(
            updatedA: updatedA, updatedB: updatedB, formDeltaA: deltaA, formDeltaB: deltaB,
            cursiveFidelityNote: cursiveFidelityNote)
    }

    /// Convenience: builds the journal-codable `MKReplaceNodesCommand` (via
    /// `ArrangeCommands.replaceComposition`) for a break or restore,
    /// replacing both nodes in-place within `ownerNode.composition`
    /// (positions/ids/provenance unchanged ، only `glyph`/`outline`/
    /// `joining` fields differ, task 6/7 accept: "positions unchanged").
    public func command(
        applying result: JoinEditResult, ownerNode: MKArrangedTextNode, isBreak: Bool
    ) -> any MKCommand {
        var copy = ownerNode.composition
        copy.nodes = copy.nodes.map { child in
            if child.id == result.updatedA.id { return .glyph(result.updatedA) }
            if child.id == result.updatedB.id { return .glyph(result.updatedB) }
            return child
        }
        return ArrangeCommands.replaceComposition(
            of: ownerNode, with: copy,
            label: isBreak ? "كسر الوصل" : "إعادة الوصل")   // break join / restore join
    }
}
