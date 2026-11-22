import MKCanvas
import MKDesignSystem
import MKFonts
import MKFoundation
import MKModel
import SwiftUI
import UIKit

/// The الخصائص (numeric inspector) panel over WS-06's `InspectorModel`
/// (packet T11: "X/Y/W/H/rotation + style fields"). `W`/`H` fields are
/// wired (unlike the EARLY placeholder era) since `InspectorModel.sizeValue`/
/// `.setSize` now has a real `geometrySource` behind it
/// (`MKCanvasRenderAdapter`, this session).
struct InspectorPanelView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel
    let fontRegistry: MKFontRegistry

    @State private var showFontBrowser = false
    /// P5.6: `MKColorPickerSheet` (P5.1), aimed at the selected text
    /// node(s)' highlight color ، same Pattern B presentation as
    /// `showFontBrowser` above.
    @State private var showHighlightColorPicker = false

    private var inspector: InspectorModel { viewModel.inspector }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.md) {
                if viewModel.hasSelection {
                    MKPanel(title: positionTitle) {
                        MKInspectorField(label: xLabel, value: xBinding, displaysArabicIndicDigits: true)
                        MKInspectorField(label: yLabel, value: yBinding, displaysArabicIndicDigits: true)
                    }
                    MKPanel(title: sizeTitle) {
                        MKInspectorField(label: widthLabel, value: widthBinding, displaysArabicIndicDigits: true)
                        MKInspectorField(label: heightLabel, value: heightBinding, displaysArabicIndicDigits: true)
                    }
                    MKPanel(title: transformTitle) {
                        MKInspectorField(label: rotationLabel, value: rotationBinding, displaysArabicIndicDigits: true)
                        MKSlider(label: opacityLabel, value: opacityBinding, in: 0...1)
                    }
                    MKPanel(title: styleTitle) {
                        ColorPicker(fillLabel, selection: fillColorBinding, supportsOpacity: false)
                            .mkTypeStyle(theme.typeRamp.style(for: .callout))
                    }
                    // Font row ، only when a text node is selected
                    if case .uniform(let fontRef) = inspector.fontRefValue {
                        MKPanel(title: fontTitle) {
                            Button {
                                showFontBrowser = true
                            } label: {
                                HStack {
                                    Text(fontRef.fontID)
                                        .mkTypeStyle(theme.typeRamp.style(for: .callout))
                                        .foregroundStyle(theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(theme.inkMuted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else if case .mixed = inspector.fontRefValue {
                        MKPanel(title: fontTitle) {
                            Text(mixedFontsText)
                                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                                .foregroundStyle(theme.inkMuted)
                        }
                    }

                    // Verbose text fields when a text node is selected
                    if inspector.textStyleValue != .empty {
                        MKPanel(title: pointSizeLabel) {
                            MKInspectorField(label: pointSizeLabel, value: pointSizeBinding, displaysArabicIndicDigits: true)
                        }
                        MKPanel(title: trackingLabel) {
                            MKInspectorField(label: trackingLabel, value: trackingBinding, displaysArabicIndicDigits: true)
                        }
                        MKPanel(title: baselineShiftLabel) {
                            MKInspectorField(label: baselineShiftLabel, value: baselineShiftBinding, displaysArabicIndicDigits: true)
                        }
                        MKPanel(title: lineHeightLabel) {
                            MKInspectorField(label: lineHeightLabel, value: lineHeightBinding, displaysArabicIndicDigits: true)
                        }
                        MKPanel(title: ligatureLabel) {
                            Text(ligatureText)
                                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                                .foregroundStyle(theme.ink)
                        }
                        // P5.6 (Bug 11): this used to be a read-only
                        // circle + label ، no button, no picker, so a
                        // highlight color could be INSPECTED here but
                        // never SET or CLEARED from this panel. Now a real
                        // setter (opens the same `MKColorPickerSheet` the
                        // font-settings sheet uses) plus a clear action
                        // (`setHighlightColor(nil)`, the widened P5.6
                        // signature).
                        MKPanel(title: highlightLabel) {
                            HStack(spacing: theme.spacing.sm) {
                                Button { showHighlightColorPicker = true } label: {
                                    HStack {
                                        Circle()
                                            .fill(highlightDisplayColor)
                                            .frame(width: 24, height: 24)
                                            .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
                                        Text(highlightValueText)
                                            .mkTypeStyle(theme.typeRamp.style(for: .callout))
                                            .foregroundStyle(theme.ink)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                }
                                .buttonStyle(.plain)
                                if hasHighlight {
                                    Button { inspector.setHighlightColor(nil) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(theme.inkMuted)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(clearHighlightLabel)
                                }
                            }
                        }
                    }
                } else {
                    Text(emptySelectionText)
                        .mkTypeStyle(theme.typeRamp.style(for: .callout))
                        .foregroundStyle(theme.inkMuted)
                        .padding(theme.spacing.md)
                }
            }
            .padding(theme.spacing.md)
        }
        .background(theme.bg)
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // UX-2: another "layout-fragile surface" the audit calls out by
        // name (numeric fields laid out in tight rows) ، clamp at
        // `.accessibility3` rather than letting the largest Dynamic Type
        // sizes break the field grid.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .sheet(isPresented: $showFontBrowser) {
            let currentFontID: String? = {
                if case .uniform(let ref) = inspector.fontRefValue { return ref.fontID }
                return nil
            }()
            FontBrowserSheet(
                fontRegistry: fontRegistry,
                currentFontID: currentFontID,
                sampleText: viewModel.selectedTextForFontSettings
            ) { fontRef in
                inspector.setFont(fontRef)
            }
        }
        .sheet(isPresented: $showHighlightColorPicker) {
            let initial = currentHighlightColor ?? (0.5, 0.5, 0.5, 0.3)
            MKColorPickerSheet(title: highlightLabel, initialColor: initial) { color in
                inspector.setHighlightColor(MKSolidColor(r: color.red, g: color.green, b: color.blue, a: color.alpha))
            }
        }
    }

    // MARK: - Bindings (Value<T> mixed/empty collapse to the last-known
    // uniform value shown at 0 ، matching MKInspectorField's own "typing
    // commits a fresh absolute value" contract; T11 P4 scope does not
    // build the "،" mixed-value glyph rendering MKInspectorField itself
    // would need extending for, a documented simplification).

    private var xBinding: Binding<Double> {
        Binding(
            get: { Double(value(of: inspector.positionValue)?.x ?? 0) },
            set: { newX in
                let y = value(of: inspector.positionValue)?.y ?? 0
                inspector.setPosition(CGPoint(x: newX, y: y))
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var yBinding: Binding<Double> {
        Binding(
            get: { Double(value(of: inspector.positionValue)?.y ?? 0) },
            set: { newY in
                let x = value(of: inspector.positionValue)?.x ?? 0
                inspector.setPosition(CGPoint(x: x, y: newY))
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var widthBinding: Binding<Double> {
        Binding(
            get: { Double(sizeValue?.width ?? 0) },
            set: { newWidth in
                inspector.setSize(width: CGFloat(newWidth), height: nil)
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var heightBinding: Binding<Double> {
        Binding(
            get: { Double(sizeValue?.height ?? 0) },
            set: { newHeight in
                inspector.setSize(width: nil, height: CGFloat(newHeight))
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var rotationBinding: Binding<Double> {
        Binding(
            get: {
                if case .uniform(let v) = inspector.rotationDegreesValue { return v }
                return 0
            },
            set: { newValue in
                inspector.setRotationDegrees(newValue)
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: {
                if case .uniform(let v) = inspector.opacityValue { return v }
                return 1
            },
            set: { newValue in
                inspector.setOpacity(newValue)
            }
        )
    }

    private var fillColorBinding: Binding<Color> {
        Binding(
            get: {
                if case .uniform(let fill) = inspector.fillValue, case .solid(let solid) = fill {
                    return Color(red: solid.r, green: solid.g, blue: solid.b, opacity: solid.a)
                }
                return theme.ink
            },
            set: { newColor in
                guard let components = newColor.resolvedRGBA else { return }
                inspector.setFill(.solid(MKSolidColor(r: components.red, g: components.green, b: components.blue, a: components.alpha)))
            }
        )
    }

    // MARK: - Text-style bindings

    private var pointSizeBinding: Binding<Double> {
        Binding(
            get: {
                if case .uniform(let v) = inspector.pointSizeValue { return v }
                return 36
            },
            set: { newValue in
                inspector.setPointSize(newValue)
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var trackingBinding: Binding<Double> {
        Binding(
            get: {
                if case .uniform(let v) = inspector.trackingValue { return v }
                return 0
            },
            set: { newValue in
                inspector.setTracking(newValue)
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var baselineShiftBinding: Binding<Double> {
        Binding(
            get: {
                if case .uniform(let v) = inspector.baselineShiftValue { return v }
                return 0
            },
            set: { newValue in
                inspector.setBaselineShift(newValue)
                viewModel.refreshCanvasChrome()
            }
        )
    }

    private var lineHeightBinding: Binding<Double> {
        Binding(
            get: {
                if case .uniform(let v) = inspector.lineHeightMultipleValue { return v }
                return 1.2
            },
            set: { newValue in
                inspector.setLineHeightMultiple(newValue)
                viewModel.refreshCanvasChrome()
            }
        )
    }

    // MARK: - Text display helpers

    private var ligatureText: String {
        if case .uniform(let setting) = inspector.ligatureSettingValue {
            switch setting {
            case .standard: return "قياسي"
            case .discretionaryOn: return "اختياري"
            case .off: return "مُعطّل"
            }
        } else if case .mixed = inspector.ligatureSettingValue {
            return "مُتعدد"
        }
        return "-"
    }

    private var highlightDisplayColor: Color {
        if case .uniform(let fill) = inspector.highlightColorValue, case .solid(let c) = fill {
            return Color(red: c.r, green: c.g, blue: c.b, opacity: c.a)
        }
        return Color.gray.opacity(0.2)
    }

    private var highlightValueText: String {
        if case .uniform(let fill) = inspector.highlightColorValue {
            if case .solid = fill { return "مُحدد" }
            return "بدون تظليل"
        } else if case .mixed = inspector.highlightColorValue {
            return "مُتعدد"
        }
        return "بدون تظليل"
    }

    private var hasHighlight: Bool {
        if case .uniform(let fill) = inspector.highlightColorValue, case .solid = fill { return true }
        return false
    }

    private var currentHighlightColor: (red: Double, green: Double, blue: Double, alpha: Double)? {
        if case .uniform(let fill) = inspector.highlightColorValue, case .solid(let c) = fill {
            return (c.r, c.g, c.b, c.a)
        }
        return nil
    }

    private func value(of value: InspectorModel.Value<CGPoint>) -> CGPoint? {
        if case .uniform(let v) = value { return v }
        return nil
    }

    private var sizeValue: CGSize? {
        if case .uniform(let v) = inspector.sizeValue { return v }
        return nil
    }

    // MARK: - Strings

    private var navTitle: String {
        // Latin gloss: properties
        "الخصائص"
    }
    private var positionTitle: String {
        // Latin gloss: position
        "الموضع"
    }
    private var sizeTitle: String {
        // Latin gloss: size
        "الحجم"
    }
    private var transformTitle: String {
        // Latin gloss: transform
        "التحويل"
    }
    private var styleTitle: String {
        // Latin gloss: style
        "التنسيق"
    }
    private var xLabel: String { "X" }
    private var yLabel: String { "Y" }
    private var widthLabel: String {
        // Latin gloss: width
        "العرض"
    }
    private var heightLabel: String {
        // Latin gloss: height
        "الارتفاع"
    }
    private var rotationLabel: String {
        // Latin gloss: rotation
        "الدوران"
    }
    private var opacityLabel: String {
        // Latin gloss: opacity
        "الشفافية"
    }
    private var fillLabel: String {
        // Latin gloss: fill
        "التعبئة"
    }
    private var emptySelectionText: String {
        // Latin gloss: select an object to edit its properties
        "اختر عنصرًا لتعديل خصائصه"
    }
    private var fontTitle: String {
        // Latin gloss: font
        "الخط"
    }
    private var mixedFontsText: String {
        // Latin gloss: mixed fonts
        "خطوط مختلطة"
    }
    private var pointSizeLabel: String {
        // Latin gloss: font size
        "حجم الخط"
    }
    private var trackingLabel: String {
        // Latin gloss: tracking
        "التباعد"
    }
    private var baselineShiftLabel: String {
        // Latin gloss: baseline shift
        "إزاحة الأساس"
    }
    private var lineHeightLabel: String {
        // Latin gloss: line height
        "ارتفاع السطر"
    }
    private var ligatureLabel: String {
        // Latin gloss: ligatures
        "الوصلات"
    }
    private var highlightLabel: String {
        // Latin gloss: highlight color
        "لون التظليل"
    }
    // UX-7: catalog-extractable accessibility label ، feeds
    // `.accessibilityLabel(_:)` directly.
    private var clearHighlightLabel: LocalizedStringResource {
        // Latin gloss: clear the highlight
        "إزالة التظليل"
    }
}

private extension Color {
    /// Resolves a SwiftUI `Color` to sRGB components via `UIColor` ، the
    /// simplest reliable cross-color-space path available without pulling
    /// in `MKColor` (WS-08/P10 territory, out of this session's fence).
    var resolvedRGBA: (red: Double, green: Double, blue: Double, alpha: Double)? {
        // Use CIColor for cross-color-space safety (handles P3, sRGB, etc.)
        let ci = CIColor(color: UIColor(self))
        return (Double(ci.red), Double(ci.green), Double(ci.blue), Double(ci.alpha))
    }
}
