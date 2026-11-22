import CoreText
import Foundation

// WS-16 (`docs/impl-log/WS-16-cursive.md`, ADR WS16-A2). D-222 step 8 found
// GPOS LookupType 3 (cursive attachment) on base glyphs in 5 held-out fonts
// (Amiri, Amiri Quran, Aref Ruqaa, Rakkas, Qahiri) and asked whether D-105's
// mark-capture model needs a "cursive-pair structure" before those fonts can
// ship. This file is the empirically-minimal answer: a per-glyph provenance
// **flag**, not a full anchor-delta structure ، see the ADR for the probe
// evidence that justified this scope (short version: `CTRunGetPositions`
// already bakes the cursive-adjusted position into the capture, exactly like
// D-105 already assumes for mark anchoring ، "the shaped positions already
// encode the answer" ، so no geometry needs recomputing; the only real gap
// is that D-107's ZWJ-synthetic-context reshape technique, used by
// MKArrange's join-break/restore and ligature-decompose paths, cannot
// reproduce a CONTEXTUAL cursive-variant glyph a real neighbor letter would
// have triggered, since ZWJ isn't a real letter. That is a bounded,
// visual-only fidelity limitation in a manual-edit path ، the exact class
// D-222 itself already accepts for the analogous "single-glyph scale inside
// a joined word" case, PROVIDED it is identified and documented rather than
// silently wrong. This flag is what makes it identifiable.)
//
// **What this file is NOT**: it does not read GPOS anchor VALUES, does not
// resolve which contextual GSUB alternate a real neighbor would trigger,
// and never feeds into any position/outline computation. It answers exactly
// one audit question per glyph ، "is this glyph ID a member of this font's
// GPOS 'curs' (LookupType 3, resolving LookupType 9 extension wrappers)
// coverage table?" ، via a Coverage-table-only read. This is the same class
// of read D-105's own rejected alternative (b) forbids for MARK anchors
// ("recompute mark anchors from font GPOS tables directly... reimplements
// shaper internals") turned into a much weaker, purely-informational
// membership test: no shaping decision anywhere in this module depends on
// the result, only a provenance annotation attached AFTER Core Text has
// already produced the real, trusted position.

/// Process-wide cache of GPOS cursive-attachment coverage per font
/// (keyed by the font's file URL ، the table content is a property of the
/// font FILE, not the point size, and S8-5 showed a PostScript-name key is
/// NOT a file identity: two files sharing a PS name ، subsetted or
/// re-versioned copies of the same family ، poisoned each other
/// first-writer-wins, and every font whose PS-name copy failed collapsed
/// onto a single `""` entry). `CTFontCopyTable` is a real table-bytes copy
/// (can be tens to hundreds of KB for a large font); this cache keeps the
/// cost to once-per-distinct-font-file, bounded by the same LRU
/// capacity/order idiom `MKGlyphPathProvider` uses (S8-5 ، the old
/// dictionary was unbounded). A plain lock-guarded dictionary (not an
/// actor) because the call site (`MKShapingEngine.capture`, a synchronous
/// static function) is not actor-isolated and must not become `async` just
/// for this lookup ، matches the synchronous, non-Sendable-CTFont-crossing
/// pattern already used by this file's own callers.
final class MKCursiveCoverageCache: @unchecked Sendable {
    static let shared = MKCursiveCoverageCache()

    private let lock = NSLock()
    private var cache: [String: Set<UInt16>] = [:]
    private var order: [String] = []   // LRU order, most-recent last (S8-5)
    private let capacity = 512         // mirrors `MKGlyphPathProvider`'s default

    private init() {}

