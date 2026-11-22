import Foundation
import MKFoundation

/// On-device usage counter store. T2.
///
/// Stores `(fontID, isoWeek) → count` as a JSON dictionary persisted to
/// Application Support. The actor is the concurrency boundary ، all reads
/// and writes go through it.
///
/// ## Retention (T2/T4)
/// Raw counters older than 8 weeks are pruned on every `prune()` call
/// (typically called at launch and after a successful upload). Pending
/// upload batches for a week are dropped together with their raw counters ،
/// there is no independent retry-window separate from the 8-week raw
/// retention (T4/DF-7 alignment rule).
///
/// ## Key format
/// `"<fontID>|<isoWeek>"` where `isoWeek` is the ISO 8601 week string
/// produced by `MKISOWeek.current()` ، e.g. `"amiri|2026-W29"`.
public actor MKUsageCounterStore {

    // MARK: Types

    typealias CounterKey = String  // "<fontID>|<isoWeek>"
    typealias Counters   = [CounterKey: Int]

    // MARK: State

    private var counters: Counters = [:]
    private let storeURL: URL

    // MARK: Init

    public init(storeURL: URL) {
        self.storeURL = storeURL
    }

    public static func production() -> MKUsageCounterStore {
        let dir = MKAnalyticsStorage.analyticsDirectory()
        let url = dir.appendingPathComponent("counters.json")
        return MKUsageCounterStore(storeURL: url)
    }

    // MARK: Load / Persist

    public func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            counters = try JSONDecoder().decode(Counters.self, from: data)
        } catch {
            MKLog.analytics.error("MKUsageCounterStore: load error: \(error, privacy: .public)")
            counters = [:]
        }
    }

    // MARK: Record

    /// Increment the counter for `fontID` in the current ISO week.
    /// No-op if called outside consent gate (caller must check).
    public func increment(fontID: String) {
        let key = makeKey(fontID: fontID, week: MKISOWeek.current())
        counters[key, default: 0] += 1
        persist()
    }

    // MARK: Query

    /// Returns all (fontID, week, count) tuples for weeks that are
    /// strictly earlier than the current week (closed weeks only ، T4).
    public func closedWeekEntries() -> [(fontID: String, week: String, count: Int)] {
        let currentWeek = MKISOWeek.current()
        return counters.compactMap { key, count in
            guard let (fontID, week) = splitKey(key), week < currentWeek else { return nil }
            return (fontID: fontID, week: week, count: count)
        }
    }

    /// Delete all counter entries for the given week (called after
    /// successful upload of that week's batch ، T4).
    public func deleteEntries(for week: String) {
        counters = counters.filter { key, _ in
            splitKey(key)?.week != week
        }
        persist()
    }

    /// Wipe ALL counters (revoke path ، T1/D-125). T1 AC: verified empty.
    public func wipeAll() {
        counters = [:]
        persist()
    }

    /// Prune counters older than 8 weeks (T2/T4 retention). Returns the
    /// set of pruned weeks.
    @discardableResult
    public func pruneOldEntries(currentWeek: String? = nil) -> Set<String> {
        let now = currentWeek ?? MKISOWeek.current()
        guard let cutoff = MKISOWeek.week(subtractingWeeks: 8, from: now) else { return [] }
        var pruned: Set<String> = []
        counters = counters.filter { key, _ in
            guard let (_, week) = splitKey(key) else { return false }
            if week < cutoff {
                pruned.insert(week)
                return false
            }
            return true
        }
        if !pruned.isEmpty { persist() }
        return pruned
    }

    // MARK: isEmpty

    public var isEmpty: Bool { counters.isEmpty }

    // MARK: Private helpers

    private func makeKey(fontID: String, week: String) -> CounterKey {
        "\(fontID)|\(week)"
    }

    private func splitKey(_ key: CounterKey) -> (fontID: String, week: String)? {
        let parts = key.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (fontID: String(parts[0]), week: String(parts[1]))
    }

    private func persist() {
        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(counters)
            try data.write(to: storeURL, options: .atomicWrite)
        } catch {
            MKLog.analytics.error("MKUsageCounterStore: persist error: \(error, privacy: .public)")
        }
    }
}

// MARK: - ISO week helpers

/// ISO 8601 week string utilities. Week boundaries use the ISO calendar
/// (Monday = first day of week, locale-independent ، re-identification
/// resistance: week granularity only, D-125 / WS-12-A2 ADR).
public enum MKISOWeek {
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    /// Current ISO week string e.g. `"2026-W29"`.
    public static func current() -> String {
        string(from: Date())
    }

    /// ISO week string for an arbitrary date.
    public static func string(from date: Date) -> String {
        let cal = calendar
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    /// Return the ISO week string `n` weeks before `base`.
    /// Returns `nil` if the calendar arithmetic fails.
    public static func week(subtractingWeeks n: Int, from base: String) -> String? {
        guard let date = date(from: base) else { return nil }
        guard let earlier = calendar.date(byAdding: .weekOfYear, value: -n, to: date) else { return nil }
        return string(from: earlier)
    }

    /// Parse an ISO week string back to a Monday Date.
    public static func date(from weekString: String) -> Date? {
        // e.g. "2026-W29" → year 2026, week 29
        let parts = weekString.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let weekStr = parts[1].dropFirst().isEmpty ? nil : String(parts[1].dropFirst()),
              let week = Int(weekStr)
        else { return nil }
        // Build a date from year + week
        let cal = calendar
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = 2  // Monday
        return cal.date(from: components)
    }
}
