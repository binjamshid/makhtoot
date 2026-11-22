import CryptoKit
import Foundation
import MKModel

// Small internal utilities `MKPersistence` needs (atomic writes, content
// hashing, a stable scene-revision digest) that FILE_MAP.md §5 sketches as
// living in `MKFoundation` (`FileLocations.swift`, `ContentHash.swift`,
// `Debouncer.swift`) with an "owner: WS-02" tag. This packet's scope fence
// is explicit ، "you own the MKModel and MKPersistence targets... ONLY...
// Do NOT touch... other module targets" ، and `MKFoundation` is WS-01's
// target, not this packet's. Rather than editing a target outside this
// packet's scope fence (which the packet governs above FILE_MAP's
// granularity sketch, same precedent as WS-01's own logged FILE_MAP
// deviations), these utilities are implemented privately inside
// `MKPersistence`, which is the only consumer. Logged as a deviation in
// `docs/impl-log/WS-02.md`.

/// Atomic write per INV-7 / §13.5: write-temp + `replaceItemAt` (rename(2)
/// semantics). A crash between the temp write and the rename leaves the
/// destination file exactly as it was before the call.
///
/// S-7: the temp file is written to a SIBLING scratch directory outside
/// the destination's own directory, never inside it. For every caller in
/// this module, `directory` (`url.deletingLastPathComponent()`) is the
/// `.makhtoot` package root itself ، a crash between the temp write and
/// `replaceItemAt` used to leave a `.tmp-*` orphan INSIDE that
/// user-visible, Files.app-exposed, CloudKit-synced package (and S-3's
/// sync packer would then upload it). `FileManager.replaceItemAt` handles
/// the cross-directory move itself; both directories live under the app's
/// own sandbox container, ordinarily the same volume, so this keeps the
/// rename(2)-based atomicity guarantee.
enum MKAtomicIO {
    static func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scratchDirectory = try MKFileLocations.atomicWriteScratchDirectory()
        let tmp = scratchDirectory.appendingPathComponent(".tmp-\(UUID().uuidString)")
        // S-6: request `.completeUnlessOpen` file protection on every
        // document write (manifest/scene/thumbnail/rescue-snapshot) ، a
        // design tool holding client work and unreleased brand material
        // warrants stronger-than-default protection, and `.unlessOpen`
        // (rather than plain `.complete`) still lets autosave/background
        // sync write while the device is locked.
        try data.write(to: tmp, options: [.atomic, .completeFileProtectionUnlessOpen])
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}

/// SHA-256 content addressing for the asset store (D-112/§13.3).
enum MKContentHash {
    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// A stable (process-launch-independent) revision digest for a scene,
/// used as journal `baseRev` (§14.4) and autosave dirty-tracking (§14.4's
/// "write scene.json + manifest only when scene changed"). `Hasher` is
/// explicitly NOT used here ، it is randomly seeded per process, so it
/// cannot be compared across a save and a later crash-recovery replay in a
/// different process. FNV-1a is simple, dependency-free, and deterministic.
enum MKSceneRevision {
    static func hash(_ scene: MKScene) -> String {
        guard let data = try? MKSceneCodec.encode(scene) else { return "unhashable" }
        return fnv1aHex(data)
    }

    /// P-6: was a `for byte in data` loop, which walks `Data`'s generic
    /// `Sequence`/`IndexingIterator` conformance one element at a time ،
    /// a multi-megabyte encode plus a per-`UInt8` loop on every glyph
    /// nudge (called for journal `baseRev` AND autosave dirty-tracking on
    /// every mutation). Reads the buffer via `withUnsafeBytes` and
    /// `loadUnaligned` in 8-byte (word-sized) chunks instead, unpacking
    /// each word's constituent bytes with shifts ، this is STILL a
    /// per-byte FNV-1a update (the algorithm is inherently sequential and
    /// byte-order-sensitive, so it cannot be vectorized without changing
    /// the digest), but every byte now comes from a raw memory load
    /// instead of a `Data` element access, which is what actually costs
    /// here. `loadUnaligned` (rather than `bindMemory(to:)`) is used
    /// deliberately: `Data`'s backing storage alignment is not guaranteed,
    /// and `bindMemory` on a misaligned raw pointer is undefined behavior.
    /// Byte order matches the original loop bit-for-bit: Apple platforms
    /// are little-endian, so a word's least-significant byte IS the first
    /// memory byte, the same byte the old loop would have visited first ،
    /// output must stay byte-for-byte identical to the previous
    /// implementation (persisted hashes / journal `baseRev` chains must
    /// remain valid, see `CrashRecovery.swift:60,68`).
    private static func fnv1aHex(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01B3
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let count = raw.count
            let wordSize = MemoryLayout<UInt64>.size
            var offset = 0
            while offset + wordSize <= count {
                var word = raw.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
                for _ in 0..<wordSize {
                    hash ^= (word & 0xFF)
                    hash = hash &* prime
                    word >>= 8
                }
                offset += wordSize
            }
            while offset < count {
                hash ^= UInt64(raw[offset])
                hash = hash &* prime
                offset += 1
            }
        }
        return String(format: "%016llx", hash)
    }
}

