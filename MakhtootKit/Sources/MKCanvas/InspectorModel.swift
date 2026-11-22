import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 11: "Numeric inspector bindings: X/Y/W/H (world
// frame of selection), rotation (degrees), opacity, fill color, stroke,
// shadow, text-style fields when a text object is selected (font size,
// kerning, tracking, baseline shift, line height), per-glyph fields in
// arrange granularity. Numeric entry accepts Latin + Arabic-Indic digits
// (WS-01 `MKInspectorField`); edits emit coalescable commands; multi-
// select shows mixed-value state ('،') and applies to all."
//
// Digit-locale parsing (Latin/Arabic-Indic) is `MKDesignSystem
// .MKInspectorField`'s job at the TEXT-FIELD layer (WS-01, already
// shipped) ، this type deals only in typed `Double`/`CGPoint`/`CGSize`
// values; it is the model half of that binding, not the text-parsing half.
// Per-glyph arrange-granularity fields are Arrange-Mode canvas UX (task 15,
// P5) ، out of this P4 slice.
@MainActor
@Observable
public final class InspectorModel {
    public let session: CanvasSession
    private var editGestureID: UUID?

    public init(session: CanvasSession) {
        self.session = session
    }

    /// One field's value across the current selection: a single node
    /// reads `.uniform`, an empty selection reads `.empty`, and a multi-
    /// select whose nodes disagree reads `.mixed` ("،" in the UI, task 11).
    public enum Value<T: Equatable>: Equatable {
        case uniform(T)
        case mixed
        case empty
    }

    private static func aggregate<T: Equatable>(_ values: [T]) -> Value<T> {
        guard let first = values.first else { return .empty }
        return values.allSatisfy { $0 == first } ? .uniform(first) : .mixed
    }

    // MARK: - Reads

    /// World-space transform for `id`, composing every ancestor group's
    /// own transform in (§10.4: numeric inspector reflects WORLD frame,
    /// not a node's raw locally-stored transform when nested inside a
    /// group) ، recursion depth is bounded by scene nesting, which v1
    /// keeps shallow (grouping only ever wraps top-level/already-grouped
    /// selections, task 8).
    public static func worldTransform(for id: MKNodeID, in scene: MKScene) -> MKTransform2D? {
        func search(_ nodes: [MKNode], parentWorld: MKTransform2D) -> MKTransform2D? {
            for node in nodes {
                let world = MKGroupTransform.worldTransform(childLocal: node.core.transform, groupTransform: parentWorld)
                if node.id == id { return world }
                if case .group(let g) = node, let found = search(g.children, parentWorld: world) { return found }
            }
            return nil
        }
        if scene.background.core.id == id { return scene.background.core.transform }
        return search(scene.nodes, parentWorld: .identity)
    }

    public var positionValue: Value<CGPoint> {
        Self.aggregate(session.selection.ids.compactMap { Self.worldTransform(for: $0, in: session.scene)?.position })
    }

    public var rotationDegreesValue: Value<Double> {
        Self.aggregate(session.selection.ids.compactMap { id -> Double? in
            guard let t = Self.worldTransform(for: id, in: session.scene) else { return nil }
            return Double(t.rotation * 180 / .pi)
        })
    }

    public var opacityValue: Value<Double> {
        Self.aggregate(session.selection.ids.compactMap { session.scene.node(id: $0)?.core.opacity })
    }

    /// World size ، only populated once a `geometrySource` is wired (WS-07
    /// dependency, see `Geometry/MKCanvasGeometrySource.swift`); `.empty`
    /// otherwise rather than a fabricated value.
    public var sizeValue: Value<CGSize> {
        guard let geometrySource = session.geometrySource else { return .empty }
        return Self.aggregate(session.selection.ids.compactMap { geometrySource.worldOBB(for: $0, in: session.scene)?.size })
    }

    public var fillValue: Value<MKFill> {
        Self.aggregate(session.selection.ids.compactMap { session.scene.node(id: $0)?.core.style.fill })
    }

    public var strokeValue: Value<MKStroke?> {
        Self.aggregate(session.selection.ids.compactMap { session.scene.node(id: $0)?.core.style.stroke })
    }

