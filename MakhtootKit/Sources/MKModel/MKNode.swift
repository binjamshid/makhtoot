import CoreGraphics
import Foundation
import MKFoundation

// WS-02 packet §5 task 3. `MKNode`, the seven D-111 cases, and their
// payload structs. `MKNode` (and everything it contains) is `Sendable` +
// value-type so undo/redo is snapshot-cheap and the renderer (WS-07) can
// hold a scene across threads without racing the editor (D-102).

/// Fields shared by every node case (composition, not inheritance ، D-111:
/// "Node: id, transform, z-order, opacity, style, locked/hidden, name").
/// Named `MKNodeCore` per the packet's literal task-3 wording; the
/// equivalent type in ARCHITECTURE.md §3.2's illustrative pseudocode is
/// called `MKNodeBase` ، same shape, packet name kept for this
/// implementation since the packet governs naming per this run's
/// instructions.
public struct MKNodeCore: Hashable, Sendable, Codable, Equatable {
    public var id: MKNodeID
    /// User-visible layer name (Arabic default per kind ، callers supply
    /// the localized default; this type stores whatever string is given).
    public var name: String
    public var transform: MKTransform2D
    /// Paint order among sibling nodes; index-order in the owning array is
    /// the source of truth for *sibling* z-order (`MKScene.nodes`,
    /// `MKGroupNode.children` ، index 0 = backmost), so this field is the
    /// D-111-mandated explicit slot but is kept consistent with array order
    /// by `MKScene`'s tree-mutation operations rather than read
    /// independently by them.
    public var zOrder: Int
    public var opacity: Double
    public var style: MKStyle
    public var isLocked: Bool
    public var isHidden: Bool

    public init(
        id: MKNodeID = MKNodeID(),
        name: String,
        transform: MKTransform2D = .identity,
        zOrder: Int = 0,
        opacity: Double = 1,
        style: MKStyle = .default,
        isLocked: Bool = false,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.transform = transform
        self.zOrder = zOrder
        self.opacity = opacity
        self.style = style
        self.isLocked = isLocked
        self.isHidden = isHidden
    }
}

// MARK: - Node payloads

public struct MKGroupNode: Hashable, Sendable, Codable, Equatable {
    public var core: MKNodeCore
    public var children: [MKNode]
    /// Parent-group line-height control (BRIEF: "line height lives on the
    /// parent group" for grouped text runs); `nil` = each child's own
    /// `MKTextStyle.lineHeightMultiple` applies.
    public var lineHeightOverride: Double?

    public init(core: MKNodeCore, children: [MKNode] = [], lineHeightOverride: Double? = nil) {
        self.core = core
        self.children = children
        self.lineHeightOverride = lineHeightOverride
    }
}

public struct MKStyleRun: Hashable, Sendable, Codable, Equatable {
    public var utf16Start: Int
    public var utf16Length: Int
    public var style: MKTextStyle

    public init(utf16Start: Int, utf16Length: Int, style: MKTextStyle) {
        self.utf16Start = utf16Start
        self.utf16Length = utf16Length
        self.style = style
    }
}

/// Source string + per-range style overrides for a reflowable text node.
public struct MKSourceText: Hashable, Sendable, Codable, Equatable {
    public var string: String
    public var styleRuns: [MKStyleRun]

    public init(string: String, styleRuns: [MKStyleRun] = []) {
        self.string = string
        self.styleRuns = styleRuns
    }
}

public enum MKTextFrameSpec: Hashable, Sendable, Codable, Equatable {
    case singleLine
    case widthConstrained(width: Double)
}

/// Reflowable, Core-Text-shaped text bound to a source string (glossary:
/// Live Text object).
public struct MKLiveTextNode: Hashable, Sendable, Codable, Equatable {
    public var core: MKNodeCore
    public var text: MKSourceText
    public var style: MKTextStyle
    public var frame: MKTextFrameSpec

    public init(core: MKNodeCore, text: MKSourceText, style: MKTextStyle = .default, frame: MKTextFrameSpec = .singleLine) {
        self.core = core
        self.text = text
        self.style = style
        self.frame = frame
    }
}

public enum MKPathSide: String, Hashable, Sendable, Codable {
    case above, below, center
}

public enum MKPathSpacingMode: String, Hashable, Sendable, Codable {
    case natural, justify
}

