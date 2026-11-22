// swift-tools-version: 6.0
// MakhtootKit ، local Swift package for Makhtoot (مخطوط).
// Owner: WS-01 (AGENT_TASK_PACKETS/WS-01-scaffold-designsystem.md).
// Layout, target list, and dependency edges mirror FOUNDATION.md §2 and
// FILE_MAP.md §4 exactly. D-101: zero third-party dependencies in v1 ، the
// `dependencies:` array below must stay empty forever in v1.
//
// Test-target scope note (deviation from the FILE_MAP §4.2 sketch, logged in
// docs/impl-log/WS-01.md): only `MKFoundationTests` and `MKDesignSystemTests`
// were declared by WS-01, per WS-01 packet §5 task 20 / §8 deliverables. The
// other module targets were stubs (owner = a later workstream); their test
// targets are added by the workstream that adds real, testable behavior to
// the module, not speculatively here. `MKModelTests`/`MKPersistenceTests`
// below were added by WS-02 (AGENT_TASK_PACKETS/WS-02-model-persistence.md)
// ، see docs/impl-log/WS-02.md.

import PackageDescription

let package = Package(
    name: "MakhtootKit",
    defaultLocalization: "ar",
    // iOS 18 is the shipped deployment target (D-100). macOS is declared
    // too, at a version new enough for `os.Logger`/`OSSignposter`, purely
    // so `swift build`/`swift test` work directly on the host toolchain
    // for fast local iteration (packet §5 task 2 accept criterion: "swift
    // build inside MakhtootKit/ compiles all targets") ، the app itself is
    // never built for macOS; only `xcodebuild` against the iOS destination
    // ships product.
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        // One library product per module so the app links exactly what it
        // needs and DEPENDENCY_GRAPH.md layering is enforced by the build.
        .library(name: "MKFoundation", targets: ["MKFoundation"]),
        .library(name: "MKModel", targets: ["MKModel"]),
        .library(name: "MKTextEngine", targets: ["MKTextEngine"]),
        .library(name: "MKArrange", targets: ["MKArrange"]),
        .library(name: "MKPathText", targets: ["MKPathText"]),
        .library(name: "MKCanvas", targets: ["MKCanvas"]),
        .library(name: "MKRender", targets: ["MKRender"]),
        .library(name: "MKColor", targets: ["MKColor"]),
        .library(name: "MKExport", targets: ["MKExport"]),
        .library(name: "MKFonts", targets: ["MKFonts"]),
        .library(name: "MKPersistence", targets: ["MKPersistence"]),
        .library(name: "MKSync", targets: ["MKSync"]),
        .library(name: "MKStore", targets: ["MKStore"]),
        .library(name: "MKAnalytics", targets: ["MKAnalytics"]),
        .library(name: "MKDesignSystem", targets: ["MKDesignSystem"]),
        .library(name: "MKAssets", targets: ["MKAssets"]),
    ],
    dependencies: [],   // D-101: zero third-party dependencies in v1
    targets: [
        // MARK: - WS-01 owned, fully implemented
        .target(name: "MKFoundation"),
        .target(name: "MKDesignSystem", dependencies: ["MKFoundation"]),

        // MARK: - Stub targets (owner named in each <Module>Placeholder.swift)
        .target(name: "MKModel", dependencies: ["MKFoundation"]),
        // WS-09: real implementation lands with bundled-font resources
        // (Resources/Fonts/<Family>, Resources/LicenseRecords,
        // Resources/*.md, Resources/catalog-seed.json ، FILE_MAP §14's
        // tree) declared as SPM package resources (`Bundle.module`), NOT
        // as Makhtoot.xcodeproj/pbxproj resources ، see
        // docs/impl-log/WS-09.md for the deviation note against the
        // packet's own "you own pbxproj edits this wave" line: FILE_MAP
        // §14's concrete resource tree is declared entirely under
        // `Sources/MKFonts/Resources/`, which is package-resource
        // territory per WS-13's own note (`docs/impl-log/WS-13.md`) that
        // MakhtootKit's local-package resources are governed by
        // `Package.swift`'s `resources:` array, not pbxproj surgery ، so
        // FILE_MAP was followed as the more concrete, authoritative
        // file-placement source. README.md is module docs, not a
        // resource, same pattern as MKTextEngine/MKRender below.
        .target(
            name: "MKFonts",
            dependencies: ["MKFoundation", "MKPersistence"],
            exclude: ["README.md"],
            resources: [
                .copy("Resources/Fonts"),
                .copy("Resources/LicenseRecords"),
                .copy("Resources/catalog-seed.json"),
                .copy("Resources/VERIFICATION_PROTOCOL.md"),
                .copy("Resources/EXCLUDED_FONTS.md"),
                .copy("Resources/PremiumCatalog"),
            ]
        ),
        // MKModel edge added by WS-03's P3-completion pass: FOUNDATION §2's
        // table row lists only "MKFoundation, MKFonts (font handles)", but
        // the WS-03 packet's own §3 upstream list ("WS-02: MKTextStyle,
        // MKFontRef, JoiningForm, MKBezierPathData"), PLAN P3's entry
        // criteria ("P2 MKModel types available for provenance structs"),
        // and DEPENDENCY_GRAPH's P2→P3 soft edge ("provenance structs
        // finalize against MKModel types late in P3") all require the
        // engine to consume MKModel types directly. Logged as a proposed
        // deviation in docs/impl-log/WS-03.md. No cycle: MKModel depends
        // only on MKFoundation.
        .target(
            name: "MKTextEngine",
            dependencies: ["MKFoundation", "MKFonts", "MKModel"],
            exclude: ["README.md"]   // module docs, not a resource
        ),
        // WS-04: `MKFoundation` and `MKPersistence` added alongside the
        // FOUNDATION §2 edge (`MKModel`, `MKTextEngine`) ، same reasoning
        // WS-07/WS-06 already logged for their own targets just above/below
        // this one. `MKFoundation`: `MKModel`/`MKTextEngine` don't
        // re-export it, and this target's public API spells `MKNodeID`,
        // `MKFontProviding`, `MKID`, `MKError` directly (`ArrangeDeriver`,
        // `PathPlacementProviding`, `ArrangeInvariants`). `MKPersistence`:
        // the packet's own mission statement requires every arrange
        // mutation to be expressed as an `MKCommand` ("Everything is
        // expressed as MKCommands over the value-type scene (WS-02 undo
        // stack), so every arrange operation is undoable and autosaved") ،
        // `MKCommand`, `MKScene` mutation helpers, and `MKReplaceNodeCommand`
        // (the documented "opaque replace... WS-04/WS-05 build on" primitive,
        // `MKPersistence/Undo/Commands.swift`) all live in `MKPersistence`.
        // Logged in `CONTRACTS.md` and `docs/impl-log/WS-04.md`. No cycle:
        // `MKPersistence` depends only on `MKModel`/`MKFoundation`.
        //
        // Known gap carried forward (not fixed here, out of this packet's
        // fence): `MKArrange`'s new `MKCommand` conformers
        // (`ArrangeCommands.swift`) are NOT registered in
        // `MKPersistence/Undo/MKCommandCoder.swift`'s closed switch (that
        // file is `MKPersistence` source, outside this packet's fence) ،
        // journal-replay (`CommandJournal.append`) will throw
        // `unknownCommandType` for them today, mirroring WS-06's initial
        // canvas-command situation (CONTRACTS.md "MKCanvas... consumption
        // seam" section) before it was canonicalized. Flagged here for
        // whoever next owns `MKCommandCoder` to canonicalize, same pattern.
        .target(
            name: "MKArrange",
            dependencies: ["MKFoundation", "MKModel", "MKTextEngine", "MKPersistence"],
            exclude: ["README.md"]   // module docs, not a resource ، same pattern as MKTextEngine/MKRender above
        ),
        // WS-05 (AGENT_TASK_PACKETS/WS-05-path-text.md), P7: `MKFoundation`
        // added alongside the FOUNDATION §2 edge (`MKModel`, `MKTextEngine`)
        // ، same empirically-verified reasoning WS-03/06/07 already logged
        // for their own targets (`MKModel`/`MKTextEngine` don't
        // `@_exported import MKFoundation`, and this target's public API
        // spells `MKID`/`MKGlyphAddress`/`MKClusterID` by name directly:
        // `BezierPathModel.swift`, `PathGlyphPlacement.swift`,
        // `PathTextCommands.swift`). `MKPersistence` added because
        // `PathTextCommands.swift` (task 11) builds `MKCommand`/
        // `MKReplaceNodesCommand` ، the canonical, journal-codable
        // node-replace primitive `MKArrange` already established the same
        // pattern for (`Sources/MKArrange/ArrangeCommands.swift`); no
        // cycle (`MKPersistence` depends only on `MKModel`/`MKFoundation`).
        // `MKArrange` added because `PathPlacementProvider.swift` (task 12)
        // conforms to `MKArrange.PathPlacementProviding` ، Swift requires
        // importing the module that DECLARES a protocol to conform to it,
        // and `MKArrange` never depends on `MKPathText` (its own deps are
        // `MKFoundation, MKModel, MKTextEngine, MKPersistence`), so this
        // edge is acyclic. All four logged in `CONTRACTS.md` and
        // `docs/impl-log/WS-05.md`, matching WS-03/06/07's own precedent
        // for packet-justified, additive dependency edges beyond
        // FOUNDATION §2's diagram.
        .target(
            name: "MKPathText",
            dependencies: ["MKFoundation", "MKModel", "MKTextEngine", "MKPersistence", "MKArrange"],
            exclude: ["README.md"]   // module docs, not a resource ، same pattern as MKTextEngine/MKRender/MKArrange above
        ),
        // WS-07: `MKFoundation` added alongside the FOUNDATION §2 /
        // DEPENDENCY_GRAPH.md edges (`MKModel`, `MKTextEngine`) ، both of
        // those already depend on MKFoundation but do not re-export it
        // (`@_exported import`), so any MKRender public API spelling a
        // MKFoundation type by name (`MKNodeID`, `MKTransform2D`,
        // `MKFontHandle`, `MKFontProviding`, `MKSignpost`, …) needs the
        // direct edge to compile ، verified empirically, not a new
        // architectural layer. Logged in `CONTRACTS.md` and
        // `docs/impl-log/WS-07.md`.
        //
        // `MKPathText` added by the two-item convergence pass
        // (`docs/impl-log/WS-07.md`'s append for this session):
        // `PathTextDrawer.swift` now adopts WS-05's real `ArcLengthLUT`/
        // `PathLayoutEngine` in place of its old self-contained polyline
        // stand-in (`MKPolylineArcLength`, this session's own deviation 5,
        // still kept for `HitTester`'s separate use) ، the exact seam
        // `CONTRACTS.md`'s "WS-05 (`MKPathText`)" section and
        // `Sources/MKPathText/README.md`'s "Seam WS-07 should adopt"
        // section describe. No cycle: `MKPathText` (and everything it
        // depends on ، `MKArrange`, `MKPersistence`, `MKTextEngine`,
        // `MKModel`, `MKFoundation`) contains no `import MKRender`
        // anywhere (verified by source grep), so this edge is acyclic.
        .target(
            name: "MKRender",
            dependencies: ["MKFoundation", "MKModel", "MKTextEngine", "MKPathText"],
            exclude: ["README.md"]   // module docs, not a resource ، same pattern as MKTextEngine above
        ),
        // WS-06: `MKFoundation` (same reasoning WS-07 logged just above ،
        // `MKModel`/`MKRender` don't re-export it, and this target's public
        // API spells `MKNodeID`/`MKTransform2D`/`MKID` directly) and
        // `MKDesignSystem` added alongside the FOUNDATION §2 edge
        // (`MKModel`, `MKRender`) ، the packet's own §3 "Upstream"
        // dependency list is explicit ("WS-01 (`MKDesignSystem` tokens for
        // chrome colors/handles)"), and `MKCanvasViewController`/
        // `SelectionChromeLayer` consume `MKTheme` (`canvasBackdrop`,
        // `selectionStroke`, `accent`, `backgroundElevated`) directly.
        // Logged in `docs/impl-log/WS-06.md` (mirrors WS-03-A5/WS-07's own
        // precedent for a packet-justified, additive dependency edge).
        .target(name: "MKCanvas", dependencies: ["MKFoundation", "MKModel", "MKRender", "MKDesignSystem"]),
        // WS-08: `exclude: ["README.md"]` ، module docs, not a resource,
        // same pattern as MKTextEngine/MKRender above. `MKColorSpec.swift`
        // is this session's whole P10-EARLY MKColor slice ، see
        // `Sources/MKColor/README.md` and `docs/impl-log/WS-08.md`.
        // Run-3 P10-COMPLETION (AGENT_TASK_PACKETS/WS-08-export-pipeline.md
        // §5 task 2, `docs/impl-log/WS-08.md`): `resources:` gains
        // `Resources/ICC/` ، the FD-03 bundled-CMYK-profile drop-in slot
        // (`ICCProfileStore.swift`). Ships EMPTY (only a README documenting
        // the drop-in contract) this session ، FD-03 is still
        // founder-pending; see that README for the no-code-change swap
        // path once a licensed profile is selected.
        .target(
            name: "MKColor", dependencies: ["MKFoundation"], exclude: ["README.md"],
            resources: [.copy("Resources/ICC")]
        ),
        // WS-08 (P10-EARLY, `docs/impl-log/WS-08.md`): `MKFoundation` added
        // explicitly alongside the FOUNDATION §2 edges ، same
        // empirically-verified reasoning WS-06/WS-07/WS-14 already logged
        // for their own targets above (`MKModel`/`MKRender`/`MKColor`/
        // `MKFonts` do not `@_exported import MKFoundation`, and this
        // target's public API spells `MKNodeID`, `MKEntitlementProviding`,
        // `MKEntitlementState`, `MKPremiumCapability` directly ،
        // `ExportGate.swift`/`ExportCoordinator.swift`). **`MKStore`
        // REMOVED** ، D-230 (DECISIONS_LOG.md, recovers ARCHITECTURE
        // §2.1's originally-orphaned decision) is explicit and founder-
        // adjacent-locked: "`MKExport` and `MKSync` must query
        // entitlements without depending on StoreKit... the module
        // dependency graph already shows `MKExport`/`MKSync` depending
        // only on `MKStoreAPI(protocols)`, not on `MKStore`" ، i.e. only
        // the `MKEntitlementProviding` PROTOCOL surface (declared in
        // `MKFoundation`, per D-230), never the concrete `MKStore` target.
        // The scaffolded `Package.swift` line this replaces had `MKStore`
        // as a real SPM target dependency, directly contradicting D-230's
        // own "Validation trigger" ("`MKExport` and `MKSync` import only
        // `MKFoundation`'s protocol surface, never `MKStore` directly").
        // Fixed here (in-fence: this packet's own Package.swift
        // declarations) rather than "stop and report" ، this brings the
        // manifest INTO compliance with an already-locked decision, not a
        // deviation from one. `MKSync`'s identical `MKStore` edge
        // (`Package.swift`, a few lines below) has the SAME defect and is
        // OUT of this packet's fence (WS-11 owns `MKSync`) ، flagged, not
        // fixed, in `docs/impl-log/WS-08.md`.
        // Run-3 P10-COMPLETION (AGENT_TASK_PACKETS/WS-08-export-pipeline.md,
        // `docs/impl-log/WS-08.md`): `MKTextEngine`/`MKPathText` added.
        // Neither is a NEW architectural layer ، both are already
        // transitive dependencies of `MKRender` (which `MKExport` already
        // depends on) ، but `MKExport`'s own PDF/SVG writers spell
        // `MKShapingEngine`/`MKShapingRequest`/`ArcLengthLUT`/
        // `PathLayoutEngine` BY NAME directly (`TextOutlining.swift`,
        // `SVGSerializer.swift`): the D-118/§16.5 per-license
        // text-vs-outline switch and the WS08-A5 "path text as placed
        // glyphs, no textPath" SVG rule both need OUR OWN shaping/placement
        // pass (never re-implemented ، the SAME engine
        // `MKRender/Drawers/LiveTextDrawer.swift`/`PathTextDrawer.swift`
        // already call), because the license-based outline substitution
        // and the SVG glyph-path serialization are `MKExport`-owned
        // concerns that `MKRender`'s drawers do not (and per D-118/§16.3
        // "no per-format drawing code", should not) implement themselves ،
        // see `TextOutlining.swift`'s header for the full "why not extend
        // MKRender instead" reasoning (same "explicit edge, verified
        // empirically" pattern WS-03/05/06/07/08 already logged for their
        // own targets). No cycle: neither `MKTextEngine` nor `MKPathText`
        // imports `MKExport`.
        .target(
            name: "MKExport",
            dependencies: ["MKFoundation", "MKModel", "MKRender", "MKColor", "MKFonts", "MKTextEngine", "MKPathText"],
            exclude: ["README.md", "ExportFallbacks.md", "SUBSETTING_FOLLOWUP.md"],
            resources: [.copy("Resources/presets.json")]
        ),
        .target(name: "MKPersistence", dependencies: ["MKModel", "MKFoundation"]),
        // WS-07 (the two-item convergence pass, `docs/impl-log/WS-07.md`'s
        // append for this session): `MKStore` REMOVED ، the identical D-230
        // defect WS-08 already fixed for `MKExport` just above (see that
        // target's own long comment for the full D-230 citation), flagged
        // as a cross-fence gap in `docs/impl-log/WS-08.md`'s "Cross-fence
        // gaps flagged" section #1 and fixed here. `DEPENDENCY_GRAPH.md`
        // draws `MKSync --> MKPersistence` as a solid (real target) edge
        // and `MKSync -.->|"entitlement protocol"| MKStore` as a DASHED
        // (protocol-only) edge ، i.e. `MKSync` should query entitlements
        // through `MKFoundation`'s `MKEntitlementProviding` protocol
        // surface (D-230), never link the concrete `MKStore` module.
        // `MKFoundation` added explicitly (`MKSyncPlaceholder.swift` is a
        // placeholder today and imports nothing yet, but the protocol
        // surface this edge exists for lives in `MKFoundation`, and
        // `MKPersistence` itself doesn't re-export it ، same "explicit
        // edge" precedent WS-06/07/08/14 already logged for their own
        // targets). Low-risk: `MKSync` is still a placeholder target (WS-11
        // owns the real implementation), so this is a pure manifest fix,
        // no source changes.
        // WS-11 (AGENT_TASK_PACKETS/WS-11-cloudkit-sync.md): real MKSync module
        // replacing the MKSyncPlaceholder stub. Depends on `MKPersistence`
        // (MetadataStore, MKProjectChange, MKTombstoneRecord, DocumentPackage)
        // and `MKFoundation` (MKEntitlementProviding for D-230 compliance ،
        // MKStore is NOT a dependency per D-230). CloudKit and CryptoKit are
        // system frameworks (no SPM entry). `exclude:` lists the three Docs/
        // markdown deliverables (T1 CloudKitSchema.md, T15 SyncPrivacy.md,
        // T16 SyncManualTests.md) ، module docs, not SPM resources, same
        // pattern MKTextEngine/MKRender/MKStore already use above.
        .target(
            name: "MKSync",
            dependencies: ["MKPersistence", "MKFoundation"],
            exclude: [
                "Docs/CloudKitSchema.md",
                "Docs/SyncPrivacy.md",
                "Docs/SyncManualTests.md",
            ]
        ),
        // WS-10 (AGENT_TASK_PACKETS/WS-10-storekit-entitlements.md) ،
        // see docs/impl-log/WS-10.md. `exclude:` lists every Markdown doc
        // this target ships (module docs, not SPM resources ، same
        // pattern MKTextEngine/MKRender/MKExport/MKAssets already use
        // above): `Docs/*.md` (T7/T12/T10/T18 deliverables) and
        // `Referral/REVIEW_RISK_MEMO.md` (T15) ، the latter sits inside
        // the `#if MAKHTOOT_REFERRAL_ENABLED`-gated `Referral/` folder but
        // is itself plain prose, not compiled Swift, so it needs its own
        // `exclude:` entry regardless of the flag.
        .target(
            name: "MKStore",
            dependencies: ["MKFoundation"],
            exclude: [
                "Docs/TrialModel.md",
                "Docs/SandboxTestPlan.md",
                "Docs/PaywallRequirements.md",
                "Docs/ServerAPISeam.md",
                "Referral/REVIEW_RISK_MEMO.md",
            ],
            resources: [.copy("Makhtoot.storekit")],
            // D-327 (founder, 2026-08-07): FD-05 granted for iOS. This define
            // activates the `Referral/` folder in EVERY configuration,
            // including Release ، which is precisely the clause of D-225 that
            // D-327 amends ("set ONLY in Debug/internal build configurations,
            // never in Release"). The app target carries the matching
            // definition in project.pbxproj; both are required, because
            // SWIFT_ACTIVE_COMPILATION_CONDITIONS does not propagate from the
            // Xcode target into SPM package targets.
            //
            // Unconditional rather than `.when(configuration:)`: the feature
            // is now meant to ship, and a define that differed between Debug
            // and Release would reintroduce exactly the Debug/Release
            // divergence D-225 flagged as a downside.
            //
            // TO REVERT to D-225 behaviour: delete this `swiftSettings` block
            // and the app-target condition. Nothing else needs to change ،
            // every referral file is `#if`-gated already.
            swiftSettings: [.define("MAKHTOOT_REFERRAL_ENABLED")]
        ),
        // WS-12 (AGENT_TASK_PACKETS/WS-12-analytics-settings.md): real
        // MKAnalytics module replacing the placeholder stub. Depends on
        // `MKFoundation` (MKFontUsageRecording, MKFeatureFlags, MKLog) and
        // `MKPersistence` (as declared in FOUNDATION §2 module map; currently
        // used for the MKAnalyticsStorage path helpers ، full SwiftData
        // integration is a deviation logged in docs/impl-log/WS-12.md §5).
        // `CloudKit` is a system framework (no SPM dependency entry needed).
        // `CryptoKit` is a system framework (same).
        // `exclude:` covers module docs (same pattern MKStore/MKExport use).
        .target(
            name: "MKAnalytics",
            dependencies: ["MKFoundation", "MKPersistence"],
            exclude: ["Docs/AnalyticsSchema.md", "Docs/PrivacyNutrition.md"]
        ),
        // WS-14: `MKFoundation` added alongside the FOUNDATION §2 edge
        // (`MKModel`) ، same empirically-verified reasoning WS-06/WS-07
        // already logged for their own targets (`MKModel` does not
        // `@_exported import MKFoundation`, so any public API here spelling
        // a MKFoundation type by name ، `MKNodeID` on `MKPlacementRecord`,
        // `MKEntitlementProviding`/`MKPremiumCapability` on
        // `MKAssetBrowserModel` ، needs the direct edge to compile). Logged
        // in `docs/impl-log/WS-14.md` and `CONTRACTS.md`.
        .target(
            name: "MKAssets", dependencies: ["MKFoundation", "MKModel"],
            exclude: ["README.md"],   // module docs, not a resource ، same pattern as MKTextEngine/MKRender above
            resources: [
                .copy("Resources/assets-manifest.json"),
                .copy("Resources/provenance-records.json"),
                .copy("Resources/ASSET_SOURCING_RULES.md"),
            ]
        ),

        // MARK: - Test targets (supporting evidence, not a v1 gate ، Q59)
        .testTarget(name: "MKFoundationTests", dependencies: ["MKFoundation"]),
        .testTarget(name: "MKDesignSystemTests", dependencies: ["MKDesignSystem"]),
        // Added by WS-03 (AGENT_TASK_PACKETS/WS-03-text-engine.md) once
        // MKTextEngine gained real, testable behavior ، see
        // docs/impl-log/WS-03.md.
        .testTarget(name: "MKTextEngineTests", dependencies: ["MKTextEngine"]),
        // Added by WS-02 (AGENT_TASK_PACKETS/WS-02-model-persistence.md) ،
        // see docs/impl-log/WS-02.md. The shared fixture library (packet §5
        // task 19) lives in `Tests/Fixtures/`, a SIBLING of both test
        // target directories, not inside either one ، SPM `resources:`
        // paths may not escape their own target directory (`.copy("../…")`
        // fails manifest validation), so fixtures are NOT declared as an
        // SPM resource. Instead `MKFixtureLocator` (in each test target)
        // resolves `Tests/Fixtures/` via `#filePath`, which every test
        // target ، including WS-06/07/08's own, later ، can reuse the same
        // way without a resource-bundle indirection.
        // `MKModelTests` depends on `MKPersistence` too (test-only
        // convenience, not a layering violation ، DEPENDENCY_GRAPH.md's
        // edges govern shipped library targets; a test target may import
        // whatever helps it test) so both test targets can generate/read
        // the exact same `.makhtoot` package fixtures via
        // `FixtureGenerator`/`MKFixtureLocator` (duplicated verbatim into
        // both target directories ، see the note at the top of either
        // copy).
        .testTarget(name: "MKModelTests", dependencies: ["MKModel", "MKPersistence"]),
        .testTarget(name: "MKPersistenceTests", dependencies: ["MKPersistence", "MKModel"]),
        // Added by WS-07 (AGENT_TASK_PACKETS/WS-07-rendering-performance.md)
        // once MKRender gained real, testable behavior ، see
        // docs/impl-log/WS-07.md. Reuses the `Tests/Fixtures/` sibling
        // directory via its own `MKFixtureLocator` copy, same pattern as
        // MKModelTests/MKPersistenceTests (see the note on that pattern
        // above).
        // `MKPersistence` added by the P14 hardening pass
        // (`docs/impl-log/WS-07-p14-run3.md`, memory-stress-drive item):
        // test-only convenience, same established "a test target may
        // import whatever helps it test" pattern `MKModelTests`/
        // `MKCanvasTests`/`MKArrangeTests` already document above (this is
        // NOT a `Sources/MKRender` dependency-graph change ، the shipped
        // library target's own deps, three lines up, are untouched).
        // `MemoryStressDriveTests.swift`'s 5000-node save-before-degrade +
        // zero-loss-relaunch evidence needs a REAL `DocumentPackage`/
        // `AutosaveController`/`CommandJournal` (not a fake) wired to a
        // real `MKDegradationController`, so it can prove the on-disk
        // journal/scene state survives a forced stage1→critical walk and a
        // subsequent `MakhtootDocument.open` ، that combination only
        // exists once this target can see both `MKRender` (the ladder)
        // and `MKPersistence` (the durable store) at once. Precedented:
        // `MKArrangeTests` already depends on `MKPersistence` + `MKRender`
        // + `MKModel` + `MKFoundation` + `MKTextEngine` simultaneously.
        .testTarget(name: "MKRenderTests", dependencies: ["MKFoundation", "MKModel", "MKTextEngine", "MKRender", "MKPersistence"]),
        // Added by WS-06 (AGENT_TASK_PACKETS/WS-06-canvas-interaction.md) ،
        // see docs/impl-log/WS-06.md. Depends on `MKPersistence` directly
        // (test-only convenience, same pattern `MKModelTests` documents
        // above) so tests can drive a real `MakhtootDocument` end to end
        // (open/apply/undo/redo) rather than mocking the document layer.
        .testTarget(name: "MKCanvasTests", dependencies: ["MKFoundation", "MKModel", "MKPersistence", "MKRender", "MKDesignSystem", "MKCanvas"]),
        // Added by WS-04 (AGENT_TASK_PACKETS/WS-04-arrange-engine.md) once
        // MKArrange gained real, testable behavior ، see
        // docs/impl-log/WS-04.md. `MKTextEngine`/`MKRender` are test-only
        // conveniences (same pattern the targets above document): the
        // fidelity suite renders through `MKRender.MKSnapshotRenderer`
        // directly rather than re-deriving a local CG rasterizer (the
        // packet's task 3 fallback ، "until then, a local CG rasterizer in
        // tests" ، is unnecessary since WS-07's real renderer already
        // exists in this repo). Reuses the `Tests/Fixtures/` sibling
        // directory via its own `MKFixtureLocator` copy, same pattern as
        // the other test targets above.
        .testTarget(name: "MKArrangeTests", dependencies: ["MKFoundation", "MKModel", "MKTextEngine", "MKPersistence", "MKRender", "MKArrange"]),
        // Added by WS-14 (AGENT_TASK_PACKETS/WS-14-assets-ornaments.md) ،
        // see docs/impl-log/WS-14.md.
        .testTarget(name: "MKAssetsTests", dependencies: ["MKFoundation", "MKModel", "MKAssets"]),
        // Added by WS-09 (AGENT_TASK_PACKETS/WS-09-fonts-licensing.md) ،
        // see docs/impl-log/WS-09.md. Depends on `MKTextEngine` (test-only
        // convenience, same established pattern as MKCanvasTests/
        // MKRenderTests above) so the T-TXT-5/T-TXT-7 per-font re-run
        // (docs/impl-log/WS-03.md's deferred item, this packet's job) can
        // drive real shaping through the newly-registered bundled fonts
        // via `MKRegistryFontProvider`, not just exercise MKFonts in
        // isolation.
        .testTarget(name: "MKFontsTests", dependencies: ["MKFonts", "MKFoundation", "MKTextEngine", "MKPersistence"]),
        // WS-16 (`docs/impl-log/WS-16-cursive.md`). Real-font (Amiri)
        // derivation-fidelity + join-break/decompose evidence for the D-222
        // step 8 cursive-attachment question, added as its OWN test target
        // rather than a new file inside `MKArrangeTests` ، a sibling agent
        // was actively working in `Sources/MKArrange`/`Tests/MKArrangeTests`
        // this run (WS-04), so this target calls `MKArrange`'s PUBLIC API
        // (`ArrangeDeriver`, `JoinController`, `LigatureDecomposer`,
        // `MKArrangedGeometry`) as a dependency, exactly like
        // `MKArrangeTests` itself does for `MKRender`, without editing any
        // file inside that module's own source/test directories (no
        // conflict surface with the concurrent WS-04 session). Registers
        // the real bundled Amiri binary directly by file URL (same
        // `NamedFontProvider`-by-`#filePath` pattern `ArrangeFixtures`/
        // `Fixtures` already use for Geeza Pro) rather than depending on
        // the `MKFonts` target, keeping this target's dependency list
        // minimal and matching the "do not touch MKFonts sources" scope
        // fence (this only READS the already-shipped font binary at test
        // time, exactly as WS-09's own `CoverageAnalysisTests` does).
        .testTarget(name: "WS16CursiveTests", dependencies: ["MKFoundation", "MKModel", "MKTextEngine", "MKPersistence", "MKRender", "MKArrange"]),
        // Added by WS-05 (AGENT_TASK_PACKETS/WS-05-path-text.md) once
        // MKPathText gained real, testable behavior ، see
        // docs/impl-log/WS-05.md. `MKPersistence` is a test-only
        // convenience (same established pattern `MKCanvasTests`/
        // `MKArrangeTests` already document above) so tests can build a
        // real `MKScene`/`MKReplaceNodesCommand` round trip rather than
        // hand-rolling scene mutation.
        .testTarget(
            name: "MKPathTextTests",
            dependencies: ["MKFoundation", "MKModel", "MKTextEngine", "MKPersistence", "MKArrange", "MKPathText"]
        ),
        // Added by WS-08 (AGENT_TASK_PACKETS/WS-08-export-pipeline.md,
        // P10-EARLY slice) ، see docs/impl-log/WS-08.md. Pure `MKColor`
        // unit tests plus the D-226 spike-evidence regression tests
        // (`CMYKSpikeEvidenceTests.swift`) ، no dependency beyond
        // `MKColor` itself is needed (the spike tests exercise raw
        // CoreGraphics/Foundation APIs directly, not any MKColor type).
        .testTarget(name: "MKColorTests", dependencies: ["MKColor"]),
        // Added by WS-08 (AGENT_TASK_PACKETS/WS-08-export-pipeline.md,
        // P10-EARLY slice) ، see docs/impl-log/WS-08.md. `MKPersistence`
        // is NOT a dependency here (unlike several sibling test targets'
        // "test-only convenience" pattern) ، every fixture this target
        // needs is a plain `MKScene`/`MKNode` value built directly via
        // `MKModel`'s own public initializers; no command/undo-stack
        // round trip is exercised.
        // Run-3 P10-COMPLETION: `MKTextEngine`/`MKPathText` added (test-only
        // convenience, same pattern documented on the `MKExport` target
        // itself above) so fixtures can build real shaped-text/path-text
        // scenes and assert against `MKShapingEngine` output directly.
        .testTarget(
            name: "MKExportTests",
            dependencies: ["MKFoundation", "MKModel", "MKRender", "MKColor", "MKFonts", "MKTextEngine", "MKPathText", "MKExport"]
        ),
        // Added by WS-12 (AGENT_TASK_PACKETS/WS-12-analytics-settings.md) ،
        // see docs/impl-log/WS-12.md. `MKFonts` is a test-only convenience
        // (same established pattern as sibling test targets above) so
        // integration tests can record usage for real font IDs from the
        // bundled catalog. `MKStore` is NOT a dependency (analytics knows
        // nothing about entitlements; it checks only consent, not
        // subscription tier).
        .testTarget(
            name: "MKAnalyticsTests",
            dependencies: ["MKAnalytics", "MKFoundation", "MKFonts"]
        ),
        // Added by WS-11 (AGENT_TASK_PACKETS/WS-11-cloudkit-sync.md) ،
        // see docs/impl-log/WS-11.md. Exercises pure-function business logic
        // (MKSyncDecisionEngine, MKConflictNaming, MKSyncErrorMapper,
        // MKSyncAccountState, MKSyncPendingQueue, MKSyncStatusPublisher,
        // MKSyncTunables). Two-device CloudKit tests (T-sync-01..06) are
        // environment-deferred: documented in Docs/SyncManualTests.md.
        // `MKPersistence`/`MKFoundation` are test-only conveniences (same
        // established pattern documented on sibling targets above) so tests
        // can construct MKProjectSummary values and use MKEntitlementProviding
        // stubs directly without re-implementing the types.
        .testTarget(
            name: "MKSyncTests",
            dependencies: ["MKSync", "MKPersistence", "MKFoundation"]
        ),
        // Added by WS-10 (AGENT_TASK_PACKETS/WS-10-storekit-entitlements.md)
        // ، see docs/impl-log/WS-10.md. `MKFoundation` is a test-only
        // convenience (same established pattern as sibling test targets
        // above) so precedence tests can construct `MKEntitlementState`
        // values directly. `MKExport`/`MKFonts`/`MKModel`/`MKPersistence`
        // are ALSO test-only convenience (same "a test target may import
        // whatever helps it test" pattern `MKModelTests`/`MKCanvasTests`
        // already establish above) ، T16's own AC requires an integration
        // test proving a real `MKEntitlementResolver` state change
        // propagates through BOTH WS-08's `MKExportGate` and WS-09's
        // `MKFontLockController` in one shot, exercising their real public
        // APIs rather than re-describing the propagation in prose. This
        // does NOT touch `MKExport`/`MKFonts` SOURCES (the fenced
        // prohibition in this packet's scope) ، it only consumes their
        // already-published public API as a library dependency, exactly
        // like every other cross-module test-only edge in this file.
        .testTarget(
            name: "MKStoreTests",
            dependencies: ["MKStore", "MKFoundation", "MKModel", "MKPersistence", "MKExport", "MKRender", "MKColor", "MKFonts", "MKTextEngine", "MKPathText"],
            // D-327: `ReferralTests.swift` is itself `#if
            // MAKHTOOT_REFERRAL_ENABLED`-gated (its T14 AC assumed the suite
            // would be run with `swift test -Xswiftc
            // -DMAKHTOOT_REFERRAL_ENABLED`). Defining the flag on the target
            // instead means the referral tests run in the ordinary `swift
            // test` invocation CI already uses ، without this, activating the
            // feature would ship it with its tests silently compiled out,
            // which is worse than not activating it.
            swiftSettings: [.define("MAKHTOOT_REFERRAL_ENABLED")]
        ),

        // MARK: - Work item 0.2 (android/, ANDROID_TASK_PACKETS/BATCH-0.md)
        // `MKGoldenExport`: an executable that drives the shipped engines
        // against canonical inputs and dumps deterministic JSON/PNG/SVG/PDF
        // goldens to `android/fixtures/**` ، the acceptance oracle every
        // later Android-port batch diffs its Kotlin output against (D-324).
        // Read-only against every other target's Sources; owns only
        // `Sources/MKGoldenExport/**` and this one manifest entry.
        .executableTarget(
            name: "MKGoldenExport",
            dependencies: [
                "MKFoundation", "MKModel", "MKTextEngine", "MKArrange", "MKPathText",
                "MKRender", "MKColor", "MKExport", "MKFonts", "MKPersistence",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