    public var shadowValue: Value<MKShadow?> {
        Self.aggregate(session.selection.ids.compactMap { session.scene.node(id: $0)?.core.style.shadow })
    }

    /// Text-style fields, populated only when every selected node is a
    /// `.liveText`/`.pathText` (task 11: "when a text object is selected").
    public var textStyleValue: Value<MKTextStyle> {
        let styles: [MKTextStyle] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style
            case .pathText(let n): return n.style
            default: return nil
            }
        }
        guard styles.count == session.selection.ids.count, !styles.isEmpty else { return .empty }
        return Self.aggregate(styles)
    }

    /// The font ref of the selected text node(s). `.empty` when selection
    /// contains no text nodes; `.mixed` when multiple text nodes with
    /// different fonts are selected.
    public var fontRefValue: Value<MKFontRef> {
        let fonts: [MKFontRef] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.font
            case .pathText(let n): return n.style.font
            default: return nil
            }
        }
        guard fonts.count == session.selection.ids.count, !fonts.isEmpty else { return .empty }
        return Self.aggregate(fonts)
    }

    // MARK: - Coalescing bracket (ARCHITECTURE §14.3: ".style(nodeID, field)"
    // slider-drag coalescing ، every field setter below shares this
    // gesture-scoped key mechanism, reusing `MKBatchTransformCommand
    // `/`MKBatchCoreCommand`'s per-gesture coalescing key exactly as
    // `MoveGesture`/`HandleGestures` do).

    /// Starts a coalescing bracket (e.g. a slider drag): every field
    /// setter called before the matching `endEdit()` merges into ONE undo
    /// entry. Committing a single text-field edit (type "200", press
    /// إدخال) can call a setter directly without `beginEdit()`/`endEdit()`
    /// ، it gets its own one-shot undo entry, which is the correct
    /// granularity for a discrete commit.
    public func beginEdit() {
        editGestureID = UUID()
        session.beginGesture()
    }

    public func endEdit() {
        guard editGestureID != nil else { return }
        session.endGesture()
        editGestureID = nil
    }

    private func currentGestureID() -> UUID { editGestureID ?? UUID() }

    // MARK: - Writes

    /// Sets every selected node's WORLD position to `newPosition`
    /// (single selection) or shifts every selected node by the delta
    /// implied by moving the CURRENT uniform/representative position to
    /// `newPosition` (multi-select ، task 11: "mixed-value editing applies
    /// delta correctly"). Only top-level (unnested) selections get an
    /// exact world-space move; nested selections fall back to editing each
    /// node's own stored (local) transform, matching how group-scoped
    /// transforms are documented to work (task 8: "transforms on a group
    /// apply to the group node only").
    public func setPosition(_ newPosition: CGPoint) {
        let reference: CGPoint
        switch positionValue {
        case .uniform(let p): reference = p
        case .mixed, .empty: reference = newPosition
        }
        let delta = CGVector(dx: newPosition.x - reference.x, dy: newPosition.y - reference.y)
        var newTransforms: [MKNodeID: MKTransform2D] = [:]
        for id in session.selection.ids {
            guard var t = session.scene.node(id: id)?.core.transform else { continue }
            t.position.x += delta.dx
            t.position.y += delta.dy
            newTransforms[id] = t
        }
        guard !newTransforms.isEmpty else { return }
        try? session.perform(MKBatchTransformCommand(gestureID: currentGestureID(), newTransforms: newTransforms))
    }

    /// Sets every selected node's rotation to the SAME absolute angle
    /// (task 11's "applies to all" default for an absolute numeric field ،
    /// contrast with `HandleGestures`' delta-preserving rigid-group
    /// rotation, which is a different gesture/method for a different UX).
    public func setRotationDegrees(_ degrees: Double) {
        let radians = CGFloat(degrees * .pi / 180)
        var newTransforms: [MKNodeID: MKTransform2D] = [:]
        for id in session.selection.ids {
            guard var t = session.scene.node(id: id)?.core.transform else { continue }
            t.rotation = radians
            newTransforms[id] = t
        }
        guard !newTransforms.isEmpty else { return }
        try? session.perform(MKBatchTransformCommand(gestureID: currentGestureID(), newTransforms: newTransforms))
    }

    public func setOpacity(_ value: Double) {
        let clamped = max(0, min(1, value))
        var newCores: [MKNodeID: MKNodeCore] = [:]
        for id in session.selection.ids {
            guard var core = session.scene.node(id: id)?.core else { continue }
            core.opacity = clamped
            newCores[id] = core
        }
        guard !newCores.isEmpty else { return }
        try? session.perform(MKBatchCoreCommand(gestureID: currentGestureID(), newCores: newCores, label: "شفافية"))
    }

    public func setFill(_ fill: MKFill) {
        applyStyle { $0.fill = fill }
    }

    public func setStroke(_ stroke: MKStroke?) {
        applyStyle { $0.stroke = stroke }
    }

    public func setShadow(_ shadow: MKShadow?) {
        applyStyle { $0.shadow = shadow }
    }

    /// Highlight color on text nodes. Reads from `MKTextStyle.highlightColor`.
    public var highlightColorValue: Value<MKFill> {
        let colors: [MKFill] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.highlightColor.map { MKFill.solid($0) } ?? MKFill.none
            case .pathText(let n): return n.style.highlightColor.map { MKFill.solid($0) } ?? MKFill.none
            default: return nil
            }
        }
        guard colors.count == session.selection.ids.count, !colors.isEmpty else { return .empty }
        return Self.aggregate(colors)
    }

    /// P5.6: widened `MKSolidColor` → `MKSolidColor?` so callers can
    /// express "clear the highlight" (`nil`) as well as "set it". This is
    /// SOURCE-COMPATIBLE with every existing call site: Swift implicitly
    /// promotes a non-optional `MKSolidColor` argument to the `Optional`
    /// parameter, so `setHighlightColor(someColor)` call sites compile
    /// unchanged; only a NEW `setHighlightColor(nil)` call site (the
    /// "remove highlight" action, added in `FontSettingsSheet`/
    /// `InspectorPanelView`) needed the widened signature at all.
    public func setHighlightColor(_ color: MKSolidColor?) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.highlightColor = color
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.highlightColor = color
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        let label = color == nil ? "إزالة التظليل" : "لون التظليل"
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: label))
    }

    // MARK: - Background color (P5.2)

    /// The canvas background's solid color, when its content is
    /// `.solid` (v1's only free-tier background kind ، `.image`
    /// backgrounds are premium content this inspector-level color entry
    /// point doesn't manage). Falls back to white when the background is
    /// currently an image, matching `MKBackgroundNode`'s own default.
    public var backgroundColorValue: MKSolidColor {
        if case .solid(let color) = session.scene.background.content { return color }
        return .white
    }

    /// Sets the canvas background to a solid color (`MKBackgroundContent
    /// .solid`). `BackgroundDrawer` already renders this case ، this is
    /// the missing entry point (P5.2). Unlike every other `InspectorModel`
    /// setter, this does NOT depend on `session.selection` ، the
    /// background is a single always-present node, not a selectable one
    /// (`LayersPanelView` deliberately excludes it from selection-gated
    /// row actions).
    public func setBackgroundColor(_ color: MKSolidColor) {
        var background = session.scene.background
        background.content = .solid(color)
        try? session.perform(MKReplaceNodesCommand(newNodes: [background.core.id: .background(background)], label: "لون الخلفية"))
    }

    // MARK: - Background image (P5.3)

    /// The canvas background's image asset ref, when its content is
    /// `.image` ، `nil` (not "no image", genuinely absent) when the
    /// background is currently `.solid`. Entitlement is NOT checked here
    /// (this is a pure read of whatever the scene already contains) ،
    /// callers that mutate go through the app-target command layer
    /// (`EditorViewModel.setBackgroundImage`), which gates BEFORE ever
    /// reaching `setBackgroundImage(_:fit:)` below, matching the P3.2
    /// asset-placement precedent.
    public var backgroundImageRef: MKAssetRef? {
        if case .image(let ref, _) = session.scene.background.content { return ref }
        return nil
    }

    public var backgroundImageFitValue: MKBackgroundImageFit? {
        if case .image(_, let fit) = session.scene.background.content { return fit }
        return nil
    }

    /// Sets the canvas background to an image asset already stored in the
    /// document's asset store (`MKAssetStore.storeAsset(data:ext:)` ،
    /// entitlement/ingestion/downscaling are all upstream of this call,
    /// see `EditorViewModel.setBackgroundImage(data:ext:entitlement:)`).
    /// This method itself performs NO gating ، same "the model exposes the
    /// primitive, the app-target command layer gates it" split
    /// `setBackgroundColor` already uses for the free-tier case, except
    /// here the app-target layer's check is load-bearing (D-119: photo
    /// backgrounds are premium).
    public func setBackgroundImage(_ ref: MKAssetRef, fit: MKBackgroundImageFit = .cover) {
        var background = session.scene.background
        background.content = .image(ref, fit: fit)
        try? session.perform(MKReplaceNodesCommand(newNodes: [background.core.id: .background(background)], label: backgroundImageLabel))
    }

    /// Changes only the fit mode of an already-set image background ،
    /// a no-op if the background isn't currently `.image` (nothing to
    /// re-fit).
    public func setBackgroundImageFit(_ fit: MKBackgroundImageFit) {
        guard case .image(let ref, let currentFit) = session.scene.background.content, currentFit != fit else { return }
        setBackgroundImage(ref, fit: fit)
    }

    /// Reverts the background to a solid color (`fallback`, default
    /// white) ، the "Remove" control in §2.5's Fit/Edit/Remove trio. A
    /// no-op (still applies the fallback color harmlessly) when the
    /// background is already `.solid`; callers normally guard on
    /// `backgroundImageRef != nil` before offering this action at all.
    public func removeBackgroundImage(fallback: MKSolidColor = .white) {
        var background = session.scene.background
        background.content = .solid(fallback)
        try? session.perform(MKReplaceNodesCommand(newNodes: [background.core.id: .background(background)], label: removeBackgroundImageLabel))
    }

    // Latin gloss: background image
    private var backgroundImageLabel: String { "صورة الخلفية" }
    // Latin gloss: remove background image
    private var removeBackgroundImageLabel: String { "إزالة صورة الخلفية" }

    /// Changes the font on every selected live/path-text node. Issues a
    /// single `MKReplaceNodesCommand` (undo entry: "خط") ، the whole node
    /// is replaced because `MKTextStyle` lives on the node content, not
    /// `MKNodeCore`, so `MKBatchCoreCommand` can't reach it.
    public func setFont(_ fontRef: MKFontRef) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.font = fontRef
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.font = fontRef
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "خط"))
    }

    public var pointSizeValue: Value<Double> {
        let sizes: [Double] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.pointSize
            case .pathText(let n): return n.style.pointSize
            default: return nil
            }
        }
        guard sizes.count == session.selection.ids.count, !sizes.isEmpty else { return .empty }
        return Self.aggregate(sizes)
    }

    public func setPointSize(_ size: Double) {
        let clamped = max(1, min(1000, size))
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.pointSize = clamped
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.pointSize = clamped
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "حجم"))
    }

    // MARK: - Traits (Bold / Italic / Underline / Strikethrough)

    public var isBoldValue: Value<Bool> {
        let values: [Bool] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.isBold
            case .pathText(let n): return n.style.isBold
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    public func setBold(_ isBold: Bool) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.isBold = isBold
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.isBold = isBold
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "خط عريض"))
    }

    public var isItalicValue: Value<Bool> {
        let values: [Bool] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.isItalic
            case .pathText(let n): return n.style.isItalic
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    public func setItalic(_ isItalic: Bool) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.isItalic = isItalic
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.isItalic = isItalic
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "خط مائل"))
    }

    public var isUnderlineValue: Value<Bool> {
        let values: [Bool] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.isUnderline
            case .pathText(let n): return n.style.isUnderline
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    public func setUnderline(_ isUnderline: Bool) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.isUnderline = isUnderline
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.isUnderline = isUnderline
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "تسطير"))
    }

    public var isStrikethroughValue: Value<Bool> {
        let values: [Bool] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.isStrikethrough
            case .pathText(let n): return n.style.isStrikethrough
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    public func setStrikethrough(_ isStrikethrough: Bool) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.isStrikethrough = isStrikethrough
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.isStrikethrough = isStrikethrough
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "خط في النص"))
    }

    // MARK: - Tracking, Baseline Shift, Line Height, Ligature

    public var trackingValue: Value<Double> {
        let values: [Double] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.tracking
            case .pathText(let n): return n.style.tracking
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    public func setTracking(_ tracking: Double) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.tracking = tracking
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.tracking = tracking
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "التباعد"))
    }

    public var baselineShiftValue: Value<Double> {
        let values: [Double] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.baselineShift
            case .pathText(let n): return n.style.baselineShift
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    public func setBaselineShift(_ baselineShift: Double) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.baselineShift = baselineShift
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.baselineShift = baselineShift
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "إزاحة الأساس"))
    }

    public var lineHeightMultipleValue: Value<Double> {
        let values: [Double] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.lineHeightMultiple
            case .pathText(let n): return n.style.lineHeightMultiple
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    public func setLineHeightMultiple(_ lineHeightMultiple: Double) {
        var newNodes: [MKNodeID: MKNode] = [:]
        for id in session.selection.ids {
            guard let node = session.scene.node(id: id) else { continue }
            switch node {
            case .liveText(var n):
                n.style.lineHeightMultiple = lineHeightMultiple
                newNodes[id] = .liveText(n)
            case .pathText(var n):
                n.style.lineHeightMultiple = lineHeightMultiple
                newNodes[id] = .pathText(n)
            default: continue
            }
        }
        guard !newNodes.isEmpty else { return }
        try? session.perform(MKReplaceNodesCommand(newNodes: newNodes, label: "ارتفاع السطر"))
    }

    public var ligatureSettingValue: Value<MKLigatureSetting> {
        let values: [MKLigatureSetting] = session.selection.ids.compactMap { id in
            switch session.scene.node(id: id) {
            case .liveText(let n): return n.style.ligatureSetting
            case .pathText(let n): return n.style.ligatureSetting
            default: return nil
            }
        }
        guard values.count == session.selection.ids.count, !values.isEmpty else { return .empty }
        return Self.aggregate(values)
    }

    private func applyStyle(_ mutate: (inout MKStyle) -> Void) {
        var newCores: [MKNodeID: MKNodeCore] = [:]
        for id in session.selection.ids {
            guard var core = session.scene.node(id: id)?.core else { continue }
            mutate(&core.style)
            newCores[id] = core
        }
        guard !newCores.isEmpty else { return }
        try? session.perform(MKBatchCoreCommand(gestureID: currentGestureID(), newCores: newCores, label: "تنسيق"))
    }

    /// Resizes every selected node to `newWidth`/`newHeight` (`nil` = keep
    /// that dimension) about ITS OWN center (task 11: "typing W=200
    /// resizes about selection center"). Requires `session.geometrySource`
    /// (WS-07 dependency) ، a no-op until that seam is wired.
    public func setSize(width newWidth: CGFloat?, height newHeight: CGFloat?) {
        guard let geometrySource = session.geometrySource else { return }
        var newTransforms: [MKNodeID: MKTransform2D] = [:]
        for id in session.selection.ids {
            guard let obb = geometrySource.worldOBB(for: id, in: session.scene),
                  let transform = session.scene.node(id: id)?.core.transform else { continue }
            // Same intrinsic-bounds rule `HandleGestures` uses (and for the
            // same reason ، typing a width teleported shapes/images/path
            // text/arranged compositions exactly like dragging a corner
            // handle did): `derivingTransform` must be handed the rect
            // `worldOBB` was actually built from.
            let intrinsic = HandleGestures.intrinsicBounds(
                for: id, obb: obb, transform: transform, geometrySource: geometrySource, scene: session.scene)
            let newSize = CGSize(width: newWidth ?? obb.size.width, height: newHeight ?? obb.size.height)
            let newOBB = MKOrientedRect(center: obb.center, size: newSize, rotation: obb.rotation)
            newTransforms[id] = newOBB.derivingTransform(localBounds: intrinsic)
        }
        guard !newTransforms.isEmpty else { return }
        try? session.perform(MKBatchTransformCommand(gestureID: currentGestureID(), newTransforms: newTransforms))
    }
}
