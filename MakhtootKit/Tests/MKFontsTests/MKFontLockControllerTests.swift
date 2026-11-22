import Foundation
import MKFoundation
import Testing
@testable import MKFonts

/// T17 AC: injected entitlement flip locks/unlocks within one runloop;
/// locked font cannot be applied to new text (error surfaced); previously
/// registered fonts remain resolvable (integration proxy for "existing
/// placed text still renders" ، full cache-stub integration is WS-03's
/// `lastShapedCache`, out of this module's fence, but the registry-level
/// contract this depends on is exercised here).
@Suite("MKFontLockController ، T17")
struct MKFontLockControllerTests {
    private func registerFakePremium(_ registry: MKFontRegistry) async throws {
        let bundledRecord = try #require(await registry.records().first)
        let face = bundledRecord.faces[0]
        let record = MKFontRecord(fontID: "fake-premium", familyName: "Fake Premium", origin: .premiumDownloaded, faces: [face], categories: [], tags: [])
        let license = MKLicenseRecord(
            fontID: "fake-premium", familyName: "Fake Premium", licenseType: .ofl11, copyrightNotice: "",
            reservedFontNames: [], sourceRepoURL: "", licenseFileBundlePath: "", verificationDate: "2026-07-18",
            verifiedBy: "test", redistributionConfirmed: true, embeddingRights: [.pdf, .svg, .commercialUse]
        )
        try await registry.registerDownloaded(record, license: license)
    }

    @Test func applyingFreeStateLocksPremiumFonts() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        try await registerFakePremium(registry)

        let controller = MKFontLockController(registry: registry)
        await controller.apply(.free)

        await #expect(throws: MKFontError.self) {
            _ = try await registry.ctFont(for: "fake-premium", size: 24)
        }
    }

    @Test func applyingLifetimeUnlocksPremiumFonts() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        try await registerFakePremium(registry)

        let controller = MKFontLockController(registry: registry)
        await controller.apply(.free)
        await controller.apply(.lifetime)

        _ = try await registry.ctFont(for: "fake-premium", size: 24)  // no throw
    }

    @Test func observeStreamAppliesEachTransition() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        try await registerFakePremium(registry)

        let controller = MKFontLockController(registry: registry)
        let (stream, continuation) = AsyncStream<MKEntitlementState>.makeStream()
        let task = Task { await controller.observe(stream) }

        continuation.yield(.free)
        // Give the controller's task a moment to process (deterministic-ish
        // via a small async yield loop rather than a fixed sleep).
        for _ in 0..<50 {
            if let record = await registry.record(for: "fake-premium"), record.isLocked { break }
            await Task.yield()
        }
        let locked = await registry.record(for: "fake-premium")?.isLocked
        #expect(locked == true)

        continuation.finish()
        task.cancel()
    }

    @Test func reconcileWithProviderMatchesCurrentState() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        try await registerFakePremium(registry)
        let controller = MKFontLockController(registry: registry)

        await controller.reconcile(with: StubEntitlementResolver())  // .lifetime
        let unlocked = await registry.record(for: "fake-premium")?.isLocked
        #expect(unlocked == false)
    }
}
