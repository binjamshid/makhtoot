import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 tasks 13/14, D-104/§4.8/D-201. The overlay LIFECYCLE
// STATE MACHINE ، coalesced text mirroring, commit, and cancel-with-full-
// unwind ، is implemented here as plain `@MainActor` logic with zero UIKit
// dependency, so it is directly unit-testable (this packet's gate: "undo
// coalescing per gesture type" explicitly includes the typing-burst case).
// The concrete `UITextView` (TextKit 2) host is a thin wrapper at the
// bottom of this file, guarded by `#if canImport(UIKit)`.
//
// D-201 rotation note: re-reading §4.8 closely, "normalizes to axis-
// aligned during editing... restores the node's original rotation on
// commit" describes the OVERLAY VIEW's own on-screen transform (it never
// applies the node's rotation) plus the engine-rendered node being HIDDEN
// while editing (§4.8: "hidden while the overlay is visible") ، not a
// mutation of the node's STORED `transform.rotation` in `MKScene`. Nothing
// here ever writes to `core.transform` during a text edit; only
// `text.string` changes. "Restores... on commit" is therefore automatic
// (the stored rotation was never touched) ، the real work is simply
// re-showing the engine-rendered layer, which is `MKCanvasRenderBridge`'s
// job once WS-07 exists to drive it.
@MainActor
public final class TextEditingOverlayController {
    public private(set) var isActive: Bool = false
    public private(set) var nodeID: MKNodeID?

    private var originalNode: MKNode?
    private var burstGenerationID: UUID?
    private var lastEditTime: TimeInterval = 0
    private var pushedUndoEntries: Int = 0

    /// §14.3: keystroke bursts coalesce within a 700 ms window.
    public static let burstWindow: TimeInterval = 0.7

    public init() {}

    /// Begins editing `nodeID` (must be `.liveText`/`.pathText`) ، enters
    /// `.editText` mode, snapshots the pre-edit node for cancel-restore,
    /// and hides the engine-rendered layer via `renderBridge` (once wired).
    public func begin(session: CanvasSession, nodeID: MKNodeID) {
        guard let node = session.scene.node(id: nodeID) else { return }
        switch node {
        case .liveText, .pathText: break
        default: return // D-104 only applies to text-bearing node kinds.
        }
        self.nodeID = nodeID
        originalNode = node
        burstGenerationID = nil
        pushedUndoEntries = 0
        isActive = true
        session.beginEditingText(nodeID: nodeID)
        // Opens the `MKUndoStack` gesture bracket for the WHOLE editing
        // session (not just one burst) ، `MKTextEditCommand`'s own
        // per-burst `coalescingKey` (rotated in `textDidChange` below
        // whenever the 700 ms window lapses) is what actually creates
        // burst boundaries; `MKUndoStack.perform` only coalesces AT ALL
        // when `gestureActive` is true, so this bracket must span every
        // burst in the session, not be re-opened per burst.
        session.beginGesture()
    }

    /// Mirrors a keystroke/IME commit into the node's stored text (D-104:
    /// "Every `textViewDidChange` mirrors the string into the node's
    /// `MKSourceText` through a *coalescing* editing command"). Callers
    /// (the UIKit wrapper below) must NOT call this while
    /// `textView.markedTextRange != nil` (§4.8: "IME/marked-text: ...
    /// mirroring is suspended ، marked text is never persisted").
    /// `now` is injectable for deterministic burst-window tests.
    public func textDidChange(session: CanvasSession, newText: String, now: TimeInterval = Date().timeIntervalSinceReferenceDate) {
        guard isActive, let nodeID, let currentNode = session.scene.node(id: nodeID) else { return }

        if burstGenerationID == nil || (now - lastEditTime) > Self.burstWindow {
            burstGenerationID = UUID()
        }
        lastEditTime = now
        guard let generationID = burstGenerationID else { return }

        let updatedNode: MKNode
        switch currentNode {
        case .liveText(var n):
            n.text.string = newText
            updatedNode = .liveText(n)
        case .pathText(var n):
            n.text.string = newText
            updatedNode = .pathText(n)
        default:
            return
        }

        let undoCountBefore = session.document.undoStack.undo.count
        try? session.perform(MKTextEditCommand(nodeID: nodeID, newNode: updatedNode, burstKey: "textEdit:\(nodeID):\(generationID)"))
        if session.document.undoStack.undo.count > undoCountBefore {
            pushedUndoEntries += 1
        }
    }

