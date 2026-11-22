import MKDesignSystem
import SwiftUI

#if DEBUG
/// Debug-only screen showing every `MKDesignSystem/Components` component
/// (WS-01 packet §5 task 15 accept criterion): `MKPanel`, `MKInspectorField`,
/// `MKSlider`, `MKChip`, `MKToolbarButton`, `MKSectionHeader`, `MKBanner`.
/// Reachable only from `RootView`'s `#if DEBUG` gallery link ، never built
/// into a Release configuration.
///
/// Manual RTL verification checklist this screen exists to support
/// (WS-01 packet §7 "Design-system gate"):
/// - Slider minimum sits on the RIGHT (RTL mirroring).
/// - Chevrons point left for "forward".
/// - Every `MKChip` category renders selected/unselected states correctly.
struct DesignSystemGallery: View {
    @Environment(\.mkTheme) private var theme

    @State private var sliderValue: Double = 0.4
    @State private var inspectorValue: Double = 12
    @State private var selectedChip = 0

    private let chipTitles = ["نسخ", "خط ديواني", "خط كوفي"] // Latin gloss: naskh / diwani / kufic ، font category sample

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                sectionHeaderDemo
                panelDemo
                inspectorFieldDemo
                sliderDemo
                chipDemo
                toolbarButtonDemo
                bannerDemo
            }
            .padding(theme.spacing.lg)
        }
        .background(theme.bg)
        .navigationTitle(Text("معرض عناصر التصميم", comment: "Gallery screen title (Latin gloss: design elements gallery)"))
    }

    private var sectionHeaderDemo: some View {
        MKSectionHeader(
            title: sectionHeaderTitle,
            actionTitle: sectionHeaderActionTitle,
            action: {}
        )
    }

    private var sectionHeaderTitle: String {
        // Latin gloss: section header
        "ترويسة القسم"
    }

    private var sectionHeaderActionTitle: String {
        // Latin gloss: more
        "المزيد"
    }

    private var panelDemo: some View {
        MKPanel(title: panelTitle) {
            Text(verbatim: "لا إله إلا الله")
                .mkTypeStyle(theme.typeRamp.style(for: .body))
                .foregroundStyle(theme.ink)
        }
    }

    private var panelTitle: String {
        // Latin gloss: panel
        "لوحة"
    }

    private var inspectorFieldDemo: some View {
        MKPanel(title: inspectorFieldTitle) {
            MKInspectorField(label: xLabel, value: $inspectorValue)
            MKInspectorField(label: yLabelArabicIndic, value: $inspectorValue, displaysArabicIndicDigits: true)
        }
    }

    private var inspectorFieldTitle: String {
        // Latin gloss: numeric inspector field
        "حقل الإدخال الرقمي"
    }

    private var xLabel: String { "س" } // Latin gloss: X (Arabic letter used as the X-axis field label)
    private var yLabelArabicIndic: String { "ص (أرقام هندية)" } // Latin gloss: Y (Arabic-Indic numerals)

    private var sliderDemo: some View {
        MKPanel(title: sliderTitle) {
            MKSlider(label: sliderLabel, value: $sliderValue)
        }
    }

    private var sliderTitle: String {
        // Latin gloss: slider ، minimum on the right under RTL
        "شريط التمرير"
    }

    private var sliderLabel: String { "الشفافية" } // Latin gloss: opacity

    private var chipDemo: some View {
        MKPanel(title: chipTitle) {
            HStack(spacing: theme.spacing.sm) {
                ForEach(chipTitles.indices, id: \.self) { index in
                    MKChip(title: chipTitles[index], isSelected: selectedChip == index) {
                        selectedChip = index
                    }
                }
            }
        }
    }

    private var chipTitle: String {
        // Latin gloss: font category chips
        "شرائح فئات الخط"
    }

    private var toolbarButtonDemo: some View {
        MKPanel(title: toolbarButtonTitle) {
            HStack(spacing: theme.spacing.md) {
                MKToolbarButton(systemImage: "chevron.forward", accessibilityLabel: forwardLabel) {}
                MKToolbarButton(systemImage: "chevron.backward", accessibilityLabel: backwardLabel) {}
                MKToolbarButton(systemImage: "plus", accessibilityLabel: addLabel, isProminent: true) {}
            }
        }
    }

    private var toolbarButtonTitle: String {
        // Latin gloss: toolbar buttons ، chevrons must point left for "forward" under RTL
        "أزرار الشريط"
    }

    private var forwardLabel: String { "التالي" } // Latin gloss: next/forward
    private var backwardLabel: String { "السابق" } // Latin gloss: previous/backward
    private var addLabel: String { "إضافة" } // Latin gloss: add

    private var bannerDemo: some View {
        VStack(spacing: theme.spacing.sm) {
            MKBanner(message: memoryWarningMessage, severity: .warning)
            MKBanner(message: infoMessage, severity: .info)
        }
    }

    private var memoryWarningMessage: String {
        // Latin gloss: memory nearly full ، autosaved (D-116 stage-2 banner text)
        "الذاكرة شبه ممتلئة ، تم الحفظ تلقائيًا"
    }

    private var infoMessage: String {
        // Latin gloss: this is a sample notice
        "هذا إشعار توضيحي"
    }
}

#Preview {
    NavigationStack {
        DesignSystemGallery()
            .environment(\.mkTheme, HibrTheme.default)
    }
}
#endif
