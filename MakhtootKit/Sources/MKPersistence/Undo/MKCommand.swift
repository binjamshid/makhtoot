import Foundation
import MKFoundation
import MKModel

// WS-02 packet §5 task 10. The command protocol every scene mutation goes
// through ، undo/redo (task 11), the crash-recovery journal (task 13), and
// `MakhtootDocument.apply(_:)` (task 9) all operate on `any MKCommand`.

/// One reversible scene mutation. `apply`/`inverse` are pure: `apply`
/// returns a NEW scene (never mutates `scene` in place ، value semantics,
/// D-102); `inverse(against:)` is computed against the scene BEFORE
/// `apply` runs, so it can capture whatever prior state it needs to
/// reverse itself later, regardless of how many other commands run in
/// between (this is what makes gesture-coalescing in `MKUndoStack` safe ،
/// see that file's doc comment).
public protocol MKCommand: Sendable {
    var id: UUID { get }
    /// Arabic label for the Undo/Redo menu (e.g. "تحريك" move, "تدوير"
    /// rotate, "تجميع" group) ، task 10/§6: Arabic with Latin gloss in the
    /// declaring type's doc comments.
    var name: String { get }
    /// Commands with equal, non-nil `coalescingKey`s emitted inside one
    /// `MKUndoStack.beginGesture()/endGesture()` bracket merge into a
    /// single undo entry (§14.3: continuous gestures, keystroke bursts,
    /// inspector slider drags).
    var coalescingKey: String? { get }

    func apply(to scene: MKScene) throws -> MKScene
    func inverse(against scene: MKScene) -> any MKCommand
}

/// `MKPersistence`'s error taxonomy (follows the `MKError` pattern from
/// `MKFoundation`; reserves the `"persistence"` error-code prefix).
public enum MKPersistenceError: Error, Sendable {
    case nodeNotFound(MKNodeID)
    case unknownCommandType(String)
    case documentPackageNotFound(URL)
    case malformedManifest(String)
    case malformedJournalLine(String)
}

/// A safe fallback command used when an inverse cannot be computed because
/// its target no longer exists (e.g. removing a node that was already
/// removed by a concurrent path) ، applying it is a deliberate no-op
/// rather than throwing, so `MKUndoStack` never corrupts the stack by
/// propagating an error out of `inverse(against:)` (a non-throwing
/// requirement of the protocol).
public struct MKNoOpCommand: MKCommand, Codable {
    public let id: UUID
    public let name: String
    public var coalescingKey: String? { nil }

    public init(name: String = "لا شيء") {
        self.id = UUID()
        self.name = name
    }

    public func apply(to scene: MKScene) throws -> MKScene { scene }
    public func inverse(against scene: MKScene) -> any MKCommand { MKNoOpCommand(name: name) }
}
