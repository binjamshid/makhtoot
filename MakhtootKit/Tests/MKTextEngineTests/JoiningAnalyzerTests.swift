import Testing
import MKModel
@testable import MKTextEngine

/// WS-03 packet §5 task 10 accept criteria + T-TXT-6 form metadata.
@Suite struct JoiningAnalyzerTests {

    private func forms(_ text: String) -> [MKJoiningForm] {
        MKJoiningAnalyzer.analyze(text: text).map(\.state.form)
    }

    @Test func muhammadFormsAreInitialMedialMedialFinal() {
        // Packet: "محمد": م initial, ح medial, م medial, د final.
        #expect(forms("محمد") == [.initial, .medial, .medial, .final])
    }

    @Test func marksDoNotAlterJoiningForms() {
        // Packet: marks in "مُحَمَّد" do not alter the forms (transparent).
        #expect(forms("مُحَمَّد") == forms("محمد"))
    }

    @Test func rightJoiningLetterBreaksTheChain() {
        // Packet: "درس" ، د is right-joining, so ر after د starts a new
        // joining region. د has nothing before it → isolated; ر cannot
        // take from د (R is not join-transmitting leftward) → isolated;
        // س after ر likewise → isolated.
        #expect(forms("درس") == [.isolated, .isolated, .isolated])
        // Contrast: "بدر" ، ب (dual) before د makes د final.
        #expect(forms("بدر") == [.initial, .final, .isolated])
    }

    @Test func tatweelIsJoinCausingContext() {
        // Packet §6 kashida note: "مـحـمـد" ، tatweel keeps م initial
        // before it; letters join *through* tatweel.
        #expect(forms(Fixtures.kashidaChain) == [.initial, .medial, .medial, .final])
    }

    @Test func zwnjBreaksJoining() {
        // §6: "می" joins; "م‌ی" (ZWNJ) breaks.
        #expect(forms(Fixtures.zwnjJoined) == [.initial, .final])
        #expect(forms(Fixtures.zwnjBroken) == [.isolated, .isolated])
    }

    @Test func zwjExtendsJoining() {
        // ZWJ after a lone م forces its initial form (the D-107 harvest
        // context depends on exactly this).
        #expect(forms("م\u{200D}") == [.initial])
        #expect(forms("\u{200D}م\u{200D}") == [.medial])
        #expect(forms("\u{200D}م") == [.final])
    }

    @Test func joinsFlagsAreConsistentWithForms() {
        for letter in MKJoiningAnalyzer.analyze(text: "محمد") {
            switch letter.state.form {
            case .isolated:
                #expect(!letter.state.joinsPrevious && !letter.state.joinsNext)
            case .initial:
                #expect(!letter.state.joinsPrevious && letter.state.joinsNext)
            case .medial:
                #expect(letter.state.joinsPrevious && letter.state.joinsNext)
            case .final:
                #expect(letter.state.joinsPrevious && !letter.state.joinsNext)
            }
            #expect(letter.state.brokenByUser == false)
        }
    }

    // MARK: - T-TXT-6: non-joining (right-joining) letters expose two forms

    @Test(arguments: ["ا", "د", "ذ", "ر", "ز", "و"])
    func rightJoiningLettersExposeOnlyIsolatedAndFinal(letter: String) {
        let scalar = letter.unicodeScalars.first!
        #expect(MKJoiningTypeTable.joiningType(of: scalar) == .rightJoining)
        #expect(MKJoiningTypeTable.validForms(for: scalar) == [.isolated, .final])
    }

    @Test(arguments: ["ب", "ح", "س", "ص", "ط", "ع", "ك", "ل", "م", "ن", "ه", "ي"])
    func dualJoiningLettersExposeAllFourForms(letter: String) {
        let scalar = letter.unicodeScalars.first!
        #expect(MKJoiningTypeTable.joiningType(of: scalar) == .dual)
        #expect(MKJoiningTypeTable.validForms(for: scalar) == [.isolated, .initial, .medial, .final])
    }

    @Test func hamzaIsNonJoining() {
        let hamza = Unicode.Scalar(0x0621)!
        #expect(MKJoiningTypeTable.joiningType(of: hamza) == .nonJoining)
        #expect(MKJoiningTypeTable.validForms(for: hamza) == [.isolated])
    }

    @Test func marksAreTransparentInTheTable() {
        #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(0x064E)!) == .transparent)   // fatha
        #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(0x0670)!) == .transparent)   // superscript alef
    }
}