    /// The set of glyph IDs covered by `font`'s GPOS cursive-attachment
    /// (LookupType 3) lookups, or an empty set if the font has no GPOS
    /// table, no 'curs' feature, or the table is malformed in any way this
    /// parser cannot safely walk (never throws, never traps ، a
    /// best-effort audit read over an arbitrary, possibly-untrusted font
    /// file must degrade to "no signal" rather than crash the shaping/
    /// capture path).
    func coveredGlyphs(for font: CTFont) -> Set<UInt16> {
        // S8-5: key on the font FILE. The URL attribute identifies the
        // actual file the table bytes come from, which a PostScript name
        // cannot (see the type-level comment).
        if let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL {
            let key = "url:" + url.standardizedFileURL.path
            if let hit = cachedValue(forKey: key) { return hit }
            let result = Self.parseCoverage(of: font)
            store(result, forKey: key)
            return result
        }

        // No URL attribute (e.g. an in-memory/data-provider-registered
        // font): fall back to PS name + GPOS table byte count, which still
        // separates differently-subsetted copies sharing a name. The table
        // bytes must be copied before that key exists, so this branch only
        // caches the parse, not the `CTFontCopyTable` copy.
        let psName = (CTFontCopyPostScriptName(font) as String?) ?? ""
        let tableData = CTFontCopyTable(font, CTFontTableTag(kCTFontTableGPOS), CTFontTableOptions()) as Data?
        let key = "ps:\(psName)#gpos:\(tableData?.count ?? 0)"
        if let hit = cachedValue(forKey: key) { return hit }
        let result = tableData.map { MKGPOSCursiveParser.coverageGlyphIDs(gposTable: $0) } ?? []
        store(result, forKey: key)
        return result
    }

    private static func parseCoverage(of font: CTFont) -> Set<UInt16> {
        guard let tableData = CTFontCopyTable(font, CTFontTableTag(kCTFontTableGPOS), CTFontTableOptions()) as Data? else {
            return []
        }
        return MKGPOSCursiveParser.coverageGlyphIDs(gposTable: tableData)
    }

    /// Test/font-reload seam (mirrors `MKGlyphPathProvider.invalidate()`/
    /// `MKFormResolver.invalidate()`'s font re-registration hook).
    func invalidate() {
        lock.lock()
        cache.removeAll()
        order.removeAll()
        lock.unlock()
    }

    // MARK: - LRU bookkeeping (S8-5 ، copies `MKGlyphPathProvider`'s
    // touch/insert-evict idiom; the parse itself intentionally runs outside
    // the lock, so two threads racing the same cold key both parse and the
    // second store wins with an identical value ، same tolerance the
    // pre-S8-5 code had).

    private func cachedValue(forKey key: String) -> Set<UInt16>? {
        lock.lock()
        defer { lock.unlock() }
        guard let hit = cache[key] else { return nil }
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
            order.append(key)
        }
        return hit
    }

    private func store(_ value: Set<UInt16>, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        if cache[key] == nil { order.append(key) }
        cache[key] = value
        while order.count > capacity {
            let evicted = order.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }
}

/// Minimal, defensive, bounds-checked OpenType `GPOS` table walker. Reads
/// ONLY what is needed to answer "which glyph IDs does the 'curs' feature's
/// LookupType-3 (cursive attachment) coverage include" ، never anchor
/// offsets/coordinates, never any other feature/lookup type. Every read is
/// range-checked; any malformed/truncated/unexpected structure yields an
/// empty result for that step rather than an index-out-of-bounds trap,
/// since this walks font files this module did not produce and cannot
/// fully trust the internal consistency of.
enum MKGPOSCursiveParser {
    static func coverageGlyphIDs(gposTable data: Data) -> Set<UInt16> {
        let reader = BEReader(data)
        // GPOS header: majorVersion(u16) minorVersion(u16) scriptListOffset(u16)
        // featureListOffset(u16) lookupListOffset(u16) [featureVariationsOffset(u32) if minor==1]
        guard let majorVersion = reader.u16(at: 0), majorVersion == 1,
              let featureListOffset = reader.u16(at: 6),
              let lookupListOffset = reader.u16(at: 8)
        else { return [] }

        let cursLookupIndices = Self.lookupIndices(featureTag: "curs", reader: reader, featureListOffset: Int(featureListOffset))
        guard !cursLookupIndices.isEmpty else { return [] }

        var glyphIDs: Set<UInt16> = []
        for lookupIndex in cursLookupIndices {
            glyphIDs.formUnion(Self.cursiveCoverage(forLookupIndex: lookupIndex, reader: reader, lookupListOffset: Int(lookupListOffset)))
        }
        return glyphIDs
    }