    /// Commit (tap-outside/Done, §4.8): every keystroke was already
    /// mirrored, so this simply ends the editing session ، the
    /// engine-rendered node becomes the sole visual again once
    /// `renderBridge` re-shows it.
    public func commit(session: CanvasSession) {
        guard isActive else { return }
        session.endGesture()
        session.renderBridge?.commitTransients()
        reset(session: session)
    }

    /// Cancel (Esc/cancel, §4.8: "restores pre-edit text"): unwinds every
    /// undo entry this editing session pushed so cancelling never leaves a
    /// stray, user-visible undo step behind, then defensively force-
    /// restores the original node if state ever drifted (should be a
    /// no-op in normal operation ، the unwind loop already gets there).
    public func cancel(session: CanvasSession) {
        guard isActive, let nodeID, let originalNode else { return }
        session.endGesture()
        for _ in 0..<pushedUndoEntries {
            try? session.undo()
        }
        if session.scene.node(id: nodeID) != originalNode {
            try? session.perform(MKReplaceNodeCommand(nodeID: nodeID, newNode: originalNode))
        }
        session.renderBridge?.commitTransients()
        reset(session: session)
    }

    private func reset(session: CanvasSession) {
        isActive = false
        nodeID = nil
        originalNode = nil
        burstGenerationID = nil
        pushedUndoEntries = 0
        session.enterBrowseMode()
    }
}

#if canImport(UIKit)
import UIKit

/// P3.3/Bug 14's palette + P6's shared caret-validity rule, namespaced and
/// `public` (not `internal`) specifically so the app target's SwiftUI
/// `TextInsertSheet` (P2.1's primary text-entry path, P6's cross-phase gap
/// fix ، see that file's header comment) can reuse the SAME mark table and
/// disabling rule `MKTashkeelAccessoryRow` (below, UIKit-only, cannot be
/// used directly from a SwiftUI sheet) already established, instead of
/// copy-pasting either.
public enum MKTashkeelInput {
    /// One tashkeel (diacritic) palette entry. `symbol` is the button's
    /// DISPLAY glyph ، a leading tatweel (ـ) makes a standalone combining
    /// mark visible on its own button, the same convention iOS's own
    /// Arabic keyboard uses to preview a bare mark. `insertedText` is the
    /// actual text inserted at the caret ، just the bare combining mark, no
    /// tatweel (the tatweel is display-only chrome, never written into the
    /// document).
    public struct Mark: Equatable, Sendable {
        public let insertedText: String
        public let symbol: String
        /// UX-7: catalog-extractable ، the SwiftUI consumer
        /// (`TextInsertSheet.tashkeelRow`) feeds this straight into
        /// `.accessibilityLabel(_:)`; the UIKit consumer
        /// (`MKTashkeelAccessoryRow` below) resolves it to a plain `String`
        /// at the one point it needs `UIAccessibilityElement
        /// .accessibilityLabel`'s `String?` type.
        public let accessibilityLabel: LocalizedStringResource

        public init(insertedText: String, symbol: String, accessibilityLabel: LocalizedStringResource) {
            self.insertedText = insertedText
            self.symbol = symbol
            self.accessibilityLabel = accessibilityLabel
        }
    }

