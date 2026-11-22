import Foundation
import MKFoundation

/// T17 ، D-119 expiry locking. Observes `MKEntitlementProviding` (via the
/// injected async sequence the caller drives ، this packet's stub-swap
/// strategy: WS-09 codes only against the protocol, so a test can inject a
/// `free`/`expired` fake through the same seam WS-10 later replaces with
/// the real resolver, per the packet's §3 upstream-dependency note).
///
/// FILE_MAP §14 lists `ExpiryLockController.swift` under "owner: WS-10",
/// while the WS-09 task packet's own T17 assigns this exact behavior (with
/// its own AC/test) to WS-09. Implemented here per the packet (the more
/// specific, directly-binding instruction for this run) ، logged as a
/// deviation from the FILE_MAP row in `docs/impl-log/WS-09.md`. WS-10 is
/// still the integration point that supplies the REAL entitlement stream;
/// this type only needs the protocol.
public actor MKFontLockController {
    private let registry: MKFontRegistry
    private var observationTask: Task<Void, Never>?

    public init(registry: MKFontRegistry) {
        self.registry = registry
    }

    /// Feeds entitlement-state transitions in. Callers wire this from
    /// `MKEntitlementProviding`'s own async sequence (WS-10 supplies the
    /// real one; tests inject a fake `AsyncStream` directly). On
    /// transition to a non-premium state: lock every
    /// `premiumDownloaded`/`userImported` record. On transition to a
    /// premium state: unlock them. Applies within one runloop of the call
    /// (AC) ، this method `await`s the registry mutation directly, no
    /// debouncing.
    ///
    /// Concrete `AsyncStream<MKEntitlementState>` rather than a generic
    /// `AsyncSequence` ، a generic constrained to `Failure == Never` needs
    /// macOS 15 (this package's `platforms:` pins macOS 14 for the host
    /// dev-loop build, D-100's iOS 18 deployment target is unaffected),
    /// and every realistic entitlement-change source (WS-10's resolver,
    /// test fakes) is naturally expressible as an `AsyncStream`.
    public func observe(_ states: AsyncStream<MKEntitlementState>) async {
        for await state in states {
            await apply(state)
        }
    }

    public func apply(_ state: MKEntitlementState) async {
        await registry.setLocked(!state.grantsPremiumAccess, origins: [.premiumDownloaded, .userImported])
    }

    /// One-shot check useful for tests/UI that don't want a running
    /// observation task.
    public func reconcile(with entitlements: any MKEntitlementProviding) async {
        await apply(entitlements.state)
    }
}
