import Foundation
import Testing
import MKFoundation
@testable import MKStore

/// Mirrors `MKEntitlementResolver`'s file-private `MKEntitlementCacheRecord`
/// DTO field-for-field so tests can pre-write a cache file without needing
/// access to that private type ، `JSONEncoder`/`JSONDecoder` match purely on
/// key name, so this is byte-compatible with what the resolver itself reads
/// and writes.
private struct FakeEntitlementCacheRecord: Codable {
    var stateTag: String
    var trialDaysLeft: Int?
    var resolvedAt: Date
}

@Suite("MKEntitlementResolver ، T5/T17 offline & caching")
struct MKEntitlementResolverTests {
    private func makeResolver(cacheURL: URL, trialClock: MKFakeClock = MKFakeClock()) -> MKEntitlementResolver {
        let catalog = MKProductCatalog(ids: []) // empty ids: no network round trip needed for these tests
        let trialManager = MKTrialManager(local: MKInMemoryKeyValueStore(), cloud: MKInMemoryKeyValueStore(), clock: trialClock)
        return MKEntitlementResolver(catalog: catalog, trialManager: trialManager, cacheURL: cacheURL)
    }

    private func writeFakeCache(stateTag: String, resolvedAt: Date, trialDaysLeft: Int? = nil, to cacheURL: URL) throws {
        let record = FakeEntitlementCacheRecord(stateTag: stateTag, trialDaysLeft: trialDaysLeft, resolvedAt: resolvedAt)
        let data = try JSONEncoder().encode(record)
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
    }

    @Test func freshResolverWithNoCacheDefaultsToFree() {
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("mk-resolver-\(UUID().uuidString).json")
        let resolver = makeResolver(cacheURL: cacheURL)
        #expect(resolver.state == .free)
    }

    // T5 AC: "cold-offline launch yields cached state in <50 ms SCOPED to
    // post-first-resolution launches only."
    @Test func cachedStateSurvivesAcrossResolverInstances() async {
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("mk-resolver-\(UUID().uuidString).json")
        let firstResolver = makeResolver(cacheURL: cacheURL)
        // Directly resolve trial-only (no StoreKit products configured) ،
        // this exercises the trial branch of precedence and persists a
        // `.trial` cache entry.
        let state = await firstResolver.resolve()
        guard case .trial = state else {
            Issue.record("expected .trial from a fresh trial with no products configured, got \(state)")
            return
        }

        // A brand-new resolver instance pointed at the SAME cache file
        // simulates "cold offline launch, post-first-resolution" ، its
        // `init` alone (no `resolve()` call) must already reflect the
        // cached state, synchronously, well under 50ms.
        let start = DispatchTime.now()
        let secondResolver = makeResolver(cacheURL: cacheURL)
        let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        guard case .trial = secondResolver.state else {
            Issue.record("expected cached .trial state, got \(secondResolver.state)")
            return
        }
        #expect(elapsedMS < 50)
    }

    @Test func statesStreamYieldsCurrentValueImmediatelyOnSubscription() async {
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("mk-resolver-\(UUID().uuidString).json")
        let resolver = makeResolver(cacheURL: cacheURL)
        _ = await resolver.resolve()
        let stream = await resolver.states()
        var iterator = stream.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first != nil)
    }

    @Test func statesStreamBroadcastsOnChange() async {
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("mk-resolver-\(UUID().uuidString).json")
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let resolver = makeResolver(cacheURL: cacheURL, trialClock: clock)
        _ = await resolver.resolve() // .trial(daysLeft: 7)

        let stream = await resolver.states()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next() // initial value

        clock.advance(by: 86_400 * 8) // trial expires
        _ = await resolver.resolve()
        let updated = await iterator.next()
        #expect(updated == .free)
    }

    // S-1 (1/3): a cached `subscribed` state older than
    // `cacheStalenessTolerance` must NOT be trusted ، it degrades to the
    // `.free` default instead of granting premium offline indefinitely.
    @Test func staleSubscribedCacheDegradesToFree() throws {
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("mk-resolver-\(UUID().uuidString).json")
        let fourDaysAgo = Date().addingTimeInterval(-4 * 86_400)
        try writeFakeCache(stateTag: "subscribed", resolvedAt: fourDaysAgo, to: cacheURL)

        // Default `cacheStalenessTolerance` is 3 days (86_400 * 3), so a
        // 4-day-old record is past tolerance.
        let resolver = makeResolver(cacheURL: cacheURL)
        #expect(resolver.state == .free)
    }

    // S-1 (2/3): `.lifetime` is exempt from staleness (T17: "honored
    // offline indefinitely") ، a 4-day-old `lifetime` record must still
    // resolve to `.lifetime`, not degrade to `.free`.
    @Test func staleLifetimeCacheRemainsLifetime() throws {
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("mk-resolver-\(UUID().uuidString).json")
        let fourDaysAgo = Date().addingTimeInterval(-4 * 86_400)
        try writeFakeCache(stateTag: "lifetime", resolvedAt: fourDaysAgo, to: cacheURL)

        let resolver = makeResolver(cacheURL: cacheURL)
        #expect(resolver.state == .lifetime)
    }

    // S-1 (3/3): the no-override default cache location must resolve under
    // Application Support, not `.cachesDirectory` ، iOS may purge Caches
    // under disk pressure, which would silently demote a paying customer to
    // `.free` on the next cold offline launch.
    @Test func defaultCachePathIsUnderApplicationSupportNotCaches() {
        let catalog = MKProductCatalog(ids: [])
        let trialManager = MKTrialManager(local: MKInMemoryKeyValueStore(), cloud: MKInMemoryKeyValueStore(), clock: MKFakeClock())
        let resolver = MKEntitlementResolver(catalog: catalog, trialManager: trialManager)

        let path = resolver.cacheURL.path
        #expect(path.contains("Application Support"))
        #expect(!path.contains("/Library/Caches/"))
    }
}
