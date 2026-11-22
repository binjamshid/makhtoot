import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-05 packet §5 task 11. Thin, coalescable `MKCommand` builders over a
// `pathText` node ، the primitive WS-06's inspector/canvas bindings call
// directly, same pattern `MKArrange.ArrangeStyleEditor` established for
// arranged-composition edits (`Sources/MKArrange/ArrangeCommands.swift`).
// Every builder here produces exactly ONE `MKPersistence.MKReplaceNodesCommand`
// ، the canonical, journal-codable "swap this node's full value" primitive
// (`CONTRACTS.md`'s WS-04 adoption row; `docs/impl-log/WS-04.md` session 2)
// ، rather than a bespoke `MKPathText`-local command type that
// `MKCommandCoder`'s closed switch could never reference (this module
// depends on `MKPersistence`, never the reverse, same reasoning
// `MKArrange` already documented for its own command layer).
public enum PathTextCommands {
    /// Retypes the source string / per-range style overrides. `burstKey`
    /// (stable within one keystroke burst, changes on a new burst) is the
    /// coalescing key ، same `.textEdit`-style scheme
    /// `MKPersistence.MKTextEditCommand` already establishes for Live Text.
    public static func setText(_ text: MKSourceText, nodeID: MKNodeID, in scene: MKScene, burstKey: String) -> (any MKCommand)? {
        replacing(nodeID: nodeID, in: scene, label: "كتابة", coalescingKeySuffix: burstKey) { node in
            node.text = text
        }
    }

    public static func setStyle(_ style: MKTextStyle, nodeID: MKNodeID, in scene: MKScene, gestureID: UUID = UUID()) -> (any MKCommand)? {
        replacing(nodeID: nodeID, in: scene, label: "تنسيق النص", coalescingKeySuffix: "style:\(gestureID)") { node in
            node.style = style
        }
    }

    /// Commits an edited `BezierPathModel` (task 10's `PathEditModel`
    /// operations produce the new model; this wraps it as a command).
    /// `coalescingKey` should stay stable for one continuous drag (e.g.
    /// `"path:\(nodeID):\(anchorID)"`) and change on the next distinct
    /// drag, so a whole drag gesture collapses to one undo step.
    public static func setPath(_ path: BezierPathModel, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)? {
        replacing(nodeID: nodeID, in: scene, label: "تحرير المسار", coalescingKeySuffix: coalescingKey) { node in
            node.path = path.bezierPathData()
        }
    }

    /// Commits the PERSISTED slice of layout options
    /// (`startOffset`/`side`/`spacingMode` ، see `PathLayoutOptions.swift`'s
    /// file header for why only these three round-trip through `MKModel`
    /// today).
    public static func setOptions(_ options: MKPathLayoutOptions, nodeID: MKNodeID, in scene: MKScene, gestureID: UUID = UUID()) -> (any MKCommand)? {
        replacing(nodeID: nodeID, in: scene, label: "خيارات المسار", coalescingKeySuffix: "options:\(gestureID)") { node in
            node.layout = options
        }
    }

    /// Converts a `PathLayoutEngine`-computed `BezierPathModel` edit AND
    /// carries it straight through ، convenience for WS-06 drag handlers
    /// that already hold a `PathEditModel`-produced model.
    public static func setPath(_ path: MKBezierPathData, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)? {
        setPath(BezierPathModel(path), nodeID: nodeID, in: scene, coalescingKey: coalescingKey)
    }

    /// Commits one per-glyph user-offset edit (task 3/9's
    /// `setGlyphOffset(clusterKey:)`) into `MKPathTextNode.glyphOffsets` ،
    /// the real, `MKCommand`/undo-integrated seam that closes WS-05 gap 2
    /// (see `MKModel.MKPathTextNode.glyphOffsets`'s own doc comment and
    /// `README.md`'s "Known schema gap" section). Overwrites (or inserts)
    /// the entry for `key`, converting the engine's runtime
    /// `PathClusterProvenanceKey`/`PathGlyphUserOffset` to `MKModel`'s
    /// persisted `MKPathGlyphOffsetKey`/`MKPathGlyphOffset` counterparts.
    /// `gestureID` follows `setStyle`'s pattern: stable across one
    /// continuous drag so the whole gesture coalesces to a single undo
    /// step, and fresh for the next distinct drag.
    public static func setGlyphOffset(
        _ offset: PathGlyphUserOffset, forKey key: PathClusterProvenanceKey, nodeID: MKNodeID, in scene: MKScene, gestureID: UUID = UUID()
    ) -> (any MKCommand)? {
        replacing(nodeID: nodeID, in: scene, label: "تحريك حرف على المسار", coalescingKeySuffix: "glyphOffset:\(gestureID)") { node in   // move a glyph on the path
            node.glyphOffsets[key.persisted] = offset.persisted
        }
    }

