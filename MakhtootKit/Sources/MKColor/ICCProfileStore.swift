import CoreGraphics
import Foundation

// P10-COMPLETION (Run-3, AGENT_TASK_PACKETS/WS-08-export-pipeline.md §5
// task 2), explicitly deferred by the P10-EARLY session
// (docs/impl-log/WS-08.md: "ICCProfileStore... Deferred to P10-completion.
// Explicitly scoped out"). D-117 §15.2: "bundled slot + Apple Generic CMYK
// fallback (FD-03 placeholder)". FD-03 (DECISIONS_LOG.md) is
// founder-pending ، this file NEVER assumes a specific third-party profile
// ships; `Resources/ICC/` (this module) is an EMPTY slot with a README
// documenting the drop-in contract, exactly like `Makhtoot/Resources/ICC/`
// at the app layer (packet §8 deliverable, WS-13/composition-root territory
// ، this module's own `Resources/ICC/` is the MKColor-local mirror so
// `Bundle.module` can find it without an app-target resource dependency).

/// Where the active CMYK profile came from ، surfaced in the PDF/print
/// export report (§16.7 `MKExportReport.profileName`) and the "never claim
/// PDF/X under an unverified fallback" rule (D-226(4), WS08-A3 ADR).
public enum MKICCProfileProvenance: Sendable, Equatable, Hashable, Codable {
    /// A licensed, redistribution-verified profile shipped in
    /// `Resources/ICC/<name>.icc` (post-FD-03). `licenseEvidencePath` points
    /// at the checked-in license/verification note (D-120-pattern: font
    /// license evidence capture, applied here to color profiles per FD-03's
    /// own "Obligation: the shipped profile's license evidence is captured
    /// in-repo like font licenses" text).
    case bundledICC(name: String, licenseEvidencePath: String)
    /// The documented, always-available fallback (D-117): Apple's built-in
    /// Generic CMYK, `CGColorSpace(name: .genericCMYK)`. Lower press
    /// fidelity, explicitly disclosed ، never presented as PDF/X-compliant.
    case appleGenericCMYK

    /// Arabic disclosure string for the export report / pre-export sheet
    /// (R-13.7 seam, D-227(7)) ، "never silent" extends to color provenance
    /// too, not just geometry fallbacks.
    public var arabicDisclosure: String {
        switch self {
        case .bundledICC(let name, _):
            return "تم استخدام ملف تعريف الألوان \"\(name)\" لتحويل الألوان إلى CMYK للطباعة"
        case .appleGenericCMYK:
            return "تم استخدام ملف تعريف الألوان الافتراضي من نظام التشغيل (Generic CMYK)؛ قد تختلف الألوان المطبوعة عن ألوان الشاشة"
        }
    }

    /// Whether a PDF built against this provenance may claim the `GTS_PDFX`
    /// OutputIntent subtype (WS08-A3 ADR: "no PDF/X claim under fallback").
    /// Only a licensed, verified bundled profile may claim PDF/X; the
    /// Generic CMYK fallback still embeds a real OutputIntent (so the
    /// destination profile is honestly disclosed to a RIP/preflight tool)
    /// but under the plain `GTS_PDFX_no-claim` style subtype string, never
    /// `GTS_PDFX`.
    public var mayClaimPDFX: Bool {
        if case .bundledICC = self { return true }
        return false
    }
}

/// D-117 §15.2 / task 2: `cmykSpace() -> CGColorSpace` returns the bundled
/// profile if present (post-FD-03), else Apple Generic CMYK
/// (`CGColorSpace(name: kCGColorSpaceGenericCMYK)`); `profileProvenance`
/// surfaced into PDF metadata + export report.
public struct MKICCProfile: Sendable {
    public let provenance: MKICCProfileProvenance
    public let iccData: Data
    public let colorSpace: CGColorSpace

    /// `name` for display (OutputIntent `/Info`/`/OutputConditionIdentifier`
    /// text, §16.5) ، the ICC profile's own embedded description when
    /// available, else the provenance's own label.
    public var name: String {
        switch provenance {
        case .bundledICC(let name, _): return name
        case .appleGenericCMYK: return "Apple Generic CMYK"
        }
    }