    /// The eight standard Arabic harakat (short vowels + tanwin + shadda +
    /// sukun) ، the PRD's own scope for "add tashkeel" (Bug 14); extended
    /// marks (dagger alif, Quranic annotation marks, …) are out of this v1's
    /// scope, same "don't invent beyond what was asked" posture the asset
    /// category enum documents for itself.
    public static let palette: [Mark] = [
        Mark(insertedText: "\u{064E}", symbol: "ـَ", accessibilityLabel: "فتحة"),
        Mark(insertedText: "\u{064F}", symbol: "ـُ", accessibilityLabel: "ضمة"),
        Mark(insertedText: "\u{0650}", symbol: "ـِ", accessibilityLabel: "كسرة"),
        Mark(insertedText: "\u{0651}", symbol: "ـّ", accessibilityLabel: "شدة"),
        Mark(insertedText: "\u{0652}", symbol: "ـْ", accessibilityLabel: "سكون"),
        Mark(insertedText: "\u{064B}", symbol: "ـً", accessibilityLabel: "تنوين فتح"),
        Mark(insertedText: "\u{064C}", symbol: "ـٌ", accessibilityLabel: "تنوين ضم"),
        Mark(insertedText: "\u{064D}", symbol: "ـٍ", accessibilityLabel: "تنوين كسر"),
    ]

    /// R-7.5-adjacent risk note (PRD: "a combining mark with no base
    /// character renders a dotted circle"). Shared by `MKTashkeelAccessoryRow
    /// .setEnabled(_:)`'s caller (`TextEditingOverlayView
    /// .updateTashkeelAvailability()`) and the SwiftUI `TextInsertSheet`'s
    /// own caret-tracking, each of which extracts "the `Character`
    /// immediately before the caret" from its OWN text representation
    /// (`UITextView` vs. a SwiftUI `TextField`/`String` binding) before
    /// calling this ، only the predicate itself (representation-agnostic:
    /// takes a bare `Character`) is shared, per this phase's instruction to
    /// reuse "its caret-has-valid-base disabling rule."
    ///
    /// **Why this is a local heuristic, not `MKTextEngine
    /// .MKJoiningAnalyzer`:** `MKCanvas`'s `Package.swift` dependency list
    /// is `[MKFoundation, MKModel, MKRender, MKDesignSystem]` ، no
    /// `MKTextEngine` edge, and P6's own instruction is to keep it that way.
    /// This predicate covers the same practical rule (a combining mark
    /// needs a preceding join-capable Arabic letter, or tatweel, as its
    /// base) using `Unicode.Scalar.properties.isAlphabetic` on the grapheme
    /// immediately before the caret ، a `Character` for an already-marked
    /// base (e.g. "بَ") is ONE extended grapheme cluster whose
    /// `.unicodeScalars.first` is still the base letter, so this correctly
    /// allows stacking a second mark on an already-marked base too. It is
    /// intentionally NOT a shaping-correctness oracle (it does not
    /// distinguish medial/final/isolated joining forms the way
    /// `MKJoiningAnalyzer` does) ، only a "don't offer a mark with nothing
    /// to attach to" UX gate.
    public static func isValidBase(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        if scalar.value == 0x0640 { return true } // tatweel/kashida, a valid mark carrier.
        return scalar.properties.isAlphabetic
    }
}

