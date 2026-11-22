import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

#if canImport(UIKit)
import UIKit
#endif

// UX-4 (AUDIT_2026-07-28.md): "zero hits for `UIImpactFeedbackGenerator`/
// `UINotificationFeedbackGenerator`/`.sensoryFeedback` across the whole
// codebase... in a canvas app the finger covers the object being
// manipulated, which makes haptics the primary confirmation channel."
// This suite checks the two production trigger points from Wave 1 work item 1.1:
// `GestureCoordinator`'s selection-changed haptic and
// `GuideRenderer`'s snap-engage haptic, both driven through a small
// injectable spy (`MKSelectionFeedbackGenerating`/`MKImpactFeedbackGenerating`)
// rather than a live UIKit haptics engine, matching the "fires exactly
// once per selection change / snap-engage transition" spec — never once
// per redraw/frame while the underlying state hasn't actually changed.
@MainActor
@Suite("MKCanvas haptics (UX-4)")
struct MKCanvasHapticsTests {
    // MARK: - GuideRenderer snap-engage/disengage
    //
    // Cross-platform: `GuideRenderer`'s engaged/disengaged edge-detection
    // logic has no UIKit dependency of its own (only the CONCRETE
    // `UIImpactFeedbackGenerator` default does, guarded separately in that
    // file) ، these tests run under a plain `swift test --no-parallel` on
    // the macOS host same as everything else in this target.

    private final class SpyImpactFeedbackGenerator: MKImpactFeedbackGenerating {
        private(set) var fireCount = 0
        func impactOccurred() { fireCount += 1 }
    }

    private static func guide(position: CGFloat = 10) -> MKSnapGuide {
        MKSnapGuide(axis: .vertical, position: position, extentStart: 0, extentEnd: 100)
    }

    @Test func firesExactlyOnceOnNotEngagedToEngagedTransition() {
        let renderer = GuideRenderer()
        let spy = SpyImpactFeedbackGenerator()
        renderer.impactFeedbackGenerator = spy

        // Not engaged (no guides): no fire.
        renderer.update(guides: [], zoomScale: 1)
        #expect(spy.fireCount == 0)

        // Not-engaged → engaged: fires once.
        renderer.update(guides: [Self.guide()], zoomScale: 1)
        #expect(spy.fireCount == 1)
    }

    @Test func doesNotRefireWhileStillEngagedAcrossMultipleRedraws() {
        let renderer = GuideRenderer()
        let spy = SpyImpactFeedbackGenerator()
        renderer.impactFeedbackGenerator = spy

        renderer.update(guides: [Self.guide()], zoomScale: 1)
        #expect(spy.fireCount == 1)

        // Still engaged (guide count/position changes, e.g. a drag
        // continuing to snap against a different candidate) — every other
        // production call site redraws on nearly every frame while
        // dragging; none of that is a new "engage" event.
        renderer.update(guides: [Self.guide(position: 20)], zoomScale: 1)
        renderer.update(guides: [Self.guide(position: 20), Self.guide(position: 40)], zoomScale: 2)
        #expect(spy.fireCount == 1)
    }

    @Test func doesNotFireOnDisengage() {
        let renderer = GuideRenderer()
        let spy = SpyImpactFeedbackGenerator()
        renderer.impactFeedbackGenerator = spy

        renderer.update(guides: [Self.guide()], zoomScale: 1)
        #expect(spy.fireCount == 1)

        // Engaged → not-engaged (guides array goes empty): no fire, only
        // engage transitions are a confirmation-worthy event.
        renderer.update(guides: [], zoomScale: 1)
        #expect(spy.fireCount == 1)
    }

    @Test func reengagingAfterADisengageFiresAgain() {
        let renderer = GuideRenderer()
        let spy = SpyImpactFeedbackGenerator()
        renderer.impactFeedbackGenerator = spy

        renderer.update(guides: [Self.guide()], zoomScale: 1)
        #expect(spy.fireCount == 1)
        renderer.update(guides: [], zoomScale: 1)
        #expect(spy.fireCount == 1)
        renderer.update(guides: [Self.guide()], zoomScale: 1)
        #expect(spy.fireCount == 2)
    }

    @Test func clearResetsEngagedStateSoTheNextUpdateFiresAgain() {
        let renderer = GuideRenderer()
        let spy = SpyImpactFeedbackGenerator()
        renderer.impactFeedbackGenerator = spy

        renderer.update(guides: [Self.guide()], zoomScale: 1)
        #expect(spy.fireCount == 1)

        renderer.clear()
        renderer.update(guides: [Self.guide()], zoomScale: 1)
        #expect(spy.fireCount == 2)
    }

    #if canImport(UIKit)
    // MARK: - GestureCoordinator selection-changed
    //
    // UIKit-only: `GestureCoordinator` is entirely `#if canImport(UIKit)`-
    // gated in its own source file and so does not exist under a plain
    // macOS `swift build`/`swift test` host at all (confirmed: zero prior
    // test coverage anywhere in this target for the same reason). This
    // block therefore does not run as part of this repo's
    // `swift test --no-parallel` gate — it exists so the contract is still
    // verified under a real iOS test run, the same "this environment
    // limitation" acknowledged elsewhere in this codebase's own test
    // suites (e.g. the Arrange Mode/Path Text DEBUG-hook drives).

    private final class SpySelectionFeedbackGenerator: MKSelectionFeedbackGenerating {
        private(set) var fireCount = 0
        func selectionChanged() { fireCount += 1 }
    }

    @Test func selectionHapticFiresExactlyOnceWhenSelectionActuallyChanges() throws {
        let session = try CanvasTestSupport.makeSession()
        let nodeID = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 100, y: 100))
        let hostView = UIView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let coordinator = GestureCoordinator(session: session, hostView: hostView)
        let spy = SpySelectionFeedbackGenerator()
        coordinator.selectionFeedbackGenerator = spy

        // `updateHandleResize`/`endHandleResize`/etc. route through the
        // SAME `notifySelectionChromeNeedsUpdate()` every tap/pan/long-
        // press handler in `GestureCoordinator` does (see that method's
        // own doc comment) ، calling one directly, repeatedly, is a
        // headless-safe way to exercise the shared haptic gate without a
        // live gesture recognizer/touch delivery pipeline.
        coordinator.updateHandleResize(worldDelta: .zero, fromCenter: false, aspectLocked: nil)
        coordinator.updateHandleResize(worldDelta: CGPoint(x: 3, y: 0), fromCenter: false, aspectLocked: nil)
        #expect(spy.fireCount == 0, "selection never changed (still whatever it started as) — must not fire")

        session.setSelection([nodeID])
        coordinator.updateHandleResize(worldDelta: .zero, fromCenter: false, aspectLocked: nil)
        #expect(spy.fireCount == 1, "a genuine selection change must fire exactly once")

        // Repeat notifications with the SAME selection (e.g. successive
        // `.changed` frames of one drag) must not refire.
        coordinator.updateHandleResize(worldDelta: CGPoint(x: 5, y: 0), fromCenter: false, aspectLocked: nil)
        coordinator.updateHandleResize(worldDelta: CGPoint(x: 8, y: 2), fromCenter: false, aspectLocked: nil)
        #expect(spy.fireCount == 1)

        // Deselecting is itself a selection change and fires once more.
        session.setSelection([])
        coordinator.updateHandleResize(worldDelta: .zero, fromCenter: false, aspectLocked: nil)
        #expect(spy.fireCount == 2)
    }
    #endif
}
