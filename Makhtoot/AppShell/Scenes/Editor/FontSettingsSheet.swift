import MKCanvas
import MKColor
import MKDesignSystem
import MKFonts
import MKFoundation
import MKModel
import SwiftUI
import UIKit

/// Font settings sheet — opened from the أء button in the tool rail.
/// Five sections: size, traits (B/I/U/S), text color, highlight color, font browser.
struct FontSettingsSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let inspector: InspectorModel
    let fontRegistry: MKFontRegistry
    /// The selected text node's current text, shown as the sample in the font browser.
    let sampleText: String

    @State private var showFontBrowser = false
    @State private var showTextColorPicker = false
    @State private var showHighlightColorPicker = false
    /// P7.3 (Bug 12 relocated): opens `FontManagementView` (Settings →
    /// الخطوط) for system-wide install/uninstall ، no longer this sheet's
    /// own responsibility, see the "Font management deep link" section
    /// below.
    @State private var showsFontManagement = false
    /// Bold/italic predicates rewrite: `MKFontRegistry` is an `actor`, but
    /// `boldSupported`/`italicSupported` below are synchronous computed
    /// properties (read straight from `body`). This snapshots the CURRENT
    /// font's catalog record into plain `@State` from a `.task(id:)` keyed
    /// on `currentFontID`, so it re-loads whenever the selection's font
    /// changes, and the two predicates below can read it synchronously ،
    /// same pattern as `FontBrowserSheet`'s own `.task { records = await
    /// fontRegistry.records() }`.
    @State private var selectedFontRecord: MKFontRecord?

    private let sizePresets: [Double] = [9, 12, 14, 16, 18, 24, 36, 48, 60, 72, 96, 144, 200]

    // UX-2: fixed-size icon/glyph sites scale with Dynamic Type below,
    // relative to `.body` unless noted otherwise. Grouped by base size
    // where several sites share one (eyedropper/favourite star both start
    // at 18 pt), matching this sheet's own existing visual sizing.
    @ScaledMetric(relativeTo: .callout) private var traitGlyphSize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var clearHighlightIconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var colorToolIconSize: CGFloat = 18

    private var currentPointSize: Double {
        if case .uniform(let s) = inspector.pointSizeValue { return s }
        return 36
    }

    private var currentFontID: MKFontID? {
        if case .uniform(let ref) = inspector.fontRefValue { return ref.fontID }
        return nil
    }

    private var isBold: Bool {
        if case .uniform(let v) = inspector.isBoldValue { return v }
        return false
    }

    private var isItalic: Bool {
        if case .uniform(let v) = inspector.isItalicValue { return v }
        return false
    }

    private var isUnderline: Bool {
        if case .uniform(let v) = inspector.isUnderlineValue { return v }
        return false
    }

    private var isStrikethrough: Bool {
        if case .uniform(let v) = inspector.isStrikethroughValue { return v }
        return false
    }

    /// P0.1: with nothing selected, `inspector`'s every `Value<T>` reads
    /// `.empty` and its setters (`setFont`, `setBold`, `setFill`, …)
    /// silently iterate an empty selection, so this sheet's controls were
    /// live but inert ، no error, no feedback, just a no-op tap. Gating on
    /// the selection here makes that state honest instead of silently
    /// broken.
    private var hasSelection: Bool { !inspector.session.selection.ids.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if hasSelection {
                    List {
                        // MARK: - Size
                        Section {
                            sizeRow
                        } header: {
                            Text(sizeLabel)
                        }

                        // MARK: - Traits (Bold / Italic / Underline / Strikethrough)
                        Section {
                            traitsRow
                            // P5.7 (Bug 9): every disabled control states
                            // WHY. Bold/italic are legitimately no-ops for
                            // most Arabic faces (most Arabic families ship
                            // one weight/one slant) ، a bare red slash with
                            // no explanation reads as a bug, not a font
                            // limitation.
                            if !boldSupported || !italicSupported {
                                traitsUnsupportedExplanation
                            }
                        } header: {
                            Text(traitsLabel)
                        }

                        // MARK: - Text color
                        Section {
                            textColorRow
                        } header: {
                            Text(textColorLabel)
                        }

                        // MARK: - Highlight / background color
                        Section {
                            highlightColorRow
                        } header: {
                            Text(highlightLabel)
                        }

                        // MARK: - Font management deep link (P7.3, Bug 12
                        // relocated: system-wide install is a device-scoped,
                        // one-time action ، it now lives in Settings →
                        // الخطوط (`FontManagementView`), not gated behind a
                        // per-selection text node here. This row is only a
                        // discoverability shortcut into that same screen.
                        Section {
                            Button {
                                showsFontManagement = true
                            } label: {
                                HStack {
                                    Text(manageFontsLabel)
                                        .foregroundStyle(theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.forward")
                                        .font(.caption)
                                        .foregroundStyle(theme.inkMuted)
                                }
                                .frame(minHeight: 44)
                            }
                        }

                        // MARK: - Font browser
                        Section {
                            fontRow
                        } header: {
                            Text(fontLabel)
                        }
                    }
                } else {
                    emptySelectionView
                }
            }
            .navigationTitle(titleLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(doneLabel) { dismiss() }
                }
            }
        }
        .task(id: currentFontID) {
            guard let id = currentFontID else {
                selectedFontRecord = nil
                return
            }
            selectedFontRecord = await fontRegistry.record(for: id)
        }
        .sheet(isPresented: $showsFontManagement) {
            NavigationStack {
                FontManagementView()
            }
        }
        .sheet(isPresented: $showFontBrowser) {
            let currentID: String? = {
                if case .uniform(let ref) = inspector.fontRefValue { return ref.fontID }
                return nil
            }()
            FontBrowserSheet(
                fontRegistry: fontRegistry,
                currentFontID: currentID,
                sampleText: sampleText
            ) { ref in
                inspector.setFont(ref)
            }
        }
        .sheet(isPresented: $showTextColorPicker) {
            MKColorPickerSheet(
                title: textColorLabel,
                initialColor: currentTextColor
            ) { color in
                inspector.setFill(.solid(MKSolidColor(r: color.red, g: color.green, b: color.blue, a: color.alpha)))
            }
        }
        .sheet(isPresented: $showHighlightColorPicker) {
            let initial = currentHighlightColor ?? (0.5, 0.5, 0.5, 0.3)
            MKColorPickerSheet(
                title: highlightLabel,
                initialColor: initial
            ) { color in
                inspector.setHighlightColor(MKSolidColor(r: color.red, g: color.green, b: color.blue, a: color.alpha))
            }
        }
    }

    // MARK: - Size

    private var sizeRow: some View {
        VStack(spacing: theme.spacing.sm) {
            HStack {
                Text("\(Int(currentPointSize)) pt")
                    .mkTypeStyle(theme.typeRamp.style(for: .body))
                    .foregroundStyle(theme.ink)
                    .frame(minWidth: 48, alignment: .trailing)
                Spacer()
                Button {
                    let clamped = max(2, currentPointSize - 1)
                    inspector.setPointSize(clamped)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.inkMuted)
                }
                .buttonStyle(.plain)
                Button {
                    inspector.setPointSize(min(999, currentPointSize + 1))
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.xs) {
                    ForEach(sizePresets, id: \.self) { size in
                        Button {
                            inspector.setPointSize(size)
                        } label: {
                            Text(MKRTLUtilities.toArabicIndicDigits(String(Int(size))))
                                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                                .padding(.horizontal, theme.spacing.sm)
                                .padding(.vertical, 4)
                                .background(
                                    abs(currentPointSize - size) < 0.01
                                        ? theme.primary.opacity(0.15)
                                        : theme.surface,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .foregroundStyle(
                                    abs(currentPointSize - size) < 0.01
                                        ? theme.primary
                                        : theme.inkMuted
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Traits

    private var traitsRow: some View {
        HStack(spacing: theme.spacing.sm) {
            Spacer()
            traitButton("B", isOn: isBold, supported: boldSupported, action: { inspector.setBold(!isBold) })
            traitButton("I", isOn: isItalic, supported: italicSupported, action: { inspector.setItalic(!isItalic) })
            traitButton("U", isOn: isUnderline, action: { inspector.setUnderline(!isUnderline) })
            traitButton("S", isOn: isStrikethrough, action: { inspector.setStrikethrough(!isStrikethrough) })
        }
    }

    /// Rewritten (was: `CTFontGetSymbolicTraits` on the CURRENTLY-SELECTED
    /// FACE, which answers "is this face itself bold?" not "does this
    /// family have a bold sibling to switch to?" ، the question the B
    /// button actually asks). Now pure data over the font RECORD's faces:
    /// bold is offered when a real ≥700-weight static cut exists, or the
    /// family is a variable font whose axis set includes `wght` (any
    /// variable weight axis implies a reachable bold-ish instance).
    private var boldSupported: Bool {
        guard case .uniform = inspector.fontRefValue, let record = selectedFontRecord else { return true }
        if record.faces.contains(where: { $0.weight >= 700 }) { return true }
        return record.faces.contains { $0.isVariable && variableAxisTags(in: $0.filename).contains("wght") }
    }

    /// Same rewrite as `boldSupported`: italic is offered when a real
    /// static italic cut exists (`styleName == "italic"`), or the family is
    /// variable with a `slnt` axis (e.g. Cairo/Cairo Play).
    private var italicSupported: Bool {
        guard case .uniform = inspector.fontRefValue, let record = selectedFontRecord else { return true }
        if record.faces.contains(where: { $0.styleName == "italic" }) { return true }
        return record.faces.contains { $0.isVariable && variableAxisTags(in: $0.filename).contains("slnt") }
    }

    /// Bundled variable-font filenames encode their axis tags in brackets
    /// (e.g. `"Cairo[slnt,wght].ttf"`, `"NotoSansArabic[wdth,wght].ttf"` ،
    /// see `records.json`/`BundledFontIndex`), and `MKFontFace` carries no
    /// separate axis-tag field, so this parses the one place that data
    /// already lives ، still pure string data, no CoreText call.
    private func variableAxisTags(in filename: String) -> Set<Substring> {
        guard let open = filename.firstIndex(of: "["), let close = filename.firstIndex(of: "]"), open < close else {
            return []
        }
        let inside = filename[filename.index(after: open)..<close]
        return Set(inside.split(separator: ","))
    }

    /// P5.7: the "why" behind a disabled B/I control ، only mentions the
    /// trait(s) actually unsupported by the CURRENT font.
    private var traitsUnsupportedExplanation: some View {
        VStack(alignment: .trailing, spacing: theme.spacing.xs) {
            if !boldSupported {
                Text(boldUnsupportedText)
            }
            if !italicSupported {
                Text(italicUnsupportedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .mkTypeStyle(theme.typeRamp.style(for: .caption))
        .foregroundStyle(theme.inkMuted)
    }

    private func traitButton(_ label: String, isOn: Bool, supported: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: traitGlyphSize, weight: isOn ? .bold : .regular))
                .frame(minWidth: 36, minHeight: 36)
                .foregroundStyle(isOn ? theme.primary : theme.inkMuted)
                .background(
                    isOn
                        ? theme.primary.opacity(0.12)
                        : theme.surface,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    if !supported {
                        GeometryReader { geo in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            }
                            .stroke(theme.destructive, lineWidth: 2)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                (isOn ? theme.primary : theme.inkMuted).opacity(0.3),
                                lineWidth: 1
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text color

    /// P5.1 verification: this sheet only reaches `textColorRow` once
    /// `hasSelection` gates the `List` (a non-empty selection), and P0.1
    /// made `inspector.fillValue` re-read correctly for that selection, so
    /// the fallback below is reachable only for a genuine MIXED-fill
    /// multi-select (several text nodes with different fill colors), not
    /// for the "selection exists but the field silently reads empty" bug
    /// P0.1 fixed. Still a real, reachable branch though ، simplified to
    /// reference `MKSolidColor.defaultInk` (the model's own canonical
    /// default-ink constant) instead of repeating its exact RGB literal
    /// here as an independent magic number.
    private var currentTextColor: (red: Double, green: Double, blue: Double, alpha: Double) {
        if case .uniform(let fill) = inspector.fillValue, case .solid(let c) = fill {
            return (c.r, c.g, c.b, c.a)
        }
        let ink = MKSolidColor.defaultInk
        return (ink.r, ink.g, ink.b, ink.a)
    }

    private var textColorRow: some View {
        Button { showTextColorPicker = true } label: {
            HStack {
                Circle()
                    .fill(Color(red: currentTextColor.red, green: currentTextColor.green, blue: currentTextColor.blue))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
                Text(textColorValueLabel)
                    .foregroundStyle(theme.ink)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    // MARK: - Highlight color

    private var currentHighlightColor: (red: Double, green: Double, blue: Double, alpha: Double)? {
        if case .uniform(let fill) = inspector.highlightColorValue, case .solid(let c) = fill {
            return (c.r, c.g, c.b, c.a)
        }
        return nil
    }

    private var hasHighlight: Bool {
        if case .uniform(let fill) = inspector.highlightColorValue, case .solid = fill { return true }
        return false
    }

    private var highlightColorRow: some View {
        HStack(spacing: theme.spacing.sm) {
            Button { showHighlightColorPicker = true } label: {
                HStack {
                    if let c = currentHighlightColor {
                        Circle()
                            .fill(Color(red: c.red, green: c.green, blue: c.blue).opacity(c.alpha))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
                    } else {
                        Circle()
                            .stroke(theme.border, lineWidth: 1)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("—")
                                    .foregroundStyle(theme.inkMuted)
                                    .font(.caption)
                            )
                    }
                    Text(hasHighlight ? highlightValueLabel : noHighlightLabel)
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            // P5.6: `setHighlightColor` can now express "clear" (nil) ،
            // this is the UI action for it. Only shown when a highlight is
            // actually set (nothing to clear otherwise), and kept as a
            // separate ≥44pt tap target from the swatch button above so
            // "open the picker" and "remove the highlight" stay two
            // distinct, unambiguous gestures.
            if hasHighlight {
                Button {
                    inspector.setHighlightColor(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: clearHighlightIconSize))
                        .foregroundStyle(theme.inkMuted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearHighlightLabel)
            }
        }
    }

    // MARK: - Font

    private var fontRow: some View {
        Button {
            showFontBrowser = true
        } label: {
            HStack {
                Text(fontLabel)
                    .foregroundStyle(theme.ink)
                Spacer()
                fontValueText
                    .foregroundStyle(theme.inkMuted)
                Image(systemName: "chevron.forward")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    @ViewBuilder
    private var fontValueText: some View {
        switch inspector.fontRefValue {
        case .uniform(let ref):
            Text(ref.postScriptName)
        case .mixed:
            Text(mixedLabel)
        case .empty:
            Text("-")
        }
    }

    // MARK: - Empty state

    private var emptySelectionView: some View {
        VStack(spacing: theme.spacing.sm) {
            Spacer()
            Text(emptySelectionText)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
    }

    // MARK: - Strings

    private var emptySelectionText: String {
        // Latin gloss: select a text object to edit its font and formatting
        "اختر عنصر نص لتعديل خطه وتنسيقه"
    }
    private var titleLabel: String { "الخط والتنسيق" }
    private var doneLabel: String { "تم" }
    private var sizeLabel: String { "الحجم" }
    private var traitsLabel: String { "التنسيق" }
    // Latin gloss: this font provides no bold weight
    private var boldUnsupportedText: String { "هذا الخط لا يوفّر وزنًا عريضًا" }
    // Latin gloss: this font provides no italic form
    private var italicUnsupportedText: String { "هذا الخط لا يوفّر شكلاً مائلاً" }
    private var fontLabel: String { "الخط" }
    private var textColorLabel: String { "لون النص" }
    private var textColorValueLabel: String { "اختر لون النص" }
    private var highlightLabel: String { "لون التظليل" }
    private var highlightValueLabel: String { "اختر لون التظليل" }
    private var noHighlightLabel: String { "بلا تظليل" }
    // Latin gloss: clear the highlight
    // UX-7: catalog-extractable accessibility label ، feeds
    // `.accessibilityLabel(_:)` directly.
    private var clearHighlightLabel: LocalizedStringResource { "إزالة التظليل" }
    private var mixedLabel: String { "متعدد" }
    // Latin gloss: manage fonts… (deep link to Settings → Fonts, P7.3)
    private var manageFontsLabel: String { "إدارة الخطوط…" }
}

// MARK: - Color picker sheet (P5.1, Bug 10 rebuild)
//
// The previous picker shipped hue + brightness sliders only ، `saturation`
// was computed from the seed color in `init` but NEVER exposed as a
// control, so a near-black/gray seed (`delta ≈ 0` → `saturation ≈ 0`) left
// every hue choice producing only greys ("can't set anything other than
// black"). This rebuild is a real SB-square + hue strip + alpha strip +
// swatch + Favourites/Custom tabs + eyedropper + numeric fields picker
// (§2.10), backed by `MKColorSpec`/`MKHSBAComponents` (`MKColor` module)
// for the RGB↔HSB math instead of hand-rolled inline conversion ، that math
// is unit-tested (`MKColorHSBTests`, round-trip incl. the achromatic edge
// case) in a place a UI file's own tests can't easily reach.
//
// Bug fixes shipped alongside the rebuild (see MASTER-PLAN P5.1):
// 1. Real saturation control (the SB square's horizontal axis) ، the
//    actual bug.
// 2. `previousHue` is no longer `static`: each sheet instance owns its own
//    `@State private var hue`, seeded once in `init`. The old `static var`
//    leaked a remembered hue between the text-color and highlight-color
//    pickers (and across sessions) ، plain instance state can't do that.
// 3. Alpha is a first-class state variable (`@State private var alpha`)
//    carried through to `onSelect` explicitly, never derived from a
//    SwiftUI `Color` (which silently drops it ، `Color(hue:saturation:
//    brightness:)` has no alpha parameter and defaults to `1`, which is
//    exactly how the old picker discarded a 30%-alpha highlight seed).
struct MKColorPickerSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var colorToolIconSize: CGFloat = 18

    let title: String
    let initialColor: (red: Double, green: Double, blue: Double, alpha: Double)
    let onSelect: ((red: Double, green: Double, blue: Double, alpha: Double)) -> Void

    private enum Tab { case custom, favourites }

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double
    @State private var alpha: Double
    @State private var activeTab: Tab = .custom
    @State private var favourites: [MKSolidColor] = []
    @State private var showEyedropper = false

    init(
        title: String, initialColor: (red: Double, green: Double, blue: Double, alpha: Double),
        onSelect: @escaping ((red: Double, green: Double, blue: Double, alpha: Double)) -> Void
    ) {
        self.title = title
        self.initialColor = initialColor
        self.onSelect = onSelect
        let seed = MKColorSpec(r: initialColor.red, g: initialColor.green, b: initialColor.blue, a: initialColor.alpha)
        let hsba = seed.hsba
        _hue = State(initialValue: hsba.hue)
        _saturation = State(initialValue: hsba.saturation)
        _brightness = State(initialValue: hsba.brightness)
        _alpha = State(initialValue: hsba.alpha)
    }

    /// The single source of truth for the picker's current color ،
    /// EVERY control (SB square, strips, numeric fields, hex field,
    /// swatch) reads/writes through `hue`/`saturation`/`brightness`/
    /// `alpha`, and this is the one place they're recombined.
    private var currentSpec: MKColorSpec {
        MKColorSpec(hsba: MKHSBAComponents(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha))
    }

    private var currentColor: Color {
        Color(red: currentSpec.r, green: currentSpec.g, blue: currentSpec.b, opacity: currentSpec.a)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.xl) {
                    previewRow
                    tabSelector
                    switch activeTab {
                    case .custom: customTabContent
                    case .favourites: favouritesTabContent
                    }
                }
                .padding(theme.spacing.xl)
            }
            .background(theme.bg)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelLabel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectLabel) {
                        let spec = currentSpec
                        onSelect((spec.r, spec.g, spec.b, spec.a))
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear { favourites = MKColorFavouritesStore.load() }
        .sheet(isPresented: $showEyedropper) {
            MKSystemEyedropperView(initial: UIColor(currentColor)) { picked in
                let ci = CIColor(color: picked)
                let sampled = MKColorSpec(r: Double(ci.red), g: Double(ci.green), b: Double(ci.blue), a: Double(ci.alpha))
                let hsba = sampled.hsba
                hue = hsba.hue
                saturation = hsba.saturation
                brightness = hsba.brightness
                alpha = hsba.alpha
            }
        }
    }

    // MARK: - Preview row (swatch + eyedropper + add-to-favourites)

    private var previewRow: some View {
        HStack(spacing: theme.spacing.md) {
            ZStack {
                MKCheckerboardPattern()
                Rectangle().fill(currentColor)
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                    .strokeBorder(theme.border, lineWidth: 1)
            )

            Button { showEyedropper = true } label: {
                Image(systemName: "eyedropper")
                    .font(.system(size: colorToolIconSize))
                    .foregroundStyle(theme.ink)
                    .frame(width: 44, height: 44)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.button, style: theme.radius.style))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(eyedropperLabel)

            Button { addCurrentToFavourites() } label: {
                Image(systemName: "star")
                    .font(.system(size: colorToolIconSize))
                    .foregroundStyle(theme.ink)
                    .frame(width: 44, height: 44)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.button, style: theme.radius.style))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(addFavouriteLabel)
        }
    }

    // MARK: - Tabs

    private var tabSelector: some View {
        HStack(spacing: theme.spacing.sm) {
            MKChip(title: customTabLabel, isSelected: activeTab == .custom) { activeTab = .custom }
            MKChip(title: favouritesTabLabel, isSelected: activeTab == .favourites) { activeTab = .favourites }
            Spacer()
        }
    }

    // MARK: - Custom tab (SB square + hue/alpha strips + numeric fields)

    private var customTabContent: some View {
        VStack(spacing: theme.spacing.lg) {
            MKSaturationBrightnessSquare(hue: hue, saturation: $saturation, brightness: $brightness, cornerRadius: theme.radius.card)
                .frame(height: 200)

            labeledStrip(label: hueLabel) {
                MKHueStrip(hue: $hue, cornerRadius: theme.radius.button)
            }
            labeledStrip(label: alphaLabel) {
                MKAlphaStrip(hue: hue, saturation: saturation, brightness: brightness, alpha: $alpha, cornerRadius: theme.radius.button)
            }

            MKPanel {
                MKInspectorField(label: redLabel, value: redBinding, displaysArabicIndicDigits: true)
                MKInspectorField(label: greenLabel, value: greenBinding, displaysArabicIndicDigits: true)
                MKInspectorField(label: blueLabel, value: blueBinding, displaysArabicIndicDigits: true)
                MKInspectorField(label: alphaPercentLabel, value: alphaPercentBinding, displaysArabicIndicDigits: true)
                MKHexColorField(value: hexString, onCommit: commitHex)
            }

            if let cmykText = cmykPreviewText {
                Text(cmykText)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func labeledStrip<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .trailing, spacing: theme.spacing.xs) {
            Text(label)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
            content()
                .frame(height: 44)
        }
    }

    // MARK: - Favourites tab

    private var favouritesTabContent: some View {
        VStack(alignment: .trailing, spacing: theme.spacing.md) {
            if favourites.isEmpty {
                Text(noFavouritesText)
                    .mkTypeStyle(theme.typeRamp.style(for: .callout))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, theme.spacing.xl)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.sm), count: 5), spacing: theme.spacing.sm) {
                    ForEach(Array(favourites.enumerated()), id: \.offset) { index, color in
                        Button { applyFavourite(color) } label: {
                            Circle()
                                .fill(Color(red: color.r, green: color.g, blue: color.b, opacity: color.a))
                                .frame(width: 44, height: 44)
                                .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { removeFavourite(at: index) } label: {
                                Label(deleteFavouriteLabel, systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Favourites persistence

    private func addCurrentToFavourites() {
        let spec = currentSpec
        let color = MKSolidColor(r: spec.r, g: spec.g, b: spec.b, a: spec.a)
        guard !favourites.contains(color) else { return }
        favourites.append(color)
        MKColorFavouritesStore.save(favourites)
    }

    private func removeFavourite(at index: Int) {
        guard favourites.indices.contains(index) else { return }
        favourites.remove(at: index)
        MKColorFavouritesStore.save(favourites)
    }

    private func applyFavourite(_ color: MKSolidColor) {
        let hsba = MKColorSpec(r: color.r, g: color.g, b: color.b, a: color.a).hsba
        hue = hsba.hue
        saturation = hsba.saturation
        brightness = hsba.brightness
        alpha = hsba.alpha
        activeTab = .custom
    }

    // MARK: - Numeric field bindings (0-255 RGB, 0-100% alpha)

    /// Rewrites ONE channel at a time on top of the CURRENT spec (not the
    /// seed), then re-derives `hue`/`saturation`/`brightness` from the
    /// result so the SB square/hue strip stay in sync with a typed RGB
    /// edit.
    private func setChannel(r: Double? = nil, g: Double? = nil, b: Double? = nil) {
        let spec = currentSpec
        let updated = MKColorSpec(
            r: r.map { $0 / 255 } ?? spec.r,
            g: g.map { $0 / 255 } ?? spec.g,
            b: b.map { $0 / 255 } ?? spec.b,
            a: spec.a
        )
        let hsba = updated.hsba
        hue = hsba.hue
        saturation = hsba.saturation
        brightness = hsba.brightness
    }

    private var redBinding: Binding<Double> {
        Binding(get: { (currentSpec.r * 255).rounded() }, set: { setChannel(r: $0) })
    }
    private var greenBinding: Binding<Double> {
        Binding(get: { (currentSpec.g * 255).rounded() }, set: { setChannel(g: $0) })
    }
    private var blueBinding: Binding<Double> {
        Binding(get: { (currentSpec.b * 255).rounded() }, set: { setChannel(b: $0) })
    }
    private var alphaPercentBinding: Binding<Double> {
        Binding(
            get: { (alpha * 100).rounded() },
            set: { alpha = min(1, max(0, $0 / 100)) }
        )
    }

    // MARK: - Hex field

    private var hexString: String {
        let spec = currentSpec
        func byte(_ v: Double) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(spec.r), byte(spec.g), byte(spec.b))
    }

    private func commitHex(_ text: String) {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return }
        let r = Double((value >> 16) & 0xFF)
        let g = Double((value >> 8) & 0xFF)
        let b = Double(value & 0xFF)
        setChannel(r: r, g: g, b: b)
    }

    // MARK: - CMYK preview (backed by `MKColor.CMYKConverter`, §2.10 "colour accuracy")

    /// A rough print-CMYK readout under the active ICC profile (bundled
    /// profile if one ships, else the documented Apple Generic CMYK
    /// fallback ، same resolution `MKExport`'s CMYK PDF writer uses).
    /// Informational only (never fed back into `hue`/`saturation`/
    /// `brightness`, v1 has no CMYK-native editing) ، `nil` only if
    /// CoreGraphics itself fails the conversion, which
    /// `CMYKConverterTests` asserts doesn't happen for well-formed sRGB
    /// input.
    private var cmykPreviewText: String? {
        let profile = ICCProfileStore.loadBundled()
        guard let cmyk = CMYKConverter.cmyk(from: currentSpec, profile: profile), cmyk.count >= 4 else { return nil }
        func pct(_ v: CGFloat) -> String { "\(Int((v * 100).rounded()))%" }
        return "\(cmykLabel) \(pct(cmyk[0]))/\(pct(cmyk[1]))/\(pct(cmyk[2]))/\(pct(cmyk[3]))"
    }

    // MARK: - Strings

    private var hueLabel: String { "اللون" }
    private var alphaLabel: String { "الشفافية" }
    private var cancelLabel: String { "إلغاء" }
    private var selectLabel: String { "اختيار" }
    private var customTabLabel: String { "مخصص" }
    private var favouritesTabLabel: String { "المفضلة" }
    private var noFavouritesText: String {
        // Latin gloss: no favourite colors yet — tap the star to add the current color
        "لا توجد ألوان مفضلة بعد ، اضغط النجمة لإضافة اللون الحالي"
    }
    // UX-7: catalog-extractable accessibility labels ، feed
    // `.accessibilityLabel(_:)` directly.
    private var eyedropperLabel: LocalizedStringResource {
        // Latin gloss: pick a color from the screen
        "التقاط لون من الشاشة"
    }
    private var addFavouriteLabel: LocalizedStringResource {
        // Latin gloss: add to favourites
        "إضافة إلى المفضلة"
    }
    private var deleteFavouriteLabel: String { "حذف" }
    private var redLabel: String { "R" }
    private var greenLabel: String { "G" }
    private var blueLabel: String { "B" }
    private var alphaPercentLabel: String {
        // Latin gloss: opacity %
        "الشفافية ٪"
    }
    private var cmykLabel: String { "CMYK:" }
}

// MARK: - Saturation/Brightness square

/// The 2D control the old picker never had: horizontal axis = saturation,
/// vertical axis = brightness, backdrop tinted by the CURRENT hue. This is
/// the actual Bug 10 fix ، everything else in this file is polish around
/// it (§2.10's other listed controls).
private struct MKSaturationBrightnessSquare: View {
    @Environment(\.mkTheme) private var theme
    let hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Base hue at full saturation/brightness, then white→clear
                // (saturation axis) and clear→black (brightness axis)
                // overlays ، the standard SB-square construction. These
                // gradients paint arbitrary user-chosen hues by design (the
                // picker's whole job), so they are deliberately NOT theme
                // tokens, unlike every other color in this app's chrome.
                Rectangle().fill(Color(hue: hue, saturation: 1, brightness: 1))
                LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                thumb(in: geo.size)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: theme.radius.style))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    update(with: value.location, size: geo.size)
                }
            )
        }
    }

    private func thumb(in size: CGSize) -> some View {
        let x = min(max(saturation, 0), 1) * size.width
        let y = (1 - min(max(brightness, 0), 1)) * size.height
        return Circle()
            .strokeBorder(.white, lineWidth: 3)
            .background(Circle().fill(Color(hue: hue, saturation: saturation, brightness: brightness)))
            .frame(width: 22, height: 22)
            .shadow(radius: 1)
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }

    private func update(with location: CGPoint, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        saturation = min(1, max(0, location.x / size.width))
        brightness = 1 - min(1, max(0, location.y / size.height))
    }
}

// MARK: - Hue strip

private struct MKHueStrip: View {
    @Environment(\.mkTheme) private var theme
    @Binding var hue: Double
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                    startPoint: .leading, endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: theme.radius.style))
                thumbFill(geo: geo)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    guard geo.size.width > 0 else { return }
                    hue = min(1, max(0, value.location.x / geo.size.width))
                }
            )
        }
    }

    private func thumbFill(geo: GeometryProxy) -> some View {
        Circle()
            .fill(.white)
            .shadow(radius: 2)
            .frame(width: 28, height: 28)
            .overlay(Circle().strokeBorder(Color(hue: hue, saturation: 1, brightness: 1), lineWidth: 2))
            .position(x: min(max(hue, 0), 1) * geo.size.width, y: geo.size.height / 2)
    }
}

// MARK: - Alpha strip (checkerboard + gradient)

private struct MKAlphaStrip: View {
    @Environment(\.mkTheme) private var theme
    let hue: Double
    let saturation: Double
    let brightness: Double
    @Binding var alpha: Double
    let cornerRadius: CGFloat

    private var opaqueColor: Color { Color(hue: hue, saturation: saturation, brightness: brightness) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                MKCheckerboardPattern()
                LinearGradient(
                    colors: [opaqueColor.opacity(0), opaqueColor.opacity(1)],
                    startPoint: .leading, endPoint: .trailing
                )
                thumbFill(geo: geo)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: theme.radius.style))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    guard geo.size.width > 0 else { return }
                    alpha = min(1, max(0, value.location.x / geo.size.width))
                }
            )
        }
    }

    private func thumbFill(geo: GeometryProxy) -> some View {
        Circle()
            .fill(.white)
            .shadow(radius: 2)
            .frame(width: 28, height: 28)
            .overlay(Circle().strokeBorder(opaqueColor.opacity(alpha), lineWidth: 2))
            .position(x: min(max(alpha, 0), 1) * geo.size.width, y: geo.size.height / 2)
    }
}