/// A horizontally-scrolling row of tashkeel buttons, stacked ABOVE the
/// existing "تم" (Done) toolbar as a second row inside `inputAccessoryView`
/// (P3.3/Bug 14's preferred remedy: "a tashkeel palette as an input
/// accessory in the text overlay, inserting the diacritic at the caret").
/// Every button keeps a ≥44×44 pt hit target (repo convention) even though
/// its VISIBLE glyph is small.
@MainActor
final class MKTashkeelAccessoryRow: UIView {
    var onSelect: ((MKTashkeelInput.Mark) -> Void)?
    private var buttons: [UIButton] = []

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        backgroundColor = .secondarySystemBackground

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor),
        ])

        for mark in MKTashkeelInput.palette {
            let button = UIButton(type: .system)
            button.setTitle(mark.symbol, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 20)
            // UIKit's `accessibilityLabel` is `String?` ، resolve the
            // `LocalizedStringResource` explicitly rather than storing a
            // second, parallel `String` on `Mark`.
            button.accessibilityLabel = String(localized: mark.accessibilityLabel)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(mark) }, for: .touchUpInside)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: 44) }

    /// R-7.5-adjacent risk note (PRD: "a combining mark with no base
    /// character renders a dotted circle"): every button is disabled ،
    /// never silently offered ، when the caret has no valid base to
    /// attach to (`MKTashkeelInput.isValidBase(_:)`'s doc comment explains
    /// why that check is a local heuristic here rather
    /// than a call into `MKTextEngine.MKJoiningAnalyzer`). The disabled
    /// state states WHY via `accessibilityHint`, not just a silent
    /// grey-out (repo convention: "every disabled control must state why").
    func setEnabled(_ enabled: Bool) {
        for button in buttons {
            button.isEnabled = enabled
            button.alpha = enabled ? 1 : 0.35
            button.accessibilityHint = enabled ? nil : Self.disabledHint
        }
    }

    private static var disabledHint: String {
        // Latin gloss: place the cursor after an Arabic letter to add a diacritic mark
        "ضع المؤشر بعد حرف عربي لإضافة حركة"
    }
}

/// TextKit-2 `UITextView` host (D-104). Zoom-matched via `overlay.transform`
/// (task 13); deliberately never applies the node's rotation (D-201, see
/// this file's header note) ، callers position `frame` in axis-aligned
/// canvas coordinates and apply only the canvas's zoom scale, never the
/// node's own rotation, when converting to view space.
@MainActor
public final class TextEditingOverlayView: UIView {
    public let textView: UITextView
    public let controller = TextEditingOverlayController()
    private weak var session: CanvasSession?
    /// P3.3/Bug 14.
    private let tashkeelRow = MKTashkeelAccessoryRow()

    /// P2.5/Bug 5 remedy 3: fired exactly once, synchronously, at the end
    /// of a deliberate `commit()` or `cancel()` ، the owner (app layer) is
    /// expected to tear the overlay down (remove from superview, drop its
    /// strong reference) from this callback instead of waiting on a poll.
    /// This is what makes dismissal deterministic rather than up-to-100 ms
    /// late (previously the ONLY teardown path was `EditorViewModel`'s
    /// 100 ms `startModePolling` noticing `session.mode` left `.editText`).
    public var onFinished: (() -> Void)?

    /// P2.5/Bug 5 fix: guards the re-entrancy that made `cancel()` silently
    /// behave like `commit()`. `resignFirstResponder()` below synchronously
    /// invokes `UITextViewDelegate.textViewDidEndEditing`, which (correctly,
    /// for the "lost first responder for some OTHER reason" case) calls
    /// `commit()` ، but when `commit()`/`cancel()` are themselves the ones
    /// calling `resignFirstResponder()`, that re-entrant call must no-op so
    /// the OUTER call (the one that actually knows whether this is a commit
    /// or a cancel) is the one that runs `controller.commit(session:)` /
    /// `controller.cancel(session:)`, in the right order. Before this flag
    /// existed, `cancel()` called `resignFirstResponder()` first, which ran
    /// the re-entrant `commit()` to completion (flipping
    /// `controller.isActive` to `false`) BEFORE `cancel()`'s own
    /// `controller.cancel(session:)` call ever ran ، that call then hit
    /// `guard isActive` and returned immediately, so `cancel()` silently
    /// committed instead of restoring. Set to `true` BEFORE
    /// `resignFirstResponder()` in both `commit()` and `cancel()` ، never
    /// reset, since this view is one-shot per editing session (a new
    /// session gets a new `TextEditingOverlayView` instance, mirroring
    /// `TextEditingOverlayController.isActive`'s own one-shot-per-session
    /// contract).
    private var isFinishing = false