public struct MKPathLayoutOptions: Hashable, Sendable, Codable, Equatable {
    public var startOffset: Double
    public var side: MKPathSide
    public var spacingMode: MKPathSpacingMode

    public init(startOffset: Double = 0, side: MKPathSide = .above, spacingMode: MKPathSpacingMode = .natural) {
        self.startOffset = startOffset
        self.side = side
        self.spacingMode = spacingMode
    }
}

/// Live text on a Bézier path ، still reflowable (retype → relayout) until
/// arranged (D-110). WS-05 (`MKPathText`) owns the arc-length layout engine
/// that consumes this payload; `MKModel` owns only the data shape.
public struct MKPathTextNode: Hashable, Sendable, Codable, Equatable {
    public var core: MKNodeCore
    public var text: MKSourceText
    public var style: MKTextStyle
    public var path: MKBezierPathData
    public var layout: MKPathLayoutOptions
    /// Per-glyph user-applied nudges ، closes WS-05 gap 2
    /// (`Sources/MKPathText/README.md`'s "Known schema gap" section /
    /// `CONTRACTS.md`'s WS-05 "Known schema gap" section). `PathLayoutEngine
    /// .layout` has always accepted a `[PathClusterProvenanceKey:
    /// PathGlyphUserOffset]` input and folded it into every matching
    /// glyph's final position/rotation; until this field, nothing
    /// round-tripped that edit through `MKPathTextNode`'s own Codable
    /// persistence ، `PathTextOffsetStore` (`PathTextCommands.swift`) was
    /// only a session-scoped, non-persistent stand-in.
    ///
    /// Keyed by `MKPathGlyphOffsetKey` (cluster codepoints + occurrence
    /// ordinal), NOT `MKClusterID` ، a fresh UUID is minted on every
    /// shaping capture (see `PathClusterProvenanceKey`'s own doc comment in
    /// `Sources/MKPathText/PathGlyphPlacement.swift`), so `MKClusterID` is
    /// not a stable key across a retype/relayout the way this dictionary
    /// needs to survive. Additive/defaulted field: absent in any
    /// `scene.json` written before this change decodes to `[:]` (see
    /// `init(from:)` below) ، no `MKSceneSchema.currentVersion` bump
    /// needed, same "new, defaulted, additive field" precedent
    /// `Arranged/GlyphNode.swift`'s `MKProvenance.cursiveAttached` already
    /// established.
    public var glyphOffsets: [MKPathGlyphOffsetKey: MKPathGlyphOffset]

    public init(
        core: MKNodeCore,
        text: MKSourceText,
        style: MKTextStyle = .default,
        path: MKBezierPathData,
        layout: MKPathLayoutOptions = MKPathLayoutOptions(),
        glyphOffsets: [MKPathGlyphOffsetKey: MKPathGlyphOffset] = [:]
    ) {
        self.core = core
        self.text = text
        self.style = style
        self.path = path
        self.layout = layout
        self.glyphOffsets = glyphOffsets
    }

    private enum CodingKeys: String, CodingKey {
        case core, text, style, path, layout, glyphOffsets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        core = try container.decode(MKNodeCore.self, forKey: .core)
        text = try container.decode(MKSourceText.self, forKey: .text)
        style = try container.decode(MKTextStyle.self, forKey: .style)
        path = try container.decode(MKBezierPathData.self, forKey: .path)
        layout = try container.decode(MKPathLayoutOptions.self, forKey: .layout)
        // Additive field (see doc comment above): absent in any scene.json
        // written before WS-05 gap 2 closed ، defaults to `[:]`, not a
        // decode failure.
        glyphOffsets = try container.decodeIfPresent([MKPathGlyphOffsetKey: MKPathGlyphOffset].self, forKey: .glyphOffsets) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(core, forKey: .core)
        try container.encode(text, forKey: .text)
        try container.encode(style, forKey: .style)
        try container.encode(path, forKey: .path)
        try container.encode(layout, forKey: .layout)
        try container.encode(glyphOffsets, forKey: .glyphOffsets)
    }
}

