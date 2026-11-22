import Foundation

// P14 hardening pass (AGENT_TASK_PACKETS/WS-07-rendering-performance.md, PLAN.md
// P14 item 1): ARCHITECTURE §12.3 declares `MKMemoryAccountable`/`MKMemoryGovernor`
// as `// MKFoundation` types ، the P4 WS-07 session explicitly left this
// cross-module registry unbuilt (`docs/impl-log/WS-07.md`, WS07-A3: "no
// cross-module `MKMemoryGovernor`... a target outside this packet's fence").
// This file closes that gap: a small, generic memory-accounting registry that
// any module's caches can register with, driven by `MKRender.MKDegradationController`
// at D-116 ladder stage transitions.
//
// **DF-12 VERIFY-AT-IMPLEMENTATION resolution (isolation story, probed before
// committing to this shape):** ARCHITECTURE §12.3's illustrative sketch declares
// `MKMemoryGovernor` as `Sendable` with synchronous methods, mutated from a
// `DispatchSource` callback queue while read from the main actor and from
// render/export tasks ، exactly the shape DF-12 flags as needing an explicit
// decision "actor vs. manually-audited `@unchecked Sendable` with a lock."
// Probed both shapes against this codebase's actual conformers before choosing:
// `MKRender.BitmapCache` is already an `actor` and `MKRender.MKLayerTreeController`
// is already `@MainActor` ، neither exposes a synchronous, non-isolated way to
// read `accountedBytes` or mutate its storage, so a `Sendable` class with a lock
// would need every conformer to ALSO expose an unsafe synchronous accessor
// (defeating the actor isolation both already have for good reason: LRU/CALayer
// mutation from arbitrary threads is exactly what actor/`@MainActor` isolation
// exists to prevent). Decision: `MKMemoryGovernor` is an `actor`;
// `MKMemoryAccountable`'s two mutating operations and its byte-accounting read
// are all `async` so any isolation domain (actor, `@MainActor`, or a plain
// `Sendable` type) can conform by implementing them as synchronous, actor-
// isolated, or `@MainActor` methods ، Swift allows a synchronous, isolated
// method to satisfy an `async` protocol requirement (the call site pays the
// hop, the conformer does not need to introduce its own asynchrony). This is
// the same pattern `MKRender.MKAutosaveTriggering` already established for the
// D-223 save-before-degrade seam (protocol `async`, conformers free to be
// actor-isolated or synchronous).
public protocol MKMemoryAccountable: AnyObject, Sendable {
    /// Current bytes this accountable is holding (bitmap caches, shaping
    /// caches, outline-path caches, etc. ، §12.2's "every cache is
    /// byte-accounted" list).
    func accountedBytes() async -> Int

    /// D-116 stage 1 (70%): drop only content that is not currently visible
    /// (offscreen bitmap tiles, cold shaping-cache entries). Named to match
    /// the action ARCHITECTURE §12.4's pseudocode calls on the governor
    /// itself (`governor.evictOffscreen()`) ، deliberately NOT the single
    /// `evict(toFraction:)` sketch in §12.3, because every real conformer in
    /// this codebase (`BitmapCache.purgeOffscreen()`/`.purgeAll()`,
    /// `MKLayerTreeController`'s equivalent pair) already has exactly two
    /// eviction actions, not a continuous fraction knob nothing here would
    /// ever call with an intermediate value ، see this file's ADR note in
    /// `docs/impl-log/WS-07-p14.md` for the full rationale, matching the
    /// precedent `docs/impl-log/WS-07.md` already set for documented,
    /// justified deviations from ARCHITECTURE's illustrative sketches.
    func evictOffscreen() async

    /// D-116/D-223 critical stage: drop everything (`purgeAll()`-equivalent).
    func evictAll() async
}

/// Eviction ordering hint for future governor policy (e.g. a governor that
/// evicts `.offscreenFirst` accountables before touching `.standard` ones
/// even at the offscreen-only stage). Not yet load-bearing ، the current
/// governor evicts every registered accountable uniformly per stage,
/// matching what D-116 actually specifies (no per-cache-class ordering is
/// documented anywhere in FOUNDATION/ARCHITECTURE) ، but the registration
/// API accepts it now so a future differential-priority policy is additive,
/// not a breaking API change.
public enum MKMemoryEvictionPriority: Int, Sendable, Comparable {
    case offscreenFirst = 0
    case standard = 1

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// The cross-module memory-accounting registry ARCHITECTURE §12.3 declares.
/// Any module's cache registers itself once; `MKRender.MKDegradationController`
/// (the D-116 ladder state machine) calls `evictOffscreen()`/`evictAll()` at
/// the appropriate stage transitions (§12.4's pseudocode: stage1 →
/// `evictOffscreen()`, critical → `evictAll()`; stage2 has no eviction call ،
/// it only degrades render fidelity, already handled by
/// `MKDegradationController.fidelity`).
public actor MKMemoryGovernor {
    /// Registrations are held via a small reference-type box so the entry
    /// itself can hold a `weak` reference to the accountable ، an actor
    /// (or any long-lived governor) must never be the reason a cache outlives
    /// its real owner. `weak` on a stored property requires a class-bound
    /// context in Swift, hence the boxing (a bare `weak` field cannot appear
    /// directly in an actor's synthesized storage the way a plain `struct`
    /// might suggest ، probed and confirmed this shape compiles cleanly
    /// under Swift 6 strict concurrency; the tuple/struct-with-weak-field
    /// alternative was tried first and rejected for exactly this reason).
    private final class Registration {
        weak var accountable: (any MKMemoryAccountable)?
        let priority: MKMemoryEvictionPriority
        init(accountable: any MKMemoryAccountable, priority: MKMemoryEvictionPriority) {
            self.accountable = accountable
            self.priority = priority
        }
    }

    private var registrations: [Registration] = []

    public init() {}

    /// Registers `accountable` for ladder-driven eviction. Idempotent-safe
    /// to call multiple times with the same instance (each call appends a
    /// new weak registration; dead ones are pruned lazily on the next
    /// governor operation, so accidental re-registration only costs a
    /// redundant-but-harmless eviction call, never a leak).
    public func register(_ accountable: any MKMemoryAccountable, priority: MKMemoryEvictionPriority = .standard) {
        registrations.append(Registration(accountable: accountable, priority: priority))
    }

    /// Sum of every live registrant's `accountedBytes()` ، the real-time
    /// figure §12.2's "<60% memory ceiling" budget is measured against
    /// (T-PRF-10), and what a P14 perf-HUD/ballast test reads to confirm
    /// eviction actually freed bytes, not just flipped a stage flag.
    public func totalAccountedBytes() async -> Int {
        prune()
        var total = 0
        for registration in registrations {
            guard let accountable = registration.accountable else { continue }
            total += await accountable.accountedBytes()
        }
        return total
    }

    /// D-116 stage 1 (70%): "drop offscreen bitmap caches."
    public func evictOffscreen() async {
        prune()
        for registration in registrations {
            await registration.accountable?.evictOffscreen()
        }
    }

    /// D-116/D-223 critical: `purgeAll()`-equivalent across every registrant.
    public func evictAll() async {
        prune()
        for registration in registrations {
            await registration.accountable?.evictAll()
        }
    }

    /// Number of currently-live (non-deallocated) registrations ، test/HUD
    /// observability only.
    public var liveRegistrationCount: Int {
        registrations.filter { $0.accountable != nil }.count
    }

    private func prune() {
        registrations.removeAll { $0.accountable == nil }
    }
}
