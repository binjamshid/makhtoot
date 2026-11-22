import Foundation

/// T14 ، native sfnt structural validation for font import (and, per
/// `VERIFICATION_PROTOCOL.md` step 8's tooling note, the same structural
/// bar bundled fonts are held to). No third-party parser (D-101):
/// hand-rolled, bounds-checked table-directory walk over raw `Data`.
///
/// Accepts: `.ttf` (`sfnt` version `0x00010000` or `'true'`), `.otf`
/// (`'OTTO'`), `.ttc`/`.otc` (`'ttcf'` collection header ، validated via its
/// first member font), and variable fonts (any of the above with an `fvar`
/// table). Rejects: WOFF/WOFF2 (`'wOFF'`/`'wOF2'` magic), bitmap-only fonts
/// (no `glyf`/`CFF `outline table), and structurally corrupt/truncated
/// files (any offset/length claim that would read past the buffer).
public struct MKFontValidator: Sendable {
    public init() {}

    public struct ValidatedFace: Sendable, Hashable {
        public var postScriptName: String?
        public var familyName: String?
        public var isVariable: Bool
        public var format: MKFontFileFormat
        public var tables: Set<String>
    }

    public enum Verdict: Sendable {
        case ok(faces: [ValidatedFace])
        case reject(MKFontError)
    }

    private static let sfntTrueType: UInt32 = 0x0001_0000
    private static let sfntTrueTypeMac: UInt32 = 0x7472_7565    // 'true'
    private static let sfntOpenTypeCFF: UInt32 = 0x4F54_544F    // 'OTTO'
    private static let sfntCollection: UInt32 = 0x7474_6366     // 'ttcf'
    private static let woff: UInt32 = 0x774F_4646                // 'wOFF'
    private static let woff2: UInt32 = 0x774F_4632               // 'wOF2'

    public func validate(_ data: Data) -> Verdict {
        guard data.count >= 12 else { return .reject(.corruptFile) }
        let tag = readU32(data, at: 0)

        if tag == Self.woff {
            return .reject(.unsupportedFormat(detected: "WOFF"))
        }
        if tag == Self.woff2 {
            return .reject(.unsupportedFormat(detected: "WOFF2"))
        }

        if tag == Self.sfntCollection {
            return validateCollection(data)
        }
        guard tag == Self.sfntTrueType || tag == Self.sfntTrueTypeMac || tag == Self.sfntOpenTypeCFF else {
            return .reject(.unsupportedFormat(detected: String(format: "0x%08X", tag)))
        }
        switch validateSingleFont(data, headerOffset: 0) {
        case .success(let face): return .ok(faces: [face])
        case .failure(let error): return .reject(error)
        }
    }

    private func validateCollection(_ data: Data) -> Verdict {
        // ttcf header: tag(4) majorVersion(2) minorVersion(2) numFonts(4) [offset(4)]*numFonts
        guard data.count >= 16 else { return .reject(.corruptFile) }
        let numFonts = readU32(data, at: 8)
        guard numFonts > 0, numFonts < 256 else { return .reject(.corruptFile) }
        let offsetsEnd = 12 + Int(numFonts) * 4
        guard data.count >= offsetsEnd else { return .reject(.corruptFile) }

        var faces: [ValidatedFace] = []
        for i in 0..<Int(numFonts) {
            let offset = Int(readU32(data, at: 12 + i * 4))
            guard offset >= 0, offset + 12 <= data.count else { return .reject(.corruptFile) }
            switch validateSingleFont(data, headerOffset: offset, formatOverride: .ttc) {
            case .success(let face): faces.append(face)
            case .failure(let error): return .reject(error)
            }
        }
        return .ok(faces: faces)
    }