public enum MKShapeGeometry: Hashable, Sendable, Codable, Equatable {
    /// `cornerRadius` is expressed in the SAME unit-square-relative local
    /// space as the rest of `.rect`'s geometry, NOT in points ،
    /// `MKRender`'s `ShapeDrawer.localPath(for:)` builds the rounded rect
    /// on a canonical `[-0.5, -0.5, 1, 1]` unit box and lets
    /// `MKNodeCore.transform.scale` carry the node's actual on-canvas box
    /// size (see that drawer's own `.rect` doc comment for the general
    /// convention). Passing a raw point value here (e.g. `8`) is a
    /// straightforward, easy-to-make mistake: CoreGraphics clamps
    /// `cornerWidth`/`cornerHeight` to half the box side, so on anything
    /// smaller than a 16 pt box a point-valued radius silently renders a
    /// full circle instead of a subtly rounded rectangle. Callers that
    /// want a fixed ON-CANVAS radius must divide it by the node's intended
    /// edge length before passing it here (see `EditorViewModel
    /// .addRectangleAtCenter()` for a worked example).
    case rect(cornerRadius: Double)
    case ellipse
    case line
    case polygon(points: [CGPoint])
    case path(MKPathData)
    case asset(MKAssetRef)
}

public struct MKShapeNode: Hashable, Sendable, Codable, Equatable {
    public var core: MKNodeCore
    public var geometry: MKShapeGeometry

    public init(core: MKNodeCore, geometry: MKShapeGeometry) {
        self.core = core
        self.geometry = geometry
    }
}

/// Content-addressed reference into the document's `assets/` store (§13.3).
///
/// S-2 (path traversal via unvalidated asset refs): `digest`/`ext` become
/// path components verbatim in `MKAssetStore.assetURL(for:)`
/// (`appendingPathComponent` does not normalize `..`). A hand-crafted
/// `.makhtoot` package ، arriving via AirDrop, Files.app, or an iCloud
/// share ، whose `scene.json` carries e.g.
/// `"ext": "png/../../../../Library/Preferences/…"` could otherwise reach
/// the filesystem as attacker-controlled input the moment the scene
/// decodes. The hand-written `init(from:)` below rejects the whole
/// document (throws) rather than importing a partially-trusted ref.
public struct MKAssetRef: Hashable, Sendable, Codable, Equatable {
    public var digest: String
    public var ext: String

    public init(digest: String, ext: String) {
        self.digest = digest
        self.ext = ext
    }

    private enum CodingKeys: String, CodingKey {
        case digest, ext
    }

    /// `digest`/`ext` must be restricted to a character class that can
    /// never form `.`/`/`/`..` once interpolated into a path component ،
    /// that alone makes traversal structurally impossible, independent of
    /// length. Bounded to a generous 64 / 8 characters (this app's own
    /// `MKContentHash.sha256Hex` always emits exactly 64 lowercase-hex
    /// characters, and a real file extension is always short) WITHOUT
    /// pinning `digest` to exactly 64 characters: several pre-existing
    /// fixtures across this package's test suite (`MKImageNodeTests`,
    /// `MKBackgroundContentTests`, `TestScenes.swift`, and others outside
    /// this agent's owned-files fence) decode/round-trip short placeholder
    /// hex digests like `"deadbeef"`/`"cafebabe"`/`"abc123"` through this
    /// exact `Decodable` path ، pinning the length would reject every one
    /// of those as a collateral regression for zero additional security
    /// (the character-class restriction is what closes S-2, not the exact
    /// length). See this agent's final report for the full trace of why
    /// this deviates from the audit's literal `^[a-f0-9]{64}$` suggestion.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let digest = try container.decode(String.self, forKey: .digest)
        let ext = try container.decode(String.self, forKey: .ext)
        guard Self.isValidDigest(digest) else {
            throw DecodingError.dataCorruptedError(
                forKey: .digest, in: container,
                debugDescription: "MKAssetRef.digest must be 1-64 lowercase hex characters (a-f0-9), got \"\(digest)\""
            )
        }
        guard Self.isValidExt(ext) else {
            throw DecodingError.dataCorruptedError(
                forKey: .ext, in: container,
                debugDescription: "MKAssetRef.ext must be 1-8 lowercase alphanumeric characters, got \"\(ext)\""
            )
        }
        self.digest = digest
        self.ext = ext
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(digest, forKey: .digest)
        try container.encode(ext, forKey: .ext)
    }

    private static func isValidDigest(_ value: String) -> Bool {
        let bytes = value.utf8
        guard !bytes.isEmpty, bytes.count <= 64 else { return false }
        return bytes.allSatisfy { (0x30...0x39).contains($0) || (0x61...0x66).contains($0) } // '0'-'9', 'a'-'f'
    }

    private static func isValidExt(_ value: String) -> Bool {
        let bytes = value.utf8
        guard !bytes.isEmpty, bytes.count <= 8 else { return false }
        return bytes.allSatisfy { (0x30...0x39).contains($0) || (0x61...0x7A).contains($0) } // '0'-'9', 'a'-'z'
    }
}

