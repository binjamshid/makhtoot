import Foundation
import MKFoundation
import Observation

/// The navigation architecture (WS-13 packet §5 T3): a route model plus an
/// `@Observable` navigation state object, shared by both idioms.
///
/// - **iPhone / compact:** `NavigationStack` rooted at the browser; editor
///   pushes onto `path` (full-screen by construction of `NavigationStack`);
///   settings presents as a sheet.
/// - **iPad / regular:** `NavigationSplitView` (sidebar = browser/settings
///   switch, content = the selected scene); editor presents as a
///   `fullScreenCover` with its own internal panel layout.
///
/// `RootShellView` is the sole owner of one `AppNavigationModel` instance
/// per window (single-window app, D-100/FILE_MAP §3.1) and injects it via
/// `.environment(_:)`; every other shell view reads it via
/// `@Environment(AppNavigationModel.self)`.
@Observable
@MainActor
final class AppNavigationModel {
    /// Push stack for the compact `NavigationStack`. `.browser` is always
    /// the implicit root and never appears in `path`.
    var path: [MKRoute] = []

    /// Settings sheet on iPhone.
    var presentedSheet: MKRoute?

    /// iPad-only full-screen-cover route for the editor (T3: "editor =
    /// full-screen cover... on iPad"). iPhone instead pushes `.editor` onto
    /// `path`.
    var presentedFullScreenCover: MKRoute?

    /// Regular-width (iPad) sidebar selection. Optional because SwiftUI's
    /// `List(selection:)` single-selection initializer requires
    /// `Binding<SelectionValue?>` ، `RootShellView` treats `nil` as
    /// `.browser` (the default landing scene).
    var sidebarSelection: SidebarItem? = .browser

    enum SidebarItem: Hashable {
        case browser
        case settings
    }

    /// P5.3: `NewProjectSheet`'s "ابدأ من صورة" (start from photo) entry
    /// creates the project (via `ProjectBrowserView.createProjectFromPhoto`,
    /// the SAME `createProject`-then-`openEditor` path every other preset
    /// uses) BEFORE a real `MakhtootDocument`/`MKAssetStore` exists to
    /// ingest into ، the photo's bytes have nowhere to land until the
    /// freshly-opened `EditorScene`'s own `EditorViewModel` exists. This
    /// carries the picked photo across that gap: `ProjectBrowserView` sets
    /// it right before navigating, `EditorScene.open()` consumes (and
    /// clears) it once the matching project's `EditorViewModel` is ready,
    /// using the same background image import path as the editor.
    struct PendingBackgroundImageImport {
        let projectID: MKProjectID
        let data: Data
    }
    var pendingBackgroundImageImport: PendingBackgroundImageImport?

    private static let hasCompletedOnboardingKey = "MKHasCompletedOnboarding"
    private static let lastOpenProjectIDKey = "MKLastOpenProjectID"

    /// First-launch onboarding completion, persisted in `UserDefaults`.
    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Self.hasCompletedOnboardingKey)
        }
    }

    /// EU-3 (AUDIT_2026-07-28.md): the project the user was last inside the
    /// editor for, persisted the SAME `UserDefaults`-latch way
    /// `hasCompletedOnboarding` is above ، deliberately plain
    /// `UserDefaults`, not `@SceneStorage` alone, because the finding this
    /// closes is specifically "iOS terminates the app in the background",
    /// which must survive a genuine process death, not just an OS-managed
    /// suspend/resume of the same scene. `RootShellView` reads this once,
    /// on its own first appearance, to decide whether to auto-navigate
    /// straight back into the editor instead of landing on the browser
    /// (`RootShellView.attemptStateRestorationIfNeeded()`); `openEditor`
    /// below sets it every time the editor opens, and `RootShellView`'s own
    /// dismiss closures (`pushedDestination(for:)`/
    /// `fullScreenCoverContent(for:)`) clear it back to `nil` once the user
    /// deliberately backs out to the browser, so a normal "done editing"
    /// flow never causes a surprise re-entry into the editor on the next
    /// cold launch.
    var lastOpenProjectID: MKProjectID? {
        didSet {
            if let lastOpenProjectID {
                UserDefaults.standard.set(lastOpenProjectID.rawValue.uuidString, forKey: Self.lastOpenProjectIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastOpenProjectIDKey)
            }
        }
    }

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.hasCompletedOnboardingKey)
        if let uuidString = UserDefaults.standard.string(forKey: Self.lastOpenProjectIDKey),
           let uuid = UUID(uuidString: uuidString) {
            lastOpenProjectID = MKProjectID(rawValue: uuid)
        } else {
            lastOpenProjectID = nil
        }
    }

    /// Routes to the editor for `id`, choosing push-vs-cover per T3's
    /// per-idiom strategy. EU-3: also records `id` as the project to
    /// auto-restore into if the app is killed while this editor session is
    /// still open ، see `lastOpenProjectID`'s own doc comment.
    func openEditor(_ id: MKProjectID, isRegularWidth: Bool) {
        lastOpenProjectID = id
        if isRegularWidth {
            presentedFullScreenCover = .editor(id)
        } else {
            path.append(.editor(id))
        }
    }

    func presentSettings() {
        presentedSheet = .settings
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    /// EU-7 (AUDIT_2026-07-28.md): clears the one-way `hasCompletedOnboarding`
    /// latch (the mirror image of `completeOnboarding()` above) so a user
    /// who tapped «تخطى» (skip) on first launch ، the common case, per the
    /// finding ، can replay the onboarding screens from
    /// `GeneralSettingsView`. Also unwinds whatever navigation is currently
    /// showing back to the root: `RootShellView.normalContent` switches to
    /// `OnboardingView` purely off `hasCompletedOnboarding`, independent of
    /// `presentedSheet`/`path`/`presentedFullScreenCover`, so without this
    /// the onboarding screens would render BEHIND whatever sheet (this very
    /// Settings screen, reached through several pushed/presented levels)
    /// triggered the reset, rather than replacing it on screen.
    func resetOnboarding() {
        hasCompletedOnboarding = false
        presentedSheet = nil
        presentedFullScreenCover = nil
        path = []
    }
}
