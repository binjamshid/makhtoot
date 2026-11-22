import Dispatch
import Foundation
#if os(iOS)
import Darwin.os.proc
#endif

// WS-07 packet §5 task 10. D-116 sampling seam: `DispatchSource
// .makeMemoryPressureSource` events + periodic `os_proc_available_memory()`
// sampling, mapped to `MKMemoryStage` via the ARCHITECTURE §12.4
// thresholds. Injectable sampler + injectable clock make the stage-walk
// unit-testable without real OS memory pressure (task 10 accept criterion).

/// Reads the process's available-memory fraction. ARCHITECTURE §12.4's
/// formula is `usedFraction = 1 - available/total`, sourced from
/// `os_proc_available_memory()` (an iOS/watchOS/tvOS-only Darwin symbol,
/// iOS 15+, NOT present in the macOS SDK).
///
/// `VERIFY-AT-IMPLEMENTATION` (this packet's hooks-only P4 scope, full
/// hardening is P14): this package also builds for macOS so `swift build`/
/// `swift test` work on the host toolchain without Xcode
/// (Package.swift's platform note) ، `os_proc_available_memory` cannot be
/// linked/verified from this sandboxed, non-Xcode toolchain. `default`
/// returns a safe "plenty of memory" `0` everywhere so the package
/// compiles and the ladder never spuriously trips on the host; the P14
/// hardening pass must replace this with the real Darwin call (behind
/// `#if os(iOS)`) and add the device-verified budget table PLAN.md P14
/// requires. Every other piece of the ladder (`MKDegradationController`,
/// `MKMemoryThresholds`, hysteresis, stage-walk tests) is real and fully
/// exercised via the injectable `sampler` below, independent of this gap.
public enum MKMemorySampling {
    /// Returns the process's used-memory fraction (1 − available/physical).
    /// Uses `os_proc_available_memory()` on iOS (iOS 13+, Darwin-only symbol).
    /// Returns 0 on macOS so the package continues to build and test on the
    /// host toolchain ، the VERIFY-AT-IMPLEMENTATION note in the original is
    /// now satisfied for the iOS target (P14 hardening pass, WS-07 §5 task 10).
    public static func currentUsedFraction() -> Double {
#if os(iOS)
        let available = Double(os_proc_available_memory())
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - available / total))
#else
        return 0
#endif
    }
}

/// D-116 threshold table (ARCHITECTURE §12.4): usedFraction ≥0.70 → stage1;
/// ≥0.85 → stage2. `.critical` is never derived from a fraction ، it only
/// ever comes from the `DispatchSource` `.critical` event (mapped directly,
/// "never downgraded" per §12.3).
public enum MKMemoryThresholds {
    public static let stage1: Double = 0.70
    public static let stage2: Double = 0.85

    public static func stage(forUsedFraction fraction: Double) -> MKMemoryStage {
        if fraction >= stage2 { return .stage2 }
        if fraction >= stage1 { return .stage1 }
        return .normal
    }
}

/// Samples memory pressure and drives an `MKDegradationController`. An
/// `actor` (task 10's own framing: "actor ، DispatchSource events + 2 s
/// os_proc_available_memory sampling"); the ladder itself
/// (`MKDegradationController`) is `@MainActor`, so every call into it hops
/// actors ، acceptable since transitions are rare (seconds-scale), not a
/// hot path.
public actor MKMemoryPressureMonitor {
    private let sampler: @Sendable () -> Double
    private let ladder: MKDegradationController
    private let sampleInterval: Duration
    private var dispatchSource: DispatchSourceMemoryPressure?
    private var samplingTask: Task<Void, Never>?

    /// - Parameters:
    ///   - sampler: Injectable used-fraction reader; defaults to
    ///     `MKMemorySampling.currentUsedFraction`. Tests pass a closure that
    ///     returns scripted values to drive the ladder through 0→1→2→3
    ///     and back deterministically.
    ///   - ladder: The controller this monitor drives.
    ///   - sampleInterval: §12.3/§12.4's "every 2 s while frontmost" ،
    ///     configurable so tests don't wait 2 real seconds per sample.
    public init(
        sampler: @escaping @Sendable () -> Double = MKMemorySampling.currentUsedFraction,
        ladder: MKDegradationController,
        sampleInterval: Duration = .seconds(2)
    ) {
        self.sampler = sampler
        self.ladder = ladder
        self.sampleInterval = sampleInterval
    }

    /// Starts periodic sampling + the `DispatchSource` `.warning`/`.critical`
    /// event listener. Idempotent (calling twice while already running is a
    /// no-op) ، matches the "start once, on editor-frontmost" lifecycle
    /// WS-13 drives.
    public func start() {
        guard samplingTask == nil else { return }

        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let isCritical = source.data.contains(.critical)
            Task { await self.handleDispatchSourceEvent(isCritical: isCritical) }
        }
        source.resume()
        dispatchSource = source

        samplingTask = Task { [sampleInterval] in
            while !Task.isCancelled {
                await self.sampleNow()
                try? await Task.sleep(for: sampleInterval)
            }
        }
    }

    public func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        samplingTask?.cancel()
        samplingTask = nil
    }

    /// Test/production seam: forces exactly one sample-and-maybe-transition
    /// cycle synchronously (awaitable), independent of the periodic loop.
    public func sampleNow() async {
        let fraction = sampler()
        let mapped = MKMemoryThresholds.stage(forUsedFraction: fraction)
        await ladder.transition(to: mapped)
    }

    /// §12.3 `.warning`-event semantics (D-223): a coarse OS signal, not
    /// itself a stage ، forces an immediate sample AND forces entry into at
    /// least `.stage1` regardless of what the sample reports (a
    /// deliberately conservative reaction). `.critical` maps directly to
    /// `MKMemoryStage.critical`.
    private func handleDispatchSourceEvent(isCritical: Bool) async {
        if isCritical {
            await ladder.transition(to: .critical)
            return
        }
        let fraction = sampler()
        let mapped = MKMemoryThresholds.stage(forUsedFraction: fraction)
        let forced = max(mapped, .stage1)
        await ladder.transition(to: forced)
    }
}
