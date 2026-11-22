import CoreGraphics
import Foundation
import MKFoundation
import MKModel

// WS-07 packet §5 task 7. Stable hash of a node's CONTENT-affecting fields,
// deliberately EXCLUDING transform/opacity (those are layer properties,
// §11.2 ، a pure transform edit must not invalidate `BitmapCache`/
// `MKLayerTreeController` entries). Uses the same dependency-free FNV-1a +
// `JSONEncoder(.sortedKeys)` pattern `MKSourceTextBackup.contentHash`
// (MKModel, WS-02) already established, for the same reason: `Hasher` is
// not stable across process launches (bitmap-cache keys and layer-diff
// keys don't need to survive a relaunch, so `Hasher` instability wouldn't
// actually break this particular use ، but reusing the established stable
// digest keeps one hashing story in the codebase instead of two, and costs
// nothing).

/// A stable, transform/opacity-EXCLUDING digest of an `MKNode`'s paintable
/// content ، the key `BitmapCache` and `MKLayerTreeController`'s scene diff
/// use to decide "does this node need to be re-rendered" (task 7 accept:
/// "transform-only edit does not invalidate cache; fill-color edit does").
public enum MKContentHash {
    /// Hashes exactly the fields that affect PIXELS at a given size/style ،
    /// not `MKNodeCore.transform`, not `MKNodeCore.opacity` (opacity is
    /// applied as a layer/context alpha, not baked into cached bitmaps, so
    /// it is excluded here for the same reason transform is: `SceneRenderer`
    /// re-applies it on top of a cached bitmap without re-rendering).
    /// `MKNodeCore.isHidden`/`isLocked` are excluded too ، hidden/locked are
    /// policy (§11.2: "locked is policy-only, still rendered"; hidden nodes
    /// simply aren't drawn, which is a presence check, not a content edit).
    public static func hash(of node: MKNode, scaleBucket: Double) -> String {
        var parts: [String] = ["kind:\(node.kindTagForHash)", "bucket:\(scaleBucket)"]
        parts.append(contentsOf: styleParts(node.core.style))
        switch node {
        case .group:
            // Group content hash intentionally shallow (task 7 doesn't
            // require recursive child hashing at MKRender's layer ، groups
            // don't get their own cached bitmap in v1, §11.2: one CALayer
            // per TOP-LEVEL node; a group's children are top-level nodes
            // themselves for layer-tree purposes until WS-06 nests them).
            break
        case .liveText(let n):
            parts.append("text:\(n.text.string)")
            parts.append(encodedOrEmpty(n.style))
            parts.append("frame:\(frameTag(n.frame))")
        case .pathText(let n):
            parts.append("text:\(n.text.string)")
            parts.append(encodedOrEmpty(n.style))
            parts.append(encodedOrEmpty(n.path))
            parts.append(encodedOrEmpty(n.layout))
        case .arranged(let n):
            // Arranged nodes include child geometry digest (task 7: "text
            // nodes include style + string + font ref; arranged nodes
            // include child geometry digest") ، layout/outline/style per
            // child, not transform (per-child transform is itself a
            // content-shape input for arranged children specifically,
            // since D-220's `child.affine` bakes `transform` INTO the
            // world geometry the outline is painted at, unlike top-level
            // nodes where transform is a separate layer property; the
            // composition's OWN `core.transform`/`core.opacity` remain
            // excluded, matching every other node kind).
            parts.append(encodedOrEmpty(n.composition))
        case .shape(let n):
            parts.append(encodedOrEmpty(n.geometry))
        case .image(let n):
            parts.append(encodedOrEmpty(n.asset))
            parts.append("kind:\(n.kind.rawValue)")
        case .background(let n):
            parts.append(encodedOrEmpty(n.content))
        }
        return fnv1aHex(parts.joined(separator: "\u{1F}"))
    }

    private static func styleParts(_ style: MKStyle) -> [String] {
        [encodedOrEmpty(style)]
    }

    private static func frameTag(_ frame: MKTextFrameSpec) -> String {
        switch frame {
        case .singleLine: return "single"
        case .widthConstrained(let w): return "width:\(w)"
        }
    }

    /// P-1: hoisted out of `encodedOrEmpty` ، this was previously allocated
    /// FRESH on every single call (two per arranged node per `sync(to:)`
    /// pass, plus one for the background), which is itself part of the
    /// audited per-sync cost even before considering how much there is to
    /// encode. `JSONEncoder.encode(_:)` does not mutate the encoder's own
    /// configuration mid-encode (the actual per-call encoding state lives
    /// on an internal object `encode` creates fresh each time), so sharing
    /// one instance across calls ، including concurrent ones ، is safe;
    /// `outputFormatting` is set once here and never touched again.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static func encodedOrEmpty<T: Encodable>(_ value: T) -> String {
        guard let data = try? encoder.encode(value), let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }

    private static func fnv1aHex(_ string: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01B3
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}

extension MKNode {
    fileprivate var kindTagForHash: String {
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

/// The zoom-scale quantization policy (§11.3): powers of √2 from 0.025× to
/// 64×, used both as a `BitmapCache`/`ContentHash` key component and by
/// `MKLayerTreeController`'s re-rasterization hysteresis.
public enum MKScaleBucket {
    private static let step = 2.0.squareRoot()
    public static let minScale = 0.025
    public static let maxScale = 64.0

    /// Quantizes an arbitrary zoom/contentsScale value down to the nearest
    /// √2 power bucket at or below it, clamped to `[minScale, maxScale]` ،
    /// "nearest at or below" (not nearest overall) means content never
    /// renders BLURRIER than the actual zoom, only ever renders at a
    /// slightly higher resolution than strictly needed (§11.3's
    /// re-rasterization-bound intent).
    public static func quantize(_ scale: Double) -> Double {
        let clamped = min(max(scale, minScale), maxScale)
        let exponent = (log(clamped / minScale) / log(step)).rounded(.down)
        let bucket = minScale * pow(step, exponent)
        return min(max(bucket, minScale), maxScale)
    }
}
