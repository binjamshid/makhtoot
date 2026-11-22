import CoreGraphics
import CoreText
import Foundation
import MKDesignSystem
import MKFonts
import MKFoundation
import MKModel
import MKPathText
import MKTextEngine
import SwiftUI

/// DEBUG Path Text harness (WS-05 gap 1 / packet task 14's deliverable ،
/// see `docs/impl-log` for the WS-05 log's own "harness view deferred to
/// WS-06/13" note). The Path-Text twin of `ShapingHarnessView`'s role ،
/// same file-header framing, same DEBUG-only Settings-reachable placement
/// ، but drives `MKPathText` (`BezierPathModel`/`ArcLengthLUT`/
/// `PathLayoutEngine`) DIRECTLY, with no `MKCanvas`/`CanvasSession`
/// involved at all (this is a pure engine inspector, not a canvas-editing
/// surface ، that's `PathEditToolbarView`/`PathOptionsPopoverView`'s job).
///
/// Renders REAL glyph outlines (`CTFontCreatePathForGlyph`), not
/// presentation-form placeholder text, so the T-AR-46..50 Arabic-letterform
/// evidence this harness exists to produce is genuine ، the same
/// "resolved glyphs, never Unicode presentation-form text" bar
/// `FormSelectorPopoverView`'s own doc comment holds itself to for its
/// preview tiles.
struct PathTextHarnessView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container

    enum PathFixture: String, CaseIterable, Identifiable {
        case circle, arc, wave, sCurve
        var id: String { rawValue }
    }

    /// The five packet-mandated T-AR-46..50 one-tap fixtures, in this
    /// exact order so a launch-arg fixture INDEX (`-mkPathHarnessFixture`)
    /// can address them positionally for the automated evidence pass.
    static let presetStrings = [
        "الخط العربي جميل",
        "حِبْرٌ وَوَرَقٌ وَقَلَمٌ",
        "سلام Hello ٤٥",
        "الرقم٤٥",
        "مخطوط",
    ]

    @State private var inputText: String
    @State private var pathFixture: PathFixture
    @State private var side: MKPathSide = .above
    @State private var insideOut = false
    @State private var startOffset: Double = 0
    @State private var previewScale: CGFloat = 1
    @State private var availableFonts: [MKFontRecord] = []
    @State private var selectedFontID: MKFontID = "amiri"
    @State private var shapedLine: MKShapedLine?
    @State private var layoutResult: PathLayoutResult?
    @State private var currentPathModel: BezierPathModel = .circle(center: .zero, radius: 140)

    private let engine = MKShapingEngine(fonts: MKRegistryFontProvider())
    private let fontProvider = MKRegistryFontProvider()

    /// `initialFixtureIndex`/`initialPathFixture`: the DEBUG launch-arg
    /// direct-entry hook (`-mkPathHarnessFixture`/`-mkPathHarnessPath`,
    /// wired in `RootShellView`) needs to pre-select a fixture/path BEFORE
    /// the first frame renders ، `@State` values are only settable this
    /// way from a custom `init`, per the standard SwiftUI pattern.
    init(initialFixtureIndex: Int = 2, initialPathFixture: PathFixture = .circle) {
        let index = (0..<Self.presetStrings.count).contains(initialFixtureIndex) ? initialFixtureIndex : 2
        _inputText = State(initialValue: Self.presetStrings[index])
        _pathFixture = State(initialValue: initialPathFixture)
    }

    var body: some View {
        Form {
            // Preview FIRST, not last: this harness's own screenshot-
            // evidence gate (T-AR-46..50) is captured via
            // `xcrun simctl io screenshot` with NO interactive scrolling
            // available in this environment (confirmed ، see
            // `EditorViewModel.debugRunE2EArrangeSequence`'s own header for
            // the established "no tap/scroll injection at all" finding
            // this restates) ، a `Form` tall enough to need scrolling
            // before the preview canvas comes into view would make the
            // evidence gate impossible to satisfy externally. Leading with
            // the preview guarantees every launch-arg-driven screenshot
            // shows real glyph outlines above the fold, regardless of
            // simulator/device height.
            Section(previewSectionTitle) {
                Canvas { context, size in
                    draw(into: context, size: size)
                }
                .frame(height: 380)
                .background(theme.bg, in: RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))

                if let layoutResult {
                    metricRow(label: glyphCountLabel, value: "\(layoutResult.placements.count)")
                    metricRow(label: curvatureWarningLabel, value: layoutResult.curvatureWarning ? warningYesLabel : warningNoLabel)
                    metricRow(label: overflowLabel, value: layoutResult.overflow.isOverflowing ? overflowYesLabel : overflowNoLabel)
                }
            }

            Section(inputSectionTitle) {
                TextField(inputPlaceholder, text: $inputText, axis: .vertical)
                    .lineLimit(1...3)
                    .multilineTextAlignment(.trailing)
                Picker(fixtureLabel, selection: $inputText) {
                    ForEach(Self.presetStrings, id: \.self) { fixture in
                        Text(fixture).tag(fixture)
                    }
                }
                if !availableFonts.isEmpty {
                    Picker(fontPickerLabel, selection: $selectedFontID) {
                        ForEach(availableFonts, id: \.fontID) { record in
                            Text(record.familyName).tag(record.fontID)
                        }
                    }
                }
            }

            Section(pathSectionTitle) {
                Picker(pathFixtureLabel, selection: $pathFixture) {
                    Text(circleLabel).tag(PathFixture.circle)
                    Text(arcLabel).tag(PathFixture.arc)
                    Text(waveLabel).tag(PathFixture.wave)
                    Text(sCurveLabel).tag(PathFixture.sCurve)
                }
                .pickerStyle(.segmented)

                Picker(sideLabel, selection: $side) {
                    Text(aboveLabel).tag(MKPathSide.above)
                    Text(belowLabel).tag(MKPathSide.below)
                    Text(centerLabel).tag(MKPathSide.center)
                }
                .pickerStyle(.segmented)

                Toggle(insideOutLabel, isOn: $insideOut)

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("\(startOffsetLabel): \(String(format: "%.2f", startOffset))")
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                    Slider(value: $startOffset, in: 0...1)
                }

                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("\(scaleLabel): \(String(format: "%.1f×", previewScale))")
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .foregroundStyle(theme.inkMuted)
                    Slider(value: $previewScale, in: 0.5...3)
                }
            }
        }
        .navigationTitle(Text(navTitle))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            for _ in 0..<20 {
                let records = await container.fontRegistry.records()
                if !records.isEmpty {
                    availableFonts = records
                    if !records.contains(where: { $0.fontID == selectedFontID }) {
                        selectedFontID = records.first?.fontID ?? selectedFontID
                    }
                    break
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            relayout()
        }
        .onChange(of: inputText) { _, _ in relayout() }
        .onChange(of: pathFixture) { _, _ in relayout() }
        .onChange(of: side) { _, _ in relayout() }
        .onChange(of: insideOut) { _, _ in relayout() }
        .onChange(of: startOffset) { _, _ in relayout() }
        .onChange(of: selectedFontID) { _, _ in relayout() }
    }

    // MARK: - Layout

    private func currentStyle() -> MKTextStyle {
        if let face = availableFonts.first(where: { $0.fontID == selectedFontID })?.faces.first {
            return MKTextStyle(font: MKFontRef(fontID: selectedFontID, postScriptName: face.postScriptName), pointSize: 32)
        }
        return .default
    }

    private func buildPathModel() -> BezierPathModel {
        switch pathFixture {
        case .circle:
            return .circle(center: .zero, radius: 140)
        case .arc:
            return .arc(center: .zero, radius: 150, startAngle: .pi, endAngle: 0)
        case .wave:
            return .wave(rect: CGRect(x: -170, y: -40, width: 340, height: 80), periods: 3, amplitude: 34)
        case .sCurve:
            // "منحنى-S" (S-curve): no `BezierPathModel` preset covers this
            // shape ، a hand-built 3-anchor open curve with opposing
            // curvature in each half, own design choice for T-AR-47's
            // "tightest curvature visible" evidence fixture (the sharpest
            // continuous direction change any preset here produces).
            let anchors = [
                PathAnchor(point: CGPoint(x: -170, y: 90), handleOut: CGPoint(x: -60, y: 90)),
                PathAnchor(point: CGPoint(x: 0, y: 0), handleIn: CGPoint(x: -70, y: -10), handleOut: CGPoint(x: 70, y: 10)),
                PathAnchor(point: CGPoint(x: 170, y: -90), handleIn: CGPoint(x: 60, y: -90)),
            ]
            return BezierPathModel(anchors: anchors, isClosed: false)
        }
    }

    private func relayout() {
        guard !inputText.isEmpty else {
            shapedLine = nil
            layoutResult = nil
            return
        }
        let request = MKShapingRequest(string: inputText, style: currentStyle(), frame: .singleLine)
        let line = engine.shapeSingleLine(request)
        shapedLine = line

        let model = buildPathModel()
        currentPathModel = model
        let options = PathLayoutOptions(startOffset: startOffset, side: side, insideOut: insideOut)
        if model.isClosed {
            let lut = ArcLengthLUT(path: model)
            layoutResult = PathLayoutEngine.layoutClosed(line: line, lut: lut, options: options)
        } else {
            layoutResult = PathLayoutEngine.layout(line: line, path: model, options: options)
        }
    }

    // MARK: - Drawing

    /// Centers the harness's own local (path-authoring) coordinate space
    /// in the `Canvas` view and draws: the path itself as a dashed guide,
    /// small dots at each placement's arc anchor, and ، the evidence this
    /// harness exists to produce ، REAL glyph outlines
    /// (`CTFontCreatePathForGlyph`) positioned/rotated per placement,
    /// mirroring `PathTextDrawer.draw(_:into:...)`'s own placement math
    /// (position, rotation, then the CoreText-native y-up→y-down glyph
    /// flip that drawer's own doc comment explains) but building a SwiftUI
    /// `Path` instead of calling `CTFontDrawGlyphs` directly, since a
    /// `GraphicsContext` fill is the idiomatic way to paint a `CGPath` in
    /// a SwiftUI `Canvas`.
    private func draw(into context: GraphicsContext, size: CGSize) {
        var context = context
        context.transform = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .concatenating(CGAffineTransform(scaleX: previewScale, y: previewScale))

        let guidePath = Path(currentPathModel.cgPath())
        context.stroke(guidePath, with: .color(theme.inkMuted.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5 / previewScale, dash: [6 / previewScale, 4 / previewScale]))

        guard let layoutResult, let shapedLine else { return }

        for placement in layoutResult.placements {
            let run = shapedLine.runs[placement.address.run]
            let handle = MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize)
            let ctFont = fontProvider.resolve(handle)
            let glyph = run.glyphs[placement.address.glyph]
            let x = placement.position.x + placement.userOffset.x
            let y = placement.position.y + placement.userOffset.y
            let rotation = placement.rotation + placement.userRotation

            if let glyphCGPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
                var transform = CGAffineTransform(translationX: x, y: y)
                transform = transform.rotated(by: rotation)
                transform = transform.scaledBy(x: 1, y: -1)   // CoreText y-up glyph space → this view's y-down space
                if let transformedGlyph = glyphCGPath.copy(using: &transform) {
                    context.fill(Path(transformedGlyph), with: .color(theme.ink))
                }
            }

            let dotRadius: CGFloat = 2.5 / previewScale
            let dot = Path(ellipseIn: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            context.fill(dot, with: .color(theme.destructive.opacity(0.8)))
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Text(value)
                .foregroundStyle(theme.ink)
        }
    }

    // MARK: - Strings

    private var navTitle: String {
        // Latin gloss: path-text harness
        "مختبر النص على مسار"
    }
    private var inputSectionTitle: String {
        // Latin gloss: input text
        "النص المُدخل"
    }
    private var inputPlaceholder: String {
        // Latin gloss: type Arabic text here
        "اكتب نصًا عربيًا هنا"
    }
    private var fixtureLabel: String {
        // Latin gloss: sample fixtures
        "نصوص جاهزة"
    }
    private var fontPickerLabel: String {
        // Latin gloss: font
        "الخط"
    }
    private var pathSectionTitle: String {
        // Latin gloss: path
        "المسار"
    }
    private var pathFixtureLabel: String {
        // Latin gloss: path shape
        "شكل المسار"
    }
    private var circleLabel: String {
        // Latin gloss: circle
        "دائرة"
    }
    private var arcLabel: String {
        // Latin gloss: arc
        "قوس"
    }
    private var waveLabel: String {
        // Latin gloss: wave
        "موجة"
    }
    private var sCurveLabel: String {
        // Latin gloss: S-curve
        "منحنى-S"
    }
    private var sideLabel: String {
        // Latin gloss: side
        "الجانب"
    }
    private var aboveLabel: String {
        // Latin gloss: above
        "فوق"
    }
    private var belowLabel: String {
        // Latin gloss: below
        "تحت"
    }
    private var centerLabel: String {
        // Latin gloss: center
        "وسط"
    }
    private var insideOutLabel: String {
        // Latin gloss: inside-out
        "من الداخل للخارج"
    }
    private var startOffsetLabel: String {
        // Latin gloss: start offset
        "إزاحة البداية"
    }
    private var scaleLabel: String {
        // Latin gloss: preview scale
        "تكبير المعاينة"
    }
    private var previewSectionTitle: String {
        // Latin gloss: preview
        "المعاينة"
    }
    private var glyphCountLabel: String {
        // Latin gloss: placed glyph count
        "عدد الحروف الموضوعة"
    }
    private var curvatureWarningLabel: String {
        // Latin gloss: curvature warning
        "تنبيه الانحناء"
    }
    private var warningYesLabel: String { "نعم" }
    private var warningNoLabel: String { "لا" }
    private var overflowLabel: String {
        // Latin gloss: overflow
        "تجاوز الطول"
    }
    private var overflowYesLabel: String { "نعم" }
    private var overflowNoLabel: String { "لا" }
}

#Preview {
    NavigationStack {
        PathTextHarnessView()
    }
    .environment(\.mkTheme, HibrTheme.default)
}
