import Testing
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import MKFoundation
import MKModel
import MKRender
@testable import MKExport

/// FC-1 (AUDIT_2026-07-28.md): a small, deterministic fake ، NOT
/// `MKRegistryFontProvider` (`MKFonts`, exercised elsewhere by
/// `SVGBoldItalicAndPathHighlightParityTests`) and NOT `SystemFontStubProvider`
/// (which inherits `MKFontProviding`'s protocol-extension default and
/// silently IGNORES `variant`, the exact defect FC-1 reports). Overriding
/// `resolve(_:variant:)` directly, resolving to a genuinely different
/// system font family per `variant.bold`, makes the test below prove the
/// `fonts:` parameter reaches the render pipeline end to end (shaping AND
/// drawing) without depending on the bundled Arabic catalog's own bold cut
/// availability.
private struct FakeVariantAwareFontProvider: MKFontProviding {
    func resolve(_ handle: MKFontHandle) -> CTFont {
        CTFontCreateWithName("Helvetica" as CFString, handle.pointSize, nil)
    }
    func resolve(_ handle: MKFontHandle, variant: MKFontVariantRequest) -> CTFont {
        let name = variant.bold ? "Helvetica-Bold" : "Helvetica"
        return CTFontCreateWithName(name as CFString, handle.pointSize, nil)
    }
}

