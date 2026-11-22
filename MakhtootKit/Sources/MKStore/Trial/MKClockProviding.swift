import Foundation

/// Clock seam (T6 AC: "unit tests with injected clock"). Two independent
/// signals per D-224: wall clock (forgeable by the user) and system uptime
/// (unforgeable within a single boot session ، resets only on reboot).
public protocol MKClockProviding: Sendable {
    func now() -> Date
    func systemUptime() -> TimeInterval
}

/// Real clock: `Date()` + `ProcessInfo.processInfo.systemUptime`.
public struct MKSystemClock: MKClockProviding {
    public init() {}
    public func now() -> Date { Date() }
    public func systemUptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
}

/// Test double: independently settable wall clock and uptime, so tests can
/// simulate a wall-clock rollback while uptime keeps advancing normally
/// (D-224's defining scenario) without the two being coupled the way a
/// simple "fake Date + fixed offset" clock would force them to be.
public final class MKFakeClock: MKClockProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    private var _uptime: TimeInterval

    public init(now: Date = Date(), uptime: TimeInterval = 0) {
        self._now = now
        self._uptime = uptime
    }

    public func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return _now
    }

    public func systemUptime() -> TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return _uptime
    }

    /// Advances both wall clock and uptime together by `interval` ، the
    /// "normal passage of time" case.
    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _now = _now.addingTimeInterval(interval)
        _uptime += interval
    }

    /// Sets the wall clock directly without touching uptime ، the
    /// "user changed the system clock" case (rollback or forward-set).
    public func setWallClock(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        _now = date
    }

    /// Sets uptime directly without touching the wall clock ، models a
    /// reboot (uptime resets near 0) independent of any wall-clock change.
    public func setUptime(_ uptime: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        _uptime = uptime
    }
}
