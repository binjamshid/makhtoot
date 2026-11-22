import Foundation
import StoreKit
import MKFoundation

/// On-disk cache DTO (T5: "cache last state in a local file (not Keychain
/// ، non-secret) for instant offline startup, marked with resolution
/// timestamp"). `MKEntitlementState` itself isn't `Codable` (WS-01-shipped
/// shape, `MKFoundation`) ، this is the module-local mapping to/from a
/// serializable form.
private struct MKEntitlementCacheRecord: Codable {
    var stateTag: String
    var trialDaysLeft: Int?
    var resolvedAt: Date

    static func encode(_ state: MKEntitlementState, resolvedAt: Date) -> MKEntitlementCacheRecord {
        switch state {
        case .lifetime: return .init(stateTag: "lifetime", trialDaysLeft: nil, resolvedAt: resolvedAt)
        case .subscribed: return .init(stateTag: "subscribed", trialDaysLeft: nil, resolvedAt: resolvedAt)
        case .inGracePeriod: return .init(stateTag: "inGracePeriod", trialDaysLeft: nil, resolvedAt: resolvedAt)
        case .inBillingRetry: return .init(stateTag: "inBillingRetry", trialDaysLeft: nil, resolvedAt: resolvedAt)
        case .trial(let daysLeft): return .init(stateTag: "trial", trialDaysLeft: daysLeft, resolvedAt: resolvedAt)
        case .free: return .init(stateTag: "free", trialDaysLeft: nil, resolvedAt: resolvedAt)
        }
    }

    func decode() -> MKEntitlementState {
        switch stateTag {
        case "lifetime": return .lifetime
        case "subscribed": return .subscribed
        case "inGracePeriod": return .inGracePeriod
        case "inBillingRetry": return .inBillingRetry
        case "trial": return .trial(daysLeft: trialDaysLeft ?? 0)
        default: return .free
        }
    }
}