    private func validateSingleFont(
        _ data: Data, headerOffset: Int, formatOverride: MKFontFileFormat? = nil
    ) -> Result<ValidatedFace, MKFontError> {
        guard headerOffset + 12 <= data.count else { return .failure(.corruptFile) }
        let versionTag = readU32(data, at: headerOffset)
        let numTables = Int(readU16(data, at: headerOffset + 4))
        guard numTables > 0, numTables < 4096 else { return .failure(.corruptFile) }
        let directoryStart = headerOffset + 12
        let directoryEnd = directoryStart + numTables * 16
        guard directoryEnd <= data.count else { return .failure(.corruptFile) }

        var tables: [String: (offset: Int, length: Int)] = [:]
        for i in 0..<numTables {
            let entryOffset = directoryStart + i * 16
            guard let tag = readTag(data, at: entryOffset) else { return .failure(.corruptFile) }
            let tableOffset = Int(readU32(data, at: entryOffset + 8))
            let tableLength = Int(readU32(data, at: entryOffset + 12))
            guard tableOffset >= 0, tableLength >= 0, tableOffset + tableLength <= data.count else {
                return .failure(.corruptFile)
            }
            tables[tag] = (tableOffset, tableLength)
        }

        let tableNames = Set(tables.keys)
        let required: Set<String> = ["cmap", "name", "head"]
        guard required.isSubset(of: tableNames) else { return .failure(.corruptFile) }

        let hasOutlines = tableNames.contains("glyf") || tableNames.contains("CFF ")
        guard hasOutlines else { return .failure(.unsupportedFormat(detected: "bitmap-only")) }

        let isVariable = tableNames.contains("fvar")
        let format = formatOverride ?? (versionTag == Self.sfntOpenTypeCFF ? .otf : .ttf)

        var postScriptName: String?
        var familyName: String?
        if let nameTable = tables["name"] {
            let names = parseNameTable(data, offset: nameTable.offset, length: nameTable.length)
            postScriptName = names[6]
            familyName = names[16] ?? names[1]
        }

        return .success(ValidatedFace(
            postScriptName: postScriptName, familyName: familyName,
            isVariable: isVariable, format: format, tables: tableNames
        ))
    }

    /// Minimal `name` table (format 0/1) parser: enough to recover the
    /// family name (nameID 1/16) and PostScript name (nameID 6) for
    /// catalog display of a freshly imported font. Prefers Windows
    /// platform (3, UTF-16BE) records, falls back to Macintosh (1,
    /// single-byte, treated as ASCII/Latin-1 ، sufficient for the Latin
    /// PostScript-name convention almost every font follows).
    private func parseNameTable(_ data: Data, offset: Int, length: Int) -> [Int: String] {
        guard length >= 6, offset + 6 <= data.count else { return [:] }
        let count = Int(readU16(data, at: offset + 2))
        let stringOffset = offset + Int(readU16(data, at: offset + 4))
        guard count > 0, count < 4096 else { return [:] }
        let recordsStart = offset + 6
        var result: [Int: String] = [:]
        var bestScore: [Int: Int] = [:]  // nameID -> platform preference score (higher wins)

        for i in 0..<count {
            let recOffset = recordsStart + i * 12
            guard recOffset + 12 <= data.count, recOffset + 12 <= offset + length + 12 else { break }
            guard recOffset + 12 <= data.count else { break }
            let platformID = Int(readU16(data, at: recOffset))
            let nameID = Int(readU16(data, at: recOffset + 6))
            let strLength = Int(readU16(data, at: recOffset + 8))
            let strOffsetInStorage = Int(readU16(data, at: recOffset + 10))
            let absoluteOffset = stringOffset + strOffsetInStorage
            guard absoluteOffset >= 0, absoluteOffset + strLength <= data.count else { continue }
            guard nameID == 1 || nameID == 6 || nameID == 16 else { continue }

            let raw = data.subdata(in: absoluteOffset..<(absoluteOffset + strLength))
            let score = platformID == 3 ? 2 : (platformID == 1 ? 1 : 0)
            guard score > (bestScore[nameID] ?? -1) else { continue }

            let decoded: String?
            if platformID == 3 {
                decoded = String(data: raw, encoding: .utf16BigEndian)
            } else {
                decoded = String(data: raw, encoding: .isoLatin1) ?? String(data: raw, encoding: .ascii)
            }
            if let decoded {
                result[nameID] = decoded
                bestScore[nameID] = score
            }
        }
        return result
    }

    private func readU32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes { raw in
            let base = raw.baseAddress!.advanced(by: offset)
            return UInt32(base.load(fromByteOffset: 0, as: UInt8.self)) << 24
                | UInt32(base.load(fromByteOffset: 1, as: UInt8.self)) << 16
                | UInt32(base.load(fromByteOffset: 2, as: UInt8.self)) << 8
                | UInt32(base.load(fromByteOffset: 3, as: UInt8.self))
        }
    }

    private func readU16(_ data: Data, at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return data.withUnsafeBytes { raw in
            let base = raw.baseAddress!.advanced(by: offset)
            return UInt16(base.load(fromByteOffset: 0, as: UInt8.self)) << 8
                | UInt16(base.load(fromByteOffset: 1, as: UInt8.self))
        }
    }

    private func readTag(_ data: Data, at offset: Int) -> String? {
        guard offset + 4 <= data.count else { return nil }
        let bytes = [UInt8](data[offset..<(offset + 4)])
        return String(bytes: bytes, encoding: .ascii)
    }
}
