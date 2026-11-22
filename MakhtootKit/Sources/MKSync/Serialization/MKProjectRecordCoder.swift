import CloudKit
import CryptoKit
import Foundation
import MKPersistence

// T2 ، Serialization to/from CloudKit records.
// "Never partially apply: a fetched project materializes fully in temp
// before rename." (T2 AC, WS-11 packet §5).

/// Packs a `.makhtoot` project package into CloudKit records and unpacks
/// a CloudKit record back into a staged temp package.
///
/// The coder never touches the live Documents directory directly:
/// - **Pack**: reads the package as-is (caller ensures autosave has quiesced
///   or a consistent snapshot is available) and creates `CKAssets` pointing
///   to temp copies of each file.
/// - **Unpack**: writes all files into a fresh temp directory, then the
///   caller atomically moves the temp directory into Documents.
///
/// This matches the "write-temp + rename" discipline of `MKAtomicIO`.
public struct MKProjectRecordCoder: Sendable {
    private let zoneID: CKRecordZone.ID

    public init(zoneID: CKRecordZone.ID = MKSyncSchema.zoneID) {
        self.zoneID = zoneID
    }

    // MARK: - Pack (local → CKRecords)

    /// Packs `package` into a project `CKRecord` and zero or more asset
    /// child `CKRecord`s.
    ///
    /// - Parameters:
    ///   - package: The source `.makhtoot` package (must exist on disk).
    ///   - projectID: UUID that becomes the CloudKit record name.
    ///   - summary: Metadata summary (title, folderID, modifiedAt, etc.).
    ///   - tempDir: Scratch directory for staging asset copies. The caller
    ///     is responsible for cleaning this up after the upload completes.
    /// - Returns: A tuple of the project record and all asset child records.
    public func pack(
        package: DocumentPackage,
        projectID: UUID,
        summary: MKProjectSummary,
        tempDir: URL
    ) throws -> (projectRecord: CKRecord, assetRecords: [CKRecord]) {
        let fm = FileManager.default
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let recordID = MKSyncSchema.projectRecordID(for: projectID)
        let projectRecord = CKRecord(recordType: MKSyncSchema.projectRecordType, recordID: recordID)

        let manifest = try package.readManifest()

        projectRecord[MKSyncSchema.fieldName] = summary.title as CKRecordValue
        projectRecord[MKSyncSchema.fieldFolderPath] = uuidString(for: summary.folderID) as CKRecordValue
        projectRecord[MKSyncSchema.fieldSchemaVersion] = Int64(manifest.schemaVersion) as CKRecordValue
        projectRecord[MKSyncSchema.fieldModifiedAt] = summary.modifiedAt as CKRecordValue

        // Content hash: re-compute from scene data to ensure accuracy.
        let sceneData = try Data(contentsOf: package.sceneURL)
        let contentHash = sha256Hex(sceneData)
        projectRecord[MKSyncSchema.fieldContentHash] = contentHash as CKRecordValue

        // Stage manifest.json as CKAsset
        let manifestDest = tempDir.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let manifestData = try encoder.encode(manifest)
        try manifestData.write(to: manifestDest)
        projectRecord[MKSyncSchema.fieldManifest] = CKAsset(fileURL: manifestDest)

        // Stage scene.json as CKAsset
        let sceneDest = tempDir.appendingPathComponent("scene.json")
        try fm.copyItem(at: package.sceneURL, to: sceneDest)
        projectRecord[MKSyncSchema.fieldScene] = CKAsset(fileURL: sceneDest)

        // Stage thumbnail if present
        if fm.fileExists(atPath: package.thumbnailURL.path) {
            let thumbDest = tempDir.appendingPathComponent("thumbnail.png")
            try fm.copyItem(at: package.thumbnailURL, to: thumbDest)
            projectRecord[MKSyncSchema.fieldThumbnail] = CKAsset(fileURL: thumbDest)
        }

        // Build asset child records + index
        var assetHashes: [String] = []
        var assetRecords: [CKRecord] = []
        let assetsDir = package.assetsDirURL

        if fm.fileExists(atPath: assetsDir.path) {
            let assetFiles = (try? fm.contentsOfDirectory(
                at: assetsDir, includingPropertiesForKeys: nil)) ?? []
            for assetURL in assetFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let data = try Data(contentsOf: assetURL)
                let hash = sha256Hex(data)
                assetHashes.append(hash)

                let assetDest = tempDir.appendingPathComponent("asset_\(hash)")
                if !fm.fileExists(atPath: assetDest.path) {
                    try fm.copyItem(at: assetURL, to: assetDest)
                }

                let assetRecordID = MKSyncSchema.assetRecordID(projectID: projectID, hash: hash)
                let assetRecord = CKRecord(recordType: MKSyncSchema.assetRecordType, recordID: assetRecordID)
                assetRecord[MKSyncSchema.assetFieldProjectRef] = CKRecord.Reference(
                    recordID: recordID, action: .deleteSelf
                ) as CKRecordValue
                assetRecord[MKSyncSchema.assetFieldHash] = hash as CKRecordValue
                assetRecord[MKSyncSchema.assetFieldPayload] = CKAsset(fileURL: assetDest)
                assetRecords.append(assetRecord)
            }
        }