/// The single source of monetization truth (T5, D-113, D-230). An `actor`
/// so the read-StoreKit / merge-precedence / persist-cache / broadcast
/// cycle is fully serialized; exposes a `nonisolated` synchronous `state`
/// (satisfying `MKEntitlementProviding`'s existing synchronous shape,
/// `CONTRACTS.md`-locked) backed by a lock-guarded snapshot so every
/// synchronous downstream reader (`MKExportGate.evaluate`,
/// `MKFontLockController.reconcile`) keeps working unmodified.
public actor MKEntitlementResolver: MKEntitlementProviding {
    private let catalog: MKProductCatalog
    private let trialManager: MKTrialManager
    /// `nonisolated` (not `private`) so `@testable import MKStore` can read
    /// the resolved default location synchronously (S-1 regression test:
    /// the no-override default must resolve under Application Support, not
    /// `.cachesDirectory`). Immutable + `Sendable` (`URL`), so exposing it
    /// this way is safe without a lock, unlike the mutable snapshot state
    /// below.
    nonisolated let cacheURL: URL
    /// ARCHITECTURE §18.2: cached `subscribed`/lifetime state is honored
    /// offline until expiry + this tolerance, then degrades to `free`
    /// rather than trusting a StoreKit round trip that may never come.
    /// `lifetime` is never subject to this (T17: "honored offline
    /// indefinitely").
    private let cacheStalenessTolerance: TimeInterval

    private nonisolated(unsafe) var _snapshotState: MKEntitlementState = .free
    private nonisolated(unsafe) var _snapshotDetail: MKEntitlementDetail = .none
    private let snapshotLock = NSLock()

    private var continuations: [UUID: AsyncStream<MKEntitlementState>.Continuation] = [:]
    private var listenerTask: Task<Void, Never>?

    public init(
        catalog: MKProductCatalog,
        trialManager: MKTrialManager,
        cacheURL: URL? = nil,
        cacheStalenessTolerance: TimeInterval = 3 * 86_400
    ) {
        self.catalog = catalog
        self.trialManager = trialManager
        self.cacheStalenessTolerance = cacheStalenessTolerance
        if let cacheURL {
            self.cacheURL = cacheURL
        } else {
            // S-1: Application Support, not `.cachesDirectory` ، iOS may
            // purge Caches under disk pressure, which would silently
            // demote a paying customer to `.free` on the next cold
            // offline launch. `MKPersistence.MKFileLocations` isn't
            // reachable here (D-230: `MKStore` must not depend on
            // `MKPersistence`), so this mirrors the direct
            // `FileManager.default.urls(for:.applicationSupportDirectory,...)`
            // pattern `MKFontDownloader.swift`/`MKCatalogManifestFetchService.swift`
            // already use.
            self.cacheURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MKStore/entitlement-cache.json")
        }
        // T5 AC: cold-offline launch yields cached state in <50 ms,
        // SCOPED to post-first-resolution launches. A plain synchronous
        // file read in `init` (actor `init` is not `async`) satisfies
        // this trivially ، no StoreKit round trip is on this path at all.
        if let data = try? Data(contentsOf: self.cacheURL),
           let record = try? JSONDecoder().decode(MKEntitlementCacheRecord.self, from: data) {
            let decoded = record.decode()
            // ARCHITECTURE §18.2 / S-1: a cached state is only honored
            // offline while still within `cacheStalenessTolerance` of its
            // resolution time ، past that it degrades to the `.free`
            // default instead of trusting a StoreKit round trip that may
            // never come. `.lifetime` is exempt (T17: "honored offline
            // indefinitely").
            if case .lifetime = decoded {
                _snapshotState = decoded
            } else if Date().timeIntervalSince(record.resolvedAt) < cacheStalenessTolerance {
                _snapshotState = decoded
            }
        }
    }

    // MARK: - MKEntitlementProviding

    public nonisolated var state: MKEntitlementState {
        snapshotLock.lock(); defer { snapshotLock.unlock() }
        return _snapshotState
    }

    /// Not part of `MKEntitlementProviding` (that protocol's `isEntitled`
    /// default extension already covers gating) ، this is the T9/T19
    /// banner/sheet-facing companion (`MKEntitlementDetail`, kept out of
    /// `MKFoundation` ، see that type's own header for why).
    public nonisolated var detail: MKEntitlementDetail {
        snapshotLock.lock(); defer { snapshotLock.unlock() }
        return _snapshotDetail
    }

    // MARK: - Resolution (T5)

    /// Gathers lifetime ownership + subscription-group status from
    /// StoreKit, folds in the trial state, applies `MKEntitlementPrecedence`,
    /// updates the snapshot + cache, and broadcasts to every `states()`
    /// subscriber. Call at launch, on foreground, and from the transaction
    /// listener (T4/T5).
    @discardableResult
    public func resolve() async -> MKEntitlementState {
        let hasLifetime = await gatherHasLifetime()
        let subscriptionSignal = hasLifetime ? .none : await gatherSubscriptionSignal()
        let trialState = await trialManager.resolve()
        let (resolved, detail) = MKEntitlementPrecedence.resolve(
            hasLifetime: hasLifetime,
            subscription: subscriptionSignal,
            trial: trialState
        )
        applySnapshot(resolved, detail: detail)
        persistCache(resolved)
        return resolved
    }

    private func applySnapshot(_ state: MKEntitlementState, detail: MKEntitlementDetail) {
        snapshotLock.lock()
        let changed = _snapshotState != state
        _snapshotState = state
        _snapshotDetail = detail
        snapshotLock.unlock()
        if changed {
            for continuation in continuations.values {
                continuation.yield(state)
            }
        }
    }

    private func persistCache(_ state: MKEntitlementState) {
        let record = MKEntitlementCacheRecord.encode(state, resolvedAt: Date())
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func gatherHasLifetime() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard let txn = try? checkVerified(result) else { continue }
            if txn.productID == MKStoreIDs.lifetime, txn.revocationDate == nil {
                return true
            }
        }
        return false
    }

    private func gatherSubscriptionSignal() async -> MKSubscriptionSignal {
        await catalog.load()
        let monthlyProduct = await catalog.product(for: MKStoreIDs.monthly)
        let annualProduct = await catalog.product(for: MKStoreIDs.annual)
        guard let anchor = monthlyProduct ?? annualProduct,
            let subscriptionInfo = anchor.subscription
        else { return .none }
        guard let statuses = try? await subscriptionInfo.status else { return .none }

        var best: MKSubscriptionSignal = .none
        for status in statuses {
            guard let renewal = try? checkVerified(status.renewalInfo) else { continue }
            let transaction = try? checkVerified(status.transaction)
            let renewalInfo = MKRenewalInfo(
                willAutoRenew: renewal.willAutoRenew,
                renewalDate: transaction?.expirationDate,
                autoRenewProductID: renewal.autoRenewPreference
            )
            let candidate: MKSubscriptionSignal
            switch status.state {
            case .subscribed:
                candidate = .subscribed(renewalInfo: renewalInfo)
            case .inGracePeriod:
                candidate = .inGracePeriod(until: renewal.gracePeriodExpirationDate)
            case .inBillingRetryPeriod:
                candidate = .inBillingRetry
            case .expired, .revoked:
                candidate = .expired
            default:
                candidate = .expired
            }
            best = Self.higherPrecedenceSignal(best, candidate)
        }
        return best
    }

    private static func signalRank(_ signal: MKSubscriptionSignal) -> Int {
        switch signal {
        case .subscribed: return 0
        case .inGracePeriod: return 1
        case .inBillingRetry: return 2
        case .expired: return 3
        case .none: return 4
        }
    }

    private static func higherPrecedenceSignal(_ a: MKSubscriptionSignal, _ b: MKSubscriptionSignal) -> MKSubscriptionSignal {
        signalRank(b) < signalRank(a) ? b : a
    }

    // MARK: - Broadcast (T5 scope: "Entitlement change broadcasting")

    /// A push channel of every resolved state (deduplicated ، only
    /// broadcasts on actual change, `applySnapshot` above). Composition
    /// root wires this into `MKFontLockController.observe(_:)`,
    /// `MKPaywallStateMachine`, and any other subscriber (WS-08/09/11's
    /// consumers all take an externally-supplied stream, per those
    /// modules' own seams ، this resolver never imports them, D-230).
    public func states() -> AsyncStream<MKEntitlementState> {
        let id = UUID()
        let initial = state
        return AsyncStream { continuation in
            continuation.yield(initial)
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    // MARK: - Transaction listener (T4)

    /// Starts the long-lived `Transaction.updates` listener (renewals,
    /// revocations, Ask-to-Buy completions, Family Sharing revocation).
    /// Idempotent ، a second call is a no-op while one is already running.
    /// Revocation-mid-export (D-228): this listener re-resolves and
    /// broadcasts on every update, but never reaches into `MKExport` to
    /// cancel anything in flight ، an in-flight export simply keeps
    /// reading whatever `state` snapshot it captured when it started; the
    /// NEXT export call reads the now-updated snapshot. That "don't reach
    /// into other subsystems" behavior is structural here (this actor has
    /// no reference to `MKExport` at all, D-230), not a special case.
    public func startTransactionListener() {
        guard listenerTask == nil else { return }
        listenerTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let transaction = try? checkVerified(update) {
                    await transaction.finish()
                }
                await self.resolve()
            }
        }
    }

    public func stopTransactionListener() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    deinit {
        listenerTask?.cancel()
    }
}
