import Foundation
import MKFoundation
import MKModel

// WS-04 packet (AGENT_TASK_PACKETS/WS-04-arrange-engine.md) §5 task 15 +
// the shared error taxonomy every other file in this module throws.
// `MKArrange` reserves the `"arrange"` `MKErrorCode` prefix (see
// `MKFoundation/MKError.swift`'s registry convention).

/// `MKArrange`'s error taxonomy (follows the `MKError` pattern from
/// `MKFoundation`, same shape as `MKPersistenceError`/`MKValidationError`).
public enum MKArrangeError: MKError {
    /// Attempted a reshape-requiring mutation (font/size/feature change) on
    /// an `arranged` node ، task 15 (INV: arranged nodes never reshape
    /// implicitly). محاولة تغيير الخط على تكوين مرتّب (Latin gloss: tried to
    /// change the font on an arranged composition).
    case arrangedNodeCannotReshape
    /// D-221's widened recompose dirty check tripped (transform OR style
    /// delta on any constituent since decomposition) and `force` was not
    /// passed. لا يمكن إعادة الدمج بعد تعديل الأجزاء (Latin gloss: cannot
    /// recompose after the parts were edited) ، the exact packet-mandated
    /// message (task 11).
    case recomposeBlockedByEdits(editedNodeCount: Int)
    /// `RevertService` found the backup's `contentHash` did not match its
    /// own recomputed hash ، INV-4 tamper/drift guard. تعذّر استرجاع النص
    /// الأصلي (Latin gloss: could not restore the original text).
    case revertBackupCorrupted
    /// A command targeted a node id that is not an `arranged` node (or does
    /// not exist) in the scene it was applied to. Dormant since the
    /// Run-3 `MKReplaceNodesCommand` adoption (see `ArrangeCommands.swift`
    /// file header): the canonical command layer no longer re-reads/
    /// kind-checks the owner node from the scene at apply time (it
    /// snapshots the full replacement node at command-construction time
    /// instead ، a missing target now throws `MKPersistenceError
    /// .nodeNotFound` per `CONTRACTS.md`'s documented adoption
    /// difference). Kept in the taxonomy for any future call site that
    /// wants an explicit "is this id really an arranged node" pre-check.
    case sourceNodeNotArranged(MKNodeID)
    /// A command targeted an arranged-child id (glyph/mark/ligature) that
    /// is not present in the composition.
    case childNodeNotFound(MKNodeID)
    /// Decompose was requested on a `MKLigatureGroup` whose
    /// `decomposable == false` (font/context could not realize the
    /// constituents individually).
    case ligatureNotDecomposable(MKNodeID)
    /// A join-break/restore/form-selection target was not a glyph node, or
    /// its letter has no valid contextual forms to offer.
    case invalidJoinTarget(MKNodeID)

    public var errorCode: String {
        switch self {
        case .arrangedNodeCannotReshape: return "arrange.cannot-reshape"
        case .recomposeBlockedByEdits: return "arrange.recompose-blocked"
        case .revertBackupCorrupted: return "arrange.revert-backup-corrupted"
        case .sourceNodeNotArranged: return "arrange.source-not-arranged"
        case .childNodeNotFound: return "arrange.child-not-found"
        case .ligatureNotDecomposable: return "arrange.ligature-not-decomposable"
        case .invalidJoinTarget: return "arrange.invalid-join-target"
        }
    }

    public var arabicUserMessage: String? {
        switch self {
        case .arrangedNodeCannotReshape:
            return "لا يمكن تغيير هذا العنصر بعد تحويله إلى ترتيب حر"   // cannot reshape after arranging
        case .recomposeBlockedByEdits:
            return "لا يمكن إعادة الدمج بعد تعديل الأجزاء"   // cannot recompose after editing the parts (packet-normative string, task 11)
        case .revertBackupCorrupted:
            return "تعذّر استرجاع النص الأصلي"   // could not restore the original text
        case .sourceNodeNotArranged, .childNodeNotFound, .invalidJoinTarget:
            return nil   // internal/programmer-error class, not user-facing
        case .ligatureNotDecomposable:
            return "لا يمكن تفكيك هذا المركّب"   // this ligature cannot be decomposed
        }
    }

    public var underlying: (any Swift.Error)? { nil }
}

/// Task 15's enforcement surface: arranged nodes may only be scaled/
/// transformed/style-edited, never reshaped (font swap, point-size change,
/// text-content edit, feature toggle) ، those routes either throw or are
/// simply not exposed on this module's arranged-node API surface (there is
/// no `setFont(on: MKArrangedTextNode, ...)` entry point anywhere in
/// `MKArrange`; this enum exists for the call sites ، canvas inspector
/// bindings, WS-06 ، that need to *detect* "is this operation legal for an
/// arranged node" before even constructing a command).
public enum MKArrangeInvariants {
    /// The INV enforcement point named literally in the packet's task 15:
    /// "attempting a font swap on an arranged node throws". Any caller
    /// building an inspector affordance for font/size/feature changes must
    /// route through this guard first (or, per task 15, through the
    /// revert-first flow instead of ever reaching a reshape call).
    /// A clean, testable throw (packet task 15 accept: "attempting a font
    /// swap on an arranged node throws") ، deliberately NOT an
    /// `assertionFailure`/`assert` trap: this function is meant to be
    /// called from legitimate "can I do this?" call sites (an inspector
    /// enabling/disabling a font-picker control, or a route-to-revert-first
    /// flow deciding whether to prompt), which is an expected, everyday
    /// code path, not a programmer error ، trapping here would crash any
    /// DEBUG-configuration caller that correctly checks this before acting.
    public static func assertReshapeAllowed(on kind: MKArrangeNodeKind) throws {
        switch kind {
        case .arranged:
            throw MKArrangeError.arrangedNodeCannotReshape
        case .liveOrPath:
            return
        }
    }
}

/// Minimal discriminator so `assertReshapeAllowed` doesn't need to import
/// the full `MKNode` enum's pattern-matching machinery at every call site ،
/// callers (this module and WS-06) map their own node reference to one of
/// these two cases.
public enum MKArrangeNodeKind: Sendable {
    case arranged
    case liveOrPath
}
