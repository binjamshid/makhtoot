import CryptoKit
import Foundation
import MKFoundation

/// T14/T15 ، premium-only user font import (Q64, D-122). Pipeline:
/// entitlement gate → sfnt validation (`MKFontValidator`) → content-
/// addressed copy into `Application Support/Fonts/Imported/<sha256>.<ext>`
/// → `.process` register → catalog entry `userImported`, with a
/// `licenseType = .userProvided` record carrying zero embedding rights
/// (T15 ، WS-08 outlines on export).
public actor MKFontImporter {
    private let registry: MKFontRegistry
    private let entitlements: any MKEntitlementProviding
    private let validator: MKFontValidator
    private let destinationRoot: URL

    public init(
        registry: MKFontRegistry, entitlements: any MKEntitlementProviding,
        validator: MKFontValidator = MKFontValidator(),
        destinationRoot: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fonts/Imported", isDirectory: true)
    ) {
        self.registry = registry
        self.entitlements = entitlements
        self.validator = validator
        self.destinationRoot = destinationRoot
    }

    /// `sourceURL` is expected to be a security-scoped Files-picker URL;
    /// the caller (WS-13 UI) owns `startAccessingSecurityScopedResource()`/
    /// `stopAccessingSecurityScopedResource()` bracketing ، this actor only
    /// reads bytes, it does not manage scope lifetime (keeps this module
    /// UIKit/AppKit-free per FOUNDATION's "SwiftUI-first + Core
    /// Text/CG only in MKTextEngine/MKFonts" rule).
    @discardableResult
    public func importFont(from sourceURL: URL, originalFilename: String) async throws -> MKFontID {
        guard entitlements.isEntitled(.fontImport) else { throw MKFontError.premiumRequired }

        let data: Data
        do {
            data = try Data(contentsOf: sourceURL)
        } catch {
            throw MKFontError.corruptFile
        }

        let verdict = validator.validate(data)
        let faces: [MKFontValidator.ValidatedFace]
        switch verdict {
        case .ok(let validated): faces = validated
        case .reject(let error): throw error
        }

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let ext = (originalFilename as NSString).pathExtension.isEmpty ? "ttf" : (originalFilename as NSString).pathExtension
        try FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        let destination = destinationRoot.appendingPathComponent("\(digest).\(ext)")

        let fontID: MKFontID = "user.\(digest.prefix(16))"

        // Idempotent: importing the same bytes twice is a no-op, not a
        // duplicate catalog entry (T14 AC).
        if let existing = await registry.record(for: fontID) {
            return existing.fontID
        }

        if !FileManager.default.fileExists(atPath: destination.path) {
            try data.write(to: destination, options: .atomic)
        }

        let mkFaces = faces.enumerated().map { index, face -> MKFontFace in
            let ps = face.postScriptName ?? "\(fontID).\(index)"
            return MKFontFace(
                postScriptName: ps, familyName: face.familyName ?? originalFilename,
                fullName: ps, styleName: "normal", weight: 400, isVariable: face.isVariable,
                format: face.format, filename: destination.lastPathComponent, fileURL: destination
            )
        }
        let familyName = mkFaces.first?.familyName ?? originalFilename
        let record = MKFontRecord(
            fontID: fontID, familyName: familyName, origin: .userImported,
            faces: mkFaces, categories: [], tags: [], isLocked: false
        )
        let license = MKLicenseRecord.userProvided(fontID: fontID, familyName: familyName, importedAt: Date())
        try await registry.registerImported(record, license: license)
        return fontID
    }
}
