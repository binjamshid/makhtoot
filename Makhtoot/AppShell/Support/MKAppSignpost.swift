import MKFoundation
import os

/// App-shell-local `OSSignposter` intervals (WS-13 packet §5 T17: "launch,
/// browser, editorOpen" categories). Kept separate from `MKFoundation`'s
/// `MKSignpost` (which is the closed, cross-module D-115 engine-budget
/// vocabulary ، `manipulationFrame`/`typingEcho`/`documentOpen`/`autosave`/
/// `export`, owned by WS-01 and out of this packet's edit fence) rather than
/// added as new cases there: this run's scope fence is `Makhtoot/` +
/// `Makhtoot.xcodeproj` only, `MKFoundation` sources are not touched by any
/// WS-13 session. `MKPersistence.MakhtootDocument.open` already emits its
/// own `MKSignpost.documentOpen` interval ، this app-local `editorOpen`
/// interval instead measures the SHELL's own routing latency (tap → route
/// pushed/covered → first frame of the destination scene), which is a
/// distinct measurement from the persistence layer's document-open time.
enum MKAppSignpost: String, Sendable {
    case launch
    case browserScroll
    case editorOpen

    static let signposter = OSSignposter(logger: MKLog.logger(for: "AppSignpost"))
}

/// One-shot cold-launch timer (T17: "cold launch <1 s to interactive
/// browser, A15" ، D-115). `MakhtootApp.init` triggers `shared`'s lazy
/// creation (begins the interval at the earliest possible moment ،
/// `@main`'s own `init`, before `AppContainer`/`RootShellView` exist);
/// `RootShellView` calls `endIfNeeded()` on the first appearance of either
/// the onboarding flow or the browser shell (whichever is the actual first
/// frame the user sees), whichever comes first, exactly once per process.
@MainActor
final class MKLaunchTimer {
    static let shared = MKLaunchTimer()

    private var state: OSSignpostIntervalState?
    private var hasEnded = false

    private init() {
        state = MKAppSignpost.signposter.beginInterval("launch")
    }

    func endIfNeeded() {
        guard !hasEnded, let state else { return }
        hasEnded = true
        MKAppSignpost.signposter.endInterval("launch", state)
    }
}
