import CoreText
import Foundation
import Testing
@testable import MKFoundation

/// WS-01 packet §5 task 11 accept criterion: the stub resolves a `CTFont`
/// for size 17 and 96, and the in-memory document store round-trips a
/// save/load without any disk I/O.
@Suite("Font + document stubs")
struct FontAndDocumentStubTests {
    @Test func systemFontStubResolvesUIPointSize() {
        let provider = SystemFontStubProvider()
        let font = provider.resolve(MKFontHandle(postScriptName: "AnyName", pointSize: 17))
        #expect(CTFontGetSize(font) > 0)
    }

    @Test func systemFontStubResolvesDisplayPointSize() {
        let provider = SystemFontStubProvider()
        let font = provider.resolve(MKFontHandle(postScriptName: "AnyName", pointSize: 96))
        #expect(CTFontGetSize(font) > 0)
    }

    @Test func inMemoryDocumentStoreRoundTripsSaveLoad() async throws {
        let store = InMemoryDocumentStore()
        let id = MKProjectID()
        let payload = Data("scaffold-fixture".utf8)

        #expect(try await store.load(for: id) == nil)
        try await store.save(payload, for: id)
        #expect(try await store.load(for: id) == payload)
        try await store.delete(for: id)
        #expect(try await store.load(for: id) == nil)
    }
}
