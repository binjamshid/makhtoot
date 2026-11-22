import CoreGraphics
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 12: "API for WS-13 toolbar ، `addLiveText(at:)`
// (default 'اكتب هنا' placeholder text, opens overlay immediately),
// `addPathText(preset:)`, `addShape(_:)`, `addImage(assetRef:)`. Accept:
// each returns the new node id and selects it."
public extension CanvasSession {
    /// Default placeholder text for a freshly-added Live Text object
    /// ("type here").
    static let defaultLiveTextPlaceholder = "اكتب هنا"

    /// Inserts a new Live Text node at `point` (canvas space, top-left
    /// anchor) and immediately enters `.editText` mode over it (task 12:
    /// "opens overlay immediately") ، the actual `UITextView` overlay
    /// lifecycle is `TextEditingOverlay`'s job; this call only prepares
    /// the scene + session mode so the hosting view controller can present
    /// it.
    @discardableResult
    func addLiveText(at point: CGPoint, text: String = CanvasSession.defaultLiveTextPlaceholder, style: MKTextStyle = .default) throws -> MKNodeID {
        let core = MKNodeCore(name: "نص", transform: MKTransform2D(position: point))
        let node = MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style, frame: .singleLine)
        let wrapped = MKNode.liveText(node)
        try perform(MKInsertNodeCommand(node: wrapped))
        setSelection([wrapped.id])
        beginEditingText(nodeID: wrapped.id)
        return wrapped.id
    }

    /// Inserts a new Path Text node following `preset` (a caller-supplied
    /// Bézier path ، WS-05's preset catalog isn't built yet, so this
    /// accepts the raw path data directly; a `PathTextPreset` convenience
    /// wrapper is WS-05/WS-13 territory once `MKPathText` ships real code).
    @discardableResult
    func addPathText(path: MKBezierPathData, at point: CGPoint = .zero, text: String = CanvasSession.defaultLiveTextPlaceholder, style: MKTextStyle = .default) throws -> MKNodeID {
        let core = MKNodeCore(name: "نص على مسار", transform: MKTransform2D(position: point))
        let node = MKPathTextNode(core: core, text: MKSourceText(string: text), style: style, path: path)
        let wrapped = MKNode.pathText(node)
        try perform(MKInsertNodeCommand(node: wrapped))
        setSelection([wrapped.id])
        return wrapped.id
    }

    /// `size` sets the shape's on-canvas box (points) via
    /// `core.transform.scale` ، `ShapeDrawer.localPath(for:)` always paints
    /// a canonical unit-square/unit-local geometry (`MKRender/Drawers/
    /// ShapeDrawer.swift`'s own doc comments), so sizing is carried
    /// entirely by the node transform's `scale`, not by the geometry
    /// itself. Defaults to the previous implicit `(1, 1)` (a visually
    /// invisible 1×1 pt box) so existing callers that don't pass `size`
    /// keep their exact prior behavior; real toolbar call sites should
    /// always pass an explicit, canvas-relative size (P1.4 bugfix ،
    /// `EditorViewModel.addRectangleAtCenter()` sizes off the canvas's
    /// short side, matching `addPathText(preset:)`'s own convention).
    @discardableResult
    func addShape(_ geometry: MKShapeGeometry, at point: CGPoint, size: CGSize = CGSize(width: 1, height: 1), style: MKStyle = .default) throws -> MKNodeID {
        let core = MKNodeCore(name: "شكل", transform: MKTransform2D(position: point, scale: size), style: style)
        let node = MKNode.shape(MKShapeNode(core: core, geometry: geometry))
        try perform(MKInsertNodeCommand(node: node))
        setSelection([node.id])
        return node.id
    }

    @discardableResult
    func addImage(assetRef: MKAssetRef, kind: MKImageKind, at point: CGPoint, isPhotoBackgroundUse: Bool = false) throws -> MKNodeID {
        let core = MKNodeCore(name: "صورة", transform: MKTransform2D(position: point))
        let node = MKNode.image(MKImageNode(core: core, asset: assetRef, kind: kind, isPhotoBackgroundUse: isPhotoBackgroundUse))
        try perform(MKInsertNodeCommand(node: node))
        setSelection([node.id])
        return node.id
    }
}