// MARK: - Checkerboard (alpha-transparency indicator ، a universal design-
// tool convention, deliberately neutral gray/white rather than a theme
// token: it must read as "transparent" regardless of the active theme,
// the same way it does in every other image/color editor).

private struct MKCheckerboardPattern: View {
    var body: some View {
        Canvas { ctx, size in
            let cell: CGFloat = 6
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var col = 0
                var x: CGFloat = 0
                while x < size.width {
                    let isLight = (row + col).isMultiple(of: 2)
                    ctx.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(isLight ? .white : Color(white: 0.82)))
                    x += cell
                    col += 1
                }
                y += cell
                row += 1
            }
        }
    }
}

// MARK: - Hex numeric-ish field (string, not Double ، `MKInspectorField`
// is Double-only, so this mirrors its exact interaction pattern for a hex
// string instead: local text buffer, commit on blur/submit, revert to the
// canonical displayed value on invalid input).

private struct MKHexColorField: View {
    @Environment(\.mkTheme) private var theme
    let value: String
    let onCommit: (String) -> Void

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(hexLabel)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
            Spacer(minLength: theme.spacing.sm)
            TextField("", text: $text)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                .keyboardType(.asciiCapable)
                #endif
                .autocorrectionDisabled()
                .mkTypeStyle(theme.typeRamp.style(for: .body))
                .foregroundStyle(theme.ink)
                .focused($isFocused)
                .frame(minWidth: 90)
                .onChange(of: isFocused) { _, focused in
                    if !focused { onCommit(text); text = value }
                }
                .onSubmit { onCommit(text); text = value }
        }
        .padding(.vertical, theme.spacing.xs)
        .onAppear { text = value }
        .onChange(of: value) { _, newValue in
            if !isFocused { text = newValue }
        }
    }

    private var hexLabel: String {
        // Latin gloss: hex
        "سداسي عشري"
    }
}