public enum MKImageKind: String, Hashable, Sendable, Codable {
    case raster, vectorPDF, vectorSVG
}

public struct MKImageNode: Hashable, Sendable, Codable, Equatable {
    public var core: MKNodeCore
    public var asset: MKAssetRef
    public var kind: MKImageKind
    /// D-119 gating marker: true when this placement counts toward
    /// `premiumContentPresent` as a "photo background" use.
    ///
    /// Additive field on an already-persisted, Codable struct that PREVIOUSLY
    /// relied on synthesized `Codable` (§2.5's exact bug class): a
    /// non-optional `Bool` is NOT auto-defaulted by Swift's synthesized
    /// `Decodable` the way an `Optional` property is, so any `scene.json`
    /// written before this field existed would fail the whole document with
    /// `keyNotFound("isPhotoBackgroundUse")`. Given a hand-written
    /// `init(from:)`/`encode(to:)` below so absence decodes to `false` (a
    /// legacy document predating this field cannot have been a photo-
    /// background use) instead of throwing ، same "new, defaulted, additive
    /// field" precedent `MKPathTextNode.glyphOffsets` (above, ~line 161),
    /// `MKProvenance.cursiveAttached` (`Arranged/GlyphNode.swift`), and
    /// `MKBackgroundContent`'s `fit` (below, ~line 296) already established.
    /// No `MKSceneSchema.currentVersion` bump needed. See
    /// `MKImageNodeTests.swift` for the legacy-payload regression test.
    public var isPhotoBackgroundUse: Bool

    public init(core: MKNodeCore, asset: MKAssetRef, kind: MKImageKind, isPhotoBackgroundUse: Bool = false) {
        self.core = core
        self.asset = asset
        self.kind = kind
        self.isPhotoBackgroundUse = isPhotoBackgroundUse
    }

    private enum CodingKeys: String, CodingKey {
        case core, asset, kind, isPhotoBackgroundUse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        core = try container.decode(MKNodeCore.self, forKey: .core)
        asset = try container.decode(MKAssetRef.self, forKey: .asset)
        kind = try container.decode(MKImageKind.self, forKey: .kind)
        // Additive field (see doc comment above): absent in any scene.json
        // written before this field existed ، defaults to `false`, not a
        // decode failure.
        isPhotoBackgroundUse = try container.decodeIfPresent(Bool.self, forKey: .isPhotoBackgroundUse) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(core, forKey: .core)
        try container.encode(asset, forKey: .asset)
        try container.encode(kind, forKey: .kind)
        try container.encode(isPhotoBackgroundUse, forKey: .isPhotoBackgroundUse)
    }
}

/// How a `.image` canvas background fits the canvas bounds (P5.3):
/// `cover` fills edge-to-edge (may crop, never letterboxes ، v1's ONLY
/// behavior until this case was added, see `BackgroundDrawer`'s own doc
/// comment); `contain` fits the whole image inside the canvas (never
/// crops, may letterbox against the background's own solid-color
/// carrier ، a plain color underneath the image, so "letterboxing" reads
/// as that color showing at the edges, not transparency).
public enum MKBackgroundImageFit: String, Hashable, Sendable, Codable {
    case cover
    case contain
}

public enum MKBackgroundContent: Hashable, Sendable, Equatable {
    case solid(MKSolidColor)
    case image(MKAssetRef, fit: MKBackgroundImageFit)
}

// MARK: - Codable (P5.3 back-compat fix ، CORRECTED, see below)

