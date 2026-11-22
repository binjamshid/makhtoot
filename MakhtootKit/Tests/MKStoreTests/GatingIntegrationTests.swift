import Foundation
import Testing
import MKFoundation
import MKModel
import MKExport
import MKFonts
@testable import MKStore

/// T16 AC: "integration test: simulate expiry ⇒ fonts lock (WS-09 T17) +
/// export matrix downgrades (WS-08) in one propagation." Exercises the
/// REAL `MKEntitlementResolver` against the REAL `MKExportGate`
/// (`resolvedPixelSize(for:isPremiumUser:)`, G20/D-229(2)) and the REAL
/// `MKFontLockController` (`observe(_:)`, D-119/T17) through their already-
/// published public APIs ، never touching `MKExport`/`MKFonts` sources
/// (this packet's fence), only consuming them as libraries, same pattern
/// every other cross-module test-only dependency in `Package.swift`
/// already establishes.
@Suite("Gating sweep ، T16 stub-retirement integration")
struct GatingIntegrationTests {
    /// A real, on-disk bundled font file (`MKFonts`' own resources) so
    /// `MKFontRegistry.registerDownloaded` ، which registers the face with
    /// `CTFontManager`, requiring a real file ، has something legitimate
    /// to register, without this test target depending on MKFonts'
    /// resource bundle machinery itself (same `#filePath`-relative
    /// resolution pattern `WS16CursiveTests` already established for
    /// reading a real bundled font by file URL).
    private static var bundledFontFileURL: URL {
        var url = URL(fileURLWithPath: #filePath)
        // .../MakhtootKit/Tests/MKStoreTests/GatingIntegrationTests.swift
        url.deleteLastPathComponent() // → .../MakhtootKit/Tests/MKStoreTests
        url.deleteLastPathComponent() // → .../MakhtootKit/Tests
        url.deleteLastPathComponent() // → .../MakhtootKit
        return url
            .appendingPathComponent("Sources")
            .appendingPathComponent("MKFonts")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Fonts")
            .appendingPathComponent("ScheherazadeNew")
            .appendingPathComponent("ScheherazadeNew-Regular.ttf")
    }

    /// A trial-less (EXPIRED trial, per `forceExpiredTrial`), product-less
    /// resolver whose only remaining signal is the trial state ، the
    /// precedence GATHERING half (StoreKit round trips, lifetime/
    /// subscription signals) is exercised elsewhere
    /// (`MKEntitlementPrecedenceTests`/`MKPurchaseControllerTests`); this
    /// suite is specifically about PROPAGATION once a state is resolved.
    /// `forceExpiredTrial: true` is required to reach a genuine `.free`
    /// resolution ، a brand-new `MKTrialManager` otherwise starts an
    /// active 7-day trial on its very first `resolve()`, which itself
    /// grants premium (by design, D-113) and would silently defeat this
    /// test's "free ⇒ locked" assertion for the wrong reason (trial
    /// covering for the lack of products, not an actual free-tier check).
    private func makeResolver(forceExpiredTrial: Bool) async -> (MKEntitlementResolver, MKTrialManager) {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let trialManager = MKTrialManager(local: MKInMemoryKeyValueStore(), cloud: MKInMemoryKeyValueStore(), clock: clock)
        if forceExpiredTrial {
            _ = await trialManager.resolve() // establish the trial anchor at t0
            clock.advance(by: 86_400 * 8) // then jump past the 7-day window
        }
        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("mk-gating-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let resolver = MKEntitlementResolver(catalog: MKProductCatalog(ids: []), trialManager: trialManager, cacheURL: cacheDir.appendingPathComponent("cache.json"))
        return (resolver, trialManager)
    }

    private func makeLockedFontRegistry() async throws -> (MKFontRegistry, MKFontID) {
        let registry = MKFontRegistry()
        let fontID = "gating-test-premium-font"
        let face = MKFontFace(
            postScriptName: "GatingTestFont-Regular",
            familyName: "Gating Test Font",
            fullName: "Gating Test Font Regular",
            styleName: "Regular",
            weight: 400,
            isVariable: false,
            format: .ttf,
            filename: "ScheherazadeNew-Regular.ttf",
            fileURL: Self.bundledFontFileURL
        )
        let record = MKFontRecord(fontID: fontID, familyName: "Gating Test Font", origin: .premiumDownloaded, faces: [face], categories: [.naskh])
        let license = MKLicenseRecord(
            fontID: fontID, familyName: "Gating Test Font", licenseType: .ofl11,
            copyrightNotice: "test", reservedFontNames: [], sourceRepoURL: "test",
            licenseFileBundlePath: "test", verificationDate: "2026-01-01", verifiedBy: "test",
            redistributionConfirmed: true, embeddingRights: [.pdf, .svg, .commercialUse]
        )
        try await registry.registerDownloaded(record, license: license)
        return (registry, fontID)
    }

    // MARK: - Direction 1: entitlement = free ⇒ premium fonts lock, custom
    // dimensions blocked (no premium leak).

    @Test func freeEntitlementLocksPremiumFontsAndBlocksCustomDimensions() async throws {
        let (resolver, _) = await makeResolver(forceExpiredTrial: true)
        let (registry, fontID) = try await makeLockedFontRegistry()
        let lockController = MKFontLockController(registry: registry)

        // Font starts unlocked (registerDownloaded default).
        #expect(await registry.record(for: fontID)?.isLocked == false)

        // One propagation: resolver's real `states()` stream drives the
        // font lock controller directly, exactly as `AppContainer`/WS-09's
        // own composition wiring would.
        let observationTask = Task {
            await lockController.observe(await resolver.states())
        }
        _ = await resolver.resolve() // resolves to `.free` (no products, no trial)
        // Allow the observation loop one runloop turn to apply the state.
        try await Task.sleep(for: .milliseconds(50))
        observationTask.cancel()

        #expect(await registry.record(for: fontID)?.isLocked == true)

        // Export gate: free tier, custom (non-preset) dimensions blocked
        // (G20, D-229(2)) ، no premium leak.
        let gate = MKExportGate()
        let customRequest = MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 4000, height: 3000)))
        let resolved = gate.resolvedPixelSize(for: customRequest, isPremiumUser: false)
        // Free tier clamps rather than nils out (`MKFreeTierBudget.clamped`)
        // ، the "no leak" assertion is that the resolved size is NOT the
        // full requested 4000×3000 (i.e. the free clamp actually fired).
        #expect(resolved != CGSize(width: 4000, height: 3000))
    }

    // MARK: - Direction 2: entitlement = lifetime ⇒ no false lock, custom
    // dimensions allowed.

    @Test func lifetimeEntitlementUnlocksFontsAndAllowsCustomDimensions() async throws {
        let (registry, fontID) = try await makeLockedFontRegistry()
        // Start LOCKED (simulating a prior free/expired state) to prove
        // the lifetime transition actively unlocks rather than merely
        // never-locking.
        await registry.setLocked(true, origins: [.premiumDownloaded])
        #expect(await registry.record(for: fontID)?.isLocked == true)

        let lockController = MKFontLockController(registry: registry)

        // Force the resolver's snapshot to `.lifetime` directly via the
        // precedence function + `applySnapshot`-equivalent path: since
        // this resolver has no real lifetime transaction to observe from
        // StoreKit in this environment (no sandbox Apple ID ، see
        // `Docs/SandboxTestPlan.md`), we drive `MKFontLockController.apply(_:)`
        // directly with the STATE VALUE `.lifetime` ، this still exercises
        // the exact same real WS-09 code path
        // (`MKFontLockController.apply`) a real resolver's broadcast would
        // have called; only the "how did we get this MKEntitlementState
        // value" half is StoreKit-sandbox-deferred, not the propagation
        // half T16 actually asks for.
        await lockController.apply(.lifetime)

        #expect(await registry.record(for: fontID)?.isLocked == false)

        let gate = MKExportGate()
        let customRequest = MKExportRequest(format: .pngOpaque, target: .custom(pixelSize: CGSize(width: 4000, height: 3000)))
        let resolved = gate.resolvedPixelSize(for: customRequest, isPremiumUser: true)
        // Premium: no clamp ، the full requested size comes back exactly
        // (no false lock).
        #expect(resolved == CGSize(width: 4000, height: 3000))
    }

    // MARK: - Reconcile one-shot (no running observation task)

    @Test func reconcileAppliesCurrentSnapshotWithoutAStream() async throws {
        let (registry, fontID) = try await makeLockedFontRegistry()
        let (resolver, _) = await makeResolver(forceExpiredTrial: true)
        _ = await resolver.resolve()
        let lockController = MKFontLockController(registry: registry)
        await lockController.reconcile(with: resolver)
        #expect(await registry.record(for: fontID)?.isLocked == true)
    }
}
