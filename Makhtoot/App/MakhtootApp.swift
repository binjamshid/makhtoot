import MKDesignSystem
import SwiftUI

/// The `@main` SwiftUI entry point (WS-01 packet §5 task 17, extended by
/// WS-13 packet §5 T2). Installs the active `MKTheme` and the `AppContainer`
/// composition root (D-231) into the environment and hosts `RootShellView`
/// ، the real navigation shell (WS-13) ، in a single `WindowGroup`;
/// Makhtoot is single-window in v1 (`UIApplicationSupportsMultipleScenes =
/// NO`, FILE_MAP §3.1).
///
/// The app is Arabic-only by construction (D-100): `Localizable.xcstrings`
/// ships exactly one language (`ar`) and `CFBundleDevelopmentRegion` is
/// `ar`, so the system presents the whole UI in Arabic/RTL regardless of
/// the device's own locale ، no `layoutDirection` override is applied
/// here (WS-01 packet §5 task 16: forced RTL follows the `ar` locale
/// naturally, it is not hacked in via `semanticContentAttribute`).
///
/// **Bootstrap ordering note (WS-13 packet §5 T2), updated this
/// P1-COMPLETION session:** `AppContainer.init` remains synchronous and
/// `<1 ms` (still true even with the real `MKPersistenceProjectLibrary`
/// wired in ، its `init` only captures URLs, see that type's header
/// comment for why the actual `MetadataStore`/`LaunchReconciler` I/O is
/// deferred to first use rather than done here). Font registration kickoff,
/// entitlement resolver start, sync controller, and analytics init still
/// have no real subsystems to order (WS-09/WS-10/WS-11/WS-12 not yet
/// landed) ، a `TaskGroup` bootstrap scaffold with only those stubs behind
/// it remains dead ceremony, per the previous session's reasoning. Only the
/// persistence leg of T2's ordering is now real, and it deliberately does
/// NOT block first paint (see `MKPersistenceProjectLibrary`'s lazy
/// bootstrap).
@main
struct MakhtootApp: App {
    /// Design-system theme selection (`MKThemeID`) and the light/dark/
    /// system appearance override ، both user preferences in Settings
    /// (`GeneralSettingsView`'s new "المظهر" section), `mk.*`-namespaced
    /// per the app's existing `@AppStorage` convention. `App` structs
    /// re-evaluate `body` on `@AppStorage` change exactly like `View`s, so
    /// changing either preference live re-themes the whole app with no
    /// extra observable store needed.
    @AppStorage("mk.appearance.themeID") private var themeIDRaw: String = MKThemeID.hibr.rawValue
    @AppStorage("mk.appearance.colorScheme") private var colorSchemeRaw: String = "system"
    @State private var container = AppContainer()

    private var theme: any MKTheme {
        (MKThemeID(rawValue: themeIDRaw) ?? .hibr).resolve()
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    init() {
        // See `UIChromeFontBootstrap`'s header: registers the design
        // system's ~9 UI-chrome font files synchronously, ahead of the
        // full async canvas-catalog registration `AppContainer.init`
        // already kicks off, so the first frame never falls back to a
        // system font for the wordmark/titles/labels.
        UIChromeFontBootstrap.registerSynchronously()
    }

    var body: some Scene {
        // T17 launch-performance signpost (packet §5 T17): starts the
        // "launch" interval as early as SwiftUI first evaluates this
        // `@MainActor`-isolated `body` (the earliest MainActor-safe point ،
        // `App.init()` itself is not guaranteed MainActor-isolated, so the
        // interval cannot safely start there under Swift 6 strict
        // concurrency); `RootShellView` closes it on the first real frame
        // the user sees. `MKLaunchTimer.shared`'s lazy-static construction
        // means this only actually begins the interval once regardless of
        // how many times SwiftUI re-evaluates `body`.
        _ = MKLaunchTimer.shared
        return WindowGroup {
            RootShellView()
                .environment(\.mkTheme, theme)
                .environment(container)
                .preferredColorScheme(preferredColorScheme)
        }
    }
}