/// Table-based CRC32 (standard IEEE 802.3 polynomial) for journal line
/// integrity checks (§14.4/§14.5). Implemented locally rather than via
/// `import zlib` to avoid any SPM linker-flag questions for a single
/// checksum function; this is the well-known reference algorithm, not a
/// novel implementation.
enum MKCRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    /// P-6: same `withUnsafeBytes` + `loadUnaligned` word-chunked byte
    /// source as `MKSceneRevision.fnv1aHex` above, same reasoning (avoid
    /// `Data`'s per-element `Sequence` overhead on every journal-line
    /// checksum, keep the per-byte table-lookup math and output bit-for-bit
    /// identical).
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let count = raw.count
            let wordSize = MemoryLayout<UInt64>.size
            var offset = 0
            while offset + wordSize <= count {
                var word = raw.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
                for _ in 0..<wordSize {
                    let index = Int((crc ^ UInt32(word & 0xFF)) & 0xFF)
                    crc = table[index] ^ (crc >> 8)
                    word >>= 8
                }
                offset += wordSize
            }
            while offset < count {
                let index = Int((crc ^ UInt32(raw[offset])) & 0xFF)
                crc = table[index] ^ (crc >> 8)
                offset += 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }

    static func hex(_ data: Data) -> String {
        String(format: "%08x", checksum(data))
    }
}

/// Abstraction over "wait this long" so tests can drive the autosave
/// debounce DETERMINISTICALLY instead of racing a wall-clock window
/// (WS-02 session 3: `mutationStormProducesAtMostTwoWrites...` was flaky
/// under full-package parallel load because its fixed post-storm sleep
/// could elapse before a CPU-starved debounce task ever ran). Production
/// always uses `MKTaskSleepScheduler` (real `Task.sleep` ، behavior
/// identical to the pre-seam code); tests inject a manual scheduler whose
/// `delay` suspends until the test explicitly releases it. Internal on
/// purpose: this is a test seam, not public API surface (`@testable`
/// reaches it).
protocol MKDelayScheduling: Sendable {
    /// Suspends for `interval` (or until the test releases it). Throws
    /// `CancellationError` (or simply returns with the task already
    /// cancelled ، callers must re-check `Task.isCancelled` either way).
    func delay(for interval: Duration) async throws
}

struct MKTaskSleepScheduler: MKDelayScheduling {
    func delay(for interval: Duration) async throws {
        try await Task.sleep(for: interval)
    }
}

/// Actor-isolated debounce: cancels and restarts a delayed task on every
/// `schedule` call, so only the *last* call in a burst actually fires
/// (used by `AutosaveController`'s ≤2 s debounced full save, D-112).
actor MKDebouncer {
    private var task: Task<Void, Never>?
    private let scheduler: any MKDelayScheduling

    init(scheduler: any MKDelayScheduling = MKTaskSleepScheduler()) {
        self.scheduler = scheduler
    }

    func schedule(after interval: Duration, _ operation: @escaping @Sendable () async -> Void) {
        task?.cancel()
        let scheduler = self.scheduler
        task = Task {
            do {
                try await scheduler.delay(for: interval)
            } catch {
                return // cancelled mid-delay
            }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

/// Canonical on-disk locations this module writes to (FILE_MAP.md §5's
/// `FileLocations.swift` sketch, implemented locally per the scope-fence
/// note above). `.documentsProjectsDirectory` holds user-visible
/// `.makhtoot` packages (§13.1: "Documents/Projects/<projectUUID>.makhtoot");
/// `.applicationSupportDirectory` holds the SwiftData metadata store
/// (§13.6: "Application Support dir... never contains scene JSON").
enum MKFileLocations {
    static func documentsProjectsDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let projects = documents.appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        // S-6: same `.completeUnlessOpen` posture as every write this
        // module makes (`MKAtomicIO.write`, `MKAssetStore.storeAsset`) ،
        // set on the directory too so it's the inherited default for
        // anything written under it without a matching explicit option.
        // Best-effort (`try?`): this attribute is an iOS Data Protection
        // concept with no real enforcement on the macOS host this
        // package's tests run on, and some non-APFS/edge configurations
        // may reject it outright ، a failure here must never break
        // directory creation itself, which every persistence path depends
        // on.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: projects.path
        )
        return projects
    }

    static func applicationSupportDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support
    }

    /// S-7: sibling scratch directory `MKAtomicIO.write` stages its
    /// `.tmp-*` temp files in, kept well outside every `.makhtoot`
    /// package (unlike the pre-fix behavior, which wrote the temp file
    /// into the destination's own directory ، for a document write, that
    /// directory IS the package). Lives under Application Support, next
    /// to this module's other non-package-visible state.
    static func atomicWriteScratchDirectory() throws -> URL {
        let support = try applicationSupportDirectory()
        let scratch = support.appendingPathComponent("MKAtomicWriteScratch", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        return scratch
    }
}