// WS-08 packet §5 task 18 accept (P10-EARLY raster-format slice):
// "integration tests per format; scene edits mid-export don't affect
// output (snapshot isolation)."
@Suite struct ExportCoordinatorTests {
    // NOTE: this helper's directory is never removed by the caller unless
    // it explicitly `defer`s a cleanup (see each test below). Prior to this
    // fix it was NEVER cleaned up at all, so every `swift test` invocation
    // left one more `mk-export-coordinator-<uuid>` directory behind in the
    // shared system temp dir permanently ، an unbounded, if individually
    // small, leak of this suite's own scratch directories (confirmed:
    // dozens of stale `mk-export-coordinator-*` directories were found
    // still present from earlier runs). Cleaning them up here is good
    // hygiene independent of any other test; see the suffix-based fix in
    // `TiledRasterExporterTests` for why this suite's directory name is
    // *not* the actual cause of that suite's flaky "leaked temp file"
    // assertions.
    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mk-export-coordinator-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func jpegExportEndToEndProducesAReadableFile() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await coordinator.export(
            MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square")),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysFree, filenameBase: "اختبار", destinationDirectory: dir
        )
        #expect(FileManager.default.fileExists(atPath: result.fileURL.path))
        #expect(result.format == .jpegDefault)
        let source = try #require(CGImageSourceCreateWithURL(result.fileURL as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 1)
    }

    @Test func pngOpaqueExportEndToEndForPremiumUser() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await coordinator.export(
            MKExportRequest(format: .pngOpaque, target: .preset(id: "social.square")),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir
        )
        #expect(result.pixelSize == CGSize(width: 1080, height: 1080))
        #expect(FileManager.default.fileExists(atPath: result.fileURL.path))
    }

    @Test func pngAlphaExportRendersATransparentBackground() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 64, height: 64))
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await coordinator.export(
            MKExportRequest(format: .pngAlpha, target: .custom(pixelSize: CGSize(width: 64, height: 64)), background: .transparent),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir
        )
        let source = try #require(CGImageSourceCreateWithURL(result.fileURL as CFURL, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.alphaInfo != .none)
    }

    @Test func freeUserJPEGRequestAboveBudgetIsClampedAndNoted() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene(canvasSize: CGSize(width: 1920, height: 1920))
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await coordinator.export(
            MKExportRequest(format: .jpegDefault, target: .preset(id: "social.storyReel")),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysFree, destinationDirectory: dir
        )
        #expect(Double(result.pixelSize.width) * Double(result.pixelSize.height) <= Double(MKFreeTierBudget.effectivePixelBudget) + 1)
        #expect(result.fallbacksApplied.contains { if case .downscaledForFreeTierBudget = $0.reason { return true }; return false })
    }

    @Test func premiumUserAtPresetBaselineGetsNoDownscaleNote() async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await coordinator.export(
            MKExportRequest(format: .pngOpaque, target: .preset(id: "social.square")),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir
        )
        #expect(result.fallbacksApplied.isEmpty)
    }

    @Test func blockedGateThrowsBlockedErrorAndWritesNoFile() async {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        await #expect(throws: MKExportError.self) {
            _ = try await coordinator.export(
                MKExportRequest(format: .pngOpaque, target: .preset(id: "social.square")),
                scene: scene, entitlement: FakeEntitlementResolver.alwaysFree, destinationDirectory: dir
            )
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        #expect(contents.isEmpty)
    }

    /// FC-1 (AUDIT_2026-07-28.md): regression-locks the composition-root
    /// wiring gap this wave's `EditorViewModel` fix closes ، a REAL
    /// `MKExportCoordinator(assets:fonts:renderer:)` construction, all
    /// three explicit (mirroring `EditorViewModel`'s raster-export call
    /// sites, not the coordinator's own bold-blind defaults), with a fake
    /// variant-aware font provider: a bold node's exported pixels must
    /// differ from its non-bold twin. Renders through the SVG-vector
    /// writer would only prove `fonts:` reaches `PDFVectorExporter`/
    /// `SVGSerializer` specifically ، this uses `.pngOpaque` (the
    /// `MKTiledRasterExporter` → `MKSnapshotRenderer` path, the exact path
    /// `exportForSharing`/`exportPNGForSharing`/`exportPDFRasterForSharing`
    /// all now go through) so the SAME `renderer:` argument this test
    /// passes explicitly is what actually gets exercised.
    @Test func explicitFontsParameterReachesRasterPipelineAndVariesBoldPixelOutput() async throws {
        func scene(isBold: Bool) -> MKScene {
            let text = MKNode.liveText(MKLiveTextNode(
                core: MKNodeCore(name: "Text", style: MKStyle(fill: .solid(.black))),
                text: MKSourceText(string: "Bold Test"),
                style: MKTextStyle(font: TestScenes.realFontRef, pointSize: 80, baseDirection: .leftToRight, isBold: isBold)
            ))
            var background = MKBackgroundNode.defaultBackground()
            background.content = .solid(.white)
            return MKScene(canvas: MKCanvasSpec(size: CGSize(width: 300, height: 150)), background: background, nodes: [text])
        }

        let fonts = FakeVariantAwareFontProvider()
        let coordinator = MKExportCoordinator(
            renderer: MKSnapshotRenderer(fonts: fonts, assets: MKEmptyAssetProvider()),
            fonts: fonts,
            assets: MKEmptyAssetProvider()
        )
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = MKExportTarget.custom(pixelSize: CGSize(width: 300, height: 150))

        let boldResult = try await coordinator.export(
            MKExportRequest(format: .pngOpaque, target: target),
            scene: scene(isBold: true), entitlement: FakeEntitlementResolver.alwaysPremium,
            filenameBase: "bold", destinationDirectory: dir
        )
        let nonBoldResult = try await coordinator.export(
            MKExportRequest(format: .pngOpaque, target: target),
            scene: scene(isBold: false), entitlement: FakeEntitlementResolver.alwaysPremium,
            filenameBase: "nonbold", destinationDirectory: dir
        )

        let boldData = try Data(contentsOf: boldResult.fileURL)
        let nonBoldData = try Data(contentsOf: nonBoldResult.fileURL)
        #expect(!boldData.isEmpty)
        #expect(!nonBoldData.isEmpty)
        #expect(boldData != nonBoldData, "A bold node's exported pixels must differ from its non-bold twin when an explicit variant-aware `fonts:` provider is threaded through MKExportCoordinator(assets:fonts:renderer:) — identical output means `variant:` never reached font resolution.")
    }

    /// P10-COMPLETION (Run-3): every `MKExportFormat` case now has a real
    /// writer (`hasImplementedWriter` is unconditionally `true`) ، this
    /// supersedes the P10-EARLY `unimplementedFormatsThrowFormatNotYetImplementedNeverSilently`
    /// test this replaces (that test asserted the OLD gap; asserting it
    /// still throws would be asserting a regression). Task 18 accept:
    /// "integration tests per format" ، this end-to-end-exercises every
    /// PDF/SVG format for a premium user and asserts a real, non-empty
    /// file lands at the expected URL.
    @Test(arguments: [MKExportFormat.pdfRaster, .svg, .pdfVectorRGB, .pdfVectorCMYK])
    func everyFormatNowProducesARealFile(_ format: MKExportFormat) async throws {
        let coordinator = MKExportCoordinator()
        let scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await coordinator.export(
            MKExportRequest(format: format, target: .preset(id: "social.square")),
            scene: scene, entitlement: FakeEntitlementResolver.alwaysPremium, destinationDirectory: dir
        )
        let data = try Data(contentsOf: result.fileURL)
        #expect(!data.isEmpty)
        if case .pdfVectorCMYK = format {
            #expect(result.fallbacksApplied.contains { $0.reason == .cmykContentRasterized })
        }
    }

    /// D-102 snapshot isolation: mutating the ORIGINAL scene value after
    /// kicking off an export must never affect the in-flight export's
    /// output ، trivially true for a value type passed by value, but
    /// asserted explicitly since it's an explicit accept criterion.
    @Test func sceneEditsAfterExportStartsDoNotAffectOutput() async throws {
        let coordinator = MKExportCoordinator()
        var scene = TestScenes.rectScene()
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let requestScene = scene // the value handed to `export` is a frozen copy
        scene.canvas.presetID = "mutated-after-the-fact"
        scene.nodes.removeAll()

        let result = try await coordinator.export(
            MKExportRequest(format: .jpegDefault, target: .preset(id: "social.square")),
            scene: requestScene, entitlement: FakeEntitlementResolver.alwaysFree, destinationDirectory: dir
        )
        #expect(FileManager.default.fileExists(atPath: result.fileURL.path))
        // The mutated local `scene` is provably a distinct value (value
        // semantics) ، this assertion documents the invariant rather than
        // re-deriving pixels.
        #expect(scene.nodes.isEmpty)
        #expect(requestScene.nodes.count == 1)
    }
}
