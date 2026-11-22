import Foundation
import Testing
@testable import MKFoundation

/// WS-01 packet §5 task 4 accept criterion: unit test round-trips Codable
/// for the typed id wrappers.
@Suite("MKID Codable round-trip")
struct IdentifiersTests {
    @Test func nodeIDRoundTripsThroughJSON() throws {
        let original = MKNodeID()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MKNodeID.self, from: data)
        #expect(decoded == original)
    }

    @Test func projectIDRoundTripsThroughJSON() throws {
        let original = MKProjectID()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MKProjectID.self, from: data)
        #expect(decoded == original)
    }

    @Test func clusterIDRoundTripsThroughJSON() throws {
        let original = MKClusterID()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MKClusterID.self, from: data)
        #expect(decoded == original)
    }

    @Test func descriptionMatchesRawUUIDString() {
        let raw = UUID()
        let id = MKNodeID(rawValue: raw)
        #expect(id.description == raw.uuidString)
    }
}
