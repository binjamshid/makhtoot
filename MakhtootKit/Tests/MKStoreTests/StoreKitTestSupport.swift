import Foundation
#if canImport(StoreKitTest)
import StoreKitTest
#endif

/// Locates the canonical `Makhtoot.storekit` config file by walking up
/// from this file's own path (same pattern `MKFixtureLocator` uses
/// elsewhere in this repo for `Tests/Fixtures/`, per the established
/// convention documented on several sibling test targets in
/// `Package.swift`) rather than via `Bundle.module` ، `MKStoreTests` and
/// `MKStore` are separate SPM resource bundles, so `MKStoreTests` can't
/// reach `MKStore`'s bundled copy through `Bundle.module` directly.
enum StoreKitConfigLocator {
    static var configURL: URL {
        var url = URL(fileURLWithPath: #filePath)
        // .../MakhtootKit/Tests/MKStoreTests/StoreKitTestSupport.swift
        url.deleteLastPathComponent() // → .../MakhtootKit/Tests/MKStoreTests
        url.deleteLastPathComponent() // → .../MakhtootKit/Tests
        url.deleteLastPathComponent() // → .../MakhtootKit
        return url
            .appendingPathComponent("Sources")
            .appendingPathComponent("MKStore")
            .appendingPathComponent("Makhtoot.storekit")
    }

    /// Returns `true` when running inside a full Xcode-managed test host
    /// (`.xctest` bundle via `xcodebuild test`), giving `SKTestSession`
    /// access to the StoreKit daemon. Returns `false` in SPM's
    /// `swiftpm-testing-helper`, where the daemon IPC is unavailable.
    static var isRunningUnderXcodeTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    #if canImport(StoreKitTest)
    /// Starts a fresh `SKTestSession` against the canonical config, with a
    /// clean transaction history (T2/T3 AC: "works against `.storekit`
    /// file in unit tests"). Callers are responsible for calling
    /// `session.clearTransactions()` between tests that must not see each
    /// other's purchases.
    static func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(contentsOf: configURL)
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// Attempts a real `SKTestSession` construction exactly once per
    /// process and records whether it actually succeeded, rather than
    /// trusting `isRunningUnderXcodeTestHost`'s environment-variable
    /// heuristic alone. That heuristic is necessary ، `swift test`'s
    /// `swiftpm-testing-helper` host has no `XCTestBundlePath` and no
    /// StoreKit daemon access at all ، but it is not sufficient on its
    /// own: an Xcode-hosted `.xctest` runner can still be denied daemon
    /// access (a CI runner, a sandboxed agent session, …), in which case
    /// `SKTestSession(contentsOf:)` itself throws, rather than merely
    /// logging `SKInternalErrorDomain` noise to stderr the way
    /// `clearTransactions()` and the property setters do when the daemon
    /// is unreachable but the session object still constructed (confirmed
    /// empirically under plain `swift test` ، see WS-10 §12: those two
    /// calls stay `void`/non-throwing and never surface the failure to
    /// Swift). Session construction is fast (sub-second in every observed
    /// run, including the daemon-unreachable case), so it's safe to probe
    /// eagerly here; this deliberately does NOT attempt a product load or
    /// purchase round-trip, which would need `async` work a `static let`
    /// can't perform and risks the same class of host hang WS-10 §4/§7
    /// already hit running the whole package under `xcodebuild test`.
    ///
    /// A `static let` is evaluated at most once per process (Swift
    /// guarantees the initializer runs exactly once, thread-safely), so
    /// every gated `@Test` that reads this pays the probe's cost once,
    /// not once per test.
    static let isStoreKitTestSessionAvailable: Bool = {
        guard isRunningUnderXcodeTestHost else { return false }
        do {
            let session = try makeSession()
            session.clearTransactions()
            return true
        } catch {
            return false
        }
    }()
    #endif
}
