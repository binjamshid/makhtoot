import Foundation

// WS-02 packet §5 task 5. Everything needed to revert an Arranged
// Composition back to its originating Live/Path Text object, or to verify
// it hasn't been silently mutated by arrange edits (INV-4).

/// Reversible backup of the text object an Arranged Composition was
/// derived from ، retained for the lifetime of the arranged node (BRIEF:
/// "retained source backup, revert w/ confirmation"). D-112: "Source Text
/// Backups are embedded in scene nodes" (inside `MKArrangedTextNode`, not a
/// separate `backups/` file ، `backups/` on disk holds rescue snapshots
/// only, §13.1).
public struct MKSourceTextBackup: Hashable, Sendable, Codable, Equatable {
    /// The exact source string at the moment of arrangement ، preserved
    /// byte-for-byte including tashkeel, ZWJ/ZWNJ, and Arabic-Indic digits
    /// (§6 Arabic-correctness notes; `String`'s native Unicode-correct
    /// storage makes byte-identical round-trip automatic, no custom
    /// normalization is ever applied here).
    public var sourceString: String
    /// Full style state at arrangement time (task 5: "full MKTextStyle").
    public var style: MKTextStyle
    /// Present iff the origin was a `pathText` node ، the frozen path at
    /// arrangement time (task 5: "path data if derived from pathText").
    public var pathData: MKBezierPathData?
    public var createdAt: Date
    /// SHA-256 (hex) over `sourceString + style` canonical encoding ،
    /// INV-4 check: arrange mutations must never alter the backup, so any
    /// caller can cheaply assert `contentHash` still matches the stored
    /// fields before trusting a revert.
    public var contentHash: String

    public init(sourceString: String, style: MKTextStyle, pathData: MKBezierPathData? = nil, createdAt: Date = Date()) {
        self.sourceString = sourceString
        self.style = style
        self.pathData = pathData
        self.createdAt = createdAt
        self.contentHash = Self.computeContentHash(sourceString: sourceString, style: style)
    }

    /// Recomputes the hash a decoded/mutated-in-place backup *should* have,
    /// for INV-4 verification (`backup.contentHash == backup.recomputedHash()`).
    public func recomputedHash() -> String {
        Self.computeContentHash(sourceString: sourceString, style: style)
    }

    private static func computeContentHash(sourceString: String, style: MKTextStyle) -> String {
        // A dependency-free, deterministic content digest: MKModel has no
        // CryptoKit import (kept to Foundation/CoreGraphics only, matching
        // the "pure value types" DEPENDENCY_GRAPH.md rule for this
        // target ، CryptoKit is a fine zero-third-party framework, but
        // isn't needed for an INV-4 *tamper/drift detector*, which only
        // needs a stable, collision-resistant-enough digest, not
        // cryptographic security). `Hasher` is not stable across process
        // launches, so this uses a small FNV-1a implementation instead,
        // which IS stable ، required since `contentHash` is persisted to
        // `scene.json` and compared across app launches.
        var encodableParts: [String] = [sourceString]
        // `.sortedKeys` is required for a STABLE hash: `JSONEncoder`'s
        // default keyed-container order is not guaranteed stable across
        // separate `JSONEncoder()` instances/calls (confirmed by this
        // exact bug ، the very first version of this function, without
        // `.sortedKeys`, made `contentHash` computed at `init` differ from
        // `recomputedHash()` moments later on an untouched value, which
        // defeats the whole INV-4 tamper/drift check this hash exists for).
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(style), let json = String(data: data, encoding: .utf8) {
            encodableParts.append(json)
        }
        let combined = encodableParts.joined(separator: "\u{1F}")
        return fnv1aHex(combined)
    }

    private static func fnv1aHex(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01B3
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}
