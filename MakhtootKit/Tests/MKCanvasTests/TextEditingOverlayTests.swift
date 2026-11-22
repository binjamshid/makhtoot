import CoreGraphics
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

#if canImport(UIKit)
import UIKit
#endif

// WS-06 packet §5 tasks 13/14, D-104/§14.3: keystroke bursts coalesce
// within a 700 ms window into one undo entry; cancel restores pre-edit
// text and leaves no stray undo entry; commit leaves the final text
// applied. All driven through `TextEditingOverlayController` directly ،
// no `UITextView`/UIKit involved (this is the state-machine half the
// packet's gate explicitly calls out: "undo coalescing per gesture type").
@MainActor
@Suite("TextEditingOverlayController")
struct TextEditingOverlayControllerTests {
    private func makeTextNodeSession() throws -> (CanvasSession, MKNodeID) {
        let session = try CanvasTestSupport.makeSession()
        let id = try session.addLiveText(at: .zero, text: "ابتدائي")
        session.enterBrowseMode() // addLiveText already opens editText; reset for a clean per-test begin()
        return (session, id)
    }

    @Test func beginEntersEditTextMode() throws {
        let (session, id) = try makeTextNodeSession()
        let controller = TextEditingOverlayController()
        controller.begin(session: session, nodeID: id)
        #expect(session.mode == .editText(nodeID: id))
        #expect(controller.isActive)
    }

    @Test func keystrokesWithinTheBurstWindowCoalesceToOneUndoEntry() throws {
        let (session, id) = try makeTextNodeSession()
        let controller = TextEditingOverlayController()
        controller.begin(session: session, nodeID: id)
        let undoCountBefore = session.document.undoStack.undo.count

        let word = "بسم"
        var accumulated = ""
        for (i, ch) in word.enumerated() {
            accumulated.append(ch)
            controller.textDidChange(session: session, newText: accumulated, now: Double(i) * 0.1)
        }
        controller.commit(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected liveText")
            return
        }
        #expect(node.text.string == "بسم")
        #expect(session.mode == .browse)
    }

    @Test func aPauseLongerThanTheBurstWindowStartsANewUndoEntry() throws {
        let (session, id) = try makeTextNodeSession()
        let controller = TextEditingOverlayController()
        controller.begin(session: session, nodeID: id)
        let undoCountBefore = session.document.undoStack.undo.count

        controller.textDidChange(session: session, newText: "ب", now: 0)
        controller.textDidChange(session: session, newText: "بس", now: 5) // > 0.7s gap
        controller.commit(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 2)
    }

