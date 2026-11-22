import CryptoKit
import Foundation
import MKFoundation
import Testing
@testable import MKFonts

/// T12 AC: checksum mismatch surfaces the exact Arabic message and doesn't
/// leave a corrupt file registered; free-tier download refused; a
/// successful download registers + updates the catalog.
@Suite("MKFontDownloader ، T12")
struct MKFontDownloaderTests {
    /// `fileURL` embeds a fresh UUID path component per call ، `StubURLProtocol`'s
    /// stub table is shared *process-wide* static state, and Swift Testing
    /// runs tests within/across suites in parallel by default, so two
    /// tests stubbing the same literal URL string race on which
    /// stub/call-count entry wins. A unique URL per test call eliminates
    /// the collision without serializing the suite (and without hiding a
    /// real bug ، this affects test isolation only, not the production
    /// `MKFontDownloader` code path itself, which always downloads
    /// whatever URL a specific manifest entry names).
    private func sampleManifestEntry(fontID: String = "amiri-premium-test", fileURL: URL? = nil) throws -> MKCatalogManifestEntry {
        let loaded = try BundledFontIndex().loadAll()
        let amiri = try #require(loaded.first { $0.record.fontID == "amiri" })
        let face = try #require(amiri.record.faces.first)
        let data = try Data(contentsOf: face.fileURL)
        let digest = CryptoKit.SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return MKCatalogManifestEntry(
            fontID: fontID, family: "Amiri", faces: [
                MKCatalogManifestFace(postScriptName: face.postScriptName, styleName: "normal", weight: 400, isVariable: false),
            ],
            categories: [.naskh], tags: [],
            fileURL: fileURL ?? URL(string: "https://fonts.example-makhtoot.invalid/amiri/\(UUID().uuidString)/Amiri-Regular.ttf")!,
            fileSHA256: digest, fileSizeBytes: data.count, licenseRecord: amiri.license, minAppVersion: "1.0.0"
        )
    }

