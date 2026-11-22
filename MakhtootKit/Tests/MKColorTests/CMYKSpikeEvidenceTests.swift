import Testing
import CoreGraphics
import Foundation

// WS-08 packet §5 task 12's two BLOCKING VERIFY-AT-IMPLEMENTATION spikes
// (D-226), run empirically this session (not assumed from the PDF spec or
// ARCHITECTURE's illustrative pseudocode) ، see `docs/impl-log/WS-08.md`
// for the full write-up, the standalone probe transcript run against a
// REAL iOS 26.5 simulator process (`xcrun simctl spawn`), and the produced
// PDF byte dumps. This file regression-locks BOTH findings as executable
// evidence so a future OS/toolchain change that silently alters this
// behavior is caught, independent of the prose write-up ، mirroring the
// "regression-locked" evidence pattern `WS16CursiveTests` already
// established in this codebase.
//
// Confirmed to behave IDENTICALLY on the macOS host (this test's actual
// execution environment under `swift test`) and the iOS 26.5 simulator
// (the shipped target, probed separately via a standalone
// `xcrun simctl spawn` binary ، see the impl log) ، both spikes' verdicts
// are therefore safe to regression-lock here even though CI for this
// package runs on macOS (Package.swift's own "iOS 18 is shipped; macOS is
// declared purely for host iteration speed" note).
//
// CMYK conversion itself (the actual `CMYKConverter`/`ICCProfileStore`/
// `PDFOutputIntent` production code) is explicitly OUT of this session's
// P10-EARLY slice ، these tests exist so the SPIKE FINDINGS survive for
// whoever builds that code in P10-completion.
@Suite struct CMYKSpikeEvidenceTests {
    // MARK: - Spike A: CMYK CGBitmapContext creation (D-226(4)(a))

    /// VERDICT: supported, but ONLY with `.none` alpha ، a CMYK bitmap
    /// context carries no alpha channel. Actionable for P10-completion's
    /// raster CMYK path: opacity/transparency-layer compositing must
    /// happen in an RGBA context BEFORE the final whole-image CMYK
    /// conversion, never inside the CMYK context itself.
    @Test func cmykBitmapContextSucceedsWithNoAlphaInfo() throws {
        let cmyk = try #require(CGColorSpace(name: CGColorSpace.genericCMYK))
        let ctx = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: cmyk, bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        #expect(ctx != nil, "Spike A regression: CMYK CGBitmapContext with .none alpha must succeed")
        #expect(ctx?.makeImage() != nil)
    }

    /// VERDICT: `.premultipliedLast` (the RGBA-reflex choice, and what
    /// `MKSnapshotRenderer.makeFlippedBitmapContext` uses for its RGB
    /// contexts) is UNSUPPORTED for a CMYK color space ، returns `nil`,
    /// not a crash, but any caller that reflexively reuses the RGB
    /// bitmapInfo for a CMYK context will silently fail to allocate.
    @Test func cmykBitmapContextFailsWithPremultipliedLastAlphaInfo() throws {
        let cmyk = try #require(CGColorSpace(name: CGColorSpace.genericCMYK))
        let ctx = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: cmyk, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        #expect(ctx == nil, "Spike A regression: CMYK + .premultipliedLast is expected to be unsupported (nil)")
    }

    /// An ICC-based CMYK space (the FD-03 bundled-profile shape, and the
    /// Apple Generic CMYK fallback's own `.copyICCData()` round-tripped
    /// through `CGColorSpace(iccData:)`) behaves identically to the named
    /// Generic CMYK space ، confirms the FD-03 drop-in-a-profile path is
    /// viable with zero code change once a licensed profile exists.
    @Test func iccBasedCMYKColorSpaceBehavesLikeGenericCMYKForBitmapContexts() throws {
        let generic = try #require(CGColorSpace(name: CGColorSpace.genericCMYK))
        let iccData = try #require(generic.copyICCData() as Data?)
        let iccSpace = try #require(CGColorSpace(iccData: iccData as CFData))
        #expect(iccSpace.model == .cmyk)
        let ctx = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: iccSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        #expect(ctx != nil)
    }

    // MARK: - Spike B: CGPDFContext OutputIntent aux-key shape (D-226(4)(b))