    /// FeatureList → every `Feature` record whose 4-byte tag matches
    /// `featureTag`, collecting `LookupListIndex` entries (there can be more
    /// than one FeatureRecord for the same tag, e.g. per-script variants ،
    /// and those records routinely repeat the SAME lookup index, which is
    /// why the result is a `Set`: S8-6 found the old array version handing
    /// duplicates to the caller, whose coverage walk then re-parsed the
    /// same lookup once per duplicate).
    private static func lookupIndices(featureTag: String, reader: BEReader, featureListOffset: Int) -> Set<Int> {
        guard let featureCount = reader.u16(at: featureListOffset) else { return [] }
        var indices: Set<Int> = []
        for i in 0..<Int(featureCount) {
            let recordOffset = featureListOffset + 2 + i * 6
            guard let tag = reader.tag(at: recordOffset),
                  let featureOffsetRel = reader.u16(at: recordOffset + 4)
            else { continue }
            guard tag == featureTag else { continue }
            let featureOffset = featureListOffset + Int(featureOffsetRel)
            guard let lookupIndexCount = reader.u16(at: featureOffset + 2) else { continue }
            for li in 0..<Int(lookupIndexCount) {
                guard let idx = reader.u16(at: featureOffset + 4 + li * 2) else { continue }
                indices.insert(Int(idx))
            }
        }
        return indices
    }

    /// LookupList[lookupIndex] → walks its subtables; for LookupType 3
    /// (cursive) reads each subtable's Coverage directly, for LookupType 9
    /// (extension positioning) resolves to the real subtable first (only
    /// when its own `extensionLookupType == 3`). Any other lookup type
    /// contributes nothing.
    private static func cursiveCoverage(forLookupIndex lookupIndex: Int, reader: BEReader, lookupListOffset: Int) -> Set<UInt16> {
        guard let lookupCount = reader.u16(at: lookupListOffset), lookupIndex < Int(lookupCount) else { return [] }
        guard let lookupOffsetRel = reader.u16(at: lookupListOffset + 2 + lookupIndex * 2) else { return [] }
        let lookupOffset = lookupListOffset + Int(lookupOffsetRel)

        guard let lookupType = reader.u16(at: lookupOffset),
              let subtableCount = reader.u16(at: lookupOffset + 4)
        else { return [] }

        var glyphIDs: Set<UInt16> = []
        for s in 0..<Int(subtableCount) {
            guard let subtableOffsetRel = reader.u16(at: lookupOffset + 6 + s * 2) else { continue }
            let subtableOffset = lookupOffset + Int(subtableOffsetRel)

            if lookupType == 3 {
                glyphIDs.formUnion(Self.coverage(cursiveSubtableOffset: subtableOffset, reader: reader))
            } else if lookupType == 9 {
                // ExtensionPosFormat1: posFormat(u16)=1 extensionLookupType(u16) extensionOffset(u32),
                // extensionOffset relative to the EXTENSION subtable's own start.
                guard let extensionLookupType = reader.u16(at: subtableOffset + 2),
                      extensionLookupType == 3,
                      let extensionOffsetRel = reader.u32(at: subtableOffset + 4)
                else { continue }
                let realOffset = subtableOffset + Int(extensionOffsetRel)
                glyphIDs.formUnion(Self.coverage(cursiveSubtableOffset: realOffset, reader: reader))
            }
        }
        return glyphIDs
    }

