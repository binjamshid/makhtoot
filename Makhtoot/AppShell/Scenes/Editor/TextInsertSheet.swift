import MKCanvas
import MKDesignSystem
import MKFonts
import MKModel
import SwiftUI

/// P2.1 insert-time text dialog ، REPLACES the old "add text field" flow
/// (blank node inserted immediately, keyboard opens inline on canvas,
/// `EditorViewModel.addLiveTextAtCenter()`, still kept for the DEBUG/E2E
/// hooks that call it directly). Presented per this repo's Pattern B
/// (trigger and presenter are the SAME view, `ToolRailView`'s local
/// `@State private var showTextInsertSheet`, exactly like that file's own
/// pre-existing `showFontSettings` ، see `ToolRailView.swift`), never
/// through `EditorViewModel.presentedPanel`/`EditorPanel` (Pattern A is for
/// when trigger and presenter are different views, which is not the case
/// here).
///
/// Font picking REUSES `FontBrowserSheet` (no second font UI). The preview
/// below is genuinely live — every field is a plain `@State` the preview
/// reads directly, no separate "Preview" button (the reference app has
/// one; this master plan explicitly lists that as a "do not take").
///
/// Cancel needs no unwind logic: nothing is written to `session` until
/// "إدراج" (Insert) runs `EditorViewModel.insertTextFromSheet(...)` ، see
/// that method's own doc comment for why that makes Cancel a correct-by-
/// construction "genuine discard," without routing through
/// `TextEditingOverlayController.cancel(session:)` (P2.5's just-fixed
/// restore-on-cancel path, which exists for EDITING an already-committed
/// node, not for a dialog that has not committed anything yet).
struct TextInsertSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let viewModel: EditorViewModel
    let fontRegistry: MKFontRegistry

    @State private var text: String = ""
    /// P6 cross-phase gap fix: caret tracking for the tashkeel palette
    /// below (`tashkeelRow`) ، `TextEditor(text:selection:)` is iOS 18+
    /// only (D-100's own floor, so no availability gate needed). Before
    /// this pass, tashkeel was reachable ONLY by inserting plain text here
    /// and then re-opening the node to reach `MKTashkeelAccessoryRow`
    /// inside `TextEditingOverlayView` (P2.1 made THIS sheet the primary
    /// text-entry path but never entered `.editText` mode, so that overlay
    /// accessory was never shown for newly-typed text).
    @State private var selection: TextSelection?
    @State private var fontRef: MKFontRef = .systemFallback
    @State private var pointSize: Double
    @State private var lineHeightMultiple: Double = 1.2
    @State private var alignment: EditorViewModel.TextInsertAlignment = .right
    @State private var splitBySpaces: Bool = false
    @State private var groupLines: Bool = false
    @State private var showFontBrowser: Bool = false

    // UX-2: the tashkeel palette's glyph size scales with Dynamic Type ،
    // the surrounding `.frame(minWidth: 44, minHeight: 44)` above already
    // has room to grow (it's a `min`, not a fixed frame).
    @ScaledMetric(relativeTo: .body) private var tashkeelGlyphSize: CGFloat = 20

    init(viewModel: EditorViewModel, fontRegistry: MKFontRegistry) {
        self.viewModel = viewModel
        self.fontRegistry = fontRegistry
        // P2.6: canvas-scaled initial size, not `MKTextStyle`'s own
        // text-editor-sized `36` default ، see
        // `EditorViewModel.defaultInsertPointSize(canvasSize:)`'s doc
        // comment.
        _pointSize = State(initialValue: EditorViewModel.defaultInsertPointSize(canvasSize: viewModel.session.scene.canvas.size))
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text, selection: $selection)
                        .frame(minHeight: 96)
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                    // P6 cross-phase gap fix: the same tashkeel palette
                    // `MKTashkeelAccessoryRow` shows inside the text-editing
                    // OVERLAY (P3.3), now also reachable from THIS, the
                    // primary text-entry sheet (P2.1) ، reuses
                    // `MKTashkeelInput.palette`/`.isValidBase(_:)` rather
                    // than a second, duplicated table/rule.
                    tashkeelRow
                } header: {
                    Text(textFieldLabel)
                } footer: {
                    Text(textFieldFooter)
                }

                Section {
                    previewRow
                } header: {
                    Text(previewLabel)
                }

                Section {
                    fontRow
                    sizeRow
                    MKSlider(label: lineSpacingLabel, value: $lineHeightMultiple, in: 0.8...2.5)
                    alignmentRow
                } header: {
                    Text(styleLabel)
                }

                Section {
                    Toggle(splitBySpacesLabel, isOn: $splitBySpaces)
                    Toggle(groupLinesLabel, isOn: $groupLines)
                        .disabled(!splitBySpaces)
                        .opacity(splitBySpaces ? 1 : 0.4)
                } header: {
                    Text(layoutLabel)
                } footer: {
                    Text(splitBySpaces ? splitOnFooter : splitOffFooter)
                }
            }
            .navigationTitle(titleLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelLabel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(insertLabel) { insert() }
                        .disabled(trimmedText.isEmpty)
                        .bold()
                }
            }
        }
        .sheet(isPresented: $showFontBrowser) {
            FontBrowserSheet(
                fontRegistry: fontRegistry,
                currentFontID: fontRef.fontID,
                sampleText: trimmedText
            ) { ref in
                fontRef = ref
            }
        }
    }

    private func insert() {
        guard !trimmedText.isEmpty else { return }
        let style = MKTextStyle(
            font: fontRef,
            pointSize: pointSize,
            lineHeightMultiple: lineHeightMultiple,
            baseDirection: .rightToLeft
        )
        viewModel.insertTextFromSheet(
            fullText: text,
            style: style,
            splitBySpaces: splitBySpaces,
            groupLines: groupLines,
            alignment: alignment
        )
        dismiss()
    }

    // MARK: - Rows

    private var fontRow: some View {
        Button {
            showFontBrowser = true
        } label: {
            HStack {
                Text(fontLabel)
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(fontRef.postScriptName)
                    .foregroundStyle(theme.inkMuted)
                Image(systemName: "chevron.forward")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    private var sizeRow: some View {
        HStack {
            Text(sizeLabel)
                .foregroundStyle(theme.ink)
            Spacer()
            Text("\(Int(pointSize)) pt")
                .foregroundStyle(theme.inkMuted)
                .frame(minWidth: 48, alignment: .trailing)
            Button {
                pointSize = max(8, pointSize - 4)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(theme.inkMuted)
            }
            .buttonStyle(.plain)
            Button {
                pointSize = min(999, pointSize + 4)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(theme.inkMuted)
            }
            .buttonStyle(.plain)
        }
    }

    private var alignmentRow: some View {
        Picker(alignmentLabel, selection: $alignment) {
            Text(alignRightLabel).tag(EditorViewModel.TextInsertAlignment.right)
            Text(alignCenterLabel).tag(EditorViewModel.TextInsertAlignment.center)
            Text(alignLeftLabel).tag(EditorViewModel.TextInsertAlignment.left)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tashkeel palette (P6 cross-phase gap fix)

    /// The current selection's LOWER bound (caret position for a plain
    /// insertion point, or the start of a real selection) as a character
    /// offset into `text`, or `nil` before the field has ever gained focus/
    /// a tracked selection. Deliberately expressed as an `Int` OFFSET
    /// rather than held as a raw `String.Index` across a later mutation
    /// (`insertTashkeel(_:)` below performs a `text.replaceSubrange`) ،
    /// `String.Index` values are only valid for the exact string state they
    /// were derived from, and re-deriving a fresh index via
    /// `text.index(startIndex, offsetBy:)` from a plain `Int` on each use
    /// sidesteps that entirely, at the cost of an O(n) walk that is
    /// irrelevant at this sheet's short-text scale.
    private var caretLowerOffset: Int? {
        guard let selection, case .selection(let range) = selection.indices else { return nil }
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }

    /// Mirrors `MKTashkeelAccessoryRow`'s own "disabled when the caret has
    /// no valid base" rule (`TextEditingOverlayView
    /// .updateTashkeelAvailability()`), against THIS sheet's own
    /// `String`-binding caret tracking instead of a `UITextView` selection.
    private var canInsertTashkeel: Bool {
        guard let offset = caretLowerOffset, offset > 0 else { return false }
        let previousCharacter = text[text.index(text.startIndex, offsetBy: offset - 1)]
        return MKTashkeelInput.isValidBase(previousCharacter)
    }

    /// Inserts `mark.insertedText` at the tracked caret/selection (replacing
    /// any real selection, matching `UITextView.replace(_:withText:)`'s own
    /// semantics `TextEditingOverlayView.insertTashkeel(_:)` relies on), or
    /// appends at the end when no selection has been tracked yet (the field
    /// has never gained focus in this presentation) ، never a silent no-op,
    /// matching every other button in this sheet.
    ///
    /// Caret repositioning is done by SUFFIX character count, not by adding
    /// `mark.insertedText.count` to the old offset: a bare combining mark's
    /// own `String` is one `Character` in isolation, but Swift re-segments
    /// grapheme clusters across the insertion boundary ، inserted right
    /// after a base letter, the mark MERGES into that base's existing
    /// `Character` (e.g. "ب" + "\u{064E}" become the single grapheme "بَ"),
    /// so the string's total `count` does not always grow by
    /// `mark.insertedText.count`. Measuring "how many characters remain
    /// AFTER the insertion point" before mutating, and subtracting that from
    /// the new total count afterward, lands the caret correctly regardless
    /// of how the boundary re-segments.
    private func insertTashkeel(_ mark: MKTashkeelInput.Mark) {
        guard let selection, case .selection(let range) = selection.indices else {
            text.append(mark.insertedText)
            return
        }
        let suffixCount = text.distance(from: range.upperBound, to: text.endIndex)
        let lowerOffset = text.distance(from: text.startIndex, to: range.lowerBound)
        let upperOffset = text.distance(from: text.startIndex, to: range.upperBound)
        let lowerIndex = text.index(text.startIndex, offsetBy: lowerOffset)
        let upperIndex = text.index(text.startIndex, offsetBy: upperOffset)
        text.replaceSubrange(lowerIndex..<upperIndex, with: mark.insertedText)
        let newOffset = max(0, text.count - suffixCount)
        self.selection = TextSelection(insertionPoint: text.index(text.startIndex, offsetBy: newOffset))
    }

    private var tashkeelRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.xs) {
                ForEach(MKTashkeelInput.palette, id: \.insertedText) { mark in
                    Button {
                        insertTashkeel(mark)
                    } label: {
                        Text(mark.symbol)
                            .font(.system(size: tashkeelGlyphSize))
                            .frame(minWidth: 44, minHeight: 44)
                            .foregroundStyle(canInsertTashkeel ? theme.ink : theme.inkMuted)
                            .background(theme.surfaceMuted, in: RoundedRectangle(cornerRadius: theme.radius.button, style: theme.radius.style))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canInsertTashkeel)
                    .accessibilityLabel(mark.accessibilityLabel)
                    .accessibilityHint(canInsertTashkeel ? "" : tashkeelDisabledHint)
                }
            }
            .padding(.vertical, theme.spacing.xs)
        }
    }

    // MARK: - Live preview

    /// Genuinely live: every value read here is a plain `@State` this
    /// view already owns, so SwiftUI re-renders it on every keystroke/
    /// stepper tap/picker change with no explicit "refresh" action of any
    /// kind. Font size is CAPPED for on-screen legibility inside the sheet
    /// (the real `pointSize` is often canvas-scaled into the hundreds,
    /// P2.6) ، the same "fixed, legible sample size regardless of the
    /// real value" precedent `FontBrowserSheet.fontRow`'s own 18pt sample
    /// already establishes, just proportionally capped instead of fixed
    /// so a genuinely tiny/huge choice still reads as smaller/larger.
    private var previewRow: some View {
        let sample = trimmedText.isEmpty ? previewPlaceholder : text
        let lines = sample.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let cappedSize = min(CGFloat(pointSize), 40)
        // `TextInsertAlignment` is canvas-space right/center/left (see its
        // own doc comment) ، under this app's ambient RTL layout direction,
        // SwiftUI `.leading` already resolves to the visual RIGHT and
        // `.trailing` to the visual LEFT, so that's the correct mapping
        // here (not the reverse).
        let frameAlignment: Alignment = {
            switch alignment {
            case .right: return .leading
            case .left: return .trailing
            case .center: return .center
            }
        }()
        return VStack(alignment: .trailing, spacing: cappedSize * (lineHeightMultiple - 1) + theme.spacing.xs) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.custom(fontRef.postScriptName, size: cappedSize))
                    .foregroundStyle(trimmedText.isEmpty ? theme.inkMuted : theme.ink)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(.vertical, theme.spacing.xs)
    }

    // MARK: - Strings

    private var titleLabel: String {
        // Latin gloss: insert text
        "إدراج نص"
    }
    private var textFieldLabel: String {
        // Latin gloss: the text
        "النص"
    }
    private var textFieldFooter: String {
        // Latin gloss: each new line becomes a separate line on the canvas
        "كل سطر جديد يصبح سطرًا مستقلًا على اللوحة"
    }
    private var tashkeelDisabledHint: String {
        // Latin gloss: place the cursor after an Arabic letter to add a diacritic mark
        "ضع المؤشر بعد حرف عربي لإضافة حركة"
    }
    private var previewLabel: String {
        // Latin gloss: preview
        "معاينة"
    }
    private var previewPlaceholder: String {
        // Latin gloss: your text here
        "نصك هنا"
    }
    private var styleLabel: String {
        // Latin gloss: style
        "التنسيق"
    }
    private var fontLabel: String {
        // Latin gloss: font
        "الخط"
    }
    private var sizeLabel: String {
        // Latin gloss: size
        "الحجم"
    }
    private var lineSpacingLabel: String {
        // Latin gloss: line spacing
        "تباعد الأسطر"
    }
    private var alignmentLabel: String {
        // Latin gloss: alignment
        "المحاذاة"
    }
    private var alignRightLabel: String {
        // Latin gloss: right
        "يمين"
    }
    private var alignCenterLabel: String {
        // Latin gloss: center
        "توسيط"
    }
    private var alignLeftLabel: String {
        // Latin gloss: left
        "يسار"
    }
    private var layoutLabel: String {
        // Latin gloss: layout
        "التخطيط"
    }
    private var splitBySpacesLabel: String {
        // Latin gloss: split text by spaces
        "تقسيم النص حسب المسافات"
    }
    private var splitOnFooter: String {
        // Latin gloss: each word becomes a separate, independently movable object
        "تصبح كل كلمة عنصرًا مستقلًا يمكن تحريكه بشكل منفصل"
    }
    private var splitOffFooter: String {
        // Latin gloss: the text is inserted as a single object per line
        "يُدرج النص كعنصر واحد لكل سطر"
    }
    private var groupLinesLabel: String {
        // Latin gloss: group lines
        "تجميع الأسطر"
    }
    private var cancelLabel: String {
        // Latin gloss: cancel
        "إلغاء"
    }
    private var insertLabel: String {
        // Latin gloss: insert
        "إدراج"
    }
}
