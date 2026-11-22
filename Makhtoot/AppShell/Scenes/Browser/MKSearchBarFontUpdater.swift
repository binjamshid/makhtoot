import SwiftUI
import UIKit

/// `.searchable(...)` is backed by a native `UISearchBar`/`UISearchTextField`
/// ، SwiftUI has no font modifier that reaches into it, so left alone it
/// always renders in the system font regardless of the active `MKTheme`.
///
/// Two things are needed to actually keep it on-theme:
/// 1. An `appearance(whenContainedInInstancesOf:)` proxy, so any search
///    bar created (or re-created) after a theme change already gets the
///    right font.
/// 2. A direct walk of the key window's already-live view hierarchy,
///    since an *existing* search bar doesn't re-read the appearance proxy
///    on its own ، `.searchable`'s underlying `UISearchController` is not
///    guaranteed to be torn down and rebuilt just because the SwiftUI
///    environment's `\.mkTheme` value changed.
enum MKSearchBarFontUpdater {
    @MainActor
    static func apply(postScriptName: String, size: CGFloat = 17) {
        guard let font = UIFont(name: postScriptName, size: size) else { return }
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font = font
        // `.searchable`'s `UISearchController` can attach its search bar to
        // the window well after this view's `.onAppear` fires (observed:
        // a single 0.3s retry was not always enough), and there's no
        // SwiftUI hook that fires exactly when it does ، so retry a few
        // times over ~1.5s rather than relying on one fixed delay.
        for delay in [0, 0.15, 0.3, 0.6, 1.0, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                walkAndApply(font)
            }
        }
    }

    @MainActor
    private static func walkAndApply(_ font: UIFont) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                applyFont(font, in: window)
            }
        }
    }

    @MainActor
    private static func applyFont(_ font: UIFont, in view: UIView) {
        if let searchBar = view as? UISearchBar {
            searchBar.searchTextField.font = font
        }
        if let searchField = view as? UISearchTextField {
            searchField.font = font
        }
        for subview in view.subviews {
            applyFont(font, in: subview)
        }
    }
}
