import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-04 packet §5 task 14 (D-106 §5.4). Revert-to-text: reconstructs the
// original `liveText`/`pathText` node from `MKSourceTextBackup`, with a
// confirmation preflight ، "استعادة النص الأصلي سيلغي جميع التعديلات
// الحرة. متابعة؟" (restoring the original text will discard all
// free-arrangement edits. Continue?, ARCHITECTURE §5.4's exact copy) ، and
// undo restores the FULL arranged node (every manual edit), since revert is
// itself a forward, undoable `MKCommand`, never applied silently.
public struct RevertService: Sendable {
    public init() {}

    /// Task 14's preflight report: `{editedNodeCount, willDiscard}`. WS-06
    /// binds this directly to the confirmation dialog copy.
    public struct RevertPreflight: Sendable, Equatable {
        public var editedNodeCount: Int
        public var willDiscard: Bool
        /// D-106/ARCHITECTURE §5.4's exact Arabic confirmation copy.
        public static let confirmationMessage = "استرجاع النص الأصلي سيلغي جميع التعديلات الحرة. متابعة؟"

        public init(editedNodeCount: Int, willDiscard: Bool = true) {
            self.editedNodeCount = editedNodeCount
            self.willDiscard = willDiscard
        }
    }

    /// Counts every child (including decomposed-ligature components) whose
    /// current state differs from what a fresh derivation would have
    /// produced ، approximated, since a full re-derivation-and-diff is
    /// expensive and unnecessary for a preflight count: any child with a
    /// non-identity `transform`, a style that differs from a freshly
    /// arranged default, a broken join (`joining.brokenByUser`), a
    /// decomposed ligature, or a detached/moved mark counts as "edited".
    /// `willDiscard` is unconditionally `true` (D-106: revert ALWAYS
    /// discards manual arrangement ، never a partial/selective revert).
    public func preflight(for composition: ArrangedComposition) -> RevertPreflight {
        var count = 0
        for child in composition.nodes {
            switch child {
            case .glyph(let g):
                if g.transform != .identity || g.joining.brokenByUser { count += 1 }
            case .mark(let m):
                if m.transform != .identity || !m.followsBase { count += 1 }
            case .ligature(let l):
                switch l.state {
                case .composed:
                    if l.transform != .identity { count += 1 }
                case .decomposed(let d):
                    count += 1
                    count += d.components.filter { $0.transform != .identity || $0.style != l.style }.count
                }
            }
        }
        return RevertPreflight(editedNodeCount: count, willDiscard: true)
    }

    /// Verifies `backup.contentHash` still matches a fresh recomputation
    /// (INV-4 tamper/drift guard) before reverting ، throws
    /// `MKArrangeError.revertBackupCorrupted` rather than silently
    /// reverting to a value that may not be what was actually backed up.
    public func verifyBackupIntegrity(_ backup: MKSourceTextBackup) throws {
        guard backup.contentHash == backup.recomputedHash() else {
            throw MKArrangeError.revertBackupCorrupted
        }
    }

    /// Task 14: rebuilds the `liveText` (or `pathText`, when the backup
    /// carries `pathData`) node from `MKSourceTextBackup` ، same
    /// transform/z (i.e. the ARRANGED node's own `core`, reused verbatim,
    /// matching `MKSourceTextBackup`'s style/string being the ONLY thing
    /// that changes) ، and returns the `MKCommand` (`MKReplaceNodeCommand`,
    /// same primitive `arrangeCommand` uses in the forward direction, task
    /// 4/14 symmetry). Undo of this command restores the full arranged
    /// node exactly (task 14 accept: "undo restores every manual edit"),
    /// since `MKReplaceNodeCommand.inverse(against:)` captures the
    /// pre-apply `.arranged` node from the scene wholesale.
    public func revertCommand(arrangedNodeID: MKNodeID, node: MKArrangedTextNode) throws -> any MKCommand {
        try verifyBackupIntegrity(node.composition.sourceBackup)
        let backup = node.composition.sourceBackup
        let sourceText = MKSourceText(string: backup.sourceString)
        let rebuilt: MKNode
        if let pathData = backup.pathData {
            rebuilt = .pathText(MKPathTextNode(core: node.core, text: sourceText, style: backup.style, path: pathData))
        } else {
            rebuilt = .liveText(MKLiveTextNode(core: node.core, text: sourceText, style: backup.style))
        }
        return MKReplaceNodeCommand(nodeID: arrangedNodeID, newNode: rebuilt)
    }
}
