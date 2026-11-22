import CoreText
import Foundation
import MKFoundation

/// T1/T5/T6/T17 ، the single runtime source of truth for every usable font
/// (bundled, premium-downloaded, user-imported): identity, faces, license
/// linkage, lock state. An `actor` because catalog mutation (download
/// completing, import completing, lock/unlock on entitlement change) can
/// race with lookups from the shaping/render hot path ، isolating state
/// here means every call site gets a consistent snapshot without its own
/// locking.
///
/// Conforms to `Sendable` (actor isolation) so it can be captured across
/// concurrency domains (WS-13's composition root, WS-03/07's default
/// `fonts:` parameter ، via `MKRegistryFontProvider`, since `MKFontProviding.
/// resolve(_:)` is synchronous and cannot itself be `actor`-isolated).
public actor MKFontRegistry {
    private var recordsByID: [MKFontID: MKFontRecord] = [:]
    private var licensesByID: [MKFontID: MKLicenseRecord] = [:]
    private var evidenceByID: [MKFontID: MKFontVerificationEvidence] = [:]
    private var provisionalIDs: Set<MKFontID> = []
    private var coverageByID: [MKFontID: MKCoverageReport] = [:]
    private var registeredURLs: Set<URL> = []
    /// Set of font IDs installed system-wide (`.persistent` scope).
    private var systemInstalledIDs: Set<MKFontID> = []
    private var continuations: [UUID: AsyncStream<[MKFontRecord]>.Continuation] = [:]

    public init() {}

    // MARK: - T3/T5 bundled load + registration

    /// Loads every bundled font whose `records.json` entry has
    /// `redistributionConfirmed == true` (T2 AC) and registers its files
    /// per-process (D-122, amended by D-219: `CTFontManagerRegisterFontURLs`
    /// with `.process` scope). Idempotent ، safe to call more than once
    /// (already-registered errors are tolerated, T5 AC).
    @discardableResult
    public func loadBundled(index: BundledFontIndex = BundledFontIndex()) throws -> [MKFontID] {
        let loaded = try index.loadAll()
        var loadedIDs: [MKFontID] = []
        for font in loaded {
            var allFacesRegistered = true
            for face in font.record.faces {
                do {
                    try registerURL(face.fileURL)
                } catch {
                    MKLog.logger(for: "MKFonts").warning("Failed to register \(face.postScriptName, privacy: .public): \(String(describing: error), privacy: .public)")
                    allFacesRegistered = false
                }
            }
            guard allFacesRegistered else { continue }
            recordsByID[font.record.fontID] = font.record
            licensesByID[font.record.fontID] = font.license
            evidenceByID[font.record.fontID] = font.evidence
            if font.isProvisionalShip { provisionalIDs.insert(font.record.fontID) }
            loadedIDs.append(font.record.fontID)
        }
        publish()
        refreshSystemInstalledStatus()
        return loadedIDs
    }

    /// Registers a single font URL per-process (D-122, amended by D-219).
    /// The modern `CTFontManagerRegisterFontURLs(_:_:_:_:)` signature takes
    /// a completion handler (not an error out-pointer) ، for local file
    /// URLs it is invoked synchronously before the call returns, which is
    /// what the tolerant error inspection below relies on. Tolerates the
    /// "already registered" case (idempotent re-launch/re-import within
    /// the same OS process ، T5 AC: "duplicate-launch registration
    /// produces no user-visible error"), which in practice matters most
    /// for test suites that construct multiple `MKFontRegistry` instances
    /// against the same on-disk font files within one `swift test`
    /// process (process-registration scope is a property of the OS
    /// process, not of any one `MKFontRegistry` instance).
    public func registerURL(_ url: URL) throws {
        guard !registeredURLs.contains(url) else { return }
        var thrown: MKFontError?
        CTFontManagerRegisterFontURLs([url] as CFArray, .process, true) { errors, done in
            guard done else { return true }
            let count = CFArrayGetCount(errors)
            guard count > 0 else { return true }
            let first = unsafeBitCast(CFArrayGetValueAtIndex(errors, 0), to: CFError.self)
            let nsError = first as Error as NSError
            let description = (nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? nsError.description).lowercased()
            if !description.contains("already") {
                thrown = .registrationFailed(underlying: nsError)
            }
            return true
        }
        if let thrown { throw thrown }
        registeredURLs.insert(url)
    }

    public func unregisterURL(_ url: URL) throws {
        guard registeredURLs.contains(url) else { return }
        CTFontManagerUnregisterFontURLs([url] as CFArray, .process, nil)
        registeredURLs.remove(url)
    }

    // MARK: - System-wide (persistent) font installation

    /// Whether a font is installed system-wide (`.persistent` scope).
    public func isFontSystemInstalled(fontID: MKFontID) -> Bool {
        systemInstalledIDs.contains(fontID)
    }

    /// Returns the set of font IDs installed system-wide.
    public func systemInstalledFontIDs() -> Set<MKFontID> {
        systemInstalledIDs
    }

    /// Installs all faces of a font system-wide via `.persistent` scope.
    /// On iOS 13+, this triggers a system dialog asking the user to approve.
    /// Throws on registration failure (user cancellation is NOT an error — the
    /// handler's `done` flag is still true with zero errors in that case).
    public func installFontSystemWide(fontID: MKFontID) async throws {
        guard let record = recordsByID[fontID] else {
            throw MKFontError.unknownFont(fontID: fontID)
        }
        for face in record.faces {
            try await installURLSystemWide(face.fileURL)
        }
        // Re-derive from CoreText rather than optimistically inserting.
        //
        // Bug fix (2026-07-29, user report: "installing fonts systemwide
        // doesn't work"). The root cause was a missing
        // `com.apple.developer.user-fonts` = `system-installation`
        // entitlement (added to `Makhtoot.entitlements` this session ،
        // without it `.persistent` registration cannot succeed at all),
        // but this line made the failure invisible: registration is
        // asynchronous and user-gated, and per this method's own contract
        // a DECLINED consent sheet resolves as success with zero errors.
        // Trusting that and inserting anyway made Settings claim the font
        // was installed system-wide when nothing had been installed.
        // `refreshSystemInstalledStatus()` asks CoreText what is actually
        // registered, so the toggle can only ever report the truth.
        refreshSystemInstalledStatus()
    }

    /// Uninstalls all faces of a font from the system-wide persistent scope.
    public func uninstallFontSystemWide(fontID: MKFontID) async throws {
        guard let record = recordsByID[fontID] else {
            throw MKFontError.unknownFont(fontID: fontID)
        }
        for face in record.faces {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                CTFontManagerUnregisterFontURLs([face.fileURL] as CFArray, .persistent) { errors, done in
                    guard done else { return true }
                    let count = CFArrayGetCount(errors)
                    if count > 0 {
                        let first = unsafeBitCast(CFArrayGetValueAtIndex(errors, 0), to: CFError.self)
                        continuation.resume(throwing: first as Error)
                    } else {
                        continuation.resume()
                    }
                    return true
                }
            }
        }
        // Same "ask CoreText, don't assume" rule as `installFontSystemWide`.
        refreshSystemInstalledStatus()
    }

    /// Rebuilds `systemInstalledIDs` from persistent-registered font descriptors.
    /// Call once at app launch after `loadBundled()`.
    ///
    /// Pre-existing build blocker fixed in passing (found while verifying
    /// an unrelated `@Observable` change, P0.1): `CTFontManagerCopyRegisteredFontDescriptors`
    /// is `API_UNAVAILABLE(macos, ...)` per CoreText's own header, so this
    /// call failed to COMPILE (not just at runtime) for the macOS host
    /// target that `Package.swift` declares "purely so `swift build`/
    /// `swift test` work directly on the host toolchain for fast local
    /// iteration." That made `swift build`/`swift test` fail for the whole
    /// package, on `main`, before this session touched anything (confirmed
    /// by reproducing on a clean stash of this branch). `#if os(iOS)`
    /// scopes the real implementation to iOS (the only platform this ever
    /// runs on in the shipped app, matching D-100's iOS 18 deployment
    /// target) and no-ops on macOS ، zero behavior change on iOS.
    public func refreshSystemInstalledStatus() {
        #if os(iOS)
        guard let descriptors = CTFontManagerCopyRegisteredFontDescriptors(.persistent, true) as? [CTFontDescriptor] else {
            return
        }
        let installedPSNames = Set(descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String })
        var found: Set<MKFontID> = []
        for (id, record) in recordsByID {
            let facePSNames = Set(record.faces.map(\.postScriptName))
            if !facePSNames.intersection(installedPSNames).isEmpty {
                found.insert(id)
            }
        }
        systemInstalledIDs = found
        #endif
    }

    /// Registers a single URL with `.persistent` scope (system-wide).
    private func installURLSystemWide(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            CTFontManagerRegisterFontURLs([url] as CFArray, .persistent, true) { errors, done in
                guard done else { return true }
                let count = CFArrayGetCount(errors)
                guard count > 0 else {
                    continuation.resume()
                    return true
                }
                let first = unsafeBitCast(CFArrayGetValueAtIndex(errors, 0), to: CFError.self)
                let nsError = first as Error as NSError
                let description = (nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? nsError.description).lowercased()
                // "already registered" is not an error for our purposes
                if description.contains("already") {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: MKFontError.registrationFailed(underlying: nsError))
                }
                return true
            }
        }
    }

    // MARK: - T1 lookups

    public func records() -> [MKFontRecord] {
        Array(recordsByID.values).sorted { $0.fontID < $1.fontID }
    }

    public func faces() -> [MKFontFace] {
        recordsByID.values.flatMap(\.faces)
    }

    public func record(for fontID: MKFontID) -> MKFontRecord? {
        recordsByID[fontID]
    }

    public func face(for fontID: MKFontID, postScriptName: String? = nil) -> MKFontFace? {
        guard let record = recordsByID[fontID] else { return nil }
        if let postScriptName {
            return record.faces.first { $0.postScriptName == postScriptName }
        }
        return record.defaultFace
    }

    public func licenseRecord(for fontID: MKFontID) -> MKLicenseRecord? {
        licensesByID[fontID]
    }

    public func verificationEvidence(for fontID: MKFontID) -> MKFontVerificationEvidence? {
        evidenceByID[fontID]
    }

    public func isProvisionalShip(_ fontID: MKFontID) -> Bool {
        provisionalIDs.contains(fontID)
    }

    /// Resolves a `CTFont` for a bundled/registered face. Throws
    /// `.fontLocked` for a locked font (T17) ، re-shape requests must not
    /// silently succeed once a font is expiry-locked.
    public func ctFont(for fontID: MKFontID, postScriptName: String? = nil, size: CGFloat) throws -> CTFont {
        guard let record = recordsByID[fontID] else { throw MKFontError.unknownFont(fontID: fontID) }
        if record.isLocked { throw MKFontError.fontLocked(fontID: fontID) }
        guard let face = postScriptName.flatMap({ ps in record.faces.first { $0.postScriptName == ps } }) ?? record.defaultFace else {
            throw MKFontError.unknownFont(fontID: fontID)
        }
        let font = CTFontCreateWithName(face.postScriptName as CFString, size, nil)
        guard (CTFontCopyPostScriptName(font) as String) == face.postScriptName else {
            throw MKFontError.registrationFailed(underlying: nil)
        }
        return font
    }

    // MARK: - T6 registration/import of non-bundled fonts

    public func registerDownloaded(_ record: MKFontRecord, license: MKLicenseRecord) throws {
        for face in record.faces { try registerURL(face.fileURL) }
        recordsByID[record.fontID] = record
        licensesByID[record.fontID] = license
        publish()
    }

    public func registerImported(_ record: MKFontRecord, license: MKLicenseRecord) throws {
        for face in record.faces { try registerURL(face.fileURL) }
        recordsByID[record.fontID] = record
        licensesByID[record.fontID] = license
        publish()
    }

    public func remove(_ fontID: MKFontID) throws {
        guard let record = recordsByID[fontID] else { return }
        for face in record.faces { try unregisterURL(face.fileURL) }
        recordsByID.removeValue(forKey: fontID)
        licensesByID.removeValue(forKey: fontID)
        evidenceByID.removeValue(forKey: fontID)
        publish()
    }

    // MARK: - T17 expiry locking

    /// Locks/unlocks every font of the given origins. Does NOT unregister
    /// (D-119: existing placed text must still display via cached shaping)
    /// ، only flips `isLocked`, which `ctFont(for:)` consults to refuse
    /// NEW shaping requests.
    public func setLocked(_ locked: Bool, origins: Set<MKFontOrigin> = [.premiumDownloaded, .userImported]) {
        for (id, record) in recordsByID where origins.contains(record.origin) {
            var updated = record
            updated.isLocked = locked
            recordsByID[id] = updated
        }
        publish()
    }

    public func setLocked(_ locked: Bool, fontID: MKFontID) {
        guard var record = recordsByID[fontID] else { return }
        record.isLocked = locked
        recordsByID[fontID] = record
        publish()
    }

    // MARK: - T6 catalog snapshot stream

    public var recordsDidChange: AsyncStream<[MKFontRecord]> {
        AsyncStream { continuation in
            let token = UUID()
            continuations[token] = continuation
            continuation.yield(records())
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(token) }
            }
        }
    }

    private func removeContinuation(_ token: UUID) {
        continuations.removeValue(forKey: token)
    }

    private func publish() {
        let snapshot = records()
        for continuation in continuations.values { continuation.yield(snapshot) }
    }

    // MARK: - T10 coverage cache

    public func coverageReport(for fontID: MKFontID) -> MKCoverageReport? {
        if let cached = coverageByID[fontID] { return cached }
        guard let record = recordsByID[fontID], let face = record.defaultFace else { return nil }
        guard let font = try? ctFont(for: fontID, postScriptName: face.postScriptName, size: 28) else { return nil }
        let report = MKCoverageAnalyzer().analyze(font)
        coverageByID[fontID] = report
        return report
    }
}