// `fit` is an ADDITIVE, DEFAULTED field on an already-persisted, Codable
// case ، same "new, defaulted, additive field" precedent `MKPathTextNode
// .glyphOffsets`'s own doc comment (above, ~line 161) and `Arranged/
// GlyphNode.swift`'s `MKProvenance.cursiveAttached` already established,
// so no `MKSceneSchema.currentVersion` bump is needed here either.
//
// **This file's FIRST attempt at this fix (review-requested) was itself
// wrong, caught by running `MKPersistenceTests` against a REAL on-disk
// fixture (`Tests/Fixtures/fixture-5000-nodes.makhtoot`, predating this
// session) rather than trusting an assumption about Swift's synthesis
// rules: the first attempt assumed a single-UNLABELED-associated-value
// enum case encodes its payload BARE (`{"image": {"digest": …, "ext":
// …}}`, no wrapping). That assumption is false ، confirmed both by the
// real fixture's actual on-disk bytes (`"solid":{"_0":{"a":1,"b":1,"g":1,
// "r":1,"space":"srgb"}}}`, `.solid(MKSolidColor)` is the SAME shape
// pattern `.image(MKAssetRef)` was) and by an isolated probe
// (`enum E { case a(Int) }` → `JSONEncoder().encode(E.a(5))` →
// `{"a":{"_0":5}}`): Swift's synthesized enum Codable ALWAYS wraps every
// associated value in a keyed container under `_0` (unlabeled) / the
// parameter's own label (labeled), even when there is only one. So the
// REAL pre-P5.3 shape was `{"image": {"_0": {"digest": …, "ext": …}}}`,
// and the first attempt's flat `{"digest": …, "ext": …, "fit": …}` target
// shape was itself a NEW, incompatible format ، it broke `.solid` decoding
// outright (real fixture data has `.solid`'s payload one level deeper than
// this file's first attempt assumed) and would have failed to read a real
// pre-P5.3 `.image` background too.
//
// The corrected fix: reproduce Swift's ACTUAL synthesized shape by hand
// (`_0` for the unlabeled `MKAssetRef`/`MKSolidColor`, `fit` as a sibling
// key at the SAME nesting level for `.image`), so `.solid` is
// BYTE-IDENTICAL to synthesis's own historical output, and `.image` is
// byte-identical EXCEPT for the added `fit` key ، decoded via
// `decodeIfPresent(...) ?? .cover` (`.cover` is exactly what
// `BackgroundDrawer` did unconditionally before this field existed, so an
// old document renders identically). See `MKBackgroundContentTests.swift`
// for the regression test built from the real fixture bytes above (not a
// re-derived/self-consistent literal).
extension MKBackgroundContent: Codable {
    private enum CodingKeys: String, CodingKey { case solid, image }
    private enum SolidPayloadKeys: String, CodingKey { case _0 }
    private enum ImagePayloadKeys: String, CodingKey { case _0, fit }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.solid) {
            let payload = try container.nestedContainer(keyedBy: SolidPayloadKeys.self, forKey: .solid)
            self = .solid(try payload.decode(MKSolidColor.self, forKey: ._0))
            return
        }
        let payload = try container.nestedContainer(keyedBy: ImagePayloadKeys.self, forKey: .image)
        let ref = try payload.decode(MKAssetRef.self, forKey: ._0)
        // Additive field (see doc comment above): absent in any scene.json
        // written before P5.3 ، defaults to `.cover`, not a decode failure.
        let fit = try payload.decodeIfPresent(MKBackgroundImageFit.self, forKey: .fit) ?? .cover
        self = .image(ref, fit: fit)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .solid(let color):
            var payload = container.nestedContainer(keyedBy: SolidPayloadKeys.self, forKey: .solid)
            try payload.encode(color, forKey: ._0)
        case .image(let ref, let fit):
            var payload = container.nestedContainer(keyedBy: ImagePayloadKeys.self, forKey: .image)
            try payload.encode(ref, forKey: ._0)
            try payload.encode(fit, forKey: .fit)
        }
    }
}

/// Canvas background: solid color (free) or image asset (premium). Exactly
/// one per scene ، stored as `MKScene.background`, not mixed into
/// `MKScene.nodes` (task 3: "MKScene: canvas size, background node, ordered
/// children"), even though `.background` remains a valid `MKNode` case so
/// generic node lookups (`MKScene.node(id:)`) can still resolve it.
public struct MKBackgroundNode: Hashable, Sendable, Codable, Equatable {
    public var core: MKNodeCore
    public var content: MKBackgroundContent

    public init(core: MKNodeCore, content: MKBackgroundContent = .solid(.white)) {
        self.core = core
        self.content = content
    }

    public static func defaultBackground() -> MKBackgroundNode {
        MKBackgroundNode(core: MKNodeCore(name: "الخلفية"), content: .solid(.white))
    }
}

// MARK: - The node enum

