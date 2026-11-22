#if DEBUG
import Foundation
import MKFoundation

/// Preset entitlement scenarios (packet §3: "ship `SandboxScenarioStub`
/// presets... for UI previews and TEST_MATRIX runs"). `#if DEBUG`-gated
/// per D-229(3) ، a Release build can never reference this, so it can
/// never end up wired into production composition roots by accident.
public struct MKSandboxScenarioStub: MKEntitlementProviding {
    public enum Scenario: String, CaseIterable, Sendable {
        case free
        case trialDay3
        case expired
        case grace
        case billingRetry
        case lifetime
    }

    public let scenario: Scenario

    public init(_ scenario: Scenario) {
        self.scenario = scenario
    }

    public var state: MKEntitlementState {
        switch scenario {
        case .free: return .free
        case .trialDay3: return .trial(daysLeft: 3)
        // "Expired" is not its own MKEntitlementState case (D-113: an
        // expired trial resolves straight to `.free`) ، this preset exists
        // so previews/tests can label the free-tier-because-trial-ended
        // path distinctly from a user who was never in a trial at all,
        // even though both resolve to the same `.free` state.
        case .expired: return .free
        case .grace: return .inGracePeriod
        case .billingRetry: return .inBillingRetry
        case .lifetime: return .lifetime
        }
    }
}

/// A general-purpose, mutable test double for `MKEntitlementProviding`
/// (packet §8 deliverable "`TestEntitlementStub`" ، the app-composition-
/// root-facing counterpart of `MKSandboxScenarioStub` above, for tests
/// that need to change state mid-test rather than pick one fixed preset).
/// `#if DEBUG`-gated for the same D-229(3) reason.
public final class TestEntitlementStub: MKEntitlementProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _state: MKEntitlementState

    public init(_ state: MKEntitlementState = .free) {
        self._state = state
    }

    public var state: MKEntitlementState {
        get {
            lock.lock(); defer { lock.unlock() }
            return _state
        }
        set {
            lock.lock()
            _state = newValue
            lock.unlock()
        }
    }
}
#endif