    @Test func premiumUserDownloadSucceedsAndRegisters() async throws {
        let entry = try sampleManifestEntry()
        let realData = try Data(contentsOf: try #require(BundledFontIndex().loadAll().first { $0.record.fontID == "amiri" }?.record.faces.first?.fileURL))
        StubURLProtocol.stub(entry.fileURL, statusCode: 200, data: realData)

        let registry = MKFontRegistry()
        let downloader = MKFontDownloader(
            registry: registry, entitlements: StubEntitlementResolver(), session: StubURLProtocol.makeSession(),
            destinationRoot: FileManager.default.temporaryDirectory.appendingPathComponent("mk-dl-\(UUID().uuidString)")
        )
        try await downloader.download(entry)
        let record = await registry.record(for: entry.fontID)
        #expect(record?.origin == .premiumDownloaded)
    }

    @Test func checksumMismatchThrowsAndDoesNotRegister() async throws {
        let entry = try sampleManifestEntry()
        StubURLProtocol.stub(entry.fileURL, statusCode: 200, data: Data("not the real font bytes".utf8))

        let registry = MKFontRegistry()
        let downloader = MKFontDownloader(
            registry: registry, entitlements: StubEntitlementResolver(), session: StubURLProtocol.makeSession(),
            destinationRoot: FileManager.default.temporaryDirectory.appendingPathComponent("mk-dl-\(UUID().uuidString)")
        )
        do {
            try await downloader.download(entry)
            Issue.record("expected checksum mismatch throw")
        } catch let error as MKFontError {
            #expect(error.arabicUserMessage == "فشل التحقق من سلامة الخط")
        }
        let record = await registry.record(for: entry.fontID)
        #expect(record == nil)
    }

    @Test func freeTierDownloadRefusedWithArabicMessage() async throws {
        let entry = try sampleManifestEntry()
        let registry = MKFontRegistry()
        let downloader = MKFontDownloader(registry: registry, entitlements: FakeEntitlementProvider(state: .free))
        do {
            try await downloader.download(entry)
            Issue.record("expected premiumRequired throw")
        } catch let error as MKFontError {
            #expect(error.arabicUserMessage == "هذا الخط يتطلب الاشتراك المميز")
        }
    }

    @Test func offlineAttemptSurfacesArabicOfflineMessage() async throws {
        let entry = try sampleManifestEntry()
        StubURLProtocol.stub(entry.fileURL, error: URLError(.notConnectedToInternet))

        let registry = MKFontRegistry()
        let downloader = MKFontDownloader(
            registry: registry, entitlements: StubEntitlementResolver(), session: StubURLProtocol.makeSession()
        )
        do {
            try await downloader.download(entry)
            Issue.record("expected offline throw")
        } catch let error as MKFontError {
            #expect(error.arabicUserMessage == "لا يتوفر اتصال بالإنترنت ، الخطوط المميزة تتطلب اتصالًا للتنزيل")
        }
    }

    /// S-9 (AUDIT_2026-07-28.md): a `file://` `fileURL` (ATS only blocks
    /// cleartext `http://`, not `file://`) must be rejected before any
    /// network attempt — asserted here by checking `StubURLProtocol` was
    /// never even called for that URL, not just that SOME error surfaced.
    @Test func nonHTTPSSchemeThrowsBeforeAnyNetworkAttempt() async throws {
        let fileURL = URL(string: "file:///private/tmp/mk-font-scheme-test-\(UUID().uuidString).ttf")!
        let entry = try sampleManifestEntry(fileURL: fileURL)

        let registry = MKFontRegistry()
        let downloader = MKFontDownloader(
            registry: registry, entitlements: StubEntitlementResolver(), session: StubURLProtocol.makeSession()
        )
        do {
            try await downloader.download(entry)
            Issue.record("expected the scheme guard to throw")
        } catch let error as MKFontError {
            guard case .offline = error else {
                Issue.record("expected .offline, got \(error)")
                return
            }
        }
        #expect(StubURLProtocol.callCount(for: fileURL) == 0, "scheme guard must reject before any network attempt")
    }

    /// S-9: the defer-reorder must not regress the success path — the
    /// destination file must exist, and no `mk-font-dl-*` scratch file
    /// (this type's tmp-file naming) should remain in the temp directory
    /// once `download(_:)` returns.
    @Test func successPathLeavesDestinationPresentAndNoOrphanedTempFile() async throws {
        let entry = try sampleManifestEntry()
        let realData = try Data(contentsOf: try #require(BundledFontIndex().loadAll().first { $0.record.fontID == "amiri" }?.record.faces.first?.fileURL))
        StubURLProtocol.stub(entry.fileURL, statusCode: 200, data: realData)

        let registry = MKFontRegistry()
        let downloader = MKFontDownloader(
            registry: registry, entitlements: StubEntitlementResolver(), session: StubURLProtocol.makeSession(),
            destinationRoot: FileManager.default.temporaryDirectory.appendingPathComponent("mk-dl-\(UUID().uuidString)")
        )

        let tmpDirPath = FileManager.default.temporaryDirectory.path
        let before = Set((try? FileManager.default.contentsOfDirectory(atPath: tmpDirPath))?.filter { $0.hasPrefix("mk-font-dl-") } ?? [])

        try await downloader.download(entry)

        let record = try #require(await registry.record(for: entry.fontID))
        let destinationFile = try #require(record.faces.first?.fileURL)
        #expect(FileManager.default.fileExists(atPath: destinationFile.path))

        let after = Set((try? FileManager.default.contentsOfDirectory(atPath: tmpDirPath))?.filter { $0.hasPrefix("mk-font-dl-") } ?? [])
        #expect(after == before, "no orphaned mk-font-dl- temp file should remain after a successful download")
    }

    /// EU-9: the previously-dead progress stream must now yield at least
    /// one in-range value and terminate, and `download(_:)` must not retain
    /// the continuation once it returns.
    @Test func progressStreamYieldsAndTerminatesThenContinuationIsRemoved() async throws {
        let entry = try sampleManifestEntry()
        let realData = try Data(contentsOf: try #require(BundledFontIndex().loadAll().first { $0.record.fontID == "amiri" }?.record.faces.first?.fileURL))
        StubURLProtocol.stub(entry.fileURL, statusCode: 200, data: realData)

        let registry = MKFontRegistry()
        let downloader = MKFontDownloader(
            registry: registry, entitlements: StubEntitlementResolver(), session: StubURLProtocol.makeSession(),
            destinationRoot: FileManager.default.temporaryDirectory.appendingPathComponent("mk-dl-\(UUID().uuidString)")
        )

        let progressStream = await downloader.progress(for: entry.fontID)
        async let collected: [Double] = {
            var values: [Double] = []
            for await value in progressStream { values.append(value) }
            return values
        }()

        try await downloader.download(entry)
        let values = await collected

        #expect(!values.isEmpty, "expected at least one progress value")
        #expect(values.allSatisfy { (0...1).contains($0) })
        let stillPending = await downloader.hasPendingProgressContinuation(for: entry.fontID)
        #expect(!stillPending, "progress continuation must be removed once download(_:) returns")
    }
}