    @Test func cancelRestoresTheOriginalTextAndLeavesNoStrayUndoEntry() throws {
        let (session, id) = try makeTextNodeSession()
        let controller = TextEditingOverlayController()
        controller.begin(session: session, nodeID: id)
        let undoCountBefore = session.document.undoStack.undo.count

        controller.textDidChange(session: session, newText: "تعديل", now: 0)
        controller.textDidChange(session: session, newText: "تعديل آخر", now: 0.1)
        controller.cancel(session: session)

        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected liveText")
            return
        }
        #expect(node.text.string == "ابتدائي")
        #expect(session.document.undoStack.undo.count == undoCountBefore)
        #expect(session.mode == .browse)
        #expect(controller.isActive == false)
    }

    @Test func cancelWithNoEditsIsANoOp() throws {
        let (session, id) = try makeTextNodeSession()
        let controller = TextEditingOverlayController()
        controller.begin(session: session, nodeID: id)
        let undoCountBefore = session.document.undoStack.undo.count
        controller.cancel(session: session)
        #expect(session.document.undoStack.undo.count == undoCountBefore)
        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected liveText")
            return
        }
        #expect(node.text.string == "ابتدائي")
    }

    // P2.5/Bug 5: `commit(session:)` is idempotent while `isActive` guards
    // it ، this is the controller-level half of the "re-entrant commit"
    // fix. `TextEditingOverlayView` (the UIKit wrapper ، it only exists
    // under `#if canImport(UIKit)` and this package also builds for plain
    // macOS, but it is NOT untestable: this same test target IS directly
    // testable against the view when run against a real iOS/UIKit
    // destination, e.g. `xcodebuild -scheme MakhtootKit-Package
    // -destination 'platform=iOS Simulator,name=iPhone 15' test` rather
    // than this package's default macOS destination ، see
    // `TextEditingOverlayViewTests` at the bottom of this file, which
    // drives the concrete view/window/first-responder machinery directly
    // and pins the exact re-entrancy bug this controller-level test below
    // can only reproduce indirectly)
    // used to rely on this guard by ACCIDENT: its `commit()` called
    // `resignFirstResponder()` BEFORE `controller.commit(session:)`, which
    // synchronously re-entered `textViewDidEndEditing` → `commit()` →
    // `controller.commit(session:)` first; the guard below is what kept
    // that accidental double call from double-committing. The view-level
    // fix (an `isFinishing` flag set before `resignFirstResponder()`) now
    // prevents the re-entrant call from ever reaching the controller at
    // all, but this guard remains the contract that makes a duplicate call
    // ، however it happens ، harmless rather than corrupting undo state.
    @Test func commitCalledTwiceIsIdempotent() throws {
        let (session, id) = try makeTextNodeSession()
        let controller = TextEditingOverlayController()
        controller.begin(session: session, nodeID: id)
        controller.textDidChange(session: session, newText: "تعديل", now: 0)

        controller.commit(session: session)
        let undoCountAfterFirstCommit = session.document.undoStack.undo.count
        let renderBridge = RecordingRenderBridge()
        session.renderBridge = renderBridge

        controller.commit(session: session) // duplicate call ، e.g. "تم" tapped twice
        #expect(session.document.undoStack.undo.count == undoCountAfterFirstCommit)
        #expect(session.mode == .browse)
        #expect(controller.isActive == false)
        // The duplicate call must not even reach `renderBridge` again ،
        // proves the SECOND call short-circuits at `guard isActive` before
        // doing any work, not just that its side effects happen to cancel out.
        #expect(renderBridge.commitCount == 0)
    }

    // P2.5/Bug 5: pins the controller-level contract whose absence is WHY
    // the real bug ("`cancel()` silently commits instead of restoring")
    // was possible at the view layer. `cancel(session:)` only restores/
    // unwinds while `isActive`; the old `TextEditingOverlayView.cancel()`
    // called `resignFirstResponder()` BEFORE `controller.cancel(session:)`,
    // which synchronously re-entered `textViewDidEndEditing` → `commit()`
    // → `controller.commit(session:)` FIRST — flipping `isActive` to
    // `false` before the outer `cancel()` call ever ran its own unwind
    // loop. This test reproduces that exact out-of-order sequence directly
    // against the controller (no UIKit involved) and confirms the
    // documented symptom: the edit stays committed, not restored, because
    // `cancel()` no-ops once `isActive` is already `false`. This is
    // precisely why the view-level fix must PREVENT the re-entrant call
    // from reaching the controller at all (an `isFinishing` guard set
    // before `resignFirstResponder()`), rather than try to fix anything
    // here ، the controller's own guard is correct on its own terms
    // (you cannot cancel something already committed).
    @Test func callingCommitBeforeCancelLeavesTheEditCommittedNotRestored() throws {
        let (session, id) = try makeTextNodeSession()
        let controller = TextEditingOverlayController()
        controller.begin(session: session, nodeID: id)
        controller.textDidChange(session: session, newText: "تعديل", now: 0)

        controller.commit(session: session) // simulates the re-entrant inner call winning first
        #expect(controller.isActive == false)

        controller.cancel(session: session) // simulates the outer call arriving second, as the old bug did
        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected liveText")
            return
        }
        #expect(node.text.string == "تعديل") // NOT restored to "ابتدائي" ، documents the bug's exact symptom.
    }
}

#if canImport(UIKit)

