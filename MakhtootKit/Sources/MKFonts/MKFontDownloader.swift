import CryptoKit
import Foundation
import MKFoundation

/// T12 ، entitlement-gated premium font download. `.hosted` mode only;
/// `.bundledFallback` mode's "download" is really just an unlock (T13),
/// handled by `MKFontImporter`-style registration directly from the bundled
/// premium-fonts directory, not this type.
public actor MKFontDownloader {
    private let registry: MKFontRegistry
    private let entitlements: any MKEntitlementProviding
    private let session: URLSession
    private let destinationRoot: URL
    private var progressContinuations: [MKFontID: AsyncStream<Double>.Continuation] = [:]

    public init(
        registry: MKFontRegistry, entitlements: any MKEntitlementProviding,
        session: URLSession = .shared,
        destinationRoot: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fonts/Premium", isDirectory: true)
    ) {
        self.registry = registry
        self.entitlements = entitlements
        self.session = session
        self.destinationRoot = destinationRoot
    }

    public func progress(for fontID: MKFontID) -> AsyncStream<Double> {
        AsyncStream { continuation in
            progressContinuations[fontID] = continuation
        }
    }

    /// Test-only observability hook (exercised via `@testable import` —
    /// `internal`, not `private`, is what makes that reachable). Asserts
    /// EU-9's fix directly: `download(_:)` must not leave a finished-but-
    /// still-retained continuation behind once it returns.
    func hasPendingProgressContinuation(for fontID: MKFontID) -> Bool {
        progressContinuations[fontID] != nil
    }

    /// Pseudocode-matching implementation of T12's gate:
    /// entitlement → manifest lookup → download → sha256 verify →
    /// content-addressed move → `.process` register → catalog update.
    public func download(_ entry: MKCatalogManifestEntry) async throws {
        // EU-9: the progress continuation registered by `progress(for:)` (if
        // any) must always be finished and removed, on every exit path —
        // including the guards immediately below, not just a transport
        // failure deeper in — or a consumer awaits forever and this
        // dictionary leaks an entry per call. Capture + defer first, before
        // any throwing path.
        let progressContinuation = progressContinuations[entry.fontID]
        defer {
            progressContinuations[entry.fontID]?.finish()
            progressContinuations.removeValue(forKey: entry.fontID)
        }

        guard entitlements.isEntitled(.premiumFonts) else { throw MKFontError.premiumRequired }
        // S-9: `entry.fileURL` comes straight off the fetched manifest ،
        // ATS blocks cleartext `http://` by default but does not cover
        // `file://`, so an untrusted/misconfigured manifest entry could
        // otherwise point this at an on-device path. Reject before any I/O.
        guard entry.fileURL.scheme == "https" else { throw MKFontError.offline }

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("mk-font-dl-\(UUID().uuidString)")

        let data: Data
        do {
            // EU-9: stream via `bytes(from:)` instead of `download(from:)` so
            // fractional progress can be yielded as bytes arrive, rather than
            // only learning the result once the whole file has landed.
            let (byteStream, response) = try await session.bytes(from: entry.fileURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw MKFontError.offline
            }
            let expectedLength = http.expectedContentLength

            var accumulated = Data()
            if expectedLength > 0 {
                accumulated.reserveCapacity(Int(expectedLength))
            }
            var lastReportedFraction = 0.0
            for try await byte in byteStream {
                accumulated.append(byte)
                guard expectedLength > 0 else { continue }
                let fraction = min(Double(accumulated.count) / Double(expectedLength), 1.0)
                // Throttle to roughly 1%-granularity yields rather than one
                // per byte — still incremental progress, without flooding
                // the (unbounded-buffer) `AsyncStream` on a multi-MB font.
                if fraction - lastReportedFraction >= 0.01 {
                    progressContinuation?.yield(fraction)
                    lastReportedFraction = fraction
                }
            }
            // `expectedContentLength` is `-1` when the server response omits
            // `Content-Length` (e.g. chunked transfer) ، there's no
            // known-total to compute fractional progress against mid-stream
            // in that case, but a consumer should still see a definite
            // completion signal rather than nothing at all before `finish()`.
            if lastReportedFraction < 1.0 {
                progressContinuation?.yield(1.0)
            }
            data = accumulated
        } catch let error as MKFontError {
            throw error
        } catch {
            throw MKFontError.offline
        }

        // S-9: the cleanup `defer` used to be registered before the file at
        // `tmpURL` existed to remove and fired unconditionally — harmless on
        // the success path (by then `moveItem` had already consumed the
        // source), but it obscured intent and would have silently swallowed
        // a genuine cleanup failure on an error path. Scope cleanup to the
        // failure paths only, explicitly.
        do {
            try data.write(to: tmpURL, options: .atomic)

            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == entry.fileSHA256 else {
                throw MKFontError.checksumMismatch
            }

            try FileManager.default.createDirectory(at: destinationRoot.appendingPathComponent(entry.fontID), withIntermediateDirectories: true)
            let destination = destinationRoot.appendingPathComponent(entry.fontID).appendingPathComponent("\(digest).ttf")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tmpURL, to: destination)

            let faces = entry.faces.map { face in
                MKFontFace(
                    postScriptName: face.postScriptName, familyName: entry.family, fullName: face.postScriptName,
                    styleName: face.styleName, weight: face.weight, isVariable: face.isVariable,
                    format: .ttf, filename: destination.lastPathComponent, fileURL: destination
                )
            }
            let record = MKFontRecord(
                fontID: entry.fontID, familyName: entry.family, origin: .premiumDownloaded,
                faces: faces, categories: entry.categories, tags: entry.tags, isLocked: false
            )
            try await registry.registerDownloaded(record, license: entry.licenseRecord)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            throw error
        }
    }
}
