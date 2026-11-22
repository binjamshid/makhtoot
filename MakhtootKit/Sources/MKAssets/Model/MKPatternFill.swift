import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 8. `MKPatternFill`: vector tile + tile size + repeat
// mode + two styleable colors (background/motif), per the task's literal
// model list. Gating: D-215 ، ALL pattern backgrounds are premium (BRIEF
// Q34's "free tier = solid colors only" extended to pattern fills; see
// `Resources/ASSET_SOURCING_RULES.md` §"Gating" and
// `docs/impl-log/WS-14.md` ADR WS-14-A2).

/// How a tile repeats across the fill area.
public enum MKPatternRepeatMode: String, Hashable, Sendable, Codable {
    case grid
    case halfDrop
}

/// One repeatable pattern tile: its own vector geometry (one motif unit,
/// authored with `MKAssetPathBuilder` like any other asset) plus the tile's
/// footprint (`tileSize`) ، the spacing the instantiator repeats it at.
public struct MKPatternTile: Hashable, Sendable, Codable, Equatable {
    public var geometry: MKAssetGeometry
    public var tileSize: CGSize

    public init(geometry: MKAssetGeometry, tileSize: CGSize) {
        self.geometry = geometry
        self.tileSize = tileSize
    }
}

/// The full pattern-background fill model (task 8): one tile, a repeat
/// mode, and two styleable colors ، the tile motif paints with `motifColor`
/// over a `backgroundColor` field. `MKPatternInstantiator` (T3/T8) realizes
/// this as tiled placed shape nodes (see that file's header for why ،
/// `MKBackgroundContent` has no pattern case in the shipped `MKModel`
/// schema, a documented, flagged gap, not a silent workaround).
public struct MKPatternFill: Hashable, Sendable, Codable, Equatable {
    public var tile: MKPatternTile
    public var repeatMode: MKPatternRepeatMode
    public var backgroundColor: MKSolidColor
    public var motifColor: MKSolidColor

    public init(tile: MKPatternTile, repeatMode: MKPatternRepeatMode, backgroundColor: MKSolidColor, motifColor: MKSolidColor) {
        self.tile = tile
        self.repeatMode = repeatMode
        self.backgroundColor = backgroundColor
        self.motifColor = motifColor
    }
}
