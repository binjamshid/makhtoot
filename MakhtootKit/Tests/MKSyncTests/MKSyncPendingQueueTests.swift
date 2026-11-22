import Foundation
import Testing
@testable import MKSync

// T4 ، Pending queue: coalescing, debounce gating, delete overrides upload.

struct MKSyncPendingQueueTests {
    // MARK: - Coalescing (T4: "10 rapid saves produce 1 upload")

    @Test("10 rapid uploads for the same project coalesce to 1 entry")
    func rapidUploadsCoalesce() async {
        let queue = MKSyncPendingQueue()
        let id = UUID()
        let past = Date(timeIntervalSinceNow: -100) // already past debounce window

        for _ in 0..<10 {
            await queue.scheduleUpload(for: id, at: past)
        }

        let all = await queue.allEntries()
        #expect(all.count == 1)
        #expect(all.first?.projectID == id)
        #expect(all.first?.kind == .upload)
    }

    @Test("Different project IDs each get their own entry")
    func differentIDsAreIndependent() async {
        let queue = MKSyncPendingQueue()
        let past = Date(timeIntervalSinceNow: -100)

        for _ in 0..<5 {
            await queue.scheduleUpload(for: UUID(), at: past)
        }

        let all = await queue.allEntries()
        #expect(all.count == 5)
    }

    // MARK: - Debounce gating

    @Test("nextBatch excludes entries within the debounce window")
    func debounceWindowExcludesRecent() async {
        let queue = MKSyncPendingQueue()
        let id = UUID()
        // Enqueue at "now" ، inside the 5-second window.
        await queue.scheduleUpload(for: id)

        let batch = await queue.nextBatch(debounce: .seconds(5))
        #expect(batch.isEmpty)
    }

    @Test("nextBatch includes entries outside the debounce window")
    func pastEntriesIncluded() async {
        let queue = MKSyncPendingQueue()
        let id = UUID()
        let past = Date(timeIntervalSinceNow: -10) // 10s ago
        await queue.scheduleUpload(for: id, at: past)

        let batch = await queue.nextBatch(debounce: .seconds(5))
        #expect(batch.count == 1)
        #expect(batch.first?.projectID == id)
    }

    // MARK: - Delete overrides upload

    @Test("delete overrides a pending upload for the same project")
    func deleteOverridesUpload() async {
        let queue = MKSyncPendingQueue()
        let id = UUID()
        let past = Date(timeIntervalSinceNow: -10)

        await queue.scheduleUpload(for: id, at: past)
        await queue.scheduleDelete(for: id, at: past)

        let batch = await queue.nextBatch(debounce: .seconds(5))
        #expect(batch.count == 1)
        #expect(batch.first?.kind == .delete)
    }

    @Test("upload after delete replaces the delete")
    func uploadAfterDeleteReplacesDelete() async {
        let queue = MKSyncPendingQueue()
        let id = UUID()
        let past = Date(timeIntervalSinceNow: -10)

        await queue.scheduleDelete(for: id, at: past)
        await queue.scheduleUpload(for: id, at: past)

        let batch = await queue.nextBatch(debounce: .seconds(5))
        #expect(batch.count == 1)
        #expect(batch.first?.kind == .upload)
    }

    // MARK: - Clear

    @Test("clear removes the entry for the specified project")
    func clearRemovesEntry() async {
        let queue = MKSyncPendingQueue()
        let id = UUID()
        let past = Date(timeIntervalSinceNow: -10)
        await queue.scheduleUpload(for: id, at: past)

        await queue.clear(id: id)

        let all = await queue.allEntries()
        #expect(all.isEmpty)
    }

    @Test("clear on non-existent entry is a no-op")
    func clearNonExistentNoop() async {
        let queue = MKSyncPendingQueue()
        await queue.clear(id: UUID())  // should not throw / crash
        #expect(await queue.count == 0)
    }

    // MARK: - removeAll

    @Test("removeAll empties the queue (account switch reset)")
    func removeAllEmpties() async {
        let queue = MKSyncPendingQueue()
        let past = Date(timeIntervalSinceNow: -10)
        for _ in 0..<5 { await queue.scheduleUpload(for: UUID(), at: past) }
        #expect(await queue.count == 5)

        await queue.removeAll()
        #expect(await queue.count == 0)
    }

    // MARK: - Count

    @Test("count reflects the number of unique projects pending")
    func countIsAccurate() async {
        let queue = MKSyncPendingQueue()
        let id = UUID()
        let past = Date(timeIntervalSinceNow: -10)

        #expect(await queue.count == 0)
        await queue.scheduleUpload(for: id, at: past)
        #expect(await queue.count == 1)
        await queue.scheduleUpload(for: id, at: past) // coalesce, not +1
        #expect(await queue.count == 1)
        await queue.clear(id: id)
        #expect(await queue.count == 0)
    }
}
