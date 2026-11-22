import Foundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 16 accept criterion, AS AMENDED (see
/// `SearchNormalizer.swift`'s top-of-file note): search text extraction is
/// titles + layer names only, per the locked D-112 amendment quoted by this
/// run's own orchestrator instructions ، NOT scene text content, despite
/// the packet's task-16 prose literally asking for content extraction.
/// This suite tests the LOCKED behavior and explicitly proves scene text
/// content is excluded.
@Suite("SearchNormalizer / SearchTextExtractor")
struct SearchNormalizerTests {
    @Test func normalizationStripsTashkeelAndUnifiesHamzaVariants() {
        #expect(SearchNormalizer.normalize("مَخْطُوطٌ") == SearchNormalizer.normalize("مخطوط"))
        #expect(SearchNormalizer.normalize("أحمد") == SearchNormalizer.normalize("احمد"))
        #expect(SearchNormalizer.normalize("مصطفى") == SearchNormalizer.normalize("مصطفي"))
    }

    @Test func matchesHelperFindsNormalizedSubstring() {
        #expect(SearchNormalizer.matches(query: "مخطوط", in: "مَخْطُوطٌ"))
        #expect(SearchNormalizer.matches(query: "علي", in: "على الطريق"))
        #expect(SearchNormalizer.matches(query: "غير موجود", in: "مخطوط") == false)
    }

    @Test func extractedSearchTextIncludesTitleAndLayerNamesOnly() {
        let core = MKNodeCore(name: "طبقة الخط الحي")
        let text = MKSourceText(string: "نص لا يجب أن يظهر في الفهرس") // must NOT appear in the index
        let node = MKNode.liveText(MKLiveTextNode(core: core, text: text))
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10)), nodes: [node])

        let searchText = SearchTextExtractor.extract(scene: scene, title: "عنوان المشروع")

        #expect(SearchNormalizer.matches(query: "عنوان المشروع", in: searchText)) // title included
        #expect(SearchNormalizer.matches(query: "طبقة الخط الحي", in: searchText)) // layer name included
        #expect(searchText.contains(SearchNormalizer.normalize("نص لا يجب")) == false) // scene TEXT CONTENT excluded (D-112 amended)
    }

    @Test func extractionRecursesIntoGroupChildNames() {
        let childCore = MKNodeCore(name: "طبقة فرعية")
        let child = MKNode.shape(MKShapeNode(core: childCore, geometry: .ellipse))
        let group = MKNode.group(MKGroupNode(core: MKNodeCore(name: "مجموعة"), children: [child]))
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10)), nodes: [group])

        let searchText = SearchTextExtractor.extract(scene: scene, title: "ت")
        #expect(SearchNormalizer.matches(query: "طبقة فرعية", in: searchText))
    }
}
