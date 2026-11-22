import Foundation
import MKFoundation
import os

// WS-07 packet §5 task 13. `os_signpost` instrumentation for every D-115
// budget MKRender itself is on the hook for, plus the render-internal
// categories (`renderTile`, `layerSync`, `pathRelayout`) the packet's
// task 13 names.
//
// `MKFoundation.MKSignpost` (WS-01) already reserves the CROSS-MODULE
// vocabulary (`manipulationFrame`, `typingEcho`, `documentOpen`,
// `autosave`, `export`) ، this file reuses those cases (via
// `MKSignpost.signposter`) rather than duplicating them, and adds ONLY the
// render-internal categories `MKSignpost` doesn't have. `MKFoundation` is
// outside this packet's fence (see CONTRACTS.md's WS-07 section), so the
// new categories live here instead of as new `MKSignpost` cases; a P14/
// WS-01 pass may hoist them later without breaking this file's call sites
// (same interval-name strings).
//
// **P14 hoist (docs/impl-log/WS-07-p14-run3.md, item 2):** `arrangeDerive`
// used to be declared here too (task 13's original naming), but this file
// never had a call site for it ، the operation it names,
// `MKArrange.ArrangeDeriver.derive`, lives in a module `MKRender` cannot
// reach INTO from here (this file's categories only cover work MKRender
// itself performs), and WS-04's own impl log flagged the real gap:
// no instrumentation on `derive` at all, anywhere. Hoisted to
// `MKFoundation.MKSignpost.arrangeDerive` instead (`MKArrange` already
// depends on `MKFoundation`) and wired directly at the real call site ،
// see that case's doc comment. Removed here to avoid two same-named,
// same-subsystem signposts existing side by side with only one ever firing.

/// Render-internal `OSSignposter` categories (task 13) not already covered
/// by `MKFoundation.MKSignpost`.
public enum MKRenderSignpost: String, Sendable {
    case renderTile
    case layerSync
    case pathRelayout

    /// Dedicated signposter so `xctrace`/Instruments can filter MKRender's
    /// own categories independently of the shared `MKSignpost` vocabulary,
    /// while both still log to the same `net.binjamshid.makhtoot.Signpost`
    /// subsystem (`MKLog.logger(for: "Signpost")`) ، one log stream, two
    /// enums, per the fence split above.
    public static let signposter = OSSignposter(logger: MKLog.logger(for: "Signpost"))
}

/// Convenience interval-tracking wrapper so call sites don't hand-roll
/// begin/end pairs (and can't forget the `end` on an early return ، `defer`
/// handles it). Used for both the shared `MKSignpost` vocabulary and this
/// module's own `MKRenderSignpost` categories.
///
/// `OSSignposter.beginInterval`/`endInterval` require a `StaticString` name
/// (Instruments resolves signpost names at compile time, not from runtime
/// string data) ، `MKSignpost`/`MKRenderSignpost` are `String`-raw enums
/// (for `Sendable`/log-message convenience elsewhere), so this wrapper
/// switches each case to its literal `StaticString` rather than passing
/// `name.rawValue` through.
public enum MKRenderSignposts {
    /// Wraps `body` in a `MKSignpost` (`MKFoundation`, shared vocabulary)
    /// interval and returns `body`'s result.
    @discardableResult
    public static func interval<T>(_ name: MKSignpost, _ body: () throws -> T) rethrows -> T {
        let signposter = MKSignpost.signposter
        let name = staticName(for: name)
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try body()
    }

    /// Same, for this module's own render-internal categories.
    @discardableResult
    public static func interval<T>(_ name: MKRenderSignpost, _ body: () throws -> T) rethrows -> T {
        let signposter = MKRenderSignpost.signposter
        let name = staticName(for: name)
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try body()
    }

    /// Async variant (e.g. `documentOpen` spanning an `await` chain).
    @discardableResult
    public static func interval<T>(_ name: MKSignpost, _ body: () async throws -> T) async rethrows -> T {
        let signposter = MKSignpost.signposter
        let name = staticName(for: name)
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try await body()
    }

    private static func staticName(for signpost: MKSignpost) -> StaticString {
        switch signpost {
        case .manipulationFrame: return "manipulationFrame"
        case .typingEcho: return "typingEcho"
        case .documentOpen: return "documentOpen"
        case .autosave: return "autosave"
        case .export: return "export"
        case .arrangeDerive: return "arrangeDerive"
        }
    }

    private static func staticName(for signpost: MKRenderSignpost) -> StaticString {
        switch signpost {
        case .renderTile: return "renderTile"
        case .layerSync: return "layerSync"
        case .pathRelayout: return "pathRelayout"
        }
    }
}

/// A rolling snapshot of the numbers `Makhtoot/App/Debug/PerfHUDView.swift`
/// (WS-13, app-target ، outside this packet's fence, see
/// `docs/impl-log/WS-07.md`) is expected to render: frame time, memory
/// stage, cache bytes. `MKRender` exposes the DATA source (this struct +
/// `MKRenderPerfHUDDataSource`), not the SwiftUI view ، matching how every
/// other MKRender/App boundary in this codebase is drawn (protocol here,
/// UI in the app target).
public struct MKRenderPerfSnapshot: Sendable, Equatable {
    public var lastFrameDuration: TimeInterval
    public var memoryStage: MKMemoryStage
    public var bitmapCacheBytes: Int
    public var rasterizationsSinceLastRead: Int

    public init(lastFrameDuration: TimeInterval, memoryStage: MKMemoryStage, bitmapCacheBytes: Int, rasterizationsSinceLastRead: Int) {
        self.lastFrameDuration = lastFrameDuration
        self.memoryStage = memoryStage
        self.bitmapCacheBytes = bitmapCacheBytes
        self.rasterizationsSinceLastRead = rasterizationsSinceLastRead
    }
}

/// The seam a DEBUG-only app-target HUD view reads from (WS-13). Kept as a
/// tiny protocol (not a concrete singleton) so `MKLayerTreeController`/
/// `MKDegradationController`/`BitmapCache` can each be adapted into one
/// without MKRender itself owning app-lifecycle/UI state.
@MainActor
public protocol MKRenderPerfHUDDataSource: AnyObject {
    func currentPerfSnapshot() -> MKRenderPerfSnapshot
}