        // Asset index JSON (list of hashes so receiver knows what to fetch)
        let indexData = try JSONSerialization.data(withJSONObject: assetHashes)
        let indexDest = tempDir.appendingPathComponent("assetIndex.json")
        try indexData.write(to: indexDest)
        projectRecord[MKSyncSchema.fieldAssetIndex] = CKAsset(fileURL: indexDest)

        return (projectRecord: projectRecord, assetRecords: assetRecords)
    }

    // MARK: - Unpack (CKRecord → staged package)

    /// Materialises a remote CloudKit project record into a staged temp package.
    ///
    /// ALL files are written to `tempDir` before the method returns.
    /// The caller atomically moves the staged package into Documents using
    /// `FileManager.replaceItemAt(_:withItemAt:)` ، same discipline as
    /// `MKAtomicIO.write`, so an interrupted apply leaves the original intact.
    ///
    /// - Returns: The staged `DocumentPackage` plus extracted metadata.
    public func unpack(
        projectRecord: CKRecord,
        assetRecords: [CKRecord],
        into tempDir: URL
    ) throws -> MKUnpackResult {
        let fm = FileManager.default

        guard let name = projectRecord[MKSyncSchema.fieldName] as? String else {
            throw MKSyncCoderError.missingField(MKSyncSchema.fieldName)
        }
        guard let projectID = UUID(uuidString: projectRecord.recordID.recordName) else {
            throw MKSyncCoderError.invalidRecordName(projectRecord.recordID.recordName)
        }

        let folderPath = projectRecord[MKSyncSchema.fieldFolderPath] as? String ?? ""
        let contentHash = projectRecord[MKSyncSchema.fieldContentHash] as? String ?? ""
        let schemaVersion = projectRecord[MKSyncSchema.fieldSchemaVersion] as? Int64 ?? 1
        let modifiedAt = projectRecord[MKSyncSchema.fieldModifiedAt] as? Date ?? Date()

        // Stage directory: tempDir/<projectID>.makhtoot/
        let stagingURL = tempDir.appendingPathComponent(
            "\(projectID.uuidString).makhtoot", isDirectory: true)
        try fm.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        let assetsDir = stagingURL.appendingPathComponent("assets", isDirectory: true)
        try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        try fm.createDirectory(
            at: stagingURL.appendingPathComponent("backups", isDirectory: true),
            withIntermediateDirectories: true)

        // Unpack manifest
        if let manifestAsset = projectRecord[MKSyncSchema.fieldManifest] as? CKAsset,
           let assetURL = manifestAsset.fileURL {
            try fm.copyItem(at: assetURL, to: stagingURL.appendingPathComponent("manifest.json"))
        }

        // Unpack scene
        if let sceneAsset = projectRecord[MKSyncSchema.fieldScene] as? CKAsset,
           let assetURL = sceneAsset.fileURL {
            try fm.copyItem(at: assetURL, to: stagingURL.appendingPathComponent("scene.json"))
        }

        // Unpack thumbnail if present
        if let thumbAsset = projectRecord[MKSyncSchema.fieldThumbnail] as? CKAsset,
           let assetURL = thumbAsset.fileURL {
            try fm.copyItem(at: assetURL, to: stagingURL.appendingPathComponent("thumbnail.png"))
        }

        // Unpack asset child records
        for assetRecord in assetRecords {
            guard
                let hash = assetRecord[MKSyncSchema.assetFieldHash] as? String,
                let payloadAsset = assetRecord[MKSyncSchema.assetFieldPayload] as? CKAsset,
                let payloadURL = payloadAsset.fileURL
            else { continue }
            let destURL = assetsDir.appendingPathComponent(hash)
            if !fm.fileExists(atPath: destURL.path) {
                try fm.copyItem(at: payloadURL, to: destURL)
            }
        }

        let package = DocumentPackage(rootURL: stagingURL)
        return MKUnpackResult(
            package: package,
            projectID: projectID,
            title: name,
            folderID: UUID(uuidString: folderPath),
            contentHash: contentHash,
            schemaVersion: schemaVersion,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - Snapshot extraction (no I/O ، used for LWW decision)

    /// Extracts an `MKSyncSnapshot` from a remote `CKRecord` without
    /// materialising the package. Used by the LWW decision engine (T6/T7).
    public func snapshot(from record: CKRecord) -> MKSyncSnapshot? {
        guard
            let hash = record[MKSyncSchema.fieldContentHash] as? String,
            let date = record[MKSyncSchema.fieldModifiedAt] as? Date
        else { return nil }
        return MKSyncSnapshot(contentHash: hash, modifiedAt: date)
    }

    /// Schema version of a remote record, or 1 if absent.
    public func schemaVersion(from record: CKRecord) -> Int64 {
        record[MKSyncSchema.fieldSchemaVersion] as? Int64 ?? 1
    }

    // MARK: - Private

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func uuidString(for uuid: UUID?) -> String {
        uuid?.uuidString ?? ""
    }
}

// MARK: - Result type

/// Result of `MKProjectRecordCoder.unpack`.
public struct MKUnpackResult: Sendable {
    public let package: DocumentPackage
    public let projectID: UUID
    public let title: String
    public let folderID: UUID?
    public let contentHash: String
    public let schemaVersion: Int64
    public let modifiedAt: Date
}

// MARK: - Errors

public enum MKSyncCoderError: Error, Sendable {
    case missingField(String)
    case invalidRecordName(String)
    case assetMissing(String)
}