    /// CursivePosFormat1: posFormat(u16)=1 coverageOffset(u16, relative to
    /// this subtable) entryExitCount(u16) entryExitRecords[...]. Only the
    /// Coverage table is read.
    private static func coverage(cursiveSubtableOffset offset: Int, reader: BEReader) -> Set<UInt16> {
        guard let posFormat = reader.u16(at: offset), posFormat == 1,
              let coverageOffsetRel = reader.u16(at: offset + 2)
        else { return [] }
        return reader.coverageGlyphIDs(at: offset + Int(coverageOffsetRel))
    }
}

/// Bounds-checked big-endian binary reader over raw sfnt table bytes. Every
/// accessor returns `nil` (never traps) when the requested range falls
/// outside `data`.
private struct BEReader {
    let data: Data
    let base: Int

    init(_ data: Data) {
        self.data = data
        self.base = data.startIndex
    }

    func u16(at offset: Int) -> UInt16? {
        let start = base + offset
        guard offset >= 0, start >= data.startIndex, start + 2 <= data.endIndex else { return nil }
        return (UInt16(data[start]) << 8) | UInt16(data[start + 1])
    }

    func u32(at offset: Int) -> UInt32? {
        let start = base + offset
        guard offset >= 0, start >= data.startIndex, start + 4 <= data.endIndex else { return nil }
        return (UInt32(data[start]) << 24) | (UInt32(data[start + 1]) << 16) | (UInt32(data[start + 2]) << 8) | UInt32(data[start + 3])
    }

    /// 4-byte ASCII feature/table tag (e.g. `"curs"`).
    func tag(at offset: Int) -> String? {
        let start = base + offset
        guard offset >= 0, start >= data.startIndex, start + 4 <= data.endIndex else { return nil }
        let bytes = data[start..<(start + 4)]
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Coverage table (OpenType spec §"Coverage Table"): format 1 lists
    /// glyph IDs directly; format 2 lists (start, end, startCoverageIndex)
    /// ranges. Either way, the result is just "which glyph IDs are covered"
    /// ، no coverage INDEX values are needed by this parser's caller.
    func coverageGlyphIDs(at offset: Int) -> Set<UInt16> {
        guard let format = u16(at: offset) else { return [] }
        var result: Set<UInt16> = []
        switch format {
        case 1:
            guard let glyphCount = u16(at: offset + 2) else { return [] }
            // Defensive cap: a legitimate Coverage table is bounded by the
            // font's own glyph count (never remotely close to this); guards
            // against a corrupt/hostile length field forcing an enormous loop.
            let count = min(Int(glyphCount), 65535)
            for i in 0..<count {
                guard let gid = u16(at: offset + 4 + i * 2) else { break }
                result.insert(gid)
            }
        case 2:
            guard let rangeCount = u16(at: offset + 2) else { return [] }
            let count = min(Int(rangeCount), 65535)
            // S8-6: total-glyph budget across ALL ranges. The per-range
            // `endGID - startGID < 65536` guard that used to sit here was
            // vacuous ، two `UInt16`s can never differ by 65536 ، so one
            // malformed table with ~65535 overlapping full-space ranges
            // could force ~4e9 synchronous insertions. 65536 processed
            // glyph IDs is the entire UInt16 glyph space: every legitimate
            // (non-overlapping) coverage table finishes under the budget,
            // and anything that exhausts it is malformed or hostile, so
            // truncating its coverage is within this parser's documented
            // best-effort degradation.
            var processed = 0
            for i in 0..<count {
                let recordOffset = offset + 4 + i * 6
                guard let startGID = u16(at: recordOffset), let endGID = u16(at: recordOffset + 2), startGID <= endGID
                else { continue }
                for gid in startGID...endGID {
                    result.insert(gid)
                    processed += 1
                    if processed >= 65536 { return result }
                }
            }
        default:
            return []
        }
        return result
    }
}