    init(provenance: MKICCProfileProvenance, iccData: Data, colorSpace: CGColorSpace) {
        self.provenance = provenance
        self.iccData = iccData
        self.colorSpace = colorSpace
    }
}

/// `Resources/ICC/` scan + fallback resolution (task 2 accept: "fallback
/// works today; dropping in a profile file switches output with no code
/// change; provenance lands in the export report"). A plain enum (no
/// instance state) ، profile resolution is a pure function of "what's in
/// the bundle right now," matching `MKExportPresetCatalog.standard`'s own
/// "load once, pure value" precedent in the sibling `MKExport` module.
public enum ICCProfileStore {
    /// The bundled-profile resource name this store looks for
    /// (`Resources/ICC/<name>.icc` + `Resources/ICC/<name>.LICENSE.md`
    /// sitting alongside it, D-120-pattern evidence capture). FD-03 is
    /// founder-pending ، as of this session `Resources/ICC/` ships EMPTY
    /// (only a README documenting the drop-in contract), so this always
    /// resolves to the Apple Generic CMYK fallback today. Not a
    /// `MKFeatureFlags`-style constant table entry because this module has
    /// no such type (`MKColor` depends only on `MKFoundation`) ، the name
    /// is a plain literal, matching FD-03's own "the profile is swappable
    /// data, not architecture" framing.
    static let bundledProfileResourceName = "PressProfile"

    /// Loads the active CMYK profile: the bundled ICC file if present (and
    /// genuinely a CMYK-model profile ، a malformed or wrong-model bundled
    /// file is treated as "not present," never silently misused), else the
    /// documented Apple Generic CMYK fallback (D-117). This function cannot
    /// fail ، the fallback is always constructible on every Apple platform
    /// this app ships to (D-100's iOS 18 floor; verified by
    /// `CMYKSpikeEvidenceTests`).
    public static func loadBundled(bundle: Bundle? = nil) -> MKICCProfile {
        // `Bundle.module` (SPM's generated resource-bundle accessor) is
        // `internal`, so it cannot appear as a `public` API's default
        // argument value directly (Swift diagnoses this at the call site,
        // not just a style nit) ، resolved to the real default inside the
        // function body instead.
        if let bundled = loadBundledFile(bundle: bundle ?? .module) {
            return bundled
        }
        return appleGenericCMYKFallback()
    }

    private static func loadBundledFile(bundle: Bundle) -> MKICCProfile? {
        guard
            let url = bundle.url(forResource: bundledProfileResourceName, withExtension: "icc", subdirectory: "ICC"),
            let data = try? Data(contentsOf: url),
            let colorSpace = CGColorSpace(iccData: data as CFData),
            colorSpace.model == .cmyk
        else { return nil }

        let evidencePath = "Resources/ICC/\(bundledProfileResourceName).LICENSE.md"
        let displayName = (colorSpace.name as String?) ?? bundledProfileResourceName
        return MKICCProfile(
            provenance: .bundledICC(name: displayName, licenseEvidencePath: evidencePath),
            iccData: data,
            colorSpace: colorSpace
        )
    }

    /// The always-available fallback (D-117, `VERIFY-AT-IMPLEMENTATION`
    /// Spike A confirmed this space is a real, constructible CMYK
    /// `CGColorSpace` on iOS ، `docs/impl-log/WS-08.md`'s SPIKE VERDICTS).
    static func appleGenericCMYKFallback() -> MKICCProfile {
        guard let generic = CGColorSpace(name: CGColorSpace.genericCMYK), let iccData = generic.copyICCData() as Data? else {
            // Unreachable on any Apple platform this app ships to (D-100)
            // ، `CMYKSpikeEvidenceTests` regression-locks that this space
            // always constructs successfully. A `preconditionFailure` here
            // (rather than a throwing API) matches `MKExportPresetCatalog
            // .standard`'s own "malformed bundled/system resource is a
            // build-time defect, not a runtime condition any caller could
            // recover from" precedent.
            preconditionFailure("CGColorSpace(name: .genericCMYK) failed to construct ، unexpected on any D-100-supported OS version, see CMYKSpikeEvidenceTests")
        }
        return MKICCProfile(provenance: .appleGenericCMYK, iccData: iccData, colorSpace: generic)
    }
}
