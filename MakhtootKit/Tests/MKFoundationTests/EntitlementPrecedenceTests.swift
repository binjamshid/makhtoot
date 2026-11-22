import Testing
@testable import MKFoundation

/// WS-01 packet §5 task 10 accept criterion: precedence ordering
/// lifetime > subscribed > inGracePeriod > inBillingRetry > trial > free
/// (D-113).
@Suite("MKEntitlementState precedence")
struct EntitlementPrecedenceTests {
    @Test func fullPrecedenceChainOutranksInOrder() {
        let ordered: [MKEntitlementState] = [
            .lifetime,
            .subscribed,
            .inGracePeriod,
            .inBillingRetry,
            .trial(daysLeft: 3),
            .free,
        ]
        for i in 0..<(ordered.count - 1) {
            #expect(ordered[i].outranks(ordered[i + 1]))
            #expect(!ordered[i + 1].outranks(ordered[i]))
        }
    }

    @Test func highestPrecedencePicksTheHigherRankRegardlessOfArgumentOrder() {
        #expect(MKEntitlementState.highestPrecedence(.free, .lifetime) == .lifetime)
        #expect(MKEntitlementState.highestPrecedence(.lifetime, .free) == .lifetime)
        #expect(MKEntitlementState.highestPrecedence(.inGracePeriod, .inBillingRetry) == .inGracePeriod)
    }

    @Test func gracePeriodAndBillingRetryGrantPremiumAccess() {
        #expect(MKEntitlementState.inGracePeriod.grantsPremiumAccess)
        #expect(MKEntitlementState.inBillingRetry.grantsPremiumAccess)
        #expect(MKEntitlementState.trial(daysLeft: 1).grantsPremiumAccess)
    }

    @Test func freeDoesNotGrantPremiumAccess() {
        #expect(!MKEntitlementState.free.grantsPremiumAccess)
    }

    @Test func stubEntitlementResolverAlwaysReturnsLifetime() {
        let resolver = StubEntitlementResolver()
        #expect(resolver.state == .lifetime)
        for capability in MKPremiumCapability.allCases {
            #expect(resolver.isEntitled(capability))
        }
    }
}
