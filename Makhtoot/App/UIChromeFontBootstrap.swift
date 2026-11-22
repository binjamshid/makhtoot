import CoreText
import Foundation
import MKFonts

/// Synchronously (and eagerly) registers just the handful of font files the
/// **design system's UI chrome** needs (`MKTheme.fonts` across all 5
/// themes ، wordmark, titles, body, mono labels), *before* `RootShellView`
/// is ever constructed.
///
/// `AppContainer.init` already registers the *full* bundled canvas-font
/// catalog (~45 families) via `MKFontRegistrar.registerBundledFontsAtLaunch()`
/// in a detached `Task` (`AppContainer.swift`) ، deliberately not gating
/// first paint, since nothing rendered with a custom font before this
/// design-system pass. Now that `MKTypeRamp` resolves every UI role via
/// `Font.custom(postScriptName:)`, an early frame could otherwise render
/// with SwiftUI's silent system-font fallback before that detached task
/// finishes. `CTFontManagerRegisterFontURLs` is synchronous for local file
/// URLs (see `MKFontRegistry.registerURL`'s own doc comment), so eagerly
/// registering just these ~9 files inline ، well under the full catalog's
/// already-fast ~150ms ، keeps `MakhtootApp.init` safely under its
/// established `<1ms` budget while guaranteeing the first frame has every
/// UI-chrome font available.
enum UIChromeFontBootstrap {
    /// `(family directory name, file name)` for every PostScript name any
    /// `MKFontSet` in `MakhtootKit/Sources/MKDesignSystem/Themes/` refers
    /// to. Keep in sync with those 5 theme files.
    private static let requiredFiles: [(family: String, file: String)] = [
        ("ArefRuqaa", "ArefRuqaa-Bold.ttf"),
        ("IbmPlexSansArabic", "IBMPlexSansArabic-Regular.ttf"),
        ("Amiri", "Amiri-Regular.ttf"),
        ("ReemKufi", "ReemKufi[wght].ttf"),
        ("ElMessiri", "ElMessiri[wght].ttf"),
        ("Tajawal", "Tajawal-Regular.ttf"),
        ("Lalezar", "Lalezar-Regular.ttf"),
        ("Cairo", "Cairo[slnt,wght].ttf"),
        ("IbmPlexMono", "IBMPlexMono-Regular.ttf"),
    ]

    static func registerSynchronously(bundle: Bundle = MKFontsResources.bundle) {
        for entry in requiredFiles {
            guard let familyDir = bundle.url(forResource: entry.family, withExtension: nil, subdirectory: "Fonts") else { continue }
            let fileURL = familyDir.appendingPathComponent(entry.file)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            CTFontManagerRegisterFontURLs([fileURL] as CFArray, .process, true) { _, _ in true }
        }
    }
}
