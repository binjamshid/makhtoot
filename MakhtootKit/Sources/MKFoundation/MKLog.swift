import os

/// Structured logging for MakhtootKit. Every module gets an `os.Logger`
/// scoped to a stable subsystem/category pair so `log stream`/Console
/// filtering works per-module without any module reaching into another's
/// logger.
///
/// The subsystem prefix `net.binjamshid.makhtoot` is derived from the
/// real bundle ID (FOUNDATION §0, FD-01 confirmed by founder).
public enum MKLog {
    /// FD-01 applied: real bundle ID `net.binjamshid.makhtoot` confirmed.
    public static let subsystemPrefix = "net.binjamshid.makhtoot"

    /// Returns an `os.Logger` for `module`, subsystem
    /// `net.binjamshid.makhtoot.<module>`.
    public static func logger(for module: String) -> Logger {
        Logger(subsystem: "\(subsystemPrefix).\(module)", category: module)
    }

    // Pre-built loggers for the modules that exist as of WS-01. Later
    // workstreams may add their own via `MKLog.logger(for:)` directly, but
    // reusing a shared instance per module avoids re-allocating on every
    // call site.
    public static let foundation = logger(for: "MKFoundation")
    public static let designSystem = logger(for: "MKDesignSystem")
    public static let app = logger(for: "App")
}

/// Reserved `OSSignposter` interval names for the D-115 performance
/// budgets. Declaring them centrally here (rather than per-module) means
/// every workstream instruments against the same vocabulary that
/// TEST_MATRIX.md profiling gates key off of.
///
/// | Signpost name | D-115 budget |
/// |---|---|
/// | `manipulationFrame` | ≤8.3 ms ProMotion / ≤16.6 ms floor per canvas manipulation frame (WS-06/07) |
/// | `typingEcho` | <50 ms from keystroke to on-screen echo (WS-03/06) |
/// | `documentOpen` | <1 s typical (≤100 nodes) / <3 s heavy (5 000 nodes) project open (WS-02) |
/// | `autosave` | <100 ms off main thread per incremental autosave (WS-02) |
/// | `export` | <10 s for a 4K PNG export on A15-class hardware (WS-08) |
/// | `arrangeDerive` | <100 ms to derive a 500-glyph arranged composition (WS-04) |
public enum MKSignpost: String, Sendable {
    case manipulationFrame
    case typingEcho
    case documentOpen
    case autosave
    case export
    // P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 2): closes
    // WS-04's own flagged gap (`docs/impl-log/WS-04.md` task 17 row: "no
    // `MKSignpost` case added ، out of fence, that enum lives in
    // `MKFoundation`, this packet's fence is `MKArrange` sources only").
    // `MKArrange` already depends on `MKFoundation` (Package.swift), so the
    // case lives here (the packet's own stated correct home) and
    // `MKArrange.ArrangeDeriver.derive` wires it directly, matching
    // `MakhtootDocument.open`'s existing `documentOpen` pattern (a raw
    // `MKSignpost.signposter.beginInterval`/`endInterval` pair with a
    // `StaticString` literal kept in sync by convention, since `MKArrange`
    // cannot depend on `MKRender`'s `MKRenderSignposts` convenience wrapper
    // ، wrong dependency direction, `MKRender` depends on `MKArrange`'s
    // sibling `MKPathText`, not the reverse).
    case arrangeDerive

    /// The `OSSignposter` this interval should be logged against ،
    /// currently all budgets share the app's default signpost logger;
    /// split further only if profiling needs per-module isolation.
    public static let signposter = OSSignposter(logger: MKLog.logger(for: "Signpost"))
}