    /// The seam a future `MKCanvas`/app-layer caller uses: converts a
    /// node's PERSISTED per-glyph offsets (`MKModel`'s
    /// `[MKPathGlyphOffsetKey: MKPathGlyphOffset]` schema) into the engine
    /// input shape `PathLayoutEngine.layout`'s `userOffsets:` parameter
    /// consumes (`[PathClusterProvenanceKey: PathGlyphUserOffset]`), so a
    /// live-on-path render/hit-test pass can feed persisted edits straight
    /// back into layout.
    public static func persistedUserOffsets(from node: MKPathTextNode) -> [PathClusterProvenanceKey: PathGlyphUserOffset] {
        Dictionary(uniqueKeysWithValues: node.glyphOffsets.map { (PathClusterProvenanceKey($0.key), PathGlyphUserOffset($0.value)) })
    }

    private static func replacing(
        nodeID: MKNodeID, in scene: MKScene, label: String, coalescingKeySuffix: String?,
        _ mutate: (inout MKPathTextNode) -> Void
    ) -> (any MKCommand)? {
        guard case .pathText(var node) = scene.node(id: nodeID) else { return nil }
        mutate(&node)
        return MKReplaceNodesCommand(nodeID: nodeID, newNode: .pathText(node), label: label, coalescingKeySuffix: coalescingKeySuffix)
    }
}

// MARK: - Per-glyph user offsets (task 3/9's `setGlyphOffset(clusterKey:)`)

/// **Known schema gap (see `README.md`): RESOLVED.** WS-05 gap 2 asked for
/// a coalescable, undo-integrated `MKCommand` for per-glyph offsets. That's
/// now real: `MKModel.MKPathTextNode.glyphOffsets`
/// (`[MKPathGlyphOffsetKey: MKPathGlyphOffset]`) is the persisted field,
/// `PathTextCommands.setGlyphOffset` above writes it via
/// `MKReplaceNodesCommand`, and `persistedUserOffsets(from:)` converts it
/// back to the engine's runtime `[PathClusterProvenanceKey:
/// PathGlyphUserOffset]` shape. See `README.md`'s "Known schema gap"
/// section for the resolution history.
///
/// This store is now LEGACY: a session-scoped, non-`Codable`,
/// non-undo-integrated holder kept for transient use (e.g. live previews
/// that shouldn't touch the undo stack) ، not the primary mechanism.
public final class PathTextOffsetStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [MKNodeID: [PathClusterProvenanceKey: PathGlyphUserOffset]] = [:]

    public init() {}

    public func offsets(for nodeID: MKNodeID) -> [PathClusterProvenanceKey: PathGlyphUserOffset] {
        lock.lock()
        defer { lock.unlock() }
        return storage[nodeID] ?? [:]
    }

    public func setOffset(_ offset: PathGlyphUserOffset, forKey key: PathClusterProvenanceKey, nodeID: MKNodeID) {
        lock.lock()
        defer { lock.unlock() }
        storage[nodeID, default: [:]][key] = offset
    }

    public func clear(nodeID: MKNodeID) {
        lock.lock()
        defer { lock.unlock() }
        storage[nodeID] = nil
    }
}

// MARK: - Runtime <-> persisted conversion (WS-05 gap 2)

/// One-directional conversions between this module's runtime
/// `PathClusterProvenanceKey`/`PathGlyphUserOffset` (deliberately
/// non-`Codable`, per `PathGlyphPlacement.swift`'s own header) and
/// `MKModel`'s persisted `MKPathGlyphOffsetKey`/`MKPathGlyphOffset`
/// counterparts ، the small seam `setGlyphOffset`/`persistedUserOffsets`
/// above are built on.
private extension PathClusterProvenanceKey {
    var persisted: MKPathGlyphOffsetKey {
        MKPathGlyphOffsetKey(codepoints: codepoints, occurrenceOrdinal: occurrenceOrdinal)
    }

    init(_ persisted: MKPathGlyphOffsetKey) {
        self.init(codepoints: persisted.codepoints, occurrenceOrdinal: persisted.occurrenceOrdinal)
    }
}

private extension PathGlyphUserOffset {
    var persisted: MKPathGlyphOffset {
        MKPathGlyphOffset(offset: offset, rotation: Double(rotation))
    }

    init(_ persisted: MKPathGlyphOffset) {
        self.init(offset: persisted.offset, rotation: CGFloat(persisted.rotation))
    }
}
