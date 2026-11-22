import Testing
import MKArrange

/// WS-04 packet §5 task 15.
@Suite struct ArrangeInvariantsTests {
    @Test func reshapeAttemptOnArrangedNodeThrows() {
        #expect(throws: MKArrangeError.self) {
            try MKArrangeInvariants.assertReshapeAllowed(on: .arranged)
        }
    }

    @Test func reshapeIsAllowedOnLiveOrPathNodes() throws {
        try MKArrangeInvariants.assertReshapeAllowed(on: .liveOrPath)   // must not throw
    }
}
