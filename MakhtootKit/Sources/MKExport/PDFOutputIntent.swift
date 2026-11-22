import CoreGraphics
import Foundation
import MKColor

// P10-COMPLETION (Run-3, packet §5 task 12 / deliverables list
// `PDFOutputIntent.swift`). Builds the `aux` dictionary
// `CGContext(_:mediaBox:_:)` needs, using the D-226 Spike-B-VERIFIED shape
// (`docs/impl-log/WS-08.md`'s "SPIKE VERDICTS" section, written up by the
// P10-EARLY session and regression-locked in
// `Tests/MKColorTests/CMYKSpikeEvidenceTests.swift`):
//
//   1. `kCGPDFContextOutputIntent` (singular) + a single `CFDictionary`
//      value ، confirmed accepted, produces a well-formed
//      `/OutputIntents` array-of-one.
//   2. `kCGPDFXDestinationOutputProfile`'s value MUST be an ICC-based
//      `CGColorSpace` (`profile.colorSpace`), NEVER a `CGDataProvider`
//      wrapping the raw ICC bytes ، ARCHITECTURE §16.5's illustrative code
//      (`CGDataProvider(data: profile.iccData as CFData)!`) is WRONG and
//      must not be copied.
//
// **New empirical finding, this session (call it Spike D ، same rigor
// class as the P10-EARLY session's A/B spikes, found via this session's
// own `PDFPrintCMYKExporterTests` failing against a REAL produced file,
// not assumed)**: `kCGPDFXOutputIntentSubtype`'s VALUE is validated by
// CoreGraphics against a small fixed vocabulary ، passing anything other
// than the literal string `"GTS_PDFX"` (a made-up
// `"GTS_PDFX_fallback_not_a_claim"` string was tried first, per the
// WS08-A3 ADR's original "non-PDF/X-claiming subtype string" plan) makes
// CoreGraphics SILENTLY DROP THE ENTIRE OutputIntent DICTIONARY ، no
// error, no `/OutputIntents` key at all in the produced catalog. Verified
// by writing a minimal reproduction, decompressing the produced PDF's
// object streams, and confirming `/Catalog`'s dictionary has NO
// `/OutputIntents` entry for the nonstandard subtype string, and DOES have
// one when the subtype is reverted to the literal `"GTS_PDFX"`.
//
// **Corrected design**: the technical `kCGPDFXOutputIntentSubtype` value
// is ALWAYS the literal `"GTS_PDFX"` (the only value CoreGraphics will
// actually embed) ، this is a PDF DICTIONARY FORMAT tag, not itself a
// legally-binding "this document is PDF/X compliant" assertion (full
// PDF/X compliance requires many other document-wide properties this v1
// pipeline does not claim). D-226(4)/WS08-A3's actual "no PDF/X claim
// under fallback" requirement is honored at the APP-COPY level instead:
// `MKICCProfileProvenance.mayClaimPDFX`/`.arabicDisclosure` gate what
// Makhtoot's OWN export report/UI text says about the file, never the raw
// PDF dictionary (which ، per this finding ، CoreGraphics does not let us
// meaningfully differentiate anyway).
public enum PDFOutputIntent {
    /// The only value CoreGraphics accepts without silently discarding the
    /// whole OutputIntent (Spike D, see file header).
    static let pdfXSubtype = "GTS_PDFX"

    /// Builds the full `aux` dictionary for `CGContext(_:mediaBox:_:)`,
    /// including `kCGPDFContextOutputIntent` (Spike-B-verified shape) plus
    /// the document metadata every PDF writer sets (title/creator).
    public static func auxiliaryInfo(title: String, profile: MKICCProfile) -> CFDictionary {
        var aux: [CFString: Any] = [
            kCGPDFContextTitle: title,
            kCGPDFContextCreator: "Makhtoot (مخطوط)",
        ]
        aux[kCGPDFContextOutputIntent] = outputIntentDictionary(profile: profile) as CFDictionary
        return aux as CFDictionary
    }

    /// The OutputIntent dictionary alone (exposed separately so tests can
    /// assert its shape without constructing a full PDF context).
    /// `/OutputConditionIdentifier`/`/Info` carry the HONEST profile name
    /// (e.g. "Apple Generic CMYK") regardless of provenance ، this is
    /// where the fallback's lower fidelity is disclosed WITHIN the PDF
    /// itself (a RIP/preflight tool reading this file sees exactly which
    /// profile was used), even though the `/S` subtype tag is always
    /// `GTS_PDFX` (Spike D).
    public static func outputIntentDictionary(profile: MKICCProfile) -> [CFString: Any] {
        [
            kCGPDFXOutputIntentSubtype: pdfXSubtype as CFString,
            kCGPDFXOutputConditionIdentifier: profile.name as CFString,
            kCGPDFXInfo: profile.name as CFString,
            // Spike B's verified, CORRECT value type ، an ICC-based
            // CGColorSpace, never a CGDataProvider (see file header).
            kCGPDFXDestinationOutputProfile: profile.colorSpace,
        ]
    }

    /// Plain metadata-only `aux` (title/creator, no OutputIntent) ، the RGB
    /// vector PDF writer's shape (§16.5: OutputIntent only applies when
    /// `req.colorTarget == .cmykPrint`).
    public static func plainAuxiliaryInfo(title: String) -> CFDictionary {
        [
            kCGPDFContextTitle: title,
            kCGPDFContextCreator: "Makhtoot (مخطوط)",
        ] as CFDictionary
    }
}