// MARK: - Eyedropper (real Apple API: `UIColorPickerViewController`, whose
// own toolbar includes a system-level eyedropper that can sample any pixel
// on screen ، not a hand-rolled pixel sampler, which this app has no
// screen-capture entitlement/path for, and per `MKRenderTests`'
// `noScreenCaptureTextRasterizationAPIsAnywhereInMKRenderSources` this
// codebase deliberately keeps it that way).

private struct MKSystemEyedropperView: UIViewControllerRepresentable {
    let initial: UIColor
    let onPick: (UIColor) -> Void

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let controller = UIColorPickerViewController()
        controller.selectedColor = initial
        controller.supportsAlpha = true
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        let onPick: (UIColor) -> Void
        init(onPick: @escaping (UIColor) -> Void) { self.onPick = onPick }
        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {}
        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            onPick(color)
        }
    }
}

// MARK: - Favourites persistence (UserDefaults, matching this app's own
// existing lightweight-preference pattern, e.g. `EditorTourModel`)

private enum MKColorFavouritesStore {
    private static let key = "mk.colorPicker.favourites.v1"

    static func load() -> [MKSolidColor] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MKSolidColor].self, from: data)
        else { return [] }
        return decoded
    }

    static func save(_ colors: [MKSolidColor]) {
        guard let data = try? JSONEncoder().encode(colors) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