// P2.5/Bug 5's actual regression surface, at the view layer this time:
// `TextEditingOverlayView.cancel()` used to call `textView
// .resignFirstResponder()` BEFORE `controller.cancel(session:)`.
// `resignFirstResponder()` synchronously fires `UITextViewDelegate
// .textViewDidEndEditing`, which (before the `isFinishing` fix) always
// called `commit()` ، so cancelling actually ran `controller
// .commit(session:)` FIRST, flipping `controller.isActive` to `false`.
// The outer `cancel()` call's own `controller.cancel(session:)` then hit
// `guard isActive` and returned immediately, restoring nothing: cancel
// silently committed. `TextEditingOverlayControllerTests
// .callingCommitBeforeCancelLeavesTheEditCommittedNotRestored` above pins
// the controller-level HALF of this (what happens once `isActive` is
// already `false`) but cannot reproduce the re-entrancy itself, since it
// never touches `UITextView`/`resignFirstResponder()` at all ، the bug
// lived entirely in the ORDER `TextEditingOverlayView.cancel()` called
// things in, which only a real `UITextView` genuinely losing first-
// responder status can exercise. This suite drives the concrete view and
// therefore only compiles/runs under `#if canImport(UIKit)` ، it needs
// this same test target built against a real iOS/UIKit destination, e.g.
// `xcodebuild -scheme MakhtootKit-Package -destination 'platform=iOS
// Simulator,name=iPhone 15' test`, not this package's default macOS
// destination.
@MainActor
@Suite("TextEditingOverlayView")
struct TextEditingOverlayViewTests {
    private func makeTextNodeSession() throws -> (CanvasSession, MKNodeID) {
        let session = try CanvasTestSupport.makeSession()
        let id = try session.addLiveText(at: .zero, text: "ابتدائي")
        session.enterBrowseMode() // addLiveText already opens editText; reset for a clean per-test begin()
        return (session, id)
    }

    /// Hosts the real overlay inside a genuinely key/visible window ، the
    /// ONLY configuration under which `resignFirstResponder()`
    /// synchronously fires `textViewDidEndEditing`. A view that never
    /// truly becomes first responder in a key window would not receive
    /// that callback at all, which would make every assertion below pass
    /// against BOTH the fixed and the broken code and prove nothing.
    private func makeHostedOverlay() -> (overlay: TextEditingOverlayView, window: UIWindow) {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 120)
        let overlay = TextEditingOverlayView(frame: frame)
        let window = UIWindow(frame: frame)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(overlay)
        window.makeKeyAndVisible()
        return (overlay, window)
    }

    @Test func cancelOnTheRealViewRestoresOriginalTextInsteadOfSilentlyCommitting() throws {
        let (session, id) = try makeTextNodeSession()
        let undoCountBefore = session.document.undoStack.undo.count
        let (overlay, window) = makeHostedOverlay()

        overlay.begin(session: session, nodeID: id, initialText: "ابتدائي")

        // CRITICAL anti-vacuous-pass assertion (do not remove): without
        // genuine first-responder status, `cancel()`'s own
        // `resignFirstResponder()` call below would not synchronously
        // invoke `textViewDidEndEditing`, and the exact bug this test
        // exists to catch could never reproduce, fixed or not.
        #expect(overlay.textView.isFirstResponder == true)

        // Simulates a keystroke. Mutating `.text` alone does NOT invoke
        // `UITextViewDelegate` callbacks (UIKit only calls those for
        // user-driven edits, not programmatic ones), so
        // `textViewDidChange(_:)` ، the same public delegate method a real
        // keystroke triggers ، is called directly to mirror the mutation
        // into the session exactly as typing would.
        overlay.textView.text = "تعديل ملغى"
        overlay.textViewDidChange(overlay.textView)

        overlay.cancel()

        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected liveText")
            return
        }
        #expect(node.text.string == "ابتدائي") // restored, NOT the mutated "تعديل ملغى" ، the bug's exact symptom would leave this mutated.
        #expect(session.mode == .browse)
        #expect(overlay.controller.isActive == false)
        #expect(session.document.undoStack.undo.count == undoCountBefore) // no stray undo entry left behind by the abandoned edit

        window.isHidden = true
    }

    /// Mirrors the test above: proves `commit()` genuinely DOES persist
    /// mutated text through the same real view, so the pair together
    /// demonstrate the two dismissal paths actually differ. Without this,
    /// a `cancel()` that (via some other, unrelated bug) never mirrored or
    /// committed ANYTHING would also make the test above pass trivially.
    @Test func commitOnTheRealViewPersistsTheMutatedText() throws {
        let (session, id) = try makeTextNodeSession()
        let (overlay, window) = makeHostedOverlay()

        overlay.begin(session: session, nodeID: id, initialText: "ابتدائي")
        #expect(overlay.textView.isFirstResponder == true)

        overlay.textView.text = "تم الحفظ"
        overlay.textViewDidChange(overlay.textView)

        overlay.commit()

        guard case .liveText(let node)? = session.scene.node(id: id) else {
            Issue.record("expected liveText")
            return
        }
        #expect(node.text.string == "تم الحفظ")
        #expect(session.mode == .browse)
        #expect(overlay.controller.isActive == false)

        window.isHidden = true
    }
}
#endif
