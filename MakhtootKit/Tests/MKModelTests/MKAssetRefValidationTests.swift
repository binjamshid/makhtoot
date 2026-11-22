import Foundation
import Testing
@testable import MKModel

/// S-2 (AUDIT_2026-07-28.md): path traversal through unvalidated
/// `MKAssetRef` fields. `MKAssetStore.assetURL(for:)` interpolates
/// `digest`/`ext` straight into a path component
/// (`"sha256-\(ref.digest).\(ref.ext)"`), and `appendingPathComponent`
/// does not normalize `..`. A hand-crafted `.makhtoot` package (AirDrop,
/// Files.app, iCloud share) whose `scene.json` carries e.g.
/// `"ext": "png/../../../../Library/Preferences/…"` must be rejected at
/// DECODE time, before that string ever reaches the filesystem ،
/// `MKAssetRef`'s hand-written `init(from:)` (`MKNode.swift`) is what this
/// suite guards: `digest` must be 1-64 lowercase-hex characters, `ext` must
/// be 1-8 lowercase alphanumeric characters, and anything else throws
/// rather than decoding partially.
///
/// `digest` is bounded to 1-64 characters (not pinned to exactly 64,
/// despite `MKContentHash.sha256Hex` always emitting exactly 64) because
/// several pre-existing fixtures elsewhere in this test suite
/// (`MKImageNodeTests`, `MKBackgroundContentTests`, `MKExportTests/Support
/// /TestScenes.swift`, `MKCanvasTests/CanvasContentAPITests.swift`, all
/// outside this file's scope) decode short placeholder hex digests like
/// `"deadbeef"`/`"cafebabe"`/`"abc123"` through this exact `Decodable`
/// path. The character-class restriction (only `[a-f0-9]`) is what closes
/// S-2 ، a traversal payload cannot consist solely of those characters ،
/// not the exact length, so relaxing the length bound costs nothing on the
/// security side while keeping every existing fixture decodable.
@Suite("MKAssetRef Codable validation (S-2)")
struct MKAssetRefValidationTests {
    private func decode(_ json: String) throws -> MKAssetRef {
        try JSONDecoder().decode(MKAssetRef.self, from: Data(json.utf8))
    }

    // MARK: - Valid inputs decode

    @Test func validDigestAndExtRoundTripThroughEncodeDecode() throws {
        let ref = MKAssetRef(
            digest: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd", ext: "png"
        )
        let data = try JSONEncoder().encode(ref)
        let decoded = try JSONDecoder().decode(MKAssetRef.self, from: data)
        #expect(decoded == ref)
    }

    @Test func shortPlaceholderDigestsUsedByExistingFixturesStillDecode() throws {
        // Matches the exact shape `MKImageNodeTests`/`MKBackgroundContentTests`
        // already rely on ، see this suite's header for why the length bound
        // is 1-64, not exactly 64.
        let decoded = try decode(#"{"digest":"deadbeef","ext":"jpg"}"#)
        #expect(decoded == MKAssetRef(digest: "deadbeef", ext: "jpg"))
    }

    // MARK: - Malformed `digest` throws

    @Test func digestContainingPathTraversalSequenceThrowsOnDecode() throws {
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"../../../etc/passwd","ext":"png"}"#)
        }
    }

    @Test func digestContainingForwardSlashThrowsOnDecode() throws {
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"abc/def","ext":"png"}"#)
        }
    }

    @Test func digestWithUppercaseHexCharactersThrowsOnDecode() throws {
        // The allowlist is strictly `[a-f0-9]` ، uppercase must be rejected,
        // not silently case-folded (silently accepting it would widen the
        // allowlist beyond what `assetURL(for:)`'s filename construction
        // was validated against).
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"DEADBEEF","ext":"png"}"#)
        }
    }

    @Test func emptyDigestThrowsOnDecode() throws {
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"","ext":"png"}"#)
        }
    }

    @Test func digestLongerThan64CharactersThrowsOnDecode() throws {
        let tooLong = String(repeating: "a", count: 65)
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"\#(tooLong)","ext":"png"}"#)
        }
    }

    @Test func digestWithNonHexLetterThrowsOnDecode() throws {
        // "g" is alphanumeric but outside the `[a-f0-9]` hex range.
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"g0123456","ext":"png"}"#)
        }
    }

    // MARK: - Malformed `ext` throws

    @Test func extContainingPathTraversalSequenceThrowsOnDecode() throws {
        // The literal shape from the audit's own worked example
        // (`AUDIT_2026-07-28.md` S-2): an `ext` that climbs out of
        // `assets/` via `..` segments once interpolated into a path
        // component.
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"deadbeef","ext":"png/../../../../Library/Preferences"}"#)
        }
    }

    @Test func extContainingDotThrowsOnDecode() throws {
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"deadbeef","ext":"png.plist"}"#)
        }
    }

    @Test func extWithUppercaseThrowsOnDecode() throws {
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"deadbeef","ext":"PNG"}"#)
        }
    }

    @Test func emptyExtThrowsOnDecode() throws {
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"deadbeef","ext":""}"#)
        }
    }

    @Test func extLongerThan8CharactersThrowsOnDecode() throws {
        #expect(throws: DecodingError.self) {
            try decode(#"{"digest":"deadbeef","ext":"toolongext"}"#)
        }
    }

    // MARK: - Memberwise initializer (documented, deliberate non-validation)

    /// `MKAssetRef.init(digest:ext:)` (the plain memberwise initializer,
    /// used throughout this package's own source and tests to construct
    /// refs from already-trusted, in-process values like
    /// `MKContentHash.sha256Hex(_:)`'s output) intentionally does NOT
    /// re-run `init(from:)`'s validation ، only the `Decodable` path, which
    /// is what untrusted on-disk/imported JSON goes through, validates.
    /// `MKAssetStore.assetURL(for:)`'s `standardizedFileURL`/`hasPrefix`
    /// check is the defense-in-depth backstop for a ref that reaches the
    /// store via this initializer with attacker-shaped fields anyway; see
    /// `AssetStoreTests.swift` for that guard's own test.
    @Test func memberwiseInitializerDoesNotValidateItsInputs() {
        let ref = MKAssetRef(digest: "../../etc", ext: "png/../x")
        #expect(ref.digest == "../../etc")
        #expect(ref.ext == "png/../x")
    }
}