    public override init(frame: CGRect) {
        // TextKit 2: the designated initializer with no explicit
        // `NSTextContainer`/`NSLayoutManager` opts into TextKit 2 ، never
        // touch `.layoutManager` (forces TextKit 1 fallback per §4.8).
        textView = UITextView(usingTextLayoutManager: true)
        super.init(frame: frame)
        textView.backgroundColor = .clear
        textView.frame = bounds
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(textView)
        textView.delegate = self

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: bounds.width, height: 44))
        let doneButton = UIBarButtonItem(title: "تم", style: .done, target: self, action: #selector(handleDoneTap))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [flex, doneButton]

        // Bug 5 remedy 1 (part two): swipe-down on the accessory toolbar
        // also dismisses (commits) the overlay ، a discoverable, low-risk
        // gesture on the one piece of overlay chrome that's guaranteed to
        // sit just above the keyboard, regardless of canvas zoom/scroll.
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleToolbarSwipeDown))
        swipeDown.direction = .down
        toolbar.addGestureRecognizer(swipeDown)

        // P3.3/Bug 14: the tashkeel palette stacks ABOVE the existing "تم"
        // toolbar as a second accessory row ، `UIStackView` here is purely
        // a layout container (never assigned as `inputAccessoryView`
        // itself needs autolayout-driven height, which `UIStackView`
        // gives for free from its two fixed-height arranged subviews).
        tashkeelRow.onSelect = { [weak self] mark in self?.insertTashkeel(mark) }
        tashkeelRow.setEnabled(false) // no caret context yet; `begin(...)` refreshes it.
        let accessoryStack = UIStackView(arrangedSubviews: [tashkeelRow, toolbar])
        accessoryStack.axis = .vertical
        accessoryStack.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 88)
        accessoryStack.autoresizingMask = [.flexibleWidth]
        textView.inputAccessoryView = accessoryStack
    }

    /// Inserts `mark.insertedText` at the caret via `UITextView
    /// .replace(_:withText:)` ، the SAME API a system keyboard uses for a
    /// typed character, which synchronously triggers `UITextViewDelegate
    /// .textViewDidChange(_:)` below exactly like a keystroke would. This
    /// is deliberate: it means a tashkeel insertion reuses the EXACT same
    /// mirroring/coalescing/undo path (`controller.textDidChange`) every
    /// other typed character already takes ، no parallel insert code, so
    /// an inserted mark survives shaping/arrange-derivation/export the
    /// same way any other character in the string already does (repo
    /// convention: "marks must survive shaping, arrange derivation and
    /// export").
    private func insertTashkeel(_ mark: MKTashkeelInput.Mark) {
        guard let selectedRange = textView.selectedTextRange else { return }
        textView.replace(selectedRange, withText: mark.insertedText)
        updateTashkeelAvailability()
    }

    /// R-7.5-adjacent risk note (PRD: "a combining mark with no base
    /// character renders a dotted circle"). Re-evaluated on every caret
    /// move (`textViewDidChangeSelection`) and every text change
    /// (`textViewDidChange`). Extracts "the `Character` immediately before
    /// the caret" from `UITextView`'s own API, then defers the actual
    /// valid-base judgment to the shared `MKTashkeelInput.isValidBase(_:)`
    /// rule (see that type's doc comment for why it's a local heuristic,
    /// not `MKJoiningAnalyzer`) ، P6 extracted that predicate out of this
    /// type so the SwiftUI `TextInsertSheet` (app target) can reuse the
    /// identical rule against its own `String`-binding caret tracking
    /// instead of duplicating it.
    private func updateTashkeelAvailability() {
        guard let selectedRange = textView.selectedTextRange else {
            tashkeelRow.setEnabled(false)
            return
        }
        let caretOffset = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
        let full = textView.text ?? ""
        guard caretOffset > 0,
              let utf16Index = full.utf16.index(full.utf16.startIndex, offsetBy: caretOffset, limitedBy: full.utf16.endIndex),
              let stringIndex = utf16Index.samePosition(in: full),
              stringIndex > full.startIndex
        else {
            tashkeelRow.setEnabled(false)
            return
        }
        let previousCharacter = full[full.index(before: stringIndex)]
        tashkeelRow.setEnabled(MKTashkeelInput.isValidBase(previousCharacter))
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Presents the overlay over `nodeID`, matching `MKTextStyle` metrics
    /// (font/kerning/line-height are applied by the caller via
    /// `configure(style:)` since resolving `MKFontRef` → a concrete
    /// `UIFont` is `MKFonts`/WS-09 territory this module doesn't own).
    public func begin(session: CanvasSession, nodeID: MKNodeID, initialText: String) {
        self.session = session
        controller.begin(session: session, nodeID: nodeID)
        textView.text = initialText
        // `UITextInput.baseWritingDirection(for:in:)` is a METHOD, not a
        // settable property ، real API to force RTL base direction on a
        // `UITextView` is `semanticContentAttribute` (drives the text
        // input system's writing-direction resolution) plus
        // `NSParagraphStyle.baseWritingDirection` in `typingAttributes`
        // (so newly-typed runs inherit RTL, matching D-109's default).
        textView.semanticContentAttribute = .forceRightToLeft
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = .rightToLeft
        paragraphStyle.alignment = .right
        textView.typingAttributes = [.paragraphStyle: paragraphStyle]
        textView.textAlignment = .right
        textView.becomeFirstResponder()
        updateTashkeelAvailability()
    }

    public func commit() {
        guard !isFinishing, let session else { return }
        isFinishing = true
        textView.resignFirstResponder() // re-entrant `textViewDidEndEditing` no-ops, see `isFinishing`.
        controller.commit(session: session)
        onFinished?()
    }

    public func cancel() {
        guard !isFinishing, let session else { return }
        isFinishing = true
        textView.resignFirstResponder() // re-entrant `textViewDidEndEditing` no-ops, see `isFinishing`.
        controller.cancel(session: session)
        onFinished?()
    }

    @objc private func handleDoneTap() {
        commit()
    }

    /// §4.8: unlike `handleDoneTap()`/tap-outside (both explicit,
    /// low-accident-rate confirmations), a swipe is easy to trigger by
    /// accident mid-IME-composition ، skip it while `markedTextRange` is
    /// set rather than yanking an in-progress composition out from under
    /// the user (same "marked text is never persisted" spirit
    /// `textViewDidChange` already guards, just applied at the dismissal
    /// trigger here rather than inside `commit()` itself, so an EXTERNAL
    /// loss of first responder — `textViewDidEndEditing` below — always
    /// still finishes the session regardless of marked-text state).
    @objc private func handleToolbarSwipeDown() {
        guard textView.markedTextRange == nil else { return }
        commit()
    }
}

