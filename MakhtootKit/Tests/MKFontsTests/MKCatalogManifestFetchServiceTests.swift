import Foundation
import Testing
@testable import MKFonts

/// T22 (DF-7) AC: fresh-cache path makes no network call; stale-cache-
/// plus-failed-refetch serves the stale cache; zero-manifest-ever fixture
/// returns the explicit empty state with the exact Arabic copy; retry
/// re-attempts and recovers.
///
/// Each test mints its own unique `manifestURL` (UUID path component)
/// rather than sharing one literal string: `StubURLProtocol`'s stub table
/// is process-wide static state and Swift Testing runs tests in parallel
/// by default, so two tests stubbing the same URL string would race on
/// which stub/call-count wins. A unique URL per test eliminates that
/// without serializing the suite (this is a test-isolation concern only ،
/// production `MKFontDownloader`/`MKCatalogManifestFetchService` always
/// operate on whatever single URL a real manifest/config names).
@Suite("MKCatalogManifestFetchService ، T22")
struct MKCatalogManifestFetchServiceTests {
    private func sampleManifestData() throws -> Data {
        let bundle = MKFontsResources.bundle
        let url = try #require(bundle.url(forResource: "manifest.sample", withExtension: "json", subdirectory: "PremiumCatalog"))
        return try Data(contentsOf: url)
    }

    private func tempCacheURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("mkfonts-test-\(UUID().uuidString).json")
    }

    private func uniqueManifestURL() -> URL {
        URL(string: "https://fonts.example-makhtoot.invalid/\(UUID().uuidString)/catalog-manifest-v1.json")!
    }

    @Test func freshFetchPopulatesCacheAndReturnsFresh() async throws {
        let manifestURL = uniqueManifestURL()
        StubURLProtocol.stub(manifestURL, statusCode: 200, data: try sampleManifestData())
        let service = MKCatalogManifestFetchService(session: StubURLProtocol.makeSession(), cacheURL: tempCacheURL())

        let state = await service.fetch(manifestURL: manifestURL)
        guard case .fresh = state else { Issue.record("expected .fresh, got \(state)"); return }
        #expect(StubURLProtocol.callCount(for: manifestURL) == 1)
    }

    @Test func secondCallWithinTTLMakesNoNetworkRequest() async throws {
        let manifestURL = uniqueManifestURL()
        StubURLProtocol.stub(manifestURL, statusCode: 200, data: try sampleManifestData())
        let cacheURL = tempCacheURL()
        let service = MKCatalogManifestFetchService(session: StubURLProtocol.makeSession(), cacheURL: cacheURL)

        _ = await service.fetch(manifestURL: manifestURL)
        #expect(StubURLProtocol.callCount(for: manifestURL) == 1)
        let secondState = await service.fetch(manifestURL: manifestURL)
        #expect(StubURLProtocol.callCount(for: manifestURL) == 1, "fresh cache must not trigger a second network call")
        guard case .fresh = secondState else { Issue.record("expected .fresh"); return }
    }

    @Test func staleCacheServedWhenRefetchFails() async throws {
        let manifestURL = uniqueManifestURL()
        let cacheURL = tempCacheURL()

        // First: seed a cache entry that's already 25h old (stale).
        let staleClock: @Sendable () -> Date = { Date().addingTimeInterval(-25 * 60 * 60) }
        StubURLProtocol.stub(manifestURL, statusCode: 200, data: try sampleManifestData())
        let seedService = MKCatalogManifestFetchService(session: StubURLProtocol.makeSession(), cacheURL: cacheURL, clock: staleClock)
        _ = await seedService.fetch(manifestURL: manifestURL)

        // Second: real clock (now sees the seeded entry as stale), but the
        // refetch now fails (500).
        StubURLProtocol.stub(manifestURL, statusCode: 500, data: Data())
        let service = MKCatalogManifestFetchService(session: StubURLProtocol.makeSession(), cacheURL: cacheURL)
        let state = await service.fetch(manifestURL: manifestURL)
        guard case .stale = state else { Issue.record("expected .stale (documented degrade), got \(state)"); return }
    }

    @Test func zeroManifestEverReturnsExactArabicEmptyState() async {
        let manifestURL = uniqueManifestURL()
        StubURLProtocol.stub(manifestURL, statusCode: 500, data: Data())
        let service = MKCatalogManifestFetchService(session: StubURLProtocol.makeSession(), cacheURL: tempCacheURL())

        let state = await service.fetch(manifestURL: manifestURL)
        guard case .empty(let message) = state else { Issue.record("expected .empty, got \(state)"); return }
        #expect(message == "لا يمكن تحميل قائمة الخطوط دون اتصال")
        #expect(message == MKCatalogManifestFetchService.emptyStateMessage)
    }

    /// S-8 (AUDIT_2026-07-28.md): a response body larger than the configured
    /// ceiling must never reach the decoder — falls back exactly like any
    /// other fetch failure (no prior cache here, so `.empty`). Injects a
    /// tiny `maxManifestBytes` rather than streaming multiple real
    /// megabytes through `StubURLProtocol` just to trip the cap.
    @Test func oversizedResponseFallsBackWithoutDecoding() async throws {
        let manifestURL = uniqueManifestURL()
        let tinyCeiling = 64
        let oversized = Data(repeating: 0x41, count: tinyCeiling + 1)
        StubURLProtocol.stub(manifestURL, statusCode: 200, data: oversized)
        let service = MKCatalogManifestFetchService(
            session: StubURLProtocol.makeSession(), cacheURL: tempCacheURL(), maxManifestBytes: tinyCeiling
        )

        let state = await service.fetch(manifestURL: manifestURL)
        guard case .empty(let message) = state else {
            Issue.record("expected .empty (no prior cache to degrade to .stale), got \(state)")
            return
        }
        #expect(message == MKCatalogManifestFetchService.emptyStateMessage)
    }

    /// A real, well-formed manifest under the ceiling must still decode
    /// normally ، the cap must not be so tight it rejects legitimate
    /// payloads, and this guards against an off-by-one in the accumulation
    /// loop's `<=` check.
    @Test func responseUnderCeilingStillDecodesNormally() async throws {
        let manifestURL = uniqueManifestURL()
        let sample = try sampleManifestData()
        StubURLProtocol.stub(manifestURL, statusCode: 200, data: sample)
        let service = MKCatalogManifestFetchService(
            session: StubURLProtocol.makeSession(), cacheURL: tempCacheURL(), maxManifestBytes: sample.count
        )

        let state = await service.fetch(manifestURL: manifestURL)
        guard case .fresh = state else { Issue.record("expected .fresh, got \(state)"); return }
    }

    @Test func retryAfterConnectivityReturnsRecoversToFresh() async throws {
        let manifestURL = uniqueManifestURL()
        StubURLProtocol.stub(manifestURL, statusCode: 500, data: Data())
        let service = MKCatalogManifestFetchService(session: StubURLProtocol.makeSession(), cacheURL: tempCacheURL())

        let first = await service.fetch(manifestURL: manifestURL)
        guard case .empty = first else { Issue.record("expected .empty"); return }

        StubURLProtocol.stub(manifestURL, statusCode: 200, data: try sampleManifestData())
        let retried = await service.fetch(manifestURL: manifestURL)
        guard case .fresh = retried else { Issue.record("expected .fresh after retry, got \(retried)"); return }
    }
}
