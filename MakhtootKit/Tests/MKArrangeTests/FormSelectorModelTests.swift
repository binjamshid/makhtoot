import Testing
import MKArrange
import MKFoundation
import MKModel

/// WS-04 packet §5 task 8. Geeza Pro (D-107 harvest fixture convention).
@Suite struct FormSelectorModelTests {
    @Test func hahListsFourValidDistinctOptions() async {
        // "لا" would not contain ح ، use a standalone حرف fixture: derive
        // just "ح" so there's exactly one glyph node to build the model for.
        let text = "ح"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard case .glyph(let node)? = composition.nodes.first else {
            Issue.record("expected a single ح glyph node")
            return
        }

        let model = await FormSelectorModel.build(for: node.id, in: composition, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard let model else {
            Issue.record("expected a form selector model for ح")
            return
        }
        #expect(model.options.count == 4)
        #expect(model.options.allSatisfy { $0.isValid }, "ح is dual-joining ، all four forms are valid")
        let glyphIDs = Set(model.options.map(\.glyphID))
        #expect(glyphIDs.count == 4, "Geeza Pro must distinguish all four contextual forms")
    }

    @Test func dalOffersOnlyIsolatedAndFinal() async {
        let text = "د"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard case .glyph(let node)? = composition.nodes.first else {
            Issue.record("expected a single د glyph node")
            return
        }

        let model = await FormSelectorModel.build(for: node.id, in: composition, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard let model else {
            Issue.record("expected a form selector model for د")
            return
        }
        let validForms = Set(model.options.filter(\.isValid).map(\.form))
        #expect(validForms == [.isolated, .final], "right-joining د exposes exactly isolated+final")
    }

    @Test func selectingAFormEmitsAnUndoableCommand() async throws {
        let text = "ح"
        let style = ArrangeFixtures.geezaStyle()
        let composition = await ArrangeFixtures.derive(text, style: style, fonts: ArrangeFixtures.geezaFonts)
        guard case .glyph(let node)? = composition.nodes.first else {
            Issue.record("expected a single ح glyph node")
            return
        }
        guard let model = await FormSelectorModel.build(for: node.id, in: composition, style: style, fonts: ArrangeFixtures.geezaFonts) else {
            Issue.record("expected a model")
            return
        }
        let ownerNode = MKArrangedTextNode(core: MKNodeCore(name: "نص"), composition: composition, derivedFrom: .liveText)
        guard let command = model.command(selecting: .final, ownerNode: ownerNode) else {
            Issue.record("expected a command for a valid form selection")
            return
        }
        #expect(command.name.isEmpty == false)
    }
}
