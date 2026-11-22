import Testing
import CoreGraphics
import MKModel
@testable import MKTextEngine

/// T-TXT-4 (TEST_MATRIX.md §5) + WS-03 packet §5 task 8: mark
/// classification (Mn/Me incl. Qur'anic subranges) and base-attachment
/// capture.
@Suite struct MarkAttachmentTests {

    // MARK: - Fatha above / kasra below (relative offset sign)

    @Test func fathaAttachesAboveBase() {
        let line = Fixtures.shape("بَ")
        let attachments = MKMarkAttacher.attachments(in: line)
        #expect(attachments.count == 1)
        let attachment = attachments.first
        #expect(attachment?.markClass == .tashkeel)
        #expect(attachment?.baseClusterIndex != nil)
        if let offset = attachment?.relativeOffset {
            #expect(offset.height > 0, "fatha must sit above the base in Core Text's y-up space")
        } else {
            Issue.record("fatha in «بَ» should have a distinct glyph and a measurable offset")
        }
    }

    @Test func kasraAttachesBelowBase() {
        let line = Fixtures.shape("بِ")
        let attachments = MKMarkAttacher.attachments(in: line)
        #expect(attachments.count == 1)
        if let offset = attachments.first?.relativeOffset {
            #expect(offset.height < 0, "kasra must sit below the base in Core Text's y-up space")
        } else {
            Issue.record("kasra in «بِ» should have a distinct glyph and a measurable offset")
        }
    }

    // MARK: - Mark attachment counts

    @Test func muhammadTashkeelStackResolvesFiveMarksAllWithABase() {
        // مُحَمَّدٌ: damma, fatha, shadda, fatha, tanwin ، 5 diacritics.
        let line = Fixtures.shape(Fixtures.muhammadTashkeel)
        let attachments = MKMarkAttacher.attachments(in: line)
        #expect(attachments.count == 5)
        #expect(attachments.allSatisfy { $0.baseClusterIndex != nil }, "D-105: no mark may be orphaned")
    }

    @Test func shaddaStackResolvesFourMarksAllWithABase() {
        // شَدَّةٌ: ش+fatha, د+shadda(fused by this font), +fatha, ة+tanwin ، 4 marks.
        let line = Fixtures.shape(Fixtures.shaddaStack)
        let attachments = MKMarkAttacher.attachments(in: line)
        #expect(attachments.count == 4)
        #expect(attachments.allSatisfy { $0.baseClusterIndex != nil })
    }

    // MARK: - Qur'anic annotation range + wasla-is-a-letter

    @Test func quranicAnnotationSubrangeClassifiesAsQuranicMark() {
        // U+06E1 (small high rounded zero) sits in the packet's Qur'anic
        // annotation subrange (0x06D6–0x06ED).
        let line = Fixtures.shape(Fixtures.bismillahWasla)
        let attachments = MKMarkAttacher.attachments(in: line)
        #expect(attachments.contains { $0.markClass == .quranicAnnotation })
    }

    @Test func waslaIsALetterNotAMark() {
        // U+0671 ARABIC LETTER ALEF WASLA must never be classified as a mark.
        #expect(MKMarkClassifier.isMark(Unicode.Scalar(0x0671)!) == false)
    }

    @Test func spacingQuranicSignsAreNotMarks() {
        // T-TXT-4: "spacing Qur'anic signs (e.g. ۞ U+06DE, ۩ U+06E9) are
        // classified as base glyphs, not marks."
        #expect(MKMarkClassifier.isMark(Unicode.Scalar(0x06DE)!) == false)
        #expect(MKMarkClassifier.isMark(Unicode.Scalar(0x06E9)!) == false)
        // U+06DD ARABIC END OF AYAH is a formatting control, not a mark either.
        #expect(MKMarkClassifier.isMark(Unicode.Scalar(0x06DD)!) == false)
    }

    // MARK: - Free marks (no preceding base at all)

    @Test func standaloneMarkIsAFreeMark() {
        let line = Fixtures.shape(Fixtures.standaloneFathatan)
        let attachments = MKMarkAttacher.attachments(in: line)
        #expect(attachments.count == 1)
        #expect(attachments.first?.baseClusterIndex == nil, "a lone mark with nothing preceding it has no base to attach to")
    }

    // MARK: - Honorific / harakat range coverage (D-105 explicit ranges)

    @Test(arguments: [
        UInt32(0x0610), UInt32(0x061A),   // honorifics range endpoints
        UInt32(0x064B), UInt32(0x065F),   // harakat block endpoints
        UInt32(0x0670),                   // superscript alef
        UInt32(0x06D6), UInt32(0x06ED),   // Qur'anic annotation range endpoints
    ])
    func explicitD105RangeEndpointsClassifyAsMarks(codepoint: UInt32) {
        guard let scalar = Unicode.Scalar(codepoint) else {
            Issue.record("U+\(String(codepoint, radix: 16)) is not a valid scalar")
            return
        }
        #expect(MKMarkClassifier.isMark(scalar))
    }

    // MARK: - MKModel handoff type checks (P3-completion)

    @Test func classifierEmitsMKModelMarkClassValues() {
        // The classifier's output type IS MKModel.MKMarkClass ، the value
        // MKMarkNode.markClass stores; spot-check each class.
        #expect(MKMarkClassifier.classify(Unicode.Scalar(0x064E)!) == MKMarkClass.tashkeel)          // fatha
        #expect(MKMarkClassifier.classify(Unicode.Scalar(0x06E1)!) == MKMarkClass.quranicAnnotation) // small high sukun
        #expect(MKMarkClassifier.classify(Unicode.Scalar(0x0300)!) == MKMarkClass.otherCombining)    // combining grave
    }
}
