import CoreGraphics
import Foundation
import MKFoundation

// WS-07 packet §5 task 8. LRU bitmap cache keyed `(nodeContentHash,
// scaleBucket)`, byte-budgeted, offscreen-first eviction. P14 hardening
// pass: conforms to `MKFoundation.MKMemoryAccountable` so any owner that
// registers an instance with `MKMemoryGovernor` gets real D-116 ladder-driven
// eviction (`purgeOffscreen()`/`purgeAll()` were already exactly the two
// eviction actions the protocol needs ، see `CONTRACTS.md`'s WS-07 section).
public struct MKBitmapCacheKey: Hashable, Sendable {
    public var nodeContentHash: String
    public var scaleBucket: Double

    public init(nodeContentHash: String, scaleBucket: Double) {
        self.nodeContentHash = nodeContentHash
        self.scaleBucket = scaleBucket
    }
}

/// One cached entry: the rendered bitmap, its accounted byte cost
/// (`bytesPerRow × height`, the same accounting `MKMemoryGovernor` would
/// use per ARCHITECTURE §12.3), and whether the owning layer is currently
/// offscreen (stage-1 eviction priority, §12.4).
public struct MKBitmapCacheEntry: Sendable {
    public var image: CGImage
    public var bytes: Int
    public var isOffscreen: Bool

    public init(image: CGImage, isOffscreen: Bool = false) {
        self.image = image
        self.bytes = image.bytesPerRow * image.height
        self.isOffscreen = isOffscreen
    }
}

/// Actor-isolated (mutable LRU state, read/written from the render queue
/// per §11.2 ، "produced on the render queue, assigned on main"). Task 8
/// accept criteria: "unit tests for budget/eviction"; "instrumented memory
/// stays under budget while zooming across the 5 000-node fixture" is a
/// P14 device/perf-harness concern (task 14), not exercised here.
public actor BitmapCache {
    /// `min(256 MB, 15% of os_proc_available_memory at init)` per task 8 ،
    /// the 15%-of-available half needs the real Darwin memory read
    /// `MemoryPressureMonitor.swift` documents as `VERIFY-AT-IMPLEMENTATION`
    /// (unavailable from this sandboxed macOS-host toolchain); this cache
    /// defaults to the 256 MB ceiling and exposes `setBudget(bytes:)` so
    /// `MKDegradationController`/a P14 governor can recompute it from a
    /// real reading at init and on every ladder stage change, matching
    /// task 8's "recomputed on ladder stage change."
    public static let maxBudgetBytes = 256 * 1024 * 1024

    private var storage: [MKBitmapCacheKey: MKBitmapCacheEntry] = [:]
    private var lruOrder: [MKBitmapCacheKey] = []   // least-recently-used first
    private var budgetBytes: Int

    public init(budgetBytes: Int = BitmapCache.maxBudgetBytes) {
        self.budgetBytes = budgetBytes
    }

    public var accountedBytes: Int {
        storage.values.reduce(0) { $0 + $1.bytes }
    }

    public func setBudget(bytes: Int) {
        budgetBytes = bytes
        evictIfNeeded()
    }

    public func insert(_ image: CGImage, for key: MKBitmapCacheKey, isOffscreen: Bool = false) {
        storage[key] = MKBitmapCacheEntry(image: image, isOffscreen: isOffscreen)
        touch(key)
        evictIfNeeded()
    }

    public func image(for key: MKBitmapCacheKey) -> CGImage? {
        guard let entry = storage[key] else { return nil }
        touch(key)
        return entry.image
    }

    public func markOffscreen(_ key: MKBitmapCacheKey, _ isOffscreen: Bool) {
        storage[key]?.isOffscreen = isOffscreen
    }

    /// D-116 stage 1 (70%): "drop offscreen bitmap caches."
    public func purgeOffscreen() {
        let offscreenKeys = storage.filter(\.value.isOffscreen).map(\.key)
        for key in offscreenKeys { remove(key) }
    }

    /// D-116 critical (§12.4): "purgeAll()."
    public func purgeAll() {
        storage.removeAll()
        lruOrder.removeAll()
    }

    public func containsKey(_ key: MKBitmapCacheKey) -> Bool {
        storage[key] != nil
    }

    public var entryCount: Int { storage.count }

    // MARK: - LRU bookkeeping

    private func touch(_ key: MKBitmapCacheKey) {
        if let index = lruOrder.firstIndex(of: key) {
            lruOrder.remove(at: index)
        }
        lruOrder.append(key)
    }

    private func remove(_ key: MKBitmapCacheKey) {
        storage.removeValue(forKey: key)
        if let index = lruOrder.firstIndex(of: key) {
            lruOrder.remove(at: index)
        }
    }

    /// Eviction order (task 8): offscreen first, then LRU.
    private func evictIfNeeded() {
        guard budgetBytes > 0 else { return }
        while accountedBytes > budgetBytes, !lruOrder.isEmpty {
            if let offscreenKey = lruOrder.first(where: { storage[$0]?.isOffscreen == true }) {
                remove(offscreenKey)
            } else {
                remove(lruOrder[0])
            }
        }
    }
}

// MARK: - MKMemoryAccountable (P14)

extension BitmapCache: MKMemoryAccountable {
    public func accountedBytes() async -> Int { accountedBytes }
    public func evictOffscreen() async { purgeOffscreen() }
    public func evictAll() async { purgeAll() }
}
