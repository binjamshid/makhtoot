import CoreGraphics
import MKFoundation
import MKModel

// WS-08 packet §5 task 5. `(request, entitlementState, contentFlags) ->
// allowed | blocked(reason)`. Amended by D-229 (Run-2 gating-enforcement
// closures ، all folded in here, not left as a future pass):
//
//   (1) `premiumContentPresent` iterates ALL nodes regardless of
//       `isHidden`/`isLocked` ، presence-based, not render-based.
//   (2) A free-tier preset-membership check (G20) is enforced HERE (engine
//       level), not only in UI.
//   (3) The `AllPremium*`/`AllFree*`-style test-only entitlement stubs
//       this gate is tested against live ONLY in `Tests/MKExportTests`
//       (`FakeEntitlementResolver`), never in this module's own sources ،
//       D-229(3)'s "no non-test/non-composition-root reference" rule is
//       satisfied structurally (the fake type does not exist here at all).
//
// **Known gap, not fixed here (documented, matching the WS-14 precedent of
// flagging a cross-fence gap rather than silently working around it)**:
// "premium assets flag from WS-14" (packet task 5's third `contentFlags`
// input) cannot be recomputed from a bare `MKScene` today ،
// `docs/impl-log/WS-14.md`'s own cross-packet coordination note #1/#2
// records that pattern-background/asset placements are NOT tagged on
// `MKNodeCore` (`sourceAssetID` was proposed, never landed ، out of every
// fenced session's `MKModel` scope so far) and `MKAssets.
// MKPremiumContentLedger` is a caller-maintained side ledger, not scene
// state. `premiumContentPresent(in:premiumAssetNodeIDs:)` below therefore
// accepts an OPTIONAL externally-supplied `Set<MKNodeID>` (the caller's own
// `MKPremiumContentLedger`-derived set) rather than adding an
// `MKExport → MKAssets` dependency edge (not in DEPENDENCY_GRAPH.md's
// module graph, and out of this session's Package.swift-fence judgment ،
// see `docs/impl-log/WS-08.md` for the full reasoning). Defaults to empty,
// so the two structurally-recoverable flags (fonts, photo backgrounds)
// still gate correctly with zero caller wiring.
public enum MKPremiumContentItem: Sendable, Equatable, Hashable {
    case premiumOrImportedFont(fontID: String, postScriptName: String)
    case photoBackground(nodeID: MKNodeID)
    case premiumAsset(nodeID: MKNodeID)
}

public enum MKExportBlockReason: Sendable, Equatable, Hashable {
    case formatRequiresPremium(MKExportFormat)
    case customDimensionsRequirePremium
    case presetRequiresPremium(presetID: String)
    case unknownPreset(presetID: String)
    case transparentBackgroundNotSupported(MKExportFormat)
    case premiumContentPresent(items: [MKPremiumContentItem])
    case invalidTargetSize
}

public enum MKExportGateDecision: Sendable, Equatable {
    case allowed(resolvedPixelSize: CGSize)
    case blocked(MKExportBlockReason)

    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

public struct MKExportGate: Sendable {
    public let fontLicense: any FontLicenseProviding
    public let presets: MKExportPresetCatalog

    public init(fontLicense: any FontLicenseProviding = AllOFLLicenseStub(), presets: MKExportPresetCatalog = .standard) {
        self.fontLicense = fontLicense
        self.presets = presets
    }

    /// D-229(1): presence-based `premiumContentPresent` walk. Visits the
    /// background node PLUS every top-level/nested node in `scene.nodes`
    /// (recursing into groups) regardless of `core.isHidden`/`isLocked` ،
    /// a hidden premium layer still counts (T-EXP-16).
    public func premiumContentPresent(in scene: MKScene, premiumAssetNodeIDs: Set<MKNodeID> = []) -> [MKPremiumContentItem] {
        var items: [MKPremiumContentItem] = []

        func noteFont(_ fontRef: MKFontRef) {
            guard fontLicense.isLockableFont(fontRef) else { return }
            items.append(.premiumOrImportedFont(fontID: fontRef.fontID, postScriptName: fontRef.postScriptName))
        }

        func visit(_ node: MKNode) {
            if premiumAssetNodeIDs.contains(node.id) {
                items.append(.premiumAsset(nodeID: node.id))
            }
            switch node {
            case .liveText(let n):
                noteFont(n.style.font)
            case .pathText(let n):
                noteFont(n.style.font)
            case .arranged(let n):
                noteFont(n.composition.sourceBackup.style.font)
            case .image(let n):
                if n.isPhotoBackgroundUse {
                    items.append(.photoBackground(nodeID: n.core.id))
                }
            case .shape:
                break
            case .group(let g):
                for child in g.children { visit(child) }
            case .background:
                break
            }
        }

        if case .image = scene.background.content {
            items.append(.photoBackground(nodeID: scene.background.core.id))
        }
        for node in scene.nodes { visit(node) }
        return items
    }

    /// Free-tier-resolved (task 6 clamp applied) or premium-native pixel
    /// size for `request.target`. `nil` on an unknown preset id or a
    /// degenerate (`<= 0`) size.
    public func resolvedPixelSize(for request: MKExportRequest, isPremiumUser: Bool) -> CGSize? {
        let base: CGSize
        switch request.target {
        case .preset(let id):
            guard let preset = presets.preset(id: id) else { return nil }
            base = preset.pixelSize
        case .custom(let size):
            base = size
        }
        guard base.width > 0, base.height > 0 else { return nil }
        return isPremiumUser ? base : MKFreeTierBudget.clamped(base)
    }

    /// The full D-119/D-229 truth table in one call. `entitlement` is read
    /// ONCE at the top (matches ARCHITECTURE §16.2's "entitlement frozen at
    /// snapshot creation ، one read" ، the caller passes a resolver whose
    /// `.state` is already the frozen snapshot value, e.g.
    /// `StubEntitlementResolver`/a `FakeEntitlementResolver` in tests).
    public func evaluate(
        _ request: MKExportRequest, scene: MKScene, entitlement: any MKEntitlementProviding,
        premiumAssetNodeIDs: Set<MKNodeID> = []
    ) -> MKExportGateDecision {
        let isPremiumUser = entitlement.state.grantsPremiumAccess

        if !isPremiumUser, !request.format.isFreeTierFormat {
            return .blocked(.formatRequiresPremium(request.format))
        }

        if request.background == .transparent, !request.format.supportsTransparentBackground {
            return .blocked(.transparentBackgroundNotSupported(request.format))
        }

        switch request.target {
        case .preset(let id):
            guard let preset = presets.preset(id: id) else {
                return .blocked(.unknownPreset(presetID: id))
            }
            // G20 (D-229(2)): engine-level free-tier preset membership check.
            if !isPremiumUser, !preset.freeTierEligible {
                return .blocked(.presetRequiresPremium(presetID: id))
            }
        case .custom:
            if !isPremiumUser {
                return .blocked(.customDimensionsRequirePremium)
            }
        }

        if !isPremiumUser {
            let items = premiumContentPresent(in: scene, premiumAssetNodeIDs: premiumAssetNodeIDs)
            if !items.isEmpty {
                return .blocked(.premiumContentPresent(items: items))
            }
        }

        guard let resolved = resolvedPixelSize(for: request, isPremiumUser: isPremiumUser) else {
            return .blocked(.invalidTargetSize)
        }
        switch MKCustomDimensionValidator.validate(resolved) {
        case .tooSmall: return .blocked(.invalidTargetSize)
        case .ok, .warnDiskFeasibility: break
        }
        return .allowed(resolvedPixelSize: resolved)
    }
}
