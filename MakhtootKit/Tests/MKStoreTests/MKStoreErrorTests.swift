import Foundation
import Testing
@testable import MKStore

@Suite("MKStoreError ، T13")
struct MKStoreErrorTests {
    @Test(arguments: [
        MKStoreError.failedVerification,
        .purchaseFailed(underlying: "x"),
        .catalogUnavailable,
        .restoreFailed(underlying: "x"),
        .pendingApproval,
        .networkRequired,
    ])
    func everyCaseHasANonEmptyArabicDescription(error: MKStoreError) {
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func catalogUnavailableIsExactCanonicalDF7String() {
        #expect(MKStoreError.catalogUnavailable.errorDescription == "يتطلب الاتصال بالإنترنت")
    }

    @Test func pendingApprovalMatchesAskToBuyCopy() {
        #expect(MKStoreError.pendingApproval.errorDescription == "بانتظار موافقة العائلة")
    }
}