/// The D-111 node enum: `group`, `liveText`, `pathText`, `arranged`,
/// `shape`, `image`, `background`.
public enum MKNode: Hashable, Sendable, Identifiable {
    case group(MKGroupNode)
    case liveText(MKLiveTextNode)
    case pathText(MKPathTextNode)
    case arranged(MKArrangedTextNode)
    case shape(MKShapeNode)
    case image(MKImageNode)
    case background(MKBackgroundNode)

    public var id: MKNodeID { core.id }

    public var core: MKNodeCore {
        switch self {
        case .group(let n): return n.core
        case .liveText(let n): return n.core
        case .pathText(let n): return n.core
        case .arranged(let n): return n.core
        case .shape(let n): return n.core
        case .image(let n): return n.core
        case .background(let n): return n.core
        }
    }

    /// Returns a copy of `self` with `core` replaced ، the primitive every
    /// higher-level command (transform/style/lock/hide/rename) is built on.
    public func withCore(_ newCore: MKNodeCore) -> MKNode {
        switch self {
        case .group(var n): n.core = newCore; return .group(n)
        case .liveText(var n): n.core = newCore; return .liveText(n)
        case .pathText(var n): n.core = newCore; return .pathText(n)
        case .arranged(var n): n.core = newCore; return .arranged(n)
        case .shape(var n): n.core = newCore; return .shape(n)
        case .image(var n): n.core = newCore; return .image(n)
        case .background(var n): n.core = newCore; return .background(n)
        }
    }

    /// `.group`'s children, or `nil` for every other case (leaf nodes,
    /// including `.arranged` whose `MKArrangedChild` family is a distinct,
    /// non-`MKNode` type per D-111 ، see `ArrangedComposition.swift`).
    public var children: [MKNode]? {
        if case .group(let g) = self { return g.children }
        return nil
    }

    fileprivate var kindTag: String {
        switch self {
        case .group: return "group"
        case .liveText: return "liveText"
        case .pathText: return "pathText"
        case .arranged: return "arranged"
        case .shape: return "shape"
        case .image: return "image"
        case .background: return "background"
        }
    }
}

// MARK: - Codable

// Custom Codable so `scene.json` encodes each node as a discriminated
// `{"kind": "<case>", "payload": {…}}` object. ARCHITECTURE.md §13.4's
// illustrative JSON schema flattens the payload's own keys alongside
// `kind` at the top level; this implementation nests the payload under its
// own `payload` key instead ، a deliberate, documented deviation, not an
// oversight: Swift's `Codable` has no supported way to "merge" an
// arbitrary `Encodable`'s keys into an enclosing keyed container without
// per-type manual field enumeration (one hand-written `CodingKeys` +
// encode/decode per node payload, ~7× the surface area for zero behavioral
// difference), and the *same* §13.4 schema already uses the nested
// `{"kind": …, "<kind>": {…}}` shape for `arrangedChild` and
// `ligatureGroup.state` ، so nesting is consistent with half of the
// schema's own two conventions, not a novel third approach. No downstream
// packet's accept criteria depend on the literal flattened key layout.
extension MKNode: Codable {
    private enum CodingKeys: String, CodingKey { case kind, payload }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "group": self = .group(try container.decode(MKGroupNode.self, forKey: .payload))
        case "liveText": self = .liveText(try container.decode(MKLiveTextNode.self, forKey: .payload))
        case "pathText": self = .pathText(try container.decode(MKPathTextNode.self, forKey: .payload))
        case "arranged": self = .arranged(try container.decode(MKArrangedTextNode.self, forKey: .payload))
        case "shape": self = .shape(try container.decode(MKShapeNode.self, forKey: .payload))
        case "image": self = .image(try container.decode(MKImageNode.self, forKey: .payload))
        case "background": self = .background(try container.decode(MKBackgroundNode.self, forKey: .payload))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container,
                debugDescription: "Unknown MKNode kind '\(kind)'"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kindTag, forKey: .kind)
        switch self {
        case .group(let n): try container.encode(n, forKey: .payload)
        case .liveText(let n): try container.encode(n, forKey: .payload)
        case .pathText(let n): try container.encode(n, forKey: .payload)
        case .arranged(let n): try container.encode(n, forKey: .payload)
        case .shape(let n): try container.encode(n, forKey: .payload)
        case .image(let n): try container.encode(n, forKey: .payload)
        case .background(let n): try container.encode(n, forKey: .payload)
        }
    }
}
