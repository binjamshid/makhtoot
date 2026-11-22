import Foundation

/// A phantom-typed UUID wrapper so identifiers for different entity kinds
/// (nodes, projects, clusters, …) cannot be cross-assigned by the compiler.
///
/// `Tag` never needs a runtime value ، it exists only to make `MKID<NodeTag>`
/// and `MKID<ProjectTag>` distinct, non-interchangeable types even though
/// both wrap a `UUID`. This is the WS-01 foundation for every other
/// workstream's identifier type (e.g. WS-02's `FontID`/`AssetID`).
public struct MKID<Tag>: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(UUID.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Phantom tag for `MKNodeID` ، identifies one scene-graph node (`MKNode`,
/// owned by WS-02's `MKModel`).
public enum MKNodeTag: Sendable {}
public typealias MKNodeID = MKID<MKNodeTag>

/// Phantom tag for `MKProjectID` ، identifies one `.makhtoot` project
/// document (owned by WS-02's `MKPersistence`).
public enum MKProjectTag: Sendable {}
public typealias MKProjectID = MKID<MKProjectTag>

/// Phantom tag for `MKClusterID` ، identifies one shaped-text cluster
/// (codepoint↔cluster↔glyph mapping, owned by WS-03's `MKTextEngine`,
/// D-105).
public enum MKClusterTag: Sendable {}
public typealias MKClusterID = MKID<MKClusterTag>

