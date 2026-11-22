import CloudKit
import Foundation

// T1 ، CloudKit schema constants. All field names, record types, and zone
// identifiers live here; `MKProjectRecordCoder` (T2) and
// `MKSyncEngineController` (T3) import these constants, never spelling
// raw strings themselves.

/// CloudKit schema constants for MKSync.
///
/// Record type `MKProject` lives in zone `MakhtootProjects` in the
/// user's *private* database (container `iCloud.net.binjamshid.makhtoot`,
/// FD-01 confirmed). Large project assets are stored as child records
/// of type `MKProjectAsset`, keyed `"\(projectUUID)_\(hash)"`, so they
/// upload/download incrementally and deduplicate across projects.
public enum MKSyncSchema {
    /// CloudKit container identifier (FD-01 applied ، real bundle ID confirmed).
    /// Mirrors FOUNDATION §0's real bundle ID `net.binjamshid.makhtoot`.
    public static let containerIdentifier = "iCloud.net.binjamshid.makhtoot"

    /// Custom zone name. A single zone scopes all project data so
    /// per-zone change tokens minimise re-fetch bandwidth.
    public static let zoneName = "MakhtootProjects"

    /// Zone ID used when constructing record IDs and the zone itself.
    public static let zoneID = CKRecordZone.ID(
        zoneName: zoneName,
        ownerName: CKCurrentUserDefaultName
    )

    /// `CKRecord` type for a Makhtoot project.
    public static let projectRecordType = "MKProject"

    /// `CKRecord` type for an individual project asset (child record).
    public static let assetRecordType = "MKProjectAsset"

    // MARK: - MKProject field names

    /// Project display name (mirrors `MKManifest.title`).
    public static let fieldName = "name"

    /// Folder path string (e.g. `"Work"`) or empty string for the root.
    /// Recreated by `MetadataStore.createFolder` on the receiving device.
    public static let fieldFolderPath = "folderPath"

    /// Schema version integer (`MKManifest.schemaVersion`). Forward-compat
    /// gate: if remote `schemaVersion > MKSyncTunables.supportedSchemaVersion`,
    /// the record is quarantined and not applied (T14).
    public static let fieldSchemaVersion = "schemaVersion"

    /// `Date` of last content change. Used by the LWW algorithm (T6/T7).
    public static let fieldModifiedAt = "modifiedAt"

    /// SHA-256 hex content hash of scene.json. The canonical divergence
    /// detector; two records are LWW-equal only if their hashes match.
    public static let fieldContentHash = "contentHash"

    /// `CKAsset` wrapping the serialised `manifest.json` bytes.
    public static let fieldManifest = "manifest"

    /// `CKAsset` wrapping the serialised `scene.json` bytes.
    public static let fieldScene = "scene"

    /// `CKAsset` wrapping the project thumbnail PNG (optional).
    public static let fieldThumbnail = "thumbnail"

    /// `CKAsset` wrapping a JSON array of asset SHA-256 hashes, so the
    /// receiver knows which `MKProjectAsset` child records belong to this
    /// project without listing the zone.
    public static let fieldAssetIndex = "assetIndex"

    // MARK: - MKProjectAsset field names

    /// `CKRecord.Reference` back to the parent `MKProject` record.
    public static let assetFieldProjectRef = "projectRef"

    /// SHA-256 hex hash of the asset payload (content-addressed).
    public static let assetFieldHash = "hash"

    /// `CKAsset` containing the raw asset bytes.
    public static let assetFieldPayload = "payload"

    // MARK: - Record-name helpers

    /// CloudKit record name for a project record: the project UUID string.
    public static func projectRecordName(for projectID: UUID) -> String {
        projectID.uuidString
    }

    /// CloudKit record name for an asset child record.
    public static func assetRecordName(projectID: UUID, hash: String) -> String {
        "\(projectID.uuidString)_\(hash)"
    }

    /// `CKRecord.ID` for a project record.
    public static func projectRecordID(for projectID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: projectRecordName(for: projectID), zoneID: zoneID)
    }

    /// `CKRecord.ID` for an asset record.
    public static func assetRecordID(projectID: UUID, hash: String) -> CKRecord.ID {
        CKRecord.ID(recordName: assetRecordName(projectID: projectID, hash: hash), zoneID: zoneID)
    }
}
