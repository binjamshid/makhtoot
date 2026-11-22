import Foundation
import MKModel

// WS-02 packet §5 task 13. Append-only crash-recovery journal, `journal.mkj`
// at the `.makhtoot` package root (D-223 ، NOT under `backups/`, which is
// reserved for rescue snapshots only). JSON Lines: one command per line,
// each line self-verifying via a CRC32 over its command payload.
//
// Line encoding note: §14.4's illustrative example embeds `"cmd"` as a
// nested JSON object. This implementation stores the command as a JSON
// **string** (`cmdJSON`) instead of a nested object, specifically so
// `crc32` can be verified by re-hashing the exact same UTF-8 bytes that
// were read back ، hashing a re-*serialized* nested object risks a
// spurious mismatch if `JSONSerialization`/`JSONDecoder` ever reorders or
// reformats keys during the read-back round trip. Hashing a stored string
// has no such ambiguity. This is a line-format detail internal to this
// packet; no other workstream reads `journal.mkj` directly (§13.1: it is
// working storage for recovery, not a public interchange format).

/// One decoded, CRC-verified journal line.
public struct MKJournalRecord: Sendable {
    public let seq: Int
    public let ts: Date
    public let baseRev: String
    public let command: any MKCommand
}

/// Append-only journal actor. `append`/`truncate` are the two operations
/// the D-223 critical path relies on being cheap and synchronous-ish. In
/// steady state an append is a single `write(2)` on a cached handle and a
/// truncate is one `ftruncate`, no scene re-encode; only the FIRST append
/// (or the first after a `truncate()`/write failure) pays the
/// directory-bootstrap + open + seek cost (P8-2 ، the previous
/// per-append open/seek/close plus formatter alloc was measurable at
/// drag-frame journaling rates).
public actor CommandJournal {
    private let journalURL: URL
    private var sequenceCounter: Int
    // P8-2: hoisted ، `ISO8601DateFormatter()` is an expensive
    // CFDateFormatter construction and `append` runs at 60–120 Hz during
    // drags (one journaled command per drag frame; coalescing merges undo
    // entries, not journal traffic). Actor-isolated, so the formatter is
    // never shared across concurrency domains. Mirrors the local hoist
    // `readValidRecords` already does.
    private let isoFormatter = ISO8601DateFormatter()
    // P8-2: cached append handle, opened lazily by `appendToFile` and
    // reused across appends. Closed/nil-ed in `truncate()` and on any
    // write failure so the recreate-a-missing-file behavior of the old
    // per-append open is preserved on the next append.
    private var appendHandle: FileHandle?

    public init(journalURL: URL) {
        self.journalURL = journalURL
        self.sequenceCounter = 0
    }

    /// Appends one command's FORWARD form (§14.4: "every command's forward
    /// form is journaled, not inverses") as one JSON-Lines record. One
    /// `write(2)` on the cached handle in steady state (P8-2); the
    /// directory/file bootstrap and open + seek-to-end run only when no
    /// handle is cached. This is the primitive both the normal
    /// per-mutation journaling path AND the D-223 stage-3 critical flush
    /// call directly, with no heavier work in between ، the critical
    /// flush remains a working single append even from a cold (nil-handle)
    /// state.
    public func append(command: any MKCommand, baseRev: String) throws {
        sequenceCounter += 1
        let cmdData = try MKCommandCoder.encode(command)
        let cmdJSON = String(decoding: cmdData, as: UTF8.self)
        let crc = MKCRC32.hex(Data(cmdJSON.utf8))

        let record: [String: Any] = [
            "seq": sequenceCounter,
            "ts": isoFormatter.string(from: Date()),
            "baseRev": baseRev,
            "cmdJSON": cmdJSON,
            "crc32": crc,
        ]
        var lineData = try JSONSerialization.data(withJSONObject: record)
        lineData.append(0x0A) // '\n'
        try appendToFile(lineData)
    }

    private func appendToFile(_ data: Data) throws {
        let handle = try openedAppendHandle()
        do {
            try handle.write(contentsOf: data)
        } catch {
            // P8-2: drop the cached handle on ANY write failure so the
            // next append re-runs the bootstrap ، this is what preserves
            // the old per-append behavior of recreating a missing journal
            // file (e.g. the package moved or the file was unlinked out
            // from under us).
            try? handle.close()
            appendHandle = nil
            throw error
        }
    }

    /// Returns the cached append handle, or performs the first-open
    /// bootstrap (createDirectory / createFile-if-missing / open /
    /// seek-to-end ، exactly what every append used to pay, P8-2) and
    /// caches the result. The handle is only cached AFTER `seekToEnd()`
    /// succeeds, so a failed bootstrap leaves no half-initialized handle
    /// behind.
    private func openedAppendHandle() throws -> FileHandle {
        if let handle = appendHandle { return handle }
        let fm = FileManager.default
        try fm.createDirectory(at: journalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fm.fileExists(atPath: journalURL.path) {
            fm.createFile(atPath: journalURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: journalURL)
        try handle.seekToEnd()
        appendHandle = handle
        return handle
    }

    /// Truncates the journal to zero length (`ftruncate`) ، the "flushed"
    /// marker (§14.4). Resets the in-memory sequence counter too, since a
    /// freshly-flushed journal's next line is logically sequence 1 again.
    public func truncate() throws {
        sequenceCounter = 0
        // P8-2: invalidate the cached append handle ، its file offset
        // points at the pre-truncate end, and dropping it here (like on a
        // write failure) keeps the next append's bootstrap able to
        // recreate the file if it disappears after a flush.
        try? appendHandle?.close()
        appendHandle = nil
        guard FileManager.default.fileExists(atPath: journalURL.path) else { return }
        let handle = try FileHandle(forWritingTo: journalURL)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
    }

    public func isEmpty() -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: journalURL.path),
              let size = attrs[.size] as? Int else { return true }
        return size == 0
    }

    /// Reads every line, verifying JSON-parseability and CRC32 per line.
    /// Returns the valid PREFIX (stopping at the first structurally
    /// invalid or CRC-mismatched line, §14.5: "stop at first mismatch,
    /// report count") and the raw bytes of everything from that point
    /// onward (the "damaged remainder" `CrashRecovery` preserves to
    /// `journal.mkj.damaged-<ts>` rather than silently discarding).
    public func readValidRecords() throws -> (records: [MKJournalRecord], damagedRemainder: Data?) {
        guard FileManager.default.fileExists(atPath: journalURL.path) else { return ([], nil) }
        let data = try Data(contentsOf: journalURL)
        guard !data.isEmpty else { return ([], nil) }

        var records: [MKJournalRecord] = []
        var offset = data.startIndex
        let formatter = ISO8601DateFormatter()

        while offset < data.endIndex {
            guard let newlineIndex = data[offset...].firstIndex(of: 0x0A) else {
                // Trailing partial line with no terminator ، treat as
                // damaged remainder (a torn write mid-line, exactly the
                // kill-window this mechanism exists to survive).
                return (records, data[offset...])
            }
            let lineData = data[offset..<newlineIndex]
            let nextOffset = data.index(after: newlineIndex)

            guard
                let object = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any],
                let seq = object["seq"] as? Int,
                let tsString = object["ts"] as? String,
                let ts = formatter.date(from: tsString),
                let baseRev = object["baseRev"] as? String,
                let cmdJSON = object["cmdJSON"] as? String,
                let crc32 = object["crc32"] as? String
            else {
                return (records, data[offset...])
            }

            let expectedCRC = MKCRC32.hex(Data(cmdJSON.utf8))
            guard expectedCRC.caseInsensitiveCompare(crc32) == .orderedSame else {
                return (records, data[offset...])
            }

            guard let command = try? MKCommandCoder.decode(Data(cmdJSON.utf8)) else {
                return (records, data[offset...])
            }

            records.append(MKJournalRecord(seq: seq, ts: ts, baseRev: baseRev, command: command))
            offset = nextOffset
        }
        return (records, nil)
    }
}
