import SwiftUI

/// A token-styled slider. RTL mirroring (minimum value on the right, fill
/// growing leftward ، WS-01 packet §5 task 15 accept criterion) comes for
/// free from SwiftUI's native `Slider` honoring
/// `\.layoutDirection == .rightToLeft`, which the `ar` locale sets
/// app-wide (WS-01 packet §5 task 16) ، this wrapper adds theme tinting and
/// an optional Arabic label, it does not re-implement track layout.
public struct MKSlider: View {
    @Environment(\.mkTheme) private var theme
    private let label: String?
    @Binding private var value: Double
    private let range: ClosedRange<Double>

    public init(label: String? = nil, value: Binding<Double>, in range: ClosedRange<Double> = 0...1) {
        self.label = label
        self._value = value
        self.range = range
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            if let label {
                Text(label)
                    .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                    .foregroundStyle(theme.inkMuted)
                    // U8-2: the caption is re-exposed through the Slider's
                    // accessibility label below ، hide the visual copy so
                    // VoiceOver does not read the same string twice.
                    .accessibilityHidden(true)
            }
            Slider(value: $value, in: range) {
                // U8-2: SwiftUI does not render this label view on iOS ،
                // but VoiceOver uses it as the slider's name, so the
                // announced percentage is no longer nameless. Reuses the
                // visible Arabic caption verbatim; when `label` is nil the
                // wrapper never had a name to give, so the empty text
                // changes nothing. Adjustability (swipe up/down) stays
                // native ، which is why the label-closure route was chosen
                // over flattening with `.accessibilityElement(children:
                // .ignore)`.
                Text(label ?? "")
            }
            .tint(theme.primary)
        }
    }
}
