import Foundation

// S-4 (AUDIT_2026-07-28.md): `importExternalPackage(at:)`
// (`Makhtoot/AppShell/Persistence/MKPersistenceProjectLibrary.swift`) is the
// app's widest untrusted-input surface ، a `.makhtoot` package handed to the
// app via AirDrop/"Open In"/Files.app ، and before this fix it validated
// only that `manifest.json` decodes before `copyItem`-ing the ENTIRE
// source directory verbatim into `Documents/Projects/`. There was no cap on
// total bytes, file count, or unexpected members, and anything extra a
// malicious or merely corrupt package carried would then be packed and
// uploaded to the user's own CloudKit container by the sync path (S-3).
//
// This file is a pure validation pass: it never mutates `at:`'s contents
// and performs no writes of its own. Call it BEFORE copying an externally-
// supplied package into managed storage, not as a replacement for the
// existing `readManifest()` check ، a package can pass this validator and
// still turn out to have a malformed manifest, and vice versa.

/// Caps + shape allowlist enforced by `DocumentPackage.validateForImport(at:limits:)`.
public struct MKPackageImportLimits: Sendable, Equatable {
    /// Maximum total bytes across every FILE in the source package
    /// (directories don't count toward this).
    public var maxTotalBytes: Int
    /// Maximum total file count (directories don't count toward this).
    public var maxFileCount: Int
    /// Allowed top-level entry NAMES directly inside the package root.
    /// Matches `DocumentPackage`'s own known layout (`manifestURL`,
    /// `sceneURL`, `journalURL`, `assetsDirURL`, `backupsDirURL`,
    /// `thumbnailURL`): a directory entry in this set is allowed to contain
    /// anything beneath it (still subject to the byte/file-count caps
    /// above); a file entry must be a file, not a directory.
    public var allowedTopLevelMembers: Set<String>

    public init(
        maxTotalBytes: Int = 200 * 1024 * 1024,
        maxFileCount: Int = 5_000,
        allowedTopLevelMembers: Set<String> = [
            "manifest.json", "scene.json", "thumbnail.png", "journal.mkj", "assets", "backups",
        ]
    ) {
        self.maxTotalBytes = maxTotalBytes
        self.maxFileCount = maxFileCount
        self.allowedTopLevelMembers = allowedTopLevelMembers
    }

    /// The limits `importExternalPackage(at:)` validates production imports
    /// against.
    public static let `default` = MKPackageImportLimits()
}

/// Thrown by `DocumentPackage.validateForImport(at:limits:)`. Distinct from
/// `MKPersistenceError` ، this is a rejection of an untrusted INPUT's shape,
/// not an internal I/O/decode failure of this app's own package format.
public enum MKPackageImportValidationError: Error, Sendable, Equatable {
    /// Total bytes across the package's files exceeded `limit`.
    case byteCapExceeded(limit: Int)
    /// Total file count across the package exceeded `limit`.
    case fileCountCapExceeded(limit: Int)
    /// A top-level entry not in `MKPackageImportLimits.allowedTopLevelMembers`
    /// was found. Carries the offending entry's name.
    case unexpectedMember(String)
}

extension DocumentPackage {
    /// Validates `url` (an externally-supplied `.makhtoot` package
    /// directory) BEFORE it is copied into this app's own managed storage.
    /// Enumerates every entry under `url`, enforcing a total-bytes cap, a
    /// total-file-count cap, an allowlist of expected top-level package
    /// members, and (S8-3) a blanket rejection of symbolic links anywhere in
    /// the package. Throws `MKPackageImportValidationError` on the first
    /// violation encountered ، this is a fail-fast gate, not a report of
    /// every violation at once.
    ///
    /// If `url` isn't a readable directory at all, this returns normally
    /// without error ، the caller's own subsequent package-open (`exists`
    /// check, `readManifest()`) is the authority on "is this actually a
    /// package", and surfaces that as its own, more specific failure. This
    /// validator's only job is bounding an otherwise-plausible directory's
    /// size and shape.
    public static func validateForImport(
        at url: URL,
        limits: MKPackageImportLimits = .default
    ) throws {
        let fm = FileManager.default

        // Top-level allowlist first ، cheap, and rejects an unexpected
        // member before spending time walking a potentially huge subtree
        // underneath it.
        let topLevelEntries = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
        for entry in topLevelEntries {
            // S8-3: the symlink check comes BEFORE the name check on purpose ،
            // a link named exactly `scene.json`/`thumbnail.png` passes the
            // allowlist on its name alone, which is the whole point of naming
            // it that. Reject on link-ness first, then on name.
            let entryURL = url.appendingPathComponent(entry)
            if (try? entryURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
                throw MKPackageImportValidationError.unexpectedMember(entry)
            }
            guard limits.allowedTopLevelMembers.contains(entry) else {
                throw MKPackageImportValidationError.unexpectedMember(entry)
            }
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]
        ) else {
            return
        }

        var totalBytes = 0
        var fileCount = 0

        for case let itemURL as URL in enumerator {
            let values = try? itemURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey])
            // S8-3: a symlink inside the package escapes every other cap here ،
            // the enumerator reports the LINK's own size (a few dozen bytes),
            // so a link to a multi-GB file never touches `maxTotalBytes`, and
            // `copyItem` preserves the link verbatim into managed storage,
            // where `MKProjectRecordCoder.pack`'s `Data(contentsOf:)` later
            // reads straight THROUGH it and uploads whatever it points at.
            // Rejecting the link entry itself is sufficient: `FileManager
            // .enumerator` does not descend into symlinked directories by
            // default. Checked before the `isDirectory` guard below ، a link
            // to a directory can report `isDirectory == true` and would
            // otherwise be skipped by that `continue`.
            guard values?.isSymbolicLink != true else {
                throw MKPackageImportValidationError.unexpectedMember(itemURL.lastPathComponent)
            }
            guard values?.isDirectory != true else { continue }

            fileCount += 1
            guard fileCount <= limits.maxFileCount else {
                throw MKPackageImportValidationError.fileCountCapExceeded(limit: limits.maxFileCount)
            }

            totalBytes += values?.fileSize ?? 0
            guard totalBytes <= limits.maxTotalBytes else {
                throw MKPackageImportValidationError.byteCapExceeded(limit: limits.maxTotalBytes)
            }
        }
    }
}
