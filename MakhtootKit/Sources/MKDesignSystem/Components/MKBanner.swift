import Accessibility
import SwiftUI

/// The severity of an inline banner. `warning` is used for the D-116
/// stage-2 memory-pressure notice; `info`/`destructive` are available for
/// grace-period (D-113) and sync-error messaging (WS-11/WS-12).
public enum MKBannerSeverity: Sendable {
    case info
    case warning
    case destructive
}

/// An inline banner component. First real consumer (later workstream):
/// the D-116 stage-2 memory-pressure warning ،
/// "الذاكرة شبه ممتلئة ، تم الحفظ تلقائيًا" (Latin gloss: memory nearly
/// full ، autosaved).
public struct MKBanner: View {
    @Environment(\.mkTheme) private var theme
    private let message: String
    private let severity: MKBannerSeverity

    public init(message: String, severity: MKBannerSeverity = .info) {
        self.message = message
        self.severity = severity
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image(systemName: iconName)
                .foregroundStyle(color)
            Text(message)
                .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                .foregroundStyle(theme.ink)
            Spacer(minLength: 0)
        }
        .padding(theme.spacing.md)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                .strokeBorder(color.opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            // U8-2: banners appear mid-task (e.g. the D-116 stage-2
            // memory-pressure notice) with no VoiceOver announcement ، a
            // non-sighted user would never learn one was presented. Post
            // the message via the platform-neutral Accessibility framework
            // API (covers both the iOS 18 and macOS 14 floors). The Text
            // already carries `.isStaticText`, so no trait change is
            // needed here.
            AccessibilityNotification.Announcement(message).post()
        }
    }

    private var color: Color {
        switch severity {
        case .info: return theme.primary
        case .warning: return theme.warning
        case .destructive: return theme.destructive
        }
    }

    private var iconName: String {
        switch severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .destructive: return "xmark.octagon.fill"
        }
    }
}
