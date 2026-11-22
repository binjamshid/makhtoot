import MKDesignSystem
import SwiftUI

/// The D-116 memory-pressure banner region (packet T11 AC: "banner region
/// renders when WS-07 stub emits stage 2"). Reads
/// `EditorViewModel.memoryBannerText`, itself sourced from a REAL
/// `MKDegradationController`/`MKMemoryPressureMonitor` (WS-07) this
/// session wires up ، see `EditorViewModel.swift`.
struct MemoryBannerView: View {
    let viewModel: EditorViewModel

    var body: some View {
        if let text = viewModel.memoryBannerText {
            MKBanner(message: text, severity: .warning)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Surfaces `MKArrangeInteractionModel.lastErrorMessage` (Bug 16 fix): every
/// `enterArrangeMode` refusal now sets an honest, actionable message ،
/// before this view existed, `lastErrorMessage` had NO reader anywhere
/// except a `#if DEBUG` E2E log line, so a refused wand-tap looked
/// completely silent to a real user. Tap-to-dismiss (`dismissError()`)
/// rather than a timed auto-hide ، the message stays put until the user has
/// actually read it or tries again (a fresh `enterArrangeMode` call always
/// clears it first regardless).
struct ArrangeErrorBannerView: View {
    let viewModel: EditorViewModel

    var body: some View {
        if let text = viewModel.arrangeInteraction.lastErrorMessage {
            MKBanner(message: text, severity: .destructive)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.arrangeInteraction.dismissError() }
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Subtle autosave indicator (packet T11: "autosave indicator (subtle,
/// from MKPersistence status)").
struct AutosaveIndicatorView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            Circle()
                .fill(viewModel.isDirty ? theme.warning : theme.primary)
                .frame(width: 6, height: 6)
            Text(viewModel.isDirty ? savingText : savedText)
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private var savingText: String {
        // Latin gloss: saving…
        "جارٍ الحفظ…"
    }
    private var savedText: String {
        // Latin gloss: saved
        "تم الحفظ"
    }
}
