import Foundation

/// T22 (DF-7) ، foreground-only premium-catalog manifest fetch with 24h
/// staleness TTL, disk cache, and an explicit zero-manifest-ever empty
/// state. Never fetches in the background (no `BGTaskScheduler` hookup
/// anywhere in this type) ، callers (WS-13 catalog screen appearance, or
/// an explicit user-triggered refresh) drive every call.
public actor MKCatalogManifestFetchService {
    public enum State: Sendable, Equatable {
        case fresh(MKCatalogManifestSnapshot)
        case stale(MKCatalogManifestSnapshot)
        /// No cache AND fetch failed/offline ، exact Arabic copy per T22 AC.
        case empty(message: String)
    }

    public static let emptyStateMessage = "لا يمكن تحميل قائمة الخطوط دون اتصال"
    public static let staleness: TimeInterval = 24 * 60 * 60

    /// S-8 (AUDIT_2026-07-28.md): default hard ceiling on the manifest
    /// response body. The real manifest is a handful of KB per font entry ،
    /// this is a generous bound against a misconfigured or hostile endpoint
    /// streaming an unbounded body into memory, not a tight fit to the
    /// expected payload size. Dormant today (`MKPremiumDelivery.current ==
    /// .bundledFallback`), fixed now so it's already correct when FC-5
    /// flips delivery mode live.
    public static let defaultMaxManifestBytes = 5 * 1024 * 1024

    private let session: URLSession
    private let cacheURL: URL
    private let clock: @Sendable () -> Date
    /// Injectable so tests can exercise the oversized-response path against
    /// a small ceiling instead of streaming multiple real megabytes through
    /// `StubURLProtocol` just to trip it.
    private let maxManifestBytes: Int

    public init(
        session: URLSession = .shared,
        cacheURL: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fonts/manifest-cache.json"),
        clock: @escaping @Sendable () -> Date = { Date() },
        maxManifestBytes: Int = MKCatalogManifestFetchService.defaultMaxManifestBytes
    ) {
        self.session = session
        self.cacheURL = cacheURL
        self.clock = clock
        self.maxManifestBytes = maxManifestBytes
    }

    /// A network call was made this call ، used by tests to assert the
    /// "fresh cache ⇒ no network round-trip" AC without needing a mock
    /// `URLProtocol` wired through every test.
    public private(set) var lastCallMadeNetworkRequest = false

    @discardableResult
    public func fetch(manifestURL: URL) async -> State {
        lastCallMadeNetworkRequest = false
        let cached = readCache()

        if let cached, clock().timeIntervalSince(cached.fetchedAt) < Self.staleness {
            return .fresh(cached)
        }

        lastCallMadeNetworkRequest = true
        do {
            let (byteStream, response) = try await session.bytes(from: manifestURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            // S-8: reject early when the server declares an implausible
            // length up front — no point reading a single byte of a body
            // that's already announced as too large. `expectedContentLength`
            // is `-1` when the server omits `Content-Length` (e.g. chunked
            // transfer) ، that's not itself a rejection reason, since the
            // accumulation cap below still bounds memory regardless of
            // whether a length was declared.
            let expectedLength = http.expectedContentLength
            if expectedLength > Int64(maxManifestBytes) {
                throw URLError(.dataLengthExceedsMaximum)
            }

            var data = Data()
            if expectedLength > 0 {
                data.reserveCapacity(Int(expectedLength))
            }
            for try await byte in byteStream {
                data.append(byte)
                guard data.count <= maxManifestBytes else {
                    throw URLError(.dataLengthExceedsMaximum)
                }
            }

            let manifest = try MKCatalogManifestDecoder.decode(data)
            let snapshot = MKCatalogManifestSnapshot(manifest: manifest, fetchedAt: clock())
            writeCache(snapshot)
            return .fresh(snapshot)
        } catch {
            if let cached {
                // Documented degrade: stale-serve-on-failure, not the empty state.
                return .stale(cached)
            }
            return .empty(message: Self.emptyStateMessage)
        }
    }

    private func readCache() -> MKCatalogManifestSnapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(MKCatalogManifestSnapshot.self, from: data)
    }

    private func writeCache(_ snapshot: MKCatalogManifestSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }
}

public struct MKCatalogManifestSnapshot: Sendable, Codable, Equatable {
    public var manifest: MKCatalogManifest
    public var fetchedAt: Date

    public init(manifest: MKCatalogManifest, fetchedAt: Date) {
        self.manifest = manifest
        self.fetchedAt = fetchedAt
    }
}

extension MKCatalogManifest: Equatable {
    public static func == (lhs: MKCatalogManifest, rhs: MKCatalogManifest) -> Bool {
        lhs.schemaVersion == rhs.schemaVersion && lhs.generatedAt == rhs.generatedAt
            && lhs.fonts.map(\.fontID) == rhs.fonts.map(\.fontID)
    }
}
