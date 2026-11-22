import MKDesignSystem
import MKFoundation
import SwiftUI

/// The app's top-level scene container (WS-13 packet §5 T3/T12). Decides
/// onboarding-vs-shell at launch, then switches `NavigationStack` (compact)
/// vs. `NavigationSplitView` (regular) by `horizontalSizeClass` ، the T3
/// navigation-architecture decision. Full adaptive-layout work (T12's
/// iPhone/iPad/Stage-Manager matrix, panel-side RTL verification) is scoped
/// to the editor slice; this is the routing skeleton only.
struct RootShellView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var nav = AppNavigationModel()
    @State private var openURLErrorText: String?

    /// EU-3 (AUDIT_2026-07-28.md): scene-level mirror of
    /// `nav.lastOpenProjectID`, restored automatically by SwiftUI/UIKit
    /// scene-state restoration across an OS-managed background-suspend-
    /// then-terminate cycle (the exact "iOS terminates the app in the
    /// background" scenario the finding names) without needing the app to
    /// have written anything itself first. `nav.lastOpenProjectID`
    /// (`UserDefaults`-backed, see that property's own doc comment) is the
    /// primary/more durable source `attemptStateRestorationIfNeeded()`
    /// prefers ، it also survives a genuine user force-quit, which scene
    /// state is not guaranteed to. This is kept in sync as a fallback for
    /// the (rare) case `UserDefaults` hasn't been read back yet but the
    /// scene-restoration archive already has a value.
    @SceneStorage("mk.restoration.lastOpenProjectID") private var restorationProjectIDString: String?
    /// Guards `attemptStateRestorationIfNeeded()` against firing more than
    /// once per `RootShellView` instance (e.g. a scene reconnect re-running
    /// `.task`).
    @State private var didAttemptStateRestoration = false

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            #if DEBUG
            // Path Text harness direct-entry hook (packet task 16's
            // screenshot-evidence gate: `-mkPathHarnessFixture <0..4>` +
            // `-mkPathHarnessPath circle|arc|wave|scurve`, mirroring
            // `ProjectBrowserView`/`EditorScene`'s existing
            // `-mkE2EArrangeDrive` DEBUG launch-arg pattern). This
            // environment has no interactive tap injection (see
            // `EditorViewModel.debugRunE2EArrangeSequence`'s own header for
            // the confirmed finding), so the harness ، normally several
            // taps deep under Settings → Debug ، needs a way to land
            // directly on a preselected fixture for an external
            // `xcrun simctl io screenshot` pass.
            if let launch = Self.debugPathHarnessLaunch {
                NavigationStack {
                    PathTextHarnessView(initialFixtureIndex: launch.fixtureIndex, initialPathFixture: launch.pathFixture)
                }
            } else {
                normalContent
            }
            #else
            normalContent
            #endif
        }
        // T17: close the cold-launch signpost interval on the first frame
        // the user actually sees, whichever branch above it is (onboarding
        // on first launch ever, the shell on every launch after).
        .onAppear { MKLaunchTimer.shared.endIfNeeded() }
        // EU-3 (AUDIT_2026-07-28.md): re-enters the editor for whichever
        // project was open when the app was last backgrounded/terminated,
        // instead of always landing on the browser after a background kill.
        .task { await attemptStateRestorationIfNeeded() }
        // ORDER IS LOAD-BEARING ، `.environment(nav)` is applied at the END
        // of this chain, below `.alert`, NOT here. `.environment(_:)` writes
        // into the subtree of the view it modifies; a presentation modifier
        // attached AFTER it wraps it, so the attachment point sits OUTSIDE
        // the write and the presented content inherits an environment with
        // no `nav` in it. When `.environment(nav)` sat here, above these two
        // modifiers, `EditorScene` reached through the `.fullScreenCover`
        // below (the iPad/regular-width editor route ، `openEditor(_:
        // isRegularWidth:)`) trapped on its `@Environment(
        // AppNavigationModel.self)` with
        //     Fatal error: No Observable object of type AppNavigationModel found.
        // The compact idiom was unaffected because it pushes the editor into
        // `compactShell`'s `NavigationStack`, which IS inside the write ،
        // which is exactly why this read as iPad-only and why the 2026-07-29
        // report could not be reproduced from the browser alone.
        //
        // Consequences, both reproduced on an iPad Pro 13" simulator before
        // this fix: creating a project crashed the app the moment the editor
        // presented, and every subsequent LAUNCH crashed too ، EU-3 state
        // restoration (`attemptStateRestorationIfNeeded()` above) re-opened
        // the same project into the same broken cover, so one created
        // project bricked the install until it was deleted.
        //
        // The per-closure `.environment(nav)` calls below are deliberate
        // belt-and-braces, not redundancy to tidy away: they keep the
        // presented content correct even if someone later reorders this
        // chain. This is the actual root cause behind the two "defensive"
        // nav removals in `GeneralSettingsView`/`SettingsPlaceholderView`
        // (1f6fe79) ، those views were reached through `.sheet` below and
        // hit the same missing write. Their closure-threaded `onResetOnboarding`
        // still works and is left alone; nothing else should need that
        // treatment now.
        .sheet(item: $nav.presentedSheet) { route in
            sheetContent(for: route)
                .environment(nav)
        }
        .fullScreenCover(item: $nav.presentedFullScreenCover) { route in
            fullScreenCoverContent(for: route)
                .environment(nav)
        }
        // WS-15 ITMS-90737 follow-up: a `.makhtoot` package opened from
        // Files.app/AirDrop/"Open In" (`LSSupportsOpeningDocumentsInPlace`,
        // `Info.plist`). KNOWN LIMITATION, not solved here: if onboarding
        // has never completed, `nav.path` (the compact/`NavigationStack`
        // route) only takes visible effect once `OnboardingView` finishes,
        // since `compactShell` ، where that path lives ، only renders
        // inside the `nav.hasCompletedOnboarding` branch; the regular-width
        // `fullScreenCover` route above presents immediately either way,
        // since that modifier sits on this outer `Group` regardless of
        // which branch is showing underneath. A brand-new user's very
        // first-ever action being "open a shared file before ever launching
        // the app" is a narrow edge case, flagged rather than engineered
        // around.
        .onOpenURL { url in
            Task { await openExternalPackage(at: url) }
        }
        .alert(
            openURLErrorTitle,
            isPresented: Binding(get: { openURLErrorText != nil }, set: { if !$0 { openURLErrorText = nil } })
        ) {
            Button(openURLErrorOK) { openURLErrorText = nil }
        } message: {
            Text(openURLErrorText ?? "")
        }
        // Applied LAST, so every modifier above ، including the `.sheet` and
        // `.fullScreenCover` presentations ، sits inside this write and their
        // content inherits `nav`. See the long note on those two modifiers
        // before moving this line back up the chain.
        .environment(nav)
    }

    /// Brackets the security-scoped resource access Apple requires for a
    /// document delivered via `.onOpenURL` this way ، no other code in this
    /// app has needed to do this before now (font import uses a different
    /// mechanism entirely, see `MKFontImporter.swift`'s own note on that
    /// responsibility split).
    private func openExternalPackage(at url: URL) async {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let opened = try await container.projectLibrary.importExternalPackage(at: url)
            nav.openEditor(opened.id, isRegularWidth: isRegularWidth)
        } catch let importError as ProjectImportError {
            openURLErrorText = openURLErrorBody(for: importError)
        } catch {
            // Not a `ProjectImportError` at all (e.g. the security-scoped
            // access above never even started) ، fall back to the same
            // generic message the whole alert used to show for every cause.
            openURLErrorText = openURLErrorBody(for: nil)
        }
    }

    /// EU-3 (AUDIT_2026-07-28.md): runs once per `RootShellView` instance
    /// (`didAttemptStateRestoration` guards a second `.task` firing, e.g. a
    /// scene reconnect). Prefers `nav.lastOpenProjectID` (the more durable,
    /// `UserDefaults`-backed source ، see that property's own doc comment)
    /// and falls back to the `@SceneStorage` mirror only if that's somehow
    /// empty. Fine-grained chrome (zoom scale, content offset, selection)
    /// is intentionally NOT restored from here: `EditorViewModel` owns that
    /// restoration itself, self-contained per project id, because this
    /// wave's fence forbids editing `EditorScene.swift` ، the ONLY call
    /// site that constructs an `EditorViewModel` ، which would otherwise be
    /// required to hand a zoom/offset/selection payload from here into a
    /// freshly-created view model's `init`/`restore(_:)`. See this agent's
    /// EXECUTION_PLAN_2026-07-28.md Wave 3 Agent 3.3 section for the exact
    /// constraint; `EditorViewModel.swift`'s own "MARK: - EU-3 state
    /// restoration" section carries that half of this finding.
    ///
    /// Waits for `container.projectLibrary.refreshFromDisk()` ،
    /// `MKPersistenceProjectLibrary`'s bootstrap/`LaunchReconciler` full
    /// pass (see that type's own header comment) ، before navigating, so a
    /// project deleted or made unavailable while the app was gone is never
    /// opened into a broken state; `packageRootURL(for:)` returning `nil`
    /// after that pass means "don't restore," not "retry."
    private func attemptStateRestorationIfNeeded() async {
        guard !didAttemptStateRestoration else { return }
        didAttemptStateRestoration = true
        #if DEBUG
        // Never hijack the screenshot/UI-test harness's direct-entry hook
        // (`Self.debugPathHarnessLaunch`, checked in `body` above) into
        // auto-navigating somewhere else first.
        guard Self.debugPathHarnessLaunch == nil else { return }
        #endif
        guard nav.hasCompletedOnboarding else { return }
        guard nav.path.isEmpty, nav.presentedFullScreenCover == nil else { return }
        let candidateIDString = nav.lastOpenProjectID?.rawValue.uuidString ?? restorationProjectIDString
        guard let idString = candidateIDString, let uuid = UUID(uuidString: idString) else { return }
        let candidateID = MKProjectID(rawValue: uuid)
        await container.projectLibrary.refreshFromDisk()
        guard await container.projectLibrary.packageRootURL(for: candidateID) != nil else {
            // The project this points to no longer resolves to a package on
            // disk (deleted while the app was gone, or never real to begin
            // with) ، clear both restoration sources rather than retrying
            // forever on every future launch.
            nav.lastOpenProjectID = nil
            restorationProjectIDString = nil
            return
        }
        restorationProjectIDString = idString
        nav.openEditor(candidateID, isRegularWidth: isRegularWidth)
    }

    /// EU-3: only clears the marker if it still points at `id` ، guards
    /// against a rare cross-talk case (e.g. two dismiss closures racing
    /// across idiom changes) clobbering a DIFFERENT project's freshly-set
    /// restoration marker.
    private func clearRestorationMarker(for id: MKProjectID) {
        if nav.lastOpenProjectID == id { nav.lastOpenProjectID = nil }
        if restorationProjectIDString == id.rawValue.uuidString { restorationProjectIDString = nil }
    }

    private var openURLErrorTitle: String {
        // Latin gloss: could not open the file
        "تعذّر فتح الملف"
    }

    /// UX-5: distinct Arabic message per `ProjectImportError` case, rather
    /// than the one generic sentence every import failure used to collapse
    /// into.
    private func openURLErrorBody(for error: ProjectImportError?) -> String {
        switch error {
        case .missingPackage, nil:
            // Latin gloss: this file is not a valid Makhtoot project
            return "هذا الملف ليس مشروع مخطوط صالحًا"
        case .malformedManifest:
            // Latin gloss: this project's data could not be read ، the file may be damaged
            return "تعذّرت قراءة بيانات هذا المشروع ، قد يكون الملف تالفًا"
        case .copyFailed:
            // Latin gloss: this project could not be imported ، check available storage on your device and try again
            return "تعذّر استيراد هذا المشروع ، تحقّق من المساحة المتوفرة على جهازك وحاول مرة أخرى"
        }
    }

    private var openURLErrorOK: String {
        // Latin gloss: OK
        "حسنًا"
    }

    /// The original onboarding-vs-shell top-level switch, unchanged ،
    /// pulled into its own property so the DEBUG harness-launch branch
    /// above can short-circuit it without duplicating the branch body in
    /// both halves of the `#if DEBUG`.
    @ViewBuilder
    private var normalContent: some View {
        if nav.hasCompletedOnboarding {
            shell
        } else {
            OnboardingView(
                onFinished: { nav.completeOnboarding() },
                onShowPaywall: { nav.presentPaywall(.onboardingTrialIntro) }
            )
        }
    }

    #if DEBUG
    /// Parses `-mkPathHarnessPath circle|arc|wave|scurve` and the optional
    /// `-mkPathHarnessFixture <0..4>` (index into
    /// `PathTextHarnessView.presetStrings`, defaulting to `2` = «سلام Hello
    /// ٤٥» when absent or out of range ، `PathTextHarnessView.init`'s own
    /// clamp is the second line of defense). `nil` (not present at all) is
    /// the normal-launch case ، every OTHER DEBUG launch-arg hook in this
    /// app checks `ProcessInfo.processInfo.arguments.contains(...)`
    /// directly at its own call site; this one needs an associated VALUE
    /// (which fixture), so it is a small static computed property instead.
    private static var debugPathHarnessLaunch: (fixtureIndex: Int, pathFixture: PathTextHarnessView.PathFixture)? {
        let args = ProcessInfo.processInfo.arguments
        guard let pathIndex = args.firstIndex(of: "-mkPathHarnessPath"), pathIndex + 1 < args.count else { return nil }
        let pathFixture: PathTextHarnessView.PathFixture
        switch args[pathIndex + 1] {
        case "circle": pathFixture = .circle
        case "arc": pathFixture = .arc
        case "wave": pathFixture = .wave
        case "scurve": pathFixture = .sCurve
        default: pathFixture = .circle
        }
        var fixtureIndex = 2
        if let fixtureArgIndex = args.firstIndex(of: "-mkPathHarnessFixture"), fixtureArgIndex + 1 < args.count, let parsed = Int(args[fixtureArgIndex + 1]) {
            fixtureIndex = parsed
        }
        return (fixtureIndex, pathFixture)
    }
    #endif

    // MARK: - Idiom switch (T3)

    @ViewBuilder
    private var shell: some View {
        if isRegularWidth {
            regularShell
        } else {
            compactShell
        }
    }

    /// iPhone / compact-width iPad: single `NavigationStack`, browser is
    /// root, editor pushes.
    private var compactShell: some View {
        NavigationStack(path: $nav.path) {
            ProjectBrowserView(onOpenSettings: { nav.presentSettings() })
                .navigationDestination(for: MKRoute.self) { route in
                    pushedDestination(for: route)
                }
        }
    }

    /// iPad / regular width: `NavigationSplitView` ، sidebar switches
    /// between the two top-level scenes this slice ships (browser,
    /// settings); editor still presents as a full-screen cover per T3.
    private var regularShell: some View {
        NavigationSplitView {
            List(selection: $nav.sidebarSelection) {
                Label(browserSidebarLabel, systemImage: "square.grid.2x2")
                    .tag(AppNavigationModel.SidebarItem.browser)
                Label(settingsSidebarLabel, systemImage: "gearshape")
                    .tag(AppNavigationModel.SidebarItem.settings)
            }
            .navigationTitle(Text(appTitle))
        } detail: {
            NavigationStack {
                switch nav.sidebarSelection ?? .browser {
                case .browser:
                    ProjectBrowserView(onOpenSettings: { nav.sidebarSelection = .settings })
                case .settings:
                    SettingsPlaceholderView(showsCloseButton: false, onResetOnboarding: { nav.resetOnboarding() })
                }
            }
        }
    }

    // MARK: - Route → view

    @ViewBuilder
    private func pushedDestination(for route: MKRoute) -> some View {
        switch route {
        case .browser:
            ProjectBrowserView(onOpenSettings: { nav.presentSettings() })
        case .editor(let id):
            EditorScene(projectID: id) {
                // EU-3: a deliberate "done editing" dismissal ، don't
                // auto-restore back into this project on the next cold
                // launch (see `nav.lastOpenProjectID`'s own doc comment).
                clearRestorationMarker(for: id)
                if !nav.path.isEmpty { nav.path.removeLast() }
            }
        case .settings:
            SettingsPlaceholderView(showsCloseButton: false, onResetOnboarding: { nav.resetOnboarding() })
        case .paywall(let context):
            PaywallView(context: context) {
                if !nav.path.isEmpty { nav.path.removeLast() }
            }
        case .onboarding:
            OnboardingView(
                onFinished: { nav.completeOnboarding() },
                onShowPaywall: { nav.presentPaywall(.onboardingTrialIntro) }
            )
        }
    }

    @ViewBuilder
    private func sheetContent(for route: MKRoute) -> some View {
        switch route {
        case .settings:
            NavigationStack {
                SettingsPlaceholderView(showsCloseButton: true, onResetOnboarding: { nav.resetOnboarding() })
            }
        case .paywall(let context):
            PaywallView(context: context) {
                nav.presentedSheet = nil
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func fullScreenCoverContent(for route: MKRoute) -> some View {
        if case .editor(let id) = route {
            NavigationStack {
                EditorScene(projectID: id) {
                    // EU-3: same deliberate-dismissal clear as the compact
                    // idiom's `pushedDestination(for:)` case above.
                    clearRestorationMarker(for: id)
                    nav.presentedFullScreenCover = nil
                }
            }
        }
    }

    // MARK: - Strings

    private var appTitle: String {
        // Latin gloss: app name (Makhtoot)
        "مخطوط"
    }

    private var browserSidebarLabel: String {
        // Latin gloss: projects (sidebar item)
        "المشاريع"
    }

    private var settingsSidebarLabel: String {
        // Latin gloss: settings (sidebar item)
        "الإعدادات"
    }
}

#Preview {
    RootShellView()
        .environment(\.mkTheme, HibrTheme.default)
        .environment(AppContainer())
}
