import MKFoundation
import SwiftUI

/// A labeled numeric field row for the inspector panel: label + value,
/// RTL label/value order (label leads, i.e. sits on the right in RTL ،
/// SwiftUI's `HStack` already mirrors under `.environment(\.layoutDirection,
/// .rightToLeft)`, so no manual reordering is needed here).
///
/// Accepts both Latin (`123`) and Arabic-Indic (`١٢٣`) digit input,
/// normalizing to Latin internally via `MKRTLUtilities` (WS-01 packet §6);
/// `displaysArabicIndicDigits` controls whether the *displayed* value uses
/// Arabic-Indic numerals while the underlying `Double` binding always
/// stays Latin/`Double`.
public struct MKInspectorField: View {
    @Environment(\.mkTheme) private var theme
    private let label: String
    @Binding private var value: Double
    private let displaysArabicIndicDigits: Bool

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    public init(label: String, value: Binding<Double>, displaysArabicIndicDigits: Bool = false) {
        self.label = label
        self._value = value
        self.displaysArabicIndicDigits = displaysArabicIndicDigits
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(label)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
            Spacer(minLength: theme.spacing.sm)
            TextField("", text: $text)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
                .mkTypeStyle(theme.typeRamp.style(for: .body))
                .foregroundStyle(theme.ink)
                .focused($isFocused)
                .frame(minWidth: 56)
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
                .onSubmit { commit() }
                // U8-2: the placeholder is empty and the visible caption is
                // a sibling `Text`, so without this the field is nameless
                // to VoiceOver ، reuse the visible Arabic label verbatim.
                .accessibilityLabel(label)
        }
        .padding(.vertical, theme.spacing.xs)
        .onAppear { text = displayString(for: value) }
        .onChange(of: value) { _, newValue in
            if !isFocused { text = displayString(for: newValue) }
        }
    }

    private func displayString(for value: Double) -> String {
        let latin = formattedLatin(value)
        return displaysArabicIndicDigits ? MKRTLUtilities.toArabicIndicDigits(latin) : latin
    }

    private func formattedLatin(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    /// Normalizes the free-typed text (which may mix Arabic-Indic and
    /// Latin digits) to Latin, parses it, and ، if valid ، commits back to
    /// the `value` binding. Invalid input reverts the field to the last
    /// committed value rather than propagating garbage into the model.
    private func commit() {
        let normalized = MKRTLUtilities.toLatinDigits(text)
        if let parsed = Double(normalized) {
            value = parsed
            text = displayString(for: parsed)
        } else {
            text = displayString(for: value)
        }
    }
}
