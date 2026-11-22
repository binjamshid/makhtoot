import Foundation

/// Minimal open/save hooks so canvas and engine test apps can round-trip
/// "a document" before WS-02's real `.makhtoot` file-package persistence
/// (`MKPersistence`, D-112) exists. Keyed by `MKProjectID`; payload is
/// opaque `Data` ، WS-01 makes no assumption about the eventual
/// `scene.json` shape here, that contract belongs to `MKModel`/
/// `MKPersistence`.
public protocol MKDocumentStoring: Sendable {
    /// Persists `data` for `id`, replacing any previous value.
    func save(_ data: Data, for id: MKProjectID) async throws

    /// Loads the most recently saved data for `id`, or `nil` if none
    /// exists yet.
    func load(for id: MKProjectID) async throws -> Data?

    /// Removes any stored data for `id`.
    func delete(for id: MKProjectID) async throws
}

/// In-memory `MKDocumentStoring` conformer: no disk I/O, no crash
/// recovery, nothing survives process exit. Exists purely so WS-03..WS-08
/// can exercise "open/save a document" code paths in tests before WS-02
/// ships `MKPersistence`'s real file-package + SwiftData stack. WS-02
/// replaces this ، see `MakhtootKit/CONTRACTS.md`.
public actor InMemoryDocumentStore: MKDocumentStoring {
    private var storage: [MKProjectID: Data] = [:]

    public init() {}

    public func save(_ data: Data, for id: MKProjectID) async throws {
        storage[id] = data
    }

    public func load(for id: MKProjectID) async throws -> Data? {
        storage[id]
    }

    public func delete(for id: MKProjectID) async throws {
        storage.removeValue(forKey: id)
    }
}
