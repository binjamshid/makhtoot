import Testing
@testable import MKFonts

/// T8 AC: "نسخ" returns all naskh-category fonts; "amiri"/"أميري" both
/// return Amiri; empty query returns full catalog ordered by category then
/// name.
@Suite("MKFontSearchIndex ، T8")
struct MKFontSearchIndexTests {
    private let fixtures: [MKFontSearchIndex.Entry] = [
        .init(fontID: "amiri", familyName: "Amiri", familyNameArabic: "أميري", tags: ["كلاسيكي"], categories: [.naskh, .quranicStyle], isFavorite: false),
        .init(fontID: "noto-naskh-arabic", familyName: "Noto Naskh Arabic", familyNameArabic: nil, tags: [], categories: [.naskh], isFavorite: true),
        .init(fontID: "reem-kufi", familyName: "Reem Kufi", familyNameArabic: nil, tags: ["هندسي"], categories: [.kufi], isFavorite: false),
    ]

    @Test func naskhQueryReturnsAllNaskhFonts() {
        let ids = MKFontSearchIndex().search("نسخ", in: fixtures)
        #expect(Set(ids) == ["amiri", "noto-naskh-arabic"])
    }

    @Test func latinAndArabicSpellingBothFindAmiri() {
        let latin = MKFontSearchIndex().search("amiri", in: fixtures)
        let arabic = MKFontSearchIndex().search("أميري", in: fixtures)
        #expect(latin.first == "amiri")
        #expect(arabic.first == "amiri")
    }

    @Test func emptyQueryReturnsFullCatalogOrderedByCategoryThenName() {
        let ids = MKFontSearchIndex().search("", in: fixtures)
        #expect(ids.count == fixtures.count)
        // "kufi" < "naskh" alphabetically by raw value, category-first ordering.
        #expect(ids.first == "reem-kufi")
    }

    @Test func favoritesAreBoosted() {
        // Both "noto-naskh-arabic" (favorite) and "amiri" match "نسخ"; the
        // favorite should rank first despite equal textual match quality.
        let ids = MKFontSearchIndex().search("نسخ", in: fixtures)
        #expect(ids.first == "noto-naskh-arabic")
    }

    @Test func normalizeStripsTashkeelAndUnifiesAlef() {
        #expect(MKFontSearchIndex.normalize("أَمِيري") == MKFontSearchIndex.normalize("اميري"))
        #expect(MKFontSearchIndex.normalize("إميري") == MKFontSearchIndex.normalize("اميري"))
    }
}
