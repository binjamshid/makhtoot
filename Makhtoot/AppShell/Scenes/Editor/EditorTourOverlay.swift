import MKDesignSystem
import SwiftUI

/// In-editor first-use guided tour overlay. Consumes `EditorTourModel` from
/// the environment. Uses a `Canvas` with `destinationOut` blend mode to cut a
/// spotlight hole over the currently-highlighted button. Button frames in the
/// model are in `.global` coordinate space; a surrounding `GeometryReader`
/// converts them to the overlay's local space for canvas rendering.
struct EditorTourOverlay: View {
    let tourModel: EditorTourModel
    @Environment(\.mkTheme) private var theme

    var body: some View {
        if !tourModel.isCompleted {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                let globalH = tourModel.currentHighlightFrame
                let localH = CGRect(
                    x: globalH.minX - origin.x,
                    y: globalH.minY - origin.y,
                    width: globalH.width,
                    height: globalH.height
                )

                ZStack {
                    Canvas { ctx, size in
                        ctx.fill(
                            Path(CGRect(origin: .zero, size: size)),
                            with: .color(.black.opacity(0.55))
                        )
                        if !globalH.isEmpty {
                            ctx.blendMode = .destinationOut
                            ctx.fill(
                                Path(roundedRect: localH.insetBy(dx: -12, dy: -12), cornerRadius: 12),
                                with: .color(.white)
                            )
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    calloutBubble
                        .frame(width: min(proxy.size.width - 32, 320))
                        .position(
                            x: proxy.size.width / 2,
                            y: globalH.isEmpty
                                ? proxy.size.height / 2 - 80
                                : max(localH.minY - 120, 100)
                        )
                }
            }
            .animation(.easeInOut(duration: 0.25), value: tourModel.step)
        }
    }

    private var calloutBubble: some View {
        VStack(alignment: .trailing, spacing: 14) {
            stepDots

            VStack(alignment: .trailing, spacing: 6) {
                Text(tourModel.currentTitle)
                    .mkTypeStyle(theme.typeRamp.style(for: .title))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(tourModel.currentBody)
                    .mkTypeStyle(theme.typeRamp.style(for: .body))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(skipLabel) { tourModel.skip() }
                    .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                Button(tourModel.isLastStep ? startLabel : nextLabel) {
                    tourModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .controlSize(.small)
            }
        }
        .padding(18)
        .background(
            theme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
    }

    private var stepDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<tourModel.stepCount, id: \.self) { i in
                Capsule()
                    .fill(i == tourModel.step ? theme.primary : theme.inkMuted.opacity(0.25))
                    .frame(width: i == tourModel.step ? 16 : 5, height: 5)
                    .animation(.spring(duration: 0.25), value: tourModel.step)
            }
            Spacer()
        }
    }

    private var skipLabel: String { "تخطى" }
    private var nextLabel: String { "التالي" }
    private var startLabel: String { "ابدأ" }
}