extension TextEditingOverlayView: UITextViewDelegate {
    public func textViewDidChange(_ textView: UITextView) {
        // P3.3/Bug 14: re-evaluated on every text change too (typing moves
        // the caret past whatever character was just inserted/deleted, not
        // only on an explicit selection change).
        updateTashkeelAvailability()
        guard let session else { return }
        // §4.8: suspend mirroring while IME marked text is in flight ،
        // marked text is never persisted.
        guard textView.markedTextRange == nil else { return }
        controller.textDidChange(session: session, newText: textView.text ?? "")
    }

    /// P3.3/Bug 14: refreshes the tashkeel palette's enabled state whenever
    /// the caret moves (tap, arrow keys, selection drag), independent of
    /// any text change.
    public func textViewDidChangeSelection(_ textView: UITextView) {
        updateTashkeelAvailability()
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        // `isFinishing` is only ever `true` here when THIS delegate call is
        // the re-entrant side effect of `commit()`/`cancel()`'s own
        // `resignFirstResponder()` call above ، the outer call already owns
        // finishing the session (in the correct order), so this re-entrant
        // invocation must no-op. When `isFinishing` is `false`, first
        // responder was lost for an EXTERNAL reason (another field became
        // first responder, app backgrounding, etc.) and this is the only
        // place that will ever hear about it, so it must still commit.
        guard !isFinishing else { return }
        commit()
    }
}
#endif
