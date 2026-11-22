import CoreGraphics
import Foundation

// WS-08 packet §5 task 4. Request-side export model. Format enum spelling
// follows the PACKET's own literal wording ("jpeg(quality), pngOpaque,
// pngAlpha, svg, pdfRaster, pdfVectorRGB, pdfVectorCMYK") rather than
// ARCHITECTURE §16.1's illustrative `pdfVector`/`pdfPrintCMYK` shorthand ،
// per D-227's precedent, the packet's own task list is the more concrete,
// authoritative source for WS-08's actual deliverable shape.
//
// **P10-EARLY implementation coverage**: `jpeg`, `pngOpaque`, `pngAlpha`
// have real writers this session (`RasterEncoders.swift`,
// `TiledRasterExporter.swift`). `pdfRaster`, `svg`, `pdfVectorRGB`,
// `pdfVectorCMYK` are FULL, REAL cases in this enum (so `ExportGate`'s
// D-119/D-229 gating logic ، task 5, also P10-EARLY ، can be completely
// implemented and tested against the whole format matrix today) but have
// NO writer yet; `ExportCoordinator.export(_:)` throws
// `MKExportError.formatNotYetImplemented(format:)` for them, never a
// silent no-op or a crash. See `docs/impl-log/WS-08.md` for the task-by-
// task P10-EARLY/P10-completion split.
public enum MKExportFormat: Sendable, Codable, Hashable, Equatable {
    /// Free tier (D-118). `quality` in `0...1` ، task 9's default is
    /// `0.85`, spelled `.jpegDefault` below (Swift enum cases cannot carry
    /// default associated-value literals).
    case jpeg(quality: Double)
    /// Free tier (D-118): single-page raster-only PDF, ≤2 MP effective ،
    /// writer deferred to P10-completion (packet task 10).
    case pdfRaster
    /// Premium (D-118): opaque PNG, canvas background composited in.
    case pngOpaque
    /// Premium (D-118): alpha PNG, transparent background legal.
    case pngAlpha
    /// Premium (D-118): custom SVG serializer ، writer deferred (tasks 13-16).
    case svg
    /// Premium (D-118): vector PDF, sRGB ، writer deferred (task 11).
    case pdfVectorRGB
    /// Premium (D-118): vector PDF, CMYK + ICC OutputIntent ، writer
    /// deferred (task 12; BLOCKED behind the two D-226 spikes, resolved
    /// this session, see `MKColor/README.md`).
    case pdfVectorCMYK

    /// D-118: whether this format is reachable on the free tier at all
    /// (before the 2 MP clamp / content gate are even considered).
    public var isFreeTierFormat: Bool {
        switch self {
        case .jpeg, .pdfRaster: return true
        case .pngOpaque, .pngAlpha, .svg, .pdfVectorRGB, .pdfVectorCMYK: return false
        }
    }

    /// Whether a `.transparent` background is legal for this format
    /// (D-118: "transparent PNG... where legal" ، only `pngAlpha`, and
    /// only for premium since it's gated by `isFreeTierFormat` already).
    public var supportsTransparentBackground: Bool {
        if case .pngAlpha = self { return true }
        return false
    }

    /// P10-COMPLETION (Run-3, packet §5 task 18 / "export history via
    /// `MetadataStore.exportHistory`"). `MKPersistence.MKExportRecord
    /// .format` (`Sources/MKPersistence/Metadata/MetadataModels.swift`)
    /// documents its OWN vocabulary in a comment: `"jpeg"|"png"|
    /// "pngAlpha"|"svg"|"pdf"|"pdfPrint"` ، a coarser set than this
    /// module's own 7-case `MKExportFormat` (e.g. `pdfRaster` and
    /// `pdfVectorRGB` both collapse to `"pdf"`; only the CMYK print
    /// variant gets its own `"pdfPrint"` bucket). `MKExport` owns this
    /// mapping (not `MKPersistence`, which must not depend on
    /// `MKExportFormat`) so a future `MKExportHistoryRecording` conformer
    /// at the app composition root (the only place allowed to import BOTH
    /// `MKExport` and `MKPersistence`) can call `MetadataStore
    /// .recordExport(projectID:format: request.format
    /// .metadataFormatString, pixelWidth:...)` as a pure, mechanical
    /// bridge ، no format-vocabulary logic duplicated at the call site.
    public var metadataFormatString: String {
        switch self {
        case .jpeg: return "jpeg"
        case .pngOpaque: return "png"
        case .pngAlpha: return "pngAlpha"
        case .svg: return "svg"
        case .pdfRaster, .pdfVectorRGB: return "pdf"
        case .pdfVectorCMYK: return "pdfPrint"
        }
    }