    /// VERDICT: `kCGPDFContextOutputIntent` (singular) + a single
    /// `CFDictionary` value is the correct, accepted shape (matches
    /// ARCHITECTURE §16.5's illustrative code) ، this part of the
    /// pseudocode was right.
    @Test func singularOutputIntentKeyWithSingleDictionaryProducesOutputIntents() throws {
        let generic = try #require(CGColorSpace(name: CGColorSpace.genericCMYK))
        let iccData = try #require(generic.copyICCData() as Data?)
        let iccSpace = try #require(CGColorSpace(iccData: iccData as CFData))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spikeB-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        var mediaBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let outputIntent: [CFString: Any] = [
            kCGPDFXOutputIntentSubtype: "GTS_PDFX" as CFString,
            kCGPDFXOutputConditionIdentifier: "Custom" as CFString,
            kCGPDFXInfo: "spike evidence" as CFString,
            kCGPDFXDestinationOutputProfile: iccSpace,
        ]
        let aux: [CFString: Any] = [kCGPDFContextOutputIntent: outputIntent as CFDictionary]
        let ctx = try #require(CGContext(url as CFURL, mediaBox: &mediaBox, aux as CFDictionary))
        ctx.beginPDFPage(nil)
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        ctx.endPDFPage()
        ctx.closePDF()

        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.contains("/OutputIntents"), "Spike B regression: singular kCGPDFContextOutputIntent must produce a /OutputIntents catalog entry")
    }

    /// VERDICT ، the correction to ARCHITECTURE §16.5's illustrative code:
    /// `kCGPDFXDestinationOutputProfile`'s value MUST be an ICC-based
    /// `CGColorSpaceRef`. A `CGDataProvider` wrapping the same raw ICC
    /// bytes is SILENTLY ACCEPTED by `CGContext` construction but the
    /// resulting PDF's `/OutputIntents` dictionary is missing
    /// `/DestOutputProfile` entirely ، the ICC stream never gets embedded.
    /// A future PDF/X claim built against the `CGDataProvider` form would
    /// be provably false; this test locks in the failure mode so nobody
    /// "fixes" the CGColorSpace form back to CGDataProvider by mistake.
    @Test func destOutputProfileAsDataProviderSilentlyOmitsTheProfileStream() throws {
        let generic = try #require(CGColorSpace(name: CGColorSpace.genericCMYK))
        let iccData = try #require(generic.copyICCData() as Data?)
        let provider = try #require(CGDataProvider(data: iccData as CFData))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spikeB-dataprovider-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        var mediaBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let outputIntent: [CFString: Any] = [
            kCGPDFXOutputIntentSubtype: "GTS_PDFX" as CFString,
            kCGPDFXOutputConditionIdentifier: "Custom" as CFString,
            kCGPDFXInfo: "spike evidence (wrong form)" as CFString,
            kCGPDFXDestinationOutputProfile: provider,
        ]
        let aux: [CFString: Any] = [kCGPDFContextOutputIntent: outputIntent as CFDictionary]
        let ctx = try #require(CGContext(url as CFURL, mediaBox: &mediaBox, aux as CFDictionary))
        ctx.beginPDFPage(nil)
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        ctx.endPDFPage()
        ctx.closePDF()

        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.contains("/OutputIntents"))
        #expect(!text.contains("/DestOutputProfile"), "Spike B regression: CGDataProvider form is expected to silently omit /DestOutputProfile ، if this now fails, CoreGraphics behavior changed and PDFOutputIntent.swift's design assumption needs re-verification")
    }

    /// The correct form (ICC-based `CGColorSpace`) DOES embed both the
    /// `/DestOutputProfile` reference and an `/ICCBased` stream ، the
    /// positive control for the previous test.
    @Test func destOutputProfileAsICCColorSpaceEmbedsTheProfileStream() throws {
        let generic = try #require(CGColorSpace(name: CGColorSpace.genericCMYK))
        let iccData = try #require(generic.copyICCData() as Data?)
        let iccSpace = try #require(CGColorSpace(iccData: iccData as CFData))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spikeB-iccspace-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        var mediaBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let outputIntent: [CFString: Any] = [
            kCGPDFXOutputIntentSubtype: "GTS_PDFX" as CFString,
            kCGPDFXOutputConditionIdentifier: "Custom" as CFString,
            kCGPDFXInfo: "spike evidence (correct form)" as CFString,
            kCGPDFXDestinationOutputProfile: iccSpace,
        ]
        let aux: [CFString: Any] = [kCGPDFContextOutputIntent: outputIntent as CFDictionary]
        let ctx = try #require(CGContext(url as CFURL, mediaBox: &mediaBox, aux as CFDictionary))
        ctx.beginPDFPage(nil)
        ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        ctx.endPDFPage()
        ctx.closePDF()

        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(text.contains("/OutputIntents"))
        #expect(text.contains("/DestOutputProfile"))
        #expect(text.contains("/ICCBased"))
    }
}
