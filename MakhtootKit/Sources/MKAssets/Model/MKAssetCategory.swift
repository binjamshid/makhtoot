import Foundation

// WS-14 packet (AGENT_TASK_PACKETS/WS-14-assets-ornaments.md) §5 task 1.
// The five BRIEF-locked asset categories ، no invented categories, per the
// task's accept criterion ("category enum locked to the five BRIEF
// classes"). Arabic names are the canonical browser-section titles (D-126
// Arabic-first naming; PRD R-11.3's category grid: أشكال/زخارف/إطارات/
// عناصر/خلفيات).

/// The five bundled-asset categories (FOUNDATION §2 module map / BRIEF
/// scope). `Codable` via the raw `String` so `assets-manifest.json` stores
/// a stable, human-readable tag per category.
public enum MKAssetCategory: String, Hashable, Sendable, Codable, CaseIterable, Identifiable {
    case basicShapes
    case ornaments
    case frames
    case calligraphicElements
    case patternBackgrounds

    public var id: String { rawValue }

    /// Arabic section title (PRD R-11.3's grid labels).
    public var nameAr: String {
        switch self {
        case .basicShapes: return "أشكال أساسية"
        case .ornaments: return "زخارف"
        case .frames: return "إطارات"
        case .calligraphicElements: return "حليات خطية"
        case .patternBackgrounds: return "خلفيات زخرفية"
        }
    }

    /// Stable ordering for the browser grid (matches the packet's §1
    /// mission-statement listing order).
    public static let browserOrder: [MKAssetCategory] = [
        .basicShapes, .ornaments, .frames, .calligraphicElements, .patternBackgrounds,
    ]
}
