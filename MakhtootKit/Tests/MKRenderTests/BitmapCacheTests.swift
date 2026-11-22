import Testing
import CoreGraphics
@testable import MKRender

/// WS-07 packet §5 task 8 accept: "unit tests for budget/eviction."
@Suite struct BitmapCacheTests {
    private func makeImage(side: Int = 16) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return ctx.makeImage()!
    }

    @Test func insertAndRetrieve() async {
        let cache = BitmapCache()
        let key = MKBitmapCacheKey(nodeContentHash: "a", scaleBucket: 1)
        let image = makeImage()
        await cache.insert(image, for: key)
        let fetched = await cache.image(for: key)
        #expect(fetched != nil)
        let count = await cache.entryCount
        #expect(count == 1)
    }

    @Test func evictsOldestWhenOverBudget() async {
        let image = makeImage(side: 16)
        let perEntryBytes = image.bytesPerRow * image.height
        // Budget for exactly 2 entries.
        let cache = BitmapCache(budgetBytes: perEntryBytes * 2)

        let keys = (0..<4).map { MKBitmapCacheKey(nodeContentHash: "k\($0)", scaleBucket: 1) }
        for key in keys {
            await cache.insert(image, for: key)
        }

        let count = await cache.entryCount
        #expect(count <= 2)
        // The two oldest keys should have been evicted first (LRU).
        let hasOldest = await cache.containsKey(keys[0])
        let hasNewest = await cache.containsKey(keys[3])
        #expect(!hasOldest)
        #expect(hasNewest)
    }

    @Test func accessRefreshesLRUOrder() async {
        let image = makeImage(side: 16)
        let perEntryBytes = image.bytesPerRow * image.height
        let cache = BitmapCache(budgetBytes: perEntryBytes * 2)

        let a = MKBitmapCacheKey(nodeContentHash: "a", scaleBucket: 1)
        let b = MKBitmapCacheKey(nodeContentHash: "b", scaleBucket: 1)
        let c = MKBitmapCacheKey(nodeContentHash: "c", scaleBucket: 1)

        await cache.insert(image, for: a)
        await cache.insert(image, for: b)
        _ = await cache.image(for: a)   // touch `a` ، now `b` is the LRU victim
        await cache.insert(image, for: c)   // forces one eviction

        let hasA = await cache.containsKey(a)
        let hasB = await cache.containsKey(b)
        #expect(hasA)
        #expect(!hasB)
    }

    @Test func offscreenEntriesEvictBeforeVisibleLRUEntries() async {
        let image = makeImage(side: 16)
        let perEntryBytes = image.bytesPerRow * image.height
        let cache = BitmapCache(budgetBytes: perEntryBytes * 3)

        let visibleOld = MKBitmapCacheKey(nodeContentHash: "visibleOld", scaleBucket: 1)
        let offscreenNew = MKBitmapCacheKey(nodeContentHash: "offscreenNew", scaleBucket: 1)
        let visibleNew = MKBitmapCacheKey(nodeContentHash: "visibleNew", scaleBucket: 1)

        await cache.insert(image, for: visibleOld, isOffscreen: false)
        await cache.insert(image, for: offscreenNew, isOffscreen: true)
        await cache.insert(image, for: visibleNew, isOffscreen: false)
        // Now over budget by one entry ، even though `visibleOld` is the
        // LRU, the OFFSCREEN entry must be evicted first (task 8: "eviction
        // order ، offscreen first, then LRU").
        let fourth = MKBitmapCacheKey(nodeContentHash: "fourth", scaleBucket: 1)
        await cache.insert(image, for: fourth, isOffscreen: false)

        let hasOffscreen = await cache.containsKey(offscreenNew)
        let hasVisibleOld = await cache.containsKey(visibleOld)
        #expect(!hasOffscreen)
        #expect(hasVisibleOld)
    }

    @Test func purgeOffscreenDropsOnlyOffscreenEntries() async {
        let image = makeImage()
        let cache = BitmapCache()
        let onscreen = MKBitmapCacheKey(nodeContentHash: "on", scaleBucket: 1)
        let offscreen = MKBitmapCacheKey(nodeContentHash: "off", scaleBucket: 1)
        await cache.insert(image, for: onscreen, isOffscreen: false)
        await cache.insert(image, for: offscreen, isOffscreen: true)

        await cache.purgeOffscreen()

        let hasOnscreen = await cache.containsKey(onscreen)
        let hasOffscreen = await cache.containsKey(offscreen)
        #expect(hasOnscreen)
        #expect(!hasOffscreen)
    }

    @Test func purgeAllDropsEverything() async {
        let image = makeImage()
        let cache = BitmapCache()
        await cache.insert(image, for: MKBitmapCacheKey(nodeContentHash: "a", scaleBucket: 1))
        await cache.insert(image, for: MKBitmapCacheKey(nodeContentHash: "b", scaleBucket: 2))
        await cache.purgeAll()
        let count = await cache.entryCount
        #expect(count == 0)
        let bytes = await cache.accountedBytes
        #expect(bytes == 0)
    }

    @Test func setBudgetTriggersImmediateEviction() async {
        let image = makeImage(side: 16)
        let perEntryBytes = image.bytesPerRow * image.height
        let cache = BitmapCache(budgetBytes: perEntryBytes * 4)
        for i in 0..<4 {
            await cache.insert(image, for: MKBitmapCacheKey(nodeContentHash: "k\(i)", scaleBucket: 1))
        }
        #expect(await cache.entryCount == 4)

        await cache.setBudget(bytes: perEntryBytes)   // shrink to fit exactly 1
        #expect(await cache.entryCount == 1)
        let bytes = await cache.accountedBytes
        #expect(bytes <= perEntryBytes)
    }
}
