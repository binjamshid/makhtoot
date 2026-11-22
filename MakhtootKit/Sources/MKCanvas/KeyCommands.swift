import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 17: "arrow-key nudge (1 pt / ⇧10 pt), ⌘Z/⇧⌘Z undo/
// redo, ⌘G/⇧⌘G group/ungroup, ⌘D duplicate, Delete removes selection
// (respecting locks). Accept: UIKeyCommand list wired; nudge emits
// coalesced commands per key-repeat burst."

/// Pure nudge-burst coalescing (no UIKit dependency ، key-repeat bursts on
/// iPad deliver many key-down events per second; this groups them into one
/// undo entry the same way `MoveGesture` groups pan-gesture frames).
@MainActor
public final class NudgeController {
    public static let normalStep: CGFloat = 1
    public static let shiftStep: CGFloat = 10
    /// A gap longer than this between two nudges starts a NEW burst (and
    /// thus a new undo entry) ، long enough to absorb OS key-repeat
    /// cadence, short enough that releasing the arrow key and pressing it
    /// again later is a clearly separate user action.
    public static let burstWindow: TimeInterval = 0.5

    private var burstGestureID: UUID?
    private var lastNudgeTime: TimeInterval = 0

    public init() {}

    public enum Direction: Sendable { case up, down, left, right }

    /// Applies one nudge step to every selected, unlocked node.
    public func nudge(session: CanvasSession, direction: Direction, shiftPressed: Bool, now: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        let step = shiftPressed ? Self.shiftStep : Self.normalStep
        let (dx, dy): (CGFloat, CGFloat) = {
            switch direction {
            case .up: return (0, -step)
            case .down: return (0, step)
            case .left: return (-step, 0)
            case .right: return (step, 0)
            }
        }()

        if burstGestureID == nil || (now - lastNudgeTime) > Self.burstWindow {
            burstGestureID = UUID()
            session.beginGesture()
        }
        lastNudgeTime = now

        var newTransforms: [MKNodeID: MKTransform2D] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id), !node.core.isLocked else { continue }
            var t = node.core.transform
            t.position.x += dx
            t.position.y += dy
            newTransforms[id] = t
        }
        guard !newTransforms.isEmpty, let gestureID = burstGestureID else { return }
        try? session.perform(MKBatchTransformCommand(gestureID: gestureID, newTransforms: newTransforms))
    }

    /// Ends the current burst ، call on key-up, or after `burstWindow`
    /// elapses with no further nudges (the hosting view controller debounces
    /// this; `nudge(...)` itself also auto-starts a fresh burst once the
    /// window lapses, so a missed `endBurst()` call only over-extends one
    /// undo entry's lifetime, it never corrupts state).
    public func endBurst(session: CanvasSession) {
        guard burstGestureID != nil else { return }
        session.endGesture()
        burstGestureID = nil
    }
}

#if canImport(UIKit)
import UIKit

/// The concrete `UIKeyCommand` list + dispatch (task 17 accept: "UIKeyCommand
/// list wired"). `MKCanvasViewController` installs these via
/// `override var keyCommands: [UIKeyCommand]?`.
///
/// **P6 verification note (checked live, not assumed):** as of this pass,
/// `MKCanvasViewController` does NOT actually override `keyCommands` or call
/// `makeKeyCommands(...)` anywhere, and nothing in the app target holds a
/// `NudgeController` either (`grep -rn "MKCanvasKeyCommands\|NudgeController"`
/// across `Makhtoot/` ، zero hits outside this file and its own tests). The
/// ENTIRE physical-keyboard shortcut path (nudge, undo/redo, group/ungroup,
/// duplicate, delete ، every selector below, not just the six new ones added
/// this pass) is pre-existing, un-wired catalog code, not "implemented end
/// to end" the way the toolbar/menu equivalents are. This pass adds the new
/// P6 selectors here (§2.3's own instruction: "add the new shortcuts there,
/// following its established pattern") without attempting to wire the whole
/// mechanism into a live `keyCommands` override ، that is a materially
/// larger, separate task (the view controller doesn't even hold the
/// `LayersModel`/`EditorViewModel` references duplicate/undo/redo need),
/// flagged as its own follow-up rather than silently expanded into this one.
@MainActor
public enum MKCanvasKeyCommands {
    public static func makeKeyCommands(
        target: Any, nudgeUp: Selector, nudgeDown: Selector, nudgeLeft: Selector, nudgeRight: Selector, nudgeUpBig: Selector, nudgeDownBig: Selector, nudgeLeftBig: Selector, nudgeRightBig: Selector, undo: Selector, redo: Selector, group: Selector, ungroup: Selector, duplicate: Selector, delete: Selector,
        // P6 (§2.3 "Editing operations") additions, following this method's
        // established shape exactly: one `Selector` parameter + one
        // `UIKeyCommand` per new shortcut, conventional modifier/key choices
        // matching mainstream design-tool muscle memory (⌘C/⌘V, ⌘A/⇧⌘A,
        // ⇧H/⇧V for flip, matching Figma/Sketch's own flip shortcuts since
        // this platform has no pre-existing convention of its own to match).
        copy: Selector, paste: Selector, selectAll: Selector, deselectAll: Selector, flipHorizontal: Selector, flipVertical: Selector
    ) -> [UIKeyCommand] {
        [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: nudgeUp),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: nudgeDown),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: nudgeLeft),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: nudgeRight),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [.shift], action: nudgeUpBig),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [.shift], action: nudgeDownBig),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [.shift], action: nudgeLeftBig),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [.shift], action: nudgeRightBig),
            UIKeyCommand(input: "z", modifierFlags: [.command], action: undo),
            UIKeyCommand(input: "z", modifierFlags: [.command, .shift], action: redo),
            UIKeyCommand(input: "g", modifierFlags: [.command], action: group),
            UIKeyCommand(input: "g", modifierFlags: [.command, .shift], action: ungroup),
            UIKeyCommand(input: "d", modifierFlags: [.command], action: duplicate),
            UIKeyCommand(input: UIKeyCommand.inputDelete, modifierFlags: [], action: delete),
            UIKeyCommand(input: "c", modifierFlags: [.command], action: copy),
            UIKeyCommand(input: "v", modifierFlags: [.command], action: paste),
            UIKeyCommand(input: "a", modifierFlags: [.command], action: selectAll),
            UIKeyCommand(input: "a", modifierFlags: [.command, .shift], action: deselectAll),
            UIKeyCommand(input: "h", modifierFlags: [.shift], action: flipHorizontal),
            UIKeyCommand(input: "v", modifierFlags: [.shift], action: flipVertical),
        ]
    }
}
#endif
