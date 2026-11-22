import CoreGraphics
import Foundation

// WS-08 packet §5 task 7. "square 1:1 (1080), story/reel 9:16
// (1080×1920), portrait 4:5, landscape 16:9, messaging-status 9:16,
// wallpaper (device-class sizes), print A5/A4/A3 at 300 DPI, business card
// 90×55 mm; each preset = ratio + free-baseline pixel size + premium print
// size; premium custom exact dimensions validated". §16.8: "All presets
// are data (`presets.json` in MKExport resources), not code."
//
// Model simplification (documented, matches §16.8's own resolution
// example "1080×1350 → scaled to ≤2MP"): each preset carries ONE canonical
// pixel size (`pixelWidth`/`pixelHeight`, `dpi`) ، the PREMIUM/native
// target. The free-tier resolved size is always
// `MKFreeTierBudget.clamped(preset.pixelSize)` computed on demand, never a
// second stored number, so the two can never drift out of sync with each
// other or with task 6's clamp math.
public struct MKExportPreset: Sendable, Codable, Hashable, Equatable {
    public var id: String
    public var nameArabic: String
    public var category: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var dpi: Double
    public var widthMM: Double?
    public var heightMM: Double?
    /// D-229(2)/G20: whether the FREE tier may select this preset at all,
    /// enforced at `ExportGate` (engine level, not just UI).
    public var freeTierEligible: Bool

    public var pixelSize: CGSize { CGSize(width: pixelWidth, height: pixelHeight) }

    /// The size a FREE-tier export of this preset actually resolves to
    /// (task 6's clamp, applied here so `ExportGate`/`ExportCoordinator`
    /// share one source of truth).
    public var freeResolvedPixelSize: CGSize { MKFreeTierBudget.clamped(pixelSize) }

    public init(
        id: String, nameArabic: String, category: String, pixelWidth: Int, pixelHeight: Int,
        dpi: Double, widthMM: Double? = nil, heightMM: Double? = nil, freeTierEligible: Bool
    ) {
        self.id = id
        self.nameArabic = nameArabic
        self.category = category
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.dpi = dpi
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.freeTierEligible = freeTierEligible
    }
}

private struct MKExportPresetFile: Codable {
    var schemaVersion: Int
    var presets: [MKExportPreset]
}

/// Loaded once from `Resources/presets.json` (Bundle.module) ، task 7's
/// "presets are data" rule. `standard` is a lazily-initialized, process-
/// wide immutable catalog (safe: the JSON never changes at runtime, and
/// `MKExportPresetCatalog` itself is a plain value type wrapping the
/// decoded array).
public struct MKExportPresetCatalog: Sendable {
    public let presets: [MKExportPreset]

    public init(presets: [MKExportPreset]) {
        self.presets = presets
    }

    /// Decodes `Resources/presets.json` from the package's resource
    /// bundle. Traps only on a genuinely corrupt bundle (malformed JSON
    /// shipped in the package itself is a build-time defect, matching this
    /// codebase's established `catalog-seed.json`/`assets-manifest.json`
    /// loading precedent in `MKFonts`/`MKAssets` ، those also decode
    /// bundled JSON with `try!`-equivalent force unwraps at static-init
    /// time, since a malformed bundled resource is not a runtime
    /// condition any caller could recover from).
    public static let standard: MKExportPresetCatalog = {
        guard let url = Bundle.module.url(forResource: "presets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(MKExportPresetFile.self, from: data)
        else {
            preconditionFailure("MKExport/Resources/presets.json is missing or malformed ، this is a packaging defect, not a runtime condition")
        }
        return MKExportPresetCatalog(presets: file.presets)
    }()

    public func preset(id: String) -> MKExportPreset? {
        presets.first { $0.id == id }
    }
}

/// Premium custom exact-dimension validation (task 7: "premium custom
/// exact dimensions validated (≥16 px, disk-feasibility warning
/// threshold)"). The disk-feasibility THRESHOLD (a soft warning, not a
/// hard cap ، Q76: "no artificial caps") is expressed here as a pure
/// query; enforcing/surfacing the warning banner is WS-13 UI territory
/// (out of this module's scope) ، `ExportCoordinator` still records a
/// `FallbackNote`-independent signpost note when a request crosses it, so
/// the signal exists in `docs/impl-log/WS-08.md`-visible evidence even
/// without the UI.
public enum MKCustomDimensionValidator {
    public static let minimumSidePixels = 16
    /// Above this many total pixels, a single uncompressed RGBA8 bitmap
    /// exceeds ~1 GB ، a reasonable "warn, don't block" threshold (Q76).
    public static let diskFeasibilityWarningPixelCount = 250_000_000

    public enum Verdict: Sendable, Equatable {
        case ok
        case tooSmall
        case warnDiskFeasibility
    }

    public static func validate(_ size: CGSize) -> Verdict {
        guard size.width >= CGFloat(minimumSidePixels), size.height >= CGFloat(minimumSidePixels) else {
            return .tooSmall
        }
        if Double(size.width) * Double(size.height) > Double(diskFeasibilityWarningPixelCount) {
            return .warnDiskFeasibility
        }
        return .ok
    }
}