    /// Whether this format has a real writer wired into
    /// `ExportCoordinator`. P10-COMPLETION (Run-3): every case now has a
    /// real writer (`PDFRasterExporter`/`PDFVectorExporter`/
    /// `PDFPrintCMYKExporter`/`SVGSerializer`) ، see
    /// `docs/impl-log/WS-08.md` for each writer's fidelity notes
    /// (`pdfVectorCMYK` in particular ships a documented, non-vector
    /// "Spike C" deviation ، whole-page raster, not per-element CMYK).
    public var hasImplementedWriter: Bool { true }

    /// Task 9's default JPEG quality (0.85).
    public static let jpegDefault = MKExportFormat.jpeg(quality: 0.85)
}

extension MKExportFormat {
    private enum CodingKeys: String, CodingKey { case kind, quality }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "jpeg": self = .jpeg(quality: try container.decodeIfPresent(Double.self, forKey: .quality) ?? 0.85)
        case "pdfRaster": self = .pdfRaster
        case "pngOpaque": self = .pngOpaque
        case "pngAlpha": self = .pngAlpha
        case "svg": self = .svg
        case "pdfVectorRGB": self = .pdfVectorRGB
        case "pdfVectorCMYK": self = .pdfVectorCMYK
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown MKExportFormat kind '\(kind)'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .jpeg(let quality):
            try container.encode("jpeg", forKey: .kind)
            try container.encode(quality, forKey: .quality)
        case .pdfRaster: try container.encode("pdfRaster", forKey: .kind)
        case .pngOpaque: try container.encode("pngOpaque", forKey: .kind)
        case .pngAlpha: try container.encode("pngAlpha", forKey: .kind)
        case .svg: try container.encode("svg", forKey: .kind)
        case .pdfVectorRGB: try container.encode("pdfVectorRGB", forKey: .kind)
        case .pdfVectorCMYK: try container.encode("pdfVectorCMYK", forKey: .kind)
        }
    }
}

/// D-117 §15.4: which color pipeline paints fills/strokes/rasters.
/// `.cmykPrint` is a reserved value (task 12 defers the actual conversion)
/// ، `ExportGate`/`ExportCoordinator` refuse `colorTarget: .cmykPrint` on
/// any format this session implements a writer for (jpeg/pngOpaque/
/// pngAlpha are always `.srgb`; the CMYK-relevant format is
/// `pdfVectorCMYK`, itself `hasImplementedWriter == false` this session).
public enum MKExportColorTarget: String, Sendable, Codable, Hashable, Equatable {
    case srgb
    case cmykPrint
}

/// Where the target pixel size comes from ، a locked preset (task 7,
/// `ExportPresets.swift`) or premium custom exact dimensions (D-118: "no
/// artificial caps beyond hardware/free-tier gate").
public enum MKExportTarget: Sendable, Codable, Hashable, Equatable {
    case preset(id: String)
    case custom(pixelSize: CGSize)
}

/// `.canvas` composites the scene's background node (opaque formats);
/// `.transparent` is legal only where `MKExportFormat
/// .supportsTransparentBackground` is true (premium alpha PNG).
public enum MKExportBackground: String, Sendable, Codable, Hashable, Equatable {
    case canvas
    case transparent
}

/// ARCHITECTURE §16.1's `MKExportRequest`, packet task-4 shape. `dpi`
/// drives ImageIO DPI metadata stamping (task 9: 72/150/300) and, for
/// print presets, the pt↔px conversion (task 7).
public struct MKExportRequest: Sendable, Codable, Hashable, Equatable {
    public var format: MKExportFormat
    public var target: MKExportTarget
    public var dpi: Double
    public var background: MKExportBackground
    public var colorTarget: MKExportColorTarget

    public init(
        format: MKExportFormat,
        target: MKExportTarget,
        dpi: Double = 72,
        background: MKExportBackground = .canvas,
        colorTarget: MKExportColorTarget = .srgb
    ) {
        self.format = format
        self.target = target
        self.dpi = dpi
        self.background = background
        self.colorTarget = colorTarget
    }
}
