# Makhtoot (مخطوط) — ARCHITECTURE.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.

**Run-1 deliverable · Deep technical architecture · Conforms to FOUNDATION.md (D-100..D-126)**

Audience: senior iOS engineers and contributors implementing the workstream packets
in AGENT_TASK_PACKETS. Everything here is execution-ready: concrete Swift 6 types, real
Core Text / StoreKit 2 / CloudKit API names, algorithms with complexity notes, wire
formats with schemas, and testable invariants. Where this document elaborates a locked
decision it cites the `D-1xx` id; new architecture-level decisions introduced here use
`D-2xx` ids and will be mirrored into DECISIONS_LOG.md. Legal/policy statements cite
`docs/makhtoot-market-study.md` footnote numbers (`[^n]`) or are marked
`VERIFY-AT-SUBMISSION`. Bundle id appears only as the marked placeholder
`net.binjamshid.makhtoot` (FD-01).

Section numbering follows FOUNDATION.md §11 exactly (25 sections + Traceability).

> **Status | Built? | Verified against source on 2026-07-20** — Run-1 design
> document; **partially built.** Module-level structure (§2/FOUNDATION §2's 16
> `MakhtootKit` library targets) was spot-checked against the current source tree
> during this pass and matches exactly. Section-by-section implementation-level
> detail was NOT fully re-verified line-by-line (3,614 lines) — 11 of 15
> `docs/impl-log/WS-*.md` entries record deviations from this document that are not
> back-ported here. Where this document and the code disagree, the code wins
> (README "Authority rule"); check `MakhtootKit/CONTRACTS.md` and the relevant
> `docs/impl-log/WS-NN.md` before trusting an implementation-level claim here.

---

## 1. System Overview

### 1.1 What Makhtoot is, architecturally

Makhtoot is a **local-first, offline-complete, document-based canvas editor** whose
differentiating subsystem is a *shaping-capture* text engine: Apple Core Text performs
all Arabic shaping (D-103), and Makhtoot's engine captures the shaped result — glyphs,
positions, advances, string indices, bidi status — into an inspectable, addressable,
transformable scene-graph structure. The product thesis from the market study is that no
competitor exposes per-glyph/per-tashkeel/per-ligature manipulation of Arabic text
[^1][^2][^4]; the architecture therefore concentrates its risk budget and its quality
budget on the `MKTextEngine` → `MKArrange` → `MKRender` spine and keeps every other
subsystem (persistence, store, sync, export, analytics) deliberately conventional.

The app is a single Xcode app target `Makhtoot` plus one local Swift package
`MakhtootKit` (D-101) containing fifteen library targets (§2). Swift 6 language mode
with strict concurrency is on everywhere (D-100). There are **no third-party
dependencies** in v1 — every capability named in this document is implemented on Apple
frameworks: SwiftUI, UIKit, Core Text, Core Graphics, Core Animation, ImageIO,
UniformTypeIdentifiers, SwiftData, CloudKit, StoreKit 2, Security (Keychain), os.log.

### 1.2 The four data representations

Everything in the app is one of four representations, with explicit, lossless
conversion points between them:

1. **Source text** — a Unicode string (`String`) plus attribute state (font reference,
   size, tracking, kerning overrides, baseline shift, line height, color). Owned by
   Live Text objects and Path Text objects, and retained forever inside Arranged
   Compositions as the Source Text Backup (D-106).
2. **Shaped capture** — the transient, value-type result of running source text through
   Core Text: `MKShapedLine` / `MKShapedRun` / `MKClusterMap` (§4). Never persisted;
   always recomputable; cached keyed by (string, style, font version).
3. **Scene graph** — the immutable value-type document model `MKScene` → `[MKNode]`
   (D-111, §3). This is what is edited, undone, persisted, synced, and rendered.
4. **Render products** — CALayer contents bitmaps for the interactive canvas, and
   export artifacts (JPEG/PNG/SVG/PDF) produced from an immutable scene snapshot
   (D-102, D-118) by the single shared renderer.

The two arrows that define the product are:

- *Shaping capture* (source text → shaped capture): performed continuously for Live
  Text and Path Text as the user types.
- *Arrange derivation* (shaped capture → arranged scene subtree): performed exactly
  once per explicit user action "تحويل إلى تشكيل حر" (Convert to Free Arrangement),
  creating Glyph Nodes, Mark Nodes, and Ligature Groups with full provenance (D-106).
  After derivation the composition **never reshapes implicitly** (INV-1).

### 1.3 Process topology and concurrency (D-102)

There is one process, no extensions in v1 (no widgets, no share extension — out of
scope). Inside the process:

- **MainActor domain** — SwiftUI shell, UIKit canvas host, the *editor document model*
  (`MKDocumentSession`), undo stack, selection state. The scene graph value lives here
  as `private(set) var scene: MKScene` on a `@MainActor` observable session object;
  because `MKScene` is a value type, handing a copy to any service is race-free by
  construction.
- **Service domain** — `Sendable` actors/services on structured-concurrency task
  groups: `MKShapingService` (CPU-bound shaping capture; Core Text objects are created,
  used, and dropped inside one isolated call), `MKExportService`,
  `MKAutosaveController`, `MKFontInstallService`, `MKSyncService` (CKSyncEngine
  delegate), `MKEntitlementResolver`, `MKAnalyticsService`.
- **Render domain** — `MKSceneRenderer` is a `Sendable` struct that renders any
  `MKSceneSnapshot` (deep value copy + resolved font handles + resolved asset URLs)
  into a `CGContext`. Preview rendering happens on a dedicated serial queue feeding
  CALayer contents; export rendering happens inside `MKExportService` task groups.
  Because renderers only ever see snapshots, **export/preview can never race the
  editor** (INV-2).

Core Text objects (`CTFont`, `CTLine`, `CTRun`, `CTTypesetter`) are not `Sendable`.
Rule: they never cross an isolation boundary. `MKShapingService` accepts value-type
requests (`MKShapingRequest`) and returns value-type results (`MKShapedLine`); fonts
cross boundaries as `MKFontRef` (an id + URL + descriptor cache key), and each isolation
domain materializes its own `CTFont` via `MKFontRuntime` (§17.4).

### 1.4 Architecture invariants (verified in TEST_MATRIX)

These are the contract lines of the architecture. Each is phrased to be mechanically
testable; TEST_MATRIX assigns `T-` ids against each `INV-` id.

- **INV-1 — No implicit reshape.** An `arranged` node's glyph geometry never changes
  except through an explicit user command (move/rotate/scale/form-change/decompose/
  recompose) or explicit confirmed revert. Opening a document, changing app fonts,
  OS updates, or font re-registration must not alter any persisted arranged geometry.
  *Test:* byte-compare `scene.json` arranged subtrees across open/close and font
  reinstall cycles.
- **INV-2 — Snapshot-only rendering.** `MKSceneRenderer.render(snapshot:into:)` is the
  only drawing entry point for both canvas preview and every export format, and it
  accepts only `MKSceneSnapshot` values. No code path renders from live mutable state
  or captures screen pixels. *Test:* API audit (renderer module has no reference to
  `MKDocumentSession` or UIKit view types) + pixel-compare canvas tile vs export crop.
- **INV-3 — Network confinement.** Only `MKFonts` (catalog manifest + font downloads),
  `MKSync` (CloudKit private DB), and `MKAnalytics` (CloudKit public DB) may create
  network tasks or CloudKit operations. `MKStore` talks only to StoreKit (which is not
  app-originated networking). *Test:* static dependency audit — `URLSession`/`CKContainer`
  symbols appear only in those targets — plus runtime `NWConnection`-less assertion in
  debug builds.
- **INV-4 — Source Text Backup immutability.** Arrange-mode edits never mutate the
  Source Text Backup (string, style state, path definition). Only revert (which
  destroys the arrangement, with confirmation) or nothing consumes it. *Test:* hash
  backup on derivation; assert equal after arbitrary arrange edit scripts.
- **INV-5 — Core Text is the only shaper.** No code constructs Arabic presentation-form
  codepoints (U+FB50–FDFF, U+FE70–FEFF) for rendering, and no code reorders or
  substitutes glyphs outside of captured Core Text output (D-103, D-107). *Test:* grep
  gate over source for presentation-form literals; unit test that form resolution
  round-trips through `MKShapingService`.
- **INV-6 — One render path.** Canvas preview at zoom z and an export at scale z of the
  same snapshot are pixel-identical modulo resampling (same glyph paths, same
  positions, same colors). *Test:* golden-image comparison at controlled scale.
- **INV-7 — Atomic persistence.** Every write of `scene.json`/`manifest.json` is
  write-temp-then-`rename()`; a crash at any instant leaves either the previous
  complete document plus journal, or the new complete document (never a torn file)
  (D-112). *Test:* kill-injection harness around autosave.
- **INV-8 — Undo is exact inverse.** For every command `c`, `apply(invert(c), apply(c, s)) == s`
  by `Equatable` value comparison of `MKScene`. *Test:* property test over generated
  command sequences.
- **INV-9 — Single entitlement authority.** All gating decisions (export formats,
  premium fonts, photo backgrounds, sync, import) read `MKEntitlementResolver.current`
  (one actor, one published state). No feature caches entitlement beyond one
  render/exports pass. *Test:* dependency audit + state-injection tests over all six
  entitlement states (D-113).
- **INV-10 — Trial never extends.** No code path moves the persisted trial-start
  timestamp later or the computed expiry further into the future, except the
  flag-gated referral module's bounded extension records (D-123, D-124). Clock
  rollback freezes rather than extends. *Test:* clock-manipulation suite (§19.3).
- **INV-11 — Analytics payload minimality.** An uploaded analytics record contains
  exactly: schema version, ISO-week bucket string, and (fontID → bucketed count)
  pairs, plus a random ephemeral batch UUID. No device ids, no user record link, no
  fine timestamps, no strings from user content (D-125). *Test:* record-shape unit
  test + CI schema check on the upload encoder.
- **INV-12 — User content stays local.** Project text, scene graphs, assets, and font
  files leave the device only as CloudKit *private-database* payloads of the premium
  sync feature, and only when the user enabled sync. *Test:* audit of every
  `CKRecord`/`URLRequest` constructor in the codebase.
- **INV-13 — Locked content renders, never reshapes.** After premium expiry, nodes
  using locked (premium/imported) fonts keep rendering from cached shaped/arranged
  geometry with a lock badge; the app never silently substitutes fonts and never
  reshapes with a fallback font (D-119). *Test:* entitlement-drop simulation with
  golden images.
- **INV-14 — SwiftData never stores scene content.** The SwiftData store contains
  metadata only (project list, folders, names, search text, export history, catalog
  state, counters, consent/trial records); no scene graph, no node data, no source
  strings other than user-visible project names (D-112). *Test:* model audit + store
  dump inspection test.
- **INV-15 — No silent flattening.** Every export element that falls back from live
  text to outlines carries a machine-readable reason (`data-mk-outlined` in SVG,
  export-report entry for PDF), per D-118. *Test:* export-report golden tests over a
  fixture matrix.
- **INV-16 — Referral inertness.** With `MKFeatureFlags.referralProgram == false`
  (default), the referral module performs no I/O, registers no UI, writes no records,
  and its removal (delete folder + flag) leaves zero dangling references (D-124).
  *Test:* flag-off behavioral audit + compile-after-delete CI job.
- **INV-17 — Save before degrade.** Every memory-ladder stage transition (D-116)
  triggers a completed save appropriate to that stage — a full autosave/journal flush
  at stages 1–2, a synchronous journal-only flush at the critical stage (D-223,
  amending D-210's mid-export claim) — *before* any cache eviction or fidelity
  degradation takes effect. *Test:* instrumented pressure simulation asserting
  save-completes-before-evict ordering at every stage.
- **INV-18 — Arabic-only UI.** Every user-facing string resolves through the `ar`
  string catalog; there is no `en` localization and no hard-coded Latin UI copy
  (D-100, D-126). *Test:* string-catalog audit + runtime locale assertion.

### 1.5 Top-level data flow

```
Keyboard/IME ──▶ UITextView overlay (TextKit 2, D-104)
                     │ commit / live mirror
                     ▼
        MKShapingService (Core Text capture, §4)
                     │ MKShapedLine + MKClusterMap
        ┌────────────┴─────────────┐
        ▼                          ▼ (explicit user action)
  Live Text render            MKArrange derivation (§5)
  (reflowable)                Arranged Composition (frozen)
        │                          │
        └────────────┬─────────────┘
                     ▼
             MKScene (value tree, §3) ◀──── undo/redo commands (§14)
             │            │        │
   snapshot  │            │        └──▶ MKPersistence (.makhtoot pkg, §13)
             ▼            ▼                     │
     MKRender preview  MKExport (§16)           └──▶ MKSync (CKSyncEngine, §20)
     (CALayer tree)    JPEG/PNG/SVG/PDF
```

### 1.6 What is deliberately *not* in this architecture

Per BRIEF and FOUNDATION: no accessibility scope (founder Q53), no templates (Q61–62;
seam only, §24.2), no animation/video (v2; seam only, §24.1), no Qur'anic content of any
kind — no verse data, no Tanzil integration (overriding market study §6's
recommendation; BRIEF is explicit), no third-party analytics SDK, no accounts/SIWA, no
server backend, no Metal (seam only, D-114), no multi-page documents (seam only).

---

## 2. Module Architecture

### 2.1 Dependency graph (normative)

The module map and dependency directions are locked in FOUNDATION §2. Rendered as a
graph (arrows point at dependencies; transitive edges omitted):

```
Makhtoot (app target)
 ├──▶ MKDesignSystem ──▶ MKFoundation
 ├──▶ MKCanvas ──▶ MKModel, MKRender
 ├──▶ MKArrange ──▶ MKModel, MKTextEngine
 ├──▶ MKPathText ──▶ MKModel, MKTextEngine
 ├──▶ MKExport ──▶ MKModel, MKRender, MKColor, MKFonts, MKStoreAPI(protocols)
 ├──▶ MKSync ──▶ MKPersistence, MKStoreAPI(protocols)
 ├──▶ MKStore ──▶ MKFoundation
 ├──▶ MKAnalytics ──▶ MKFoundation, MKPersistence
 ├──▶ MKAssets ──▶ MKModel
 ├──▶ MKFonts ──▶ MKFoundation, MKPersistence
 ├──▶ MKPersistence ──▶ MKModel, MKFoundation
 ├──▶ MKRender ──▶ MKModel, MKTextEngine
 ├──▶ MKTextEngine ──▶ MKFoundation, MKFonts(handles)
 ├──▶ MKColor ──▶ MKFoundation
 └──▶ MKModel ──▶ MKFoundation
```

Two clarifications this document adds (D-230, D-231 — expansions, not contradictions;
renumbered from this document's earlier local D-200/D-201 labels, which collided with
unrelated global decisions of the same numbers — see DECISIONS_LOG.md D-200
(localization string catalog) and D-201 (UITextView overlay trade study)):

- **D-230 `MKStoreAPI` protocol seam.** `MKExport` and `MKSync` must *query*
  entitlements without depending on StoreKit. FOUNDATION already notes "entitlement
  queries via protocol"; concretely, `MKFoundation` hosts the tiny protocol surface and
  `MKStore` provides the live implementation, injected at app assembly:

```swift
// MKFoundation/Sources/Entitlements/MKEntitlementProviding.swift
public enum MKEntitlementState: String, Sendable, Codable, CaseIterable {
    case lifetime, subscribed, inGracePeriod, inBillingRetry, trial, free
    /// D-113 precedence: lifetime > subscribed > inGracePeriod > inBillingRetry > trial > free
    public var isPremium: Bool { self != .free }
}

public protocol MKEntitlementProviding: Sendable {
    /// Snapshot read; resolves in-memory, never blocks on network. INV-9.
    func currentState() async -> MKEntitlementState
    /// Push stream for UI badges / gating banners.
    var stateUpdates: AsyncStream<MKEntitlementState> { get }
}
```

- **D-231 App assembly.** The app target owns a single `MakhtootAppServices`
  composition root (created in `MakhtootApp.init`), which constructs every service,
  wires protocol seams, and hands scene-level environments to SwiftUI. No singletons
  except `MKLog` (os.log wrapper) and `MKFeatureFlags` (constant table).

### 2.2 Target-by-target responsibilities and key public surfaces

| Target | Key public types (authoritative list; FILE_MAP.md places files) |
|---|---|
| `MKFoundation` | `MKID` (typed UUIDs), `MKTransform2D`, `MKRect`, `MKAngle`, `MKRTL` (mirroring helpers), `MKError`, `MKLog`, `MKFeatureFlags`, `MKEntitlementProviding`, `MKClock` (testable time source) |
| `MKModel` | `MKScene`, `MKNode`, all node payload structs, `MKStyle`, `MKProvenance`, `MKSceneSnapshot`, Codable + `schemaVersion` migration (`MKSceneCoder`) |
| `MKTextEngine` | `MKShapingService`, `MKShapingRequest`, `MKShapedLine/Run`, `MKClusterMap`, `MKJoiningAnalyzer`, `MKFormResolver` (ZWJ technique), `MKFontFeatureSet`, `MKBidiMap` |
| `MKArrange` | `MKArrangeDeriver`, `MKMarkAttacher`, `MKLigatureGrouper`, `MKLigatureDecomposer`, `MKJoinBreaker`, `MKRevertService` |
| `MKPathText` | `MKBezierPath` (value type), `MKArcLengthTable`, `MKPathLayoutEngine`, `MKPathTextArranger` |
| `MKCanvas` | `MKCanvasViewController`, `MKCanvasView`, `MKSelectionController`, `MKGestureRouter`, `MKGuideEngine` (snapping), `MKTextEditingOverlay`, `MKHitTester` façade |
| `MKRender` | `MKSceneRenderer`, `MKLayerTreeController`, `MKTileCache`, `MKDegradationController`, `MKHitGeometry` |
| `MKColor` | `MKColor` (sRGB components + optional swatch name), `MKICCProfile`, `MKCMYKConverter`, `MKColorPipeline` |
| `MKExport` | `MKExportService`, `MKExportRequest/Preset/Result/Report`, `MKRasterTiler`, `MKPDFWriter`, `MKSVGSerializer`, `MKExportGate` |
| `MKFonts` | `MKFontRegistry`, `MKFontRef`, `MKFontRuntime`, `MKFontCatalog`, `MKFontDownloadService`, `MKFontImportService`, `MKFontValidator`, `MKLicenseStore`, `MKFontLockController` |
| `MKPersistence` | `MKDocumentStore`, `MKDocumentSession`, `MKProjectPackage`, `MKAutosaveController`, `MKJournal`, `MKUndoStack`, `MKCommand`, SwiftData `@Model` set (§13.6), `MKAssetStore` |
| `MKSync` | `MKSyncService`, `MKSyncRecordMapper`, `MKConflictPolicy`, `MKSyncStatusModel` |
| `MKStore` | `MKStoreService`, `MKEntitlementResolver`, `MKTrialController`, `MKPaywallModel`, `Referral/` (flag-isolated folder, §19) |
| `MKAnalytics` | `MKConsentController`, `MKUsageAggregator`, `MKAnalyticsUploader`, `MKAnalyticsKillSwitch` |
| `MKDesignSystem` | `MKTheme` protocol + `MKInkPaperTheme` (FD-02), tokens, RTL-first controls (§22) |
| `MKAssets` | `MKAssetLibrary`, `MKAssetItem` (vector ornaments/shapes/frames/patterns), `MKAssetBrowserModel` |

### 2.3 Build-time rules

- Swift 6 language mode, `StrictConcurrency` complete, `ExistentialAny` upcoming
  feature on, warnings-as-errors in `MakhtootKit` (app target may relax for SwiftUI
  previews during development but ships clean).
- `MKFeatureFlags` is a compile-time constant table plus a *local-only* runtime
  override read from `UserDefaults` under debug builds; release builds read constants
  only, except `referralProgram` which additionally requires the local flag file
  mechanism described in §19.6 to remain OFF by default (D-124). No flag is ever
  fetched from a server.
- Each target has a `Tests/` mirror. Test strategy lives in TEST_MATRIX.md; gate list
  is BRIEF "Gates (Q59)".

---

## 3. Scene Graph & Data Model

### 3.1 Design constraints

The scene graph (D-111) must simultaneously satisfy: (a) value semantics so undo/redo
is snapshot-cheap and renderers race-free (D-102); (b) stable identity (`UUID`) so
selection, layers panel, sync, and provenance survive structural edits; (c) losslessly
Codable to `scene.json` schemaVersion 1 (§13.4); (d) provenance-complete for arranged
content so *both* editing levels (shaped-glyph and Unicode-letter) lose nothing when
switching (BRIEF "Both levels supported").

### 3.2 Core value types

```swift
// MKFoundation
public struct MKID<Tag>: Hashable, Sendable, Codable {
    public let raw: UUID
    public init(_ raw: UUID = UUID()) { self.raw = raw }
}
public enum NodeTag {} ; public enum ClusterTag {} ; public enum ProjectTag {}
public typealias MKNodeID = MKID<NodeTag>
public typealias MKClusterID = MKID<ClusterTag>

/// Decomposed transform (D-111): never a raw matrix, so the numeric inspector can
/// edit each component and rotation survives round-tripping.
public struct MKTransform2D: Hashable, Sendable, Codable {
    public var position: CGPoint      // canvas points, canvas origin = top-left
    public var rotation: Double       // radians, CCW-positive in canvas space
    public var scale: CGSize          // non-uniform allowed; negative = mirror (guarded in UI)
    public var affine: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y)
            .rotated(by: rotation)
            .scaledBy(x: scale.width, y: scale.height)
    }
    public static let identity = MKTransform2D(position: .zero, rotation: 0,
                                               scale: CGSize(width: 1, height: 1))
}
```

```swift
// MKModel — style model (v1 fill = solid color only, D-111)
public struct MKStyle: Hashable, Sendable, Codable {
    public var fill: MKFill                 // .solid(MKColor) | .none
    public var stroke: MKStroke?            // color, width (pt), join, cap
    public var shadow: MKShadow?            // color, blur, offset
    public var opacity: Double              // 0...1, multiplies down the tree
    public var blendMode: MKBlendMode       // .normal only in v1 UI; enum future-proofs
}
public enum MKFill: Hashable, Sendable, Codable { case none, solid(MKColor) }
public struct MKStroke: Hashable, Sendable, Codable {
    public var color: MKColor; public var width: Double
    public var join: MKLineJoin; public var cap: MKLineCap
}
public struct MKShadow: Hashable, Sendable, Codable {
    public var color: MKColor; public var blur: Double; public var offset: CGSize
}
```

### 3.3 The node enum

```swift
// MKModel
public struct MKScene: Hashable, Sendable, Codable {
    public var schemaVersion: Int              // 1
    public var canvas: MKCanvasSpec            // size (pt), background node id
    public var nodes: [MKNode]                 // z-order: index 0 = backmost
    public var nodeIndex: [MKNodeID: MKNodePath] { get }  // derived, not encoded
}

public struct MKCanvasSpec: Hashable, Sendable, Codable {
    public var size: CGSize                    // document points
    public var presetID: String?               // export preset provenance (§16.8)
}

public enum MKNode: Hashable, Sendable, Codable, Identifiable {
    case group(MKGroupNode)
    case liveText(MKLiveTextNode)
    case pathText(MKPathTextNode)
    case arranged(MKArrangedTextNode)
    case shape(MKShapeNode)
    case image(MKImageNode)
    case background(MKBackgroundNode)

    public var id: MKNodeID { base.id }
    public var base: MKNodeBase { /* switch over cases */ }
}

/// Fields shared by every node case (composition, not inheritance).
public struct MKNodeBase: Hashable, Sendable, Codable {
    public var id: MKNodeID
    public var name: String            // user-visible layer name (Arabic default per kind)
    public var transform: MKTransform2D
    public var style: MKStyle
    public var isLocked: Bool
    public var isHidden: Bool
}
```

Case payloads:

```swift
public struct MKGroupNode: Hashable, Sendable, Codable {
    public var base: MKNodeBase
    public var children: [MKNode]              // group transform composes over children
    public var lineHeightOverride: Double?     // parent-group line-height control (BRIEF per-object list)
}

/// Reflowable Core-Text-shaped text bound to a source string (glossary: Live Text object).
public struct MKLiveTextNode: Hashable, Sendable, Codable {
    public var base: MKNodeBase
    public var text: MKSourceText              // string + per-range style runs
    public var frame: MKTextFrameSpec          // width-constrained | single-line
    public var typography: MKTypography        // font ref, size, tracking, features…
}

public struct MKSourceText: Hashable, Sendable, Codable {
    public var string: String
    public var styleRuns: [MKStyleRun]         // range (UTF-16 offsets), overrides
    public var baseDirection: MKBaseDirection  // .rightToLeft default (D-109)
}

public struct MKTypography: Hashable, Sendable, Codable {
    public var font: MKFontRef
    public var pointSize: Double
    public var tracking: Double                // pt added per glyph advance
    public var kerningOverrides: [MKKernOverride]   // cluster-pair overrides
    public var baselineShift: Double
    public var lineHeightMultiple: Double
    public var features: MKFontFeatureSet      // dlig/calt toggles etc. (§7.6)
}

/// Live text on a Bézier path — still reflowable until arranged (D-110).
public struct MKPathTextNode: Hashable, Sendable, Codable {
    public var base: MKNodeBase
    public var text: MKSourceText
    public var typography: MKTypography
    public var path: MKBezierPath              // value-type cubic path, editable live
    public var layout: MKPathLayoutOptions     // start offset, side, spacing mode (§9)
}

public struct MKShapeNode: Hashable, Sendable, Codable {
    public var base: MKNodeBase
    public var geometry: MKShapeGeometry       // .rect(corner) | .ellipse | .line | .polygon | .path(MKBezierPath) | .asset(MKAssetID)
}

public struct MKImageNode: Hashable, Sendable, Codable {
    public var base: MKNodeBase
    public var asset: MKAssetRef               // content-addressed ref into assets/ (§13.3)
    public var kind: MKImageKind               // .raster | .vectorPDF | .vectorSVG
    public var isPhotoBackgroundUse: Bool      // premium gating marker (D-119)
}

public struct MKBackgroundNode: Hashable, Sendable, Codable {
    public var base: MKNodeBase                // transform ignored; always canvas-filling
    public var content: MKBackgroundContent    // .solid(MKColor) | .image(MKAssetRef) (premium)
}
```

### 3.4 The arranged subtree (the differentiator's data model)

An Arranged Composition freezes shaped output into independently addressable children
(D-106). It is a node case, and its children are *not* `MKNode` — they are a dedicated
closed set, because they carry provenance and joining metadata regular nodes do not:

```swift
public struct MKArrangedTextNode: Hashable, Sendable, Codable {
    public var base: MKNodeBase
    public var backup: MKSourceTextBackup      // INV-4: never mutated by arrange edits
    public var children: [MKArrangedChild]     // z within composition; visual order at derivation
    public var clusterTable: [MKClusterRecord] // cluster ↔ codepoint ↔ glyph map (§4.5)
    public var bidi: MKBidiSnapshot            // levels + visual order (§8)
    public var derivedFrom: MKArrangeOrigin    // .liveText | .pathText(MKBezierPath frozen copy)
}

/// Everything needed to revert or to re-derive: the full former node payload.
public struct MKSourceTextBackup: Hashable, Sendable, Codable {
    public var text: MKSourceText
    public var typography: MKTypography
    public var frame: MKTextFrameSpec?
    public var pathLayout: MKPathLayoutOptions?    // present iff origin was pathText
    public var contentHash: String                 // SHA-256 over canonical encoding (INV-4 check)
}

public enum MKArrangedChild: Hashable, Sendable, Codable, Identifiable {
    case glyph(MKGlyphNode)
    case mark(MKMarkNode)
    case ligature(MKLigatureGroup)
    public var id: MKNodeID { /* switch */ }
}

/// One base glyph (glossary: Glyph Node).
public struct MKGlyphNode: Hashable, Sendable, Codable {
    public var id: MKNodeID
    public var glyph: MKGlyphRef               // CGGlyph id + font ref + font version tag
    public var outline: MKPathData?            // cached CTFontCreatePathForGlyph result; lazily filled, encoded for lock-resilience (INV-13)
    public var layout: MKGlyphLayout           // position (composition space), advance, baselineOrigin
    public var transform: MKTransform2D        // user deltas on top of layout.position
    public var style: MKStyle                  // per-glyph fill/stroke/shadow/opacity
    public var provenance: MKProvenance        // ← the both-levels contract
    public var joining: MKJoiningState         // §7
    public var isHidden: Bool
    public var isLocked: Bool
}

public struct MKGlyphRef: Hashable, Sendable, Codable {
    public var glyphID: UInt16                 // CGGlyph
    public var font: MKFontRef
    public var fontChecksum: String            // sfnt head.checkSumAdjustment hex; detects font-file drift (risk RSK-03)
    public var variationCoordinates: [String: Double]?  // variable-font axis values if any
}

public struct MKGlyphLayout: Hashable, Sendable, Codable {
    public var position: CGPoint               // shaped position at derivation (composition space)
    public var advance: CGSize                 // CTRunGetAdvances result
    public var pathTangentAngle: Double?       // set for path-derived glyphs (D-110)
}

/// Provenance: exact link back to Unicode (D-106; BRIEF "Store codepoint sequences +
/// resolved glyph/shaping-form references so switching level loses nothing").
public struct MKProvenance: Hashable, Sendable, Codable {
    public var clusterID: MKClusterID          // key into MKArrangedTextNode.clusterTable
    public var codepoints: [UInt32]            // Unicode scalars this glyph realizes
    public var utf16Range: MKRangeCodec        // range in backup.text.string
    public var bidiLevel: UInt8
    public var visualIndex: Int                // index in visual order at derivation
    public var logicalIndex: Int               // cluster index in logical order
}

/// Combining mark (glossary: Mark Node). §6 details attachment mechanics.
public struct MKMarkNode: Hashable, Sendable, Codable {
    public var id: MKNodeID
    public var glyph: MKGlyphRef
    public var outline: MKPathData?
    public var attachedTo: MKNodeID?           // base glyph node; nil = detached (explicit user act)
    public var relativeOffset: CGSize          // GPOS-captured offset, in BASE-LOCAL space (D-105, D-220)
    public var followsBase: Bool               // default true: base transform composes onto mark
    public var transform: MKTransform2D        // mark's own transform, applied AFTER relativeOffset (D-220)
    public var style: MKStyle
    public var provenance: MKProvenance
    public var markClass: MKMarkClass          // .tashkeel | .quranicAnnotation | .otherCombining (§6.2)
    public var stackIndex: Int                 // paint/stacking order among marks on the same base (D-220;
                                                // own field — NOT overloaded onto MKProvenance.visualIndex)
    public var isHidden: Bool
    public var isLocked: Bool
}

/// Multi-codepoint single-glyph cluster (glossary: Ligature Group). §7.
public struct MKLigatureGroup: Hashable, Sendable, Codable {
    public var id: MKNodeID
    public var state: MKLigatureState
    public var provenance: MKProvenance        // codepoints = all constituents
    public var transform: MKTransform2D
    public var style: MKStyle
    public var attachedMarks: [MKNodeID]       // marks positioned against the ligature
    public var isHidden: Bool
    public var isLocked: Bool
}

public enum MKLigatureState: Hashable, Sendable, Codable {
    /// Combined: one glyph, selectable as a unit.
    case composed(MKComposedLigature)
    /// Decomposed: constituent glyph nodes + fidelity offsets (D-108).
    case decomposed(MKDecomposedLigature)
}
public struct MKComposedLigature: Hashable, Sendable, Codable {
    public var glyph: MKGlyphRef
    public var outline: MKPathData?
    public var layout: MKGlyphLayout
    public var decomposable: Bool              // false if constituents cannot be reshaped (risk RSK-02)
}
public struct MKDecomposedLigature: Hashable, Sendable, Codable {
    public var components: [MKGlyphNode]       // reshaped constituents (joining-preserving)
    public var fidelityOffsets: [MKNodeID: CGSize]  // per-component nudge matching original bounds
    public var fidelityMode: MKFidelityMode    // .matchOriginal (default) | .defaultForms (opt-out, Q71)
    public var original: MKComposedLigature    // retained for exact recomposition
}
```

Design notes:

- **`outline` is persisted, not just cached.** Encoding the extracted glyph path
  (compact binary-ish path data, §3.6) makes arranged nodes render-complete even when
  the source font is locked after expiry (INV-13) or a font file is updated
  (`fontChecksum` mismatch → keep outline, flag "font drifted" in inspector). This is
  the concrete mechanism behind BRIEF's "projects stay viewable/editable" after expiry.
  Cost: ~120–400 bytes per glyph path in scene.json (measured against Amiri average
  contour complexity); a 500-glyph arranged headline ≈ 60–200 KB — acceptable for a
  file-package document, and `scene.json` is not sync-chunked (whole-asset upload,
  §20.2).
- **Marks reference bases by id, not containment**, so detaching a mark is a field
  change (`attachedTo = nil`), not a tree move — undo stays trivial and provenance
  stays intact.
- **Ligature groups own their marks list** (`attachedMarks`) because mark anchoring on
  a ligature (e.g., shadda+fatha over lam-alif) must survive decomposition: on
  decompose, each mark's `attachedTo` is re-pointed to the nearest component by
  horizontal anchor distance (§7.5, step 6).

### 3.5 Snapshots

```swift
/// Deep value copy + resolved runtime references. The ONLY input MKRender accepts (INV-2).
public struct MKSceneSnapshot: Sendable {
    public let scene: MKScene                      // value copy — already immutable
    public let fontHandles: [MKFontRef: MKFontHandle]  // resolved descriptors (Sendable wrapper of URL+cache key, not CTFont)
    public let assetURLs: [MKAssetRef: URL]        // pinned, read-only asset files
    public let renderIntent: MKRenderIntent        // .editorPreview(zoom) | .export(MKExportRequest)
    public let entitlement: MKEntitlementState     // frozen at snapshot time (INV-9 single read)
}
```

Snapshot creation is O(1) amortized (COW on arrays); asset URLs are hard-linked into a
per-snapshot temp dir during export so a concurrent asset GC can never invalidate an
in-flight export (§13.3).

### 3.6 Path data encoding

`MKPathData` stores glyph outlines and freeform shapes as a flat command array —
faithful to `CGPath` element semantics, compact in JSON:

```swift
public struct MKPathData: Hashable, Sendable, Codable {
    /// Flattened command stream: [op, coords…]. Ops: 0=move(2), 1=line(2),
    /// 2=quad(4), 3=cubic(6), 4=close(0). Coordinates in glyph units scaled to
    /// 1000/em at encode time (font-size independent), Double.
    public var commands: [Double]
    public var unitsPerEm: Double            // always 1000 in v1 encodes
    public func cgPath(at pointSize: Double) -> CGPath { /* scale 1000→size */ }
}
```

JSON size discipline: coordinates rounded to 2 decimals in glyph-unit space (≤0.1%
of em — invisible at 300 DPI print for realistic sizes; verified in TEST_MATRIX
sharpness checks).

### 3.7 Equality, hashing, diffing

`MKScene` is `Hashable`; `MKSceneDiffer` (MKModel) computes node-id-keyed diffs used
by: layer-tree incremental update (§11.2), sync change detection (§20.3), and autosave
dirty tracking (§14.4). Diffing is O(n) over node count with early-out on subtree hash
equality (each node caches a structural hash, recomputed on mutation by the command
layer — commands know exactly what they touched).

---

## 4. Text Engine (Shaping Capture)

### 4.1 Contract

`MKTextEngine` turns *source text + typography* into a *complete, value-type record of
what Core Text shaped*, with enough structure to (a) render Live Text identically to
what UITextView would show, (b) derive an Arranged Composition losslessly, and (c)
answer cluster/caret/hit queries. The feasibility of this exact approach —
`CTTypesetter`/`CTLine`/`CTRun` capture with `CTRunGetGlyphs`/`CTRunGetPositions`/
`CTRunGetStringIndices` and `kCTRunStatusRightToLeft` — is established in the market
study [^20][^21][^23], including the critical caveat that positions arrive in visual
order and RTL runs reverse visual-vs-logical correspondence [^23].

Never done here (INV-5): no shaping, no reordering, no presentation-form codepoints
(U+FB50–FDFF/U+FE70–FEFF are rejected on input normalization and never emitted).

### 4.2 Request/response types

```swift
// MKTextEngine
public struct MKShapingRequest: Hashable, Sendable {
    public var text: MKSourceText
    public var typography: MKTypography
    public var frame: MKTextFrameSpec          // .singleLine | .width(Double)
    public var purpose: Purpose                // .display | .arrangeDerivation | .formResolution
    public enum Purpose: Hashable, Sendable { case display, arrangeDerivation, formResolution }
}

public struct MKShapedLine: Hashable, Sendable {
    public var runs: [MKShapedRun]             // CTLine run order preserved (D-109)
    public var typographicBounds: MKLineMetrics // ascent, descent, leading, width
    public var clusterMap: MKClusterMap        // §4.5
    public var lineIndexInParagraph: Int
}

public struct MKShapedRun: Hashable, Sendable {
    public var glyphs: [UInt16]                // CGGlyph
    public var positions: [CGPoint]            // visual order, line-origin-relative (CTRunGetPositions)
    public var advances: [CGSize]              // CTRunGetAdvances
    public var stringIndices: [Int]            // UTF-16 indices into source (CTRunGetStringIndices)
    public var isRTL: Bool                     // CTRunGetStatus(run).contains(.rightToLeft)
    public var bidiLevel: UInt8                // derived: odd = RTL (§8.2)
    public var font: MKFontRef                 // resolved from CTRunGetAttributes kCTFontAttributeName
    public var attributes: MKResolvedRunAttributes  // color/tracking/baseline actually applied
}
```

### 4.3 Attributed-string construction

One function builds the `NSAttributedString`; every consumer (display, derivation, form
resolution, PDF live-text export) goes through it so attributes never diverge:

```swift
enum MKAttributedStringBuilder {
    static func make(_ req: MKShapingRequest, runtime: MKFontRuntime) throws -> NSAttributedString {
        let font: CTFont = try runtime.ctFont(req.typography.font,
                                              size: req.typography.pointSize,
                                              features: req.typography.features)
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = req.text.baseDirection == .rightToLeft
            ? .rightToLeft : .leftToRight                     // D-109
        paragraph.lineHeightMultiple = req.typography.lineHeightMultiple

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .kern: req.typography.tracking,                    // NSAttributedString.Key.kern
            .baselineOffset: req.typography.baselineShift,
            .ligature: req.typography.features.standardLigatures ? 1 : 0,
        ]
        // Explicit writing-direction override only when the user forced direction:
        if req.text.baseDirection == .rightToLeftOverride {
            attrs[NSAttributedString.Key(kCTWritingDirectionAttributeName as String)] =
                [NSNumber(value: CTWritingDirection.rightToLeft.rawValue | kCTWritingDirectionOverride)]
        }
        let s = NSMutableAttributedString(string: req.text.string, attributes: attrs)
        for run in req.text.styleRuns { s.addAttributes(run.resolvedAttributes(runtime), range: run.nsRange) }
        for kern in req.typography.kerningOverrides {          // per-cluster-pair kerning
            s.addAttribute(.kern, value: kern.value, range: kern.nsRange)
        }
        return s
    }
}
```

Discretionary/contextual ligature control (`dlig`, `calt`) is applied on the **font**,
not the string, via `kCTFontFeatureSettingsAttribute` (§7.6) so `CTFontCreatePathForGlyph`
later resolves against the identical feature-configured font.

### 4.4 Typesetting and extraction

```swift
public actor MKShapingService {
    private var cache = MKLRUCache<MKShapingRequest, [MKShapedLine]>(costLimit: 32 * 1024 * 1024)
    private let runtime: MKFontRuntime

    public func shape(_ req: MKShapingRequest) throws -> [MKShapedLine] {
        if let hit = cache[req] { return hit }
        let attributed = try MKAttributedStringBuilder.make(req, runtime: runtime)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        var lines: [MKShapedLine] = []
        var start = 0
        let length = attributed.length
        while start < length {
            let count: CFIndex = {
                switch req.frame {
                case .singleLine: return length - start
                case .width(let w):
                    return CTTypesetterSuggestLineBreak(typesetter, start, Double(w))
                }
            }()
            let ctLine = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
            lines.append(Self.capture(ctLine, lineIndex: lines.count, runtime: runtime))
            start += count
        }
        cache[req] = lines
        return lines
    }

    private static func capture(_ line: CTLine, lineIndex: Int, runtime: MKFontRuntime) -> MKShapedLine {
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let ctRuns = CTLineGetGlyphRuns(line) as! [CTRun]
        var runs: [MKShapedRun] = []
        for ctRun in ctRuns {
            let n = CTRunGetGlyphCount(ctRun)
            guard n > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: n)
            var positions = [CGPoint](repeating: .zero, count: n)
            var advances = [CGSize](repeating: .zero, count: n)
            var indices = [CFIndex](repeating: 0, count: n)
            let all = CFRange(location: 0, length: n)
            CTRunGetGlyphs(ctRun, all, &glyphs)
            CTRunGetPositions(ctRun, all, &positions)       // visual order [^23]
            CTRunGetAdvances(ctRun, all, &advances)
            CTRunGetStringIndices(ctRun, all, &indices)
            let status = CTRunGetStatus(ctRun)
            let attrs = CTRunGetAttributes(ctRun) as! [NSAttributedString.Key: Any]
            let ctFont = attrs[.font] as! CTFont            // Core Text always resolves a font
            runs.append(MKShapedRun(
                glyphs: glyphs.map(UInt16.init),
                positions: positions,
                advances: advances,
                stringIndices: indices.map(Int.init),
                isRTL: status.contains(.rightToLeft),
                bidiLevel: status.contains(.rightToLeft) ? 1 : 0,  // refined by MKBidiMap §8.2
                font: runtime.ref(for: ctFont),
                attributes: MKResolvedRunAttributes(attrs)))
        }
        let clusterMap = MKClusterMapBuilder.build(runs: runs)   // §4.5
        return MKShapedLine(runs: runs,
                            typographicBounds: .init(ascent: ascent, descent: descent,
                                                     leading: leading, width: width),
                            clusterMap: clusterMap,
                            lineIndexInParagraph: lineIndex)
    }
}
```

Notes for implementers:

- `CTRunGetPositions` origins are relative to the **line origin**; MKRender adds line
  origin + node transform. Never use `CTLineDraw` for committed rendering — glyphs are
  drawn individually (preview may batch via `CTFontDrawGlyphs` per run for speed, same
  geometry).
- `CTRunGetAdvances` is the source of truth for pen advance; do not recompute from
  `CTFontGetAdvancesForGlyphs` (feature settings and tracking already applied).
- Fractional positions are kept as `CGFloat` exactly as returned; rounding happens
  only at rasterization (INV-6 depends on this).
- The service is an actor: Core Text objects never escape `capture`.

### 4.5 Cluster ↔ codepoint ↔ glyph mapping (D-105)

`CTRunGetStringIndices` gives, per glyph, the UTF-16 index of the **first** character
of the cluster the glyph belongs to [^23]. The builder inverts that into a
bidirectional table:

```swift
public struct MKClusterMap: Hashable, Sendable {
    public var clusters: [MKCluster]                    // logical order
    public var glyphToCluster: [MKGlyphAddress: Int]    // (runIdx, glyphIdx) → cluster ordinal
    public var utf16ToCluster: [Int: Int]               // every UTF-16 idx → cluster ordinal
}

public struct MKGlyphAddress: Hashable, Sendable { public var run: Int; public var glyph: Int }

public struct MKCluster: Hashable, Sendable {
    public var id: MKClusterID
    public var utf16Range: Range<Int>          // in source string
    public var codepoints: [UInt32]            // scalars in the range (logical order)
    public var glyphs: [MKGlyphAddress]        // 1..n glyphs realizing this cluster (visual order)
    public var kind: Kind
    public enum Kind: Hashable, Sendable {
        case simple                            // 1 codepoint → 1 glyph
        case ligature                          // >1 base codepoint → 1 glyph (candidate Ligature Group)
        case baseWithMarks(baseCount: Int)     // base + Mn/Me combining marks in cluster
        case markOnly                          // mark got its own glyph (typical GPOS case)
        case control                           // ZWJ/ZWNJ/bidi controls: zero-width, non-selectable
    }
}
```

**Algorithm `MKClusterMapBuilder.build`** (O(g log g), g = glyph count):

1. Collect `(address, stringIndex)` for every glyph in every run.
2. Sort unique string indices ascending → cluster boundary candidates. For an RTL run,
   glyph order is visually LTR but string indices *descend*; sorting by string index
   restores logical order [^23].
3. A **cluster** = the set of glyphs sharing the same string index, spanning UTF-16
   range `[idx, nextIdx)` (next distinct index in logical order; last cluster ends at
   run string range end from `CTRunGetStringRange`).
4. Decode `codepoints` from the source string range (surrogate-pair aware:
   `String.UTF16View` → `Unicode.Scalar`).
5. Classify `kind`:
   - all codepoints are ZWJ (U+200D), ZWNJ (U+200C), or bidi controls → `.control`;
   - >1 non-mark codepoint and 1 glyph → `.ligature` (D-105's "ligature candidate");
   - contains combining marks (`Unicode.Scalar.Properties.generalCategory` is
     `.nonspacingMark`/`.enclosingMark`, or scalar in the explicit Arabic mark ranges
     of §6.2) → `.baseWithMarks` or `.markOnly` depending on whether the *glyph's*
     advance is zero and a base glyph shares the cluster;
   - else `.simple`.
6. Fill both inverse maps.

Correctness caveat (risk RSK-02): Core Text may fuse base+mark into a single precomposed
glyph, or split one codepoint into multiple glyphs (rare in Arabic fonts). The table
never assumes 1:1 anywhere; every algorithm downstream iterates `cluster.glyphs`.

### 4.6 Joining analysis

For each Arabic-letter cluster the engine computes the *expected* joining form from
Unicode joining types (ArabicShaping semantics via `Unicode.Scalar` properties table
embedded in `MKJoiningAnalyzer` — the ~90-entry joining-type table for the Arabic block
is compiled in, since Foundation does not expose Joining_Type):

```swift
public enum MKJoiningForm: String, Hashable, Sendable, Codable {
    case isolated, initial, medial, final
}
public struct MKJoiningState: Hashable, Sendable, Codable {
    public var form: MKJoiningForm             // form realized at derivation
    public var joinsPrevious: Bool             // toward logically-previous letter (visually right in RTL)
    public var joinsNext: Bool
    public var brokenByUser: Bool              // explicit break happened (§7.3)
}
```

`MKJoiningAnalyzer.expectedForm(at:in:)` walks logical-order letters, skipping
transparent codepoints (marks, ZWJ handled per rule), and returns the form Core Text
*should* have chosen. This is used (a) to label glyphs in the Arrange inspector,
(b) as the initial selection in the form picker after a join break (D-107), and
(c) as a debug cross-check against the harvested glyph.

### 4.7 Shaping cache & invalidation

Key: full `MKShapingRequest` hash (includes font ref + font checksum + feature set).
Invalidation events: font re-registration (`MKFontRegistry.fontsDidChange`), memory
ladder stage ≥1 (drop whole cache, D-116), document close. Cost accounting = glyph
count × 64 bytes estimate. The cache lives inside the actor; hit path is one actor hop
(measured budget: <0.1 ms; typing-echo budget 50 ms, D-115, leaves margin).

### 4.8 Typing mode integration (D-104)

The `MKTextEditingOverlay` (MKCanvas) hosts a `UITextView` (TextKit 2 — do not set
`.layoutManager`-era APIs, which force TextKit 1 fallback) positioned over the node,
with matched font, size, `baseWritingDirection`, tracking, and line height, and
transparent background. While editing:

- Every `textViewDidChange` mirrors the string into the node's `MKSourceText` through
  a *coalescing* editing command (§14.3) and triggers async shaping capture for the
  engine-rendered preview underneath (hidden while the overlay is visible to avoid
  double-draw; the overlay IS the preview during editing).
- On commit (`textViewDidEndEditing`, tap-outside, or الرجوع key in single-line), the
  overlay is removed and the engine-rendered Live Text object becomes the sole
  visual. TEST_MATRIX carries a golden test that overlay-final and engine-render are
  metrically identical (ascent/descent/width within 0.25 pt) for the bundled font set.
- IME/marked-text: while `textView.markedTextRange != nil`, mirroring is suspended
  (no commands generated) — marked text is never persisted.
- **Rotated objects (D-201)**: a Live Text node whose `transform.rotation != 0`
  **normalizes to axis-aligned** for the duration of editing — the overlay is
  positioned unrotated so system text-input affordances (selection handles,
  magnifier, marked-text UI) behave correctly — and **restores** the node's original
  rotation on commit. This is a documented UX tradeoff (D-201; PRD §5.1), not a bug:
  in-place editing of rotated text is intentionally not attempted.

---

## 5. Arrange Mode Engine

### 5.1 Derivation pipeline (D-106)

Entering Arrange Mode ("تحويل إلى تشكيل حر") on a Live Text or Path Text node runs:

```swift
public struct MKArrangeDeriver: Sendable {
    public func derive(from node: MKNode,                    // .liveText or .pathText
                       shaped: [MKShapedLine],               // fresh capture, purpose .arrangeDerivation
                       pathPlacements: [MKPathGlyphPlacement]? // §9 output when origin is pathText
    ) throws -> MKArrangedTextNode
}
```

Steps (all pure; output is one value):

1. **Backup.** Build `MKSourceTextBackup` from the node payload; compute
   `contentHash` (SHA-256 over canonical JSON encoding) — INV-4 anchor.
2. **Cluster sweep.** Iterate `clusterMap.clusters` in logical order. Per cluster kind:
   - `.simple` → one `MKGlyphNode`.
   - `.ligature` → one `MKLigatureGroup` in `.composed` state; `decomposable` =
     constituents all have known joining types (letters), false for exotic fusions.
   - `.baseWithMarks`/`.markOnly` → base glyph(s) become `MKGlyphNode`s / attach to
     the preceding base; each mark glyph becomes `MKMarkNode` with
     `relativeOffset = markPosition − basePosition` (both from `CTRunGetPositions` —
     this *is* the GPOS result, D-105) and `attachedTo = base.id`, `followsBase = true`.
   - `.control` → dropped from children; recorded in `clusterTable` so revert and
     Unicode-level editing still see them.
3. **Geometry freeze.** `layout.position` = line origin + shaped position (+ path
   placement transform for path origin); `advance` from capture; `outline` filled by
   `CTFontCreatePathForGlyph(font, glyph, &identity)` scaled to 1000/em (§3.6).
   Extraction happens once here — arranged rendering never asks the font again
   (INV-1, INV-13).
4. **Joining state.** From `MKJoiningAnalyzer` + neighbor examination (§4.6).
5. **Bidi snapshot.** Per-child `bidiLevel` + `visualIndex` (§8.3).
6. **Cluster table.** Persist the full `MKClusterMap` as `[MKClusterRecord]` (Codable
   projection) — the joint index both editing levels share.
7. **Node swap command.** The editor replaces the source node with the arranged node
   in one undoable command (`MKArrangeCommand`), so undo = instant un-arrange (the
   full former node is the command's inverse payload — distinct from *revert*, which
   is a forward command requiring confirmation, D-106).

Complexity O(g); a 5,000-glyph derivation ≈ 5,000 path extractions — measured budget
<400 ms on A15 (TEST_MATRIX perf gate; if exceeded, outline extraction falls back to
lazy fill with persistence-on-save, an allowed optimization because `outline` is
optional).

### 5.2 The two editing levels

**Shaped-glyph level** (default): selection/hit/transform operates on
`MKArrangedChild` values directly.

**Unicode-letter level** ("تحرير الحروف"): the inspector shows the backup string with
cluster highlighting driven by `clusterTable`; selecting a codepoint range selects the
mapped children (via `utf16ToCluster` → cluster → child ids); style edits applied at
this level fan out to all glyphs of the covered clusters. Because both levels address
the same children through `MKProvenance.clusterID`, switching levels is a *view*
change, not a data conversion — nothing is lost in either direction (BRIEF
requirement; verified by round-trip test T-ARR-*).

Text *content* editing at the Unicode level is not live in an arrangement (that would
force reshape, violating INV-1); the UI routes content changes through revert
(confirmation) or "duplicate as new text" instead.

### 5.3 Transform composition rules (D-220 — normative)

Mark attachment is an affine chain, not an ad hoc offset add. §6.3/§6.4 restate this
formula; this section is where it is defined once, normatively:

- **Glyph/ligature children** (no `followsBase`): world transform =
  `composition.affine ∘ child.affine`.
- **Following marks** (`followsBase == true`): world transform =
  `composition.affine ∘ base.affine ∘ translate(relativeOffset) ∘ mark.affine`,
  where `composition.affine`/`base.affine`/`mark.affine` are each `MKTransform2D.affine`
  (§3.2 — position, then rotation, then scale, in that composition order) and
  `relativeOffset` (`MKMarkNode.relativeOffset`) is expressed in **base-local space**
  (the coordinate frame *before* `base.affine` is applied, i.e. the frame the mark was
  captured in at derivation, §6.3) — never a raw world-space delta.
- **Pivot semantics**: because `translate(relativeOffset)` precedes `mark.affine` in
  the chain, the mark's own rotation/scale (from `mark.transform`) pivots about the
  relativeOffset-anchored origin, not about the mark's own bounds center or the base's
  origin. This matches the intuitive "rotate the tashkeel in place over the letter"
  behavior.
- **Non-uniform base scale**: if `base.affine` carries non-uniform `scale`, the
  `relativeOffset` component skews with it — this falls directly out of the affine
  chain above (the offset is transformed by `base.affine` like any other base-local
  point) and is *not* a special case to implement separately.
- **Re-attach** recomputes `relativeOffset` in base-local space (§6.4), never as a raw
  world-position subtraction — see the exact formula there.
- The numeric inspector edits decomposed fields directly (D-111 — no matrix drift).
- Multi-select transforms produce per-child delta commands batched into one undo
  group, pivoting about the selection bounds center (or a dragged anchor).

### 5.4 Revert (D-106)

`MKRevertService.revert(_:)` reconstructs the original node from
`MKSourceTextBackup` (verifying `contentHash`), emits `MKRevertCommand` whose inverse
is the entire arranged node — so even revert is undoable. UI copy (Arabic, per
FOUNDATION convention): "استرجاع النص الأصلي سيلغي جميع التعديلات الحرة. متابعة؟"
(Restoring the original text will discard all free-arrangement edits. Continue?).

---

## 6. Tashkeel/Marks Mechanics

### 6.1 Requirements recap

BRIEF: tashkeel **plus full Qur'anic/Uthmani-style marks** (founder Q11) attach to the
base by default, follow it, and are individually selectable/detachable/movable/
transformable. Note carefully: *mark support* is full; *Qur'anic content* is absent
(no verse data) — users may type any marks with any keyboard and the engine must
handle them.

### 6.2 Mark classification

```swift
public enum MKMarkClass: String, Hashable, Sendable, Codable {
    case tashkeel            // U+064B–0652 core harakat + shadda/sukun, U+0670 superscript alef
    case quranicAnnotation   // U+06D6–06ED Qur'anic annotation signs, U+0610–061A honorifics/marks
    case otherCombining      // any other Mn/Me (e.g., U+0653–065F maddah/hamza marks fall here or tashkeel per table below)
}

enum MKMarkTables {
    /// Explicit ranges required by D-105. Membership test is scalar-range based,
    /// falling back to generalCategory ∈ {nonspacingMark, enclosingMark}.
    static let honorifics: ClosedRange<UInt32>        = 0x0610...0x061A
    static let harakatBlock: ClosedRange<UInt32>      = 0x064B...0x065F   // fathatan…wavy hamza below
    static let superscriptAlef: UInt32                = 0x0670
    static let quranicAnnotations: ClosedRange<UInt32> = 0x06D6...0x06ED  // small high ligatures, stop signs, sajdah, rub el hizb…
    // Classification:
    //  0x064B–0x0652, 0x0670            → .tashkeel
    //  0x0653–0x065F                    → .tashkeel (extended harakat set)
    //  0x0610–0x061A, 0x06D6–0x06ED     → .quranicAnnotation
    //  other Mn/Me                      → .otherCombining
    static func classify(_ scalar: UInt32) -> MKMarkClass? { /* range switch as above */ }
}
```

Canonical combining classes (`Unicode.Scalar.Properties.canonicalCombiningClass`) are
recorded per mark (`ccc 27–35` for the fixed-position harakat, `230/220` for
above/below marks) and used only for *stacking order restoration* when a user re-attaches
a detached mark: marks re-stack in original captured order, but when the original order
is unavailable (mark moved across bases) the attacher orders by ccc then logical index.

### 6.3 Attachment capture

During derivation (§5.1 step 2), for each mark glyph:

- `relativeOffset = markShapedPosition − baseShapedPosition`, computed while both
  positions are still in the *same shaped-line (base-local) coordinate frame* — since
  both come from `CTRunGetPositions` at derivation time, this offset embodies the
  font's GPOS `mark`/`mkmk` anchoring (D-105) and is, by construction, already
  base-local (D-220 — see §5.3's normative affine chain, which is what consumes this
  field at render/hit-test time). No anchor-table parsing is performed (rejected:
  reading GPOS directly — fragile, redundant with shaped output).
- Base resolution: the base is the nearest preceding non-mark glyph *within the same
  cluster*; for `.markOnly` clusters (mark carried its own cluster, e.g., isolated
  tashkeel typed after a space) the mark becomes a **free mark**: `attachedTo = nil`
  from birth, positioned absolutely.
- Mark-on-mark (`mkmk`, e.g., shadda then fatha): `attachedTo` points at the *base
  glyph*, not the lower mark, but `relativeOffset` preserves the stacked position;
  `stackIndex` (`MKMarkNode.stackIndex`, D-220 — a dedicated field, not overloaded
  onto `MKProvenance.visualIndex`) records order within the captured stack so
  re-stacking is deterministic.

### 6.4 Behavior semantics

| Operation | Data effect | Notes |
|---|---|---|
| Move base glyph | none on mark values | renderer composes base transform when `followsBase` — mark follows for free per the §5.3 affine chain |
| Move mark (attached) | `mark.transform.position` delta, applied *after* `relativeOffset` in the §5.3 chain (i.e. in the base-local frame anchored at `relativeOffset`) | stays attached; `relativeOffset` itself is preserved on future base moves — only `transform` changes |
| Detach mark ("فصل الحركة") | `attachedTo = nil`; position rebased into composition space (current world position preserved) | undoable field command |
| Re-attach ("إلحاق بالحرف") | `attachedTo = target.id`; `relativeOffset` recomputed **in base-local space** (D-220, normative): `relativeOffset = target.affine⁻¹(mark.worldPosition) − target.affine⁻¹(target.worldPosition)` — never a raw world-space subtraction | target = user tap or nearest base by anchor distance |
| Hide/lock/style | per-node fields | marks are full citizens: opacity/fill/stroke/shadow all apply |
| Delete mark | child removal command | provenance stays in `clusterTable`; revert unaffected (INV-4) |

Rendering order: marks draw after their base (stack order per `MKMarkNode.stackIndex`,
D-220), within the composition's child z-order; a user may explicitly reorder (brings
mark above overlapping neighbor glyphs — legitimate calligraphic need).

### 6.5 Hit-testing marks

Marks are small; naive path hit-testing fails finger-size targets. `MKHitGeometry`
inflates mark hit bounds to min 22×22 pt in *view* space (scaled by zoom), and when a
tap hits base+mark overlap, the disambiguation order is: (1) currently-selected item's
handles, (2) mark, (3) base glyph, (4) repeated taps cycle (§10.5). Rationale: marks
are the harder target; base glyphs are reachable by tapping their body away from the
mark.

---

## 7. Ligature & Joining Mechanics

### 7.1 Scope

Two independent mechanics share Core Text plumbing:

- **Joining control**: breaking the cursive join at a chosen boundary, and selecting
  an explicit Joining Form for a letter afterward (D-107).
- **Ligature control**: treating a multi-codepoint single-glyph cluster (lam-alif,
  discretionary ligatures) as one object, decomposing it into constituent letters,
  and recomposing (D-108, founder Q71).

### 7.2 The ZWJ-context form resolver (D-107)

To realize a specific contextual form of a single letter *in the project's actual
font*, the resolver shapes a tiny synthetic string in which U+200D ZERO WIDTH JOINER
supplies the joining context, then harvests the letter's glyph. This is guaranteed
font-consistent because it exercises the font's own `init/medi/fina` OpenType logic
through Core Text, and it never touches presentation-form codepoints (INV-5).

**Exact synthetic contexts (normative):**

| Requested form | Synthetic string (logical order) | Harvest |
|---|---|---|
| `isolated` | `[letter]` | the letter's cluster glyph |
| `initial`  | `[letter] U+200D` | glyph of the letter's cluster (ZWJ cluster discarded) |
| `medial`   | `U+200D [letter] U+200D` | glyph of the letter's cluster |
| `final`    | `U+200D [letter]` | glyph of the letter's cluster |

```swift
public struct MKFormResolver: Sendable {
    let shaper: MKShapingService

    public func resolveGlyph(for scalar: Unicode.Scalar,
                             form: MKJoiningForm,
                             typography: MKTypography) async throws -> MKResolvedForm {
        let zwj = "\u{200D}"
        let s: String
        switch form {
        case .isolated: s = String(scalar)
        case .initial:  s = String(scalar) + zwj
        case .medial:   s = zwj + String(scalar) + zwj
        case .final:    s = zwj + String(scalar)
        }
        var req = MKShapingRequest.formResolution(s, typography)   // purpose: .formResolution, RTL base dir
        let line = try await shaper.shape(req).first!
        // Find the cluster whose codepoints == [scalar] (ZWJ clusters are .control kind):
        guard let cluster = line.clusterMap.clusters.first(where: { $0.codepoints == [scalar.value] }),
              let addr = cluster.glyphs.first
        else { throw MKError.formResolutionFailed(scalar, form) }
        let run = line.runs[addr.run]
        return MKResolvedForm(glyph: MKGlyphRef(glyphID: run.glyphs[addr.glyph],
                                                font: run.font,
                                                fontChecksum: /* from registry */,
                                                variationCoordinates: nil),
                              advance: run.advances[addr.glyph],
                              form: form,
                              achieved: /* §7.2.1 verification */ true)
    }
}
```

**7.2.1 Verification & degraded fonts.** Some display fonts lack full contextual
coverage; the resolver verifies the harvested glyph differs from the isolated-form
glyph when `form != .isolated`. If identical (font has no such form), the result is
returned with `achieved = false`; UI shows the form chip disabled with tooltip
"الخط لا يوفر هذا الشكل" (this font doesn't provide this form). Never synthesize a
fake form (INV-5). Dual-joining vs right-joining letters (د ر و ز ذ etc.) only offer
`isolated`/`final` in the picker — `MKJoiningAnalyzer` gates the menu.

### 7.3 Explicit join break

"كسر الوصل" on a selected boundary between two arranged glyph nodes:

1. Mark both glyphs `joining.brokenByUser = true` and update
   `joinsNext/joinsPrevious` across the boundary.
2. For each affected letter, resolve its new form: default = the form implied by its
   remaining connections (e.g., a formerly-medial letter whose *next* join broke
   becomes `final` — computed by `MKJoiningAnalyzer` truth table below).
3. Present the **form selector** (visual chips rendering each available form via
   `MKFormResolver`, actual glyph previews) — the user may override the default
   (BRIEF: "offer a visual selector for isolated/initial/medial/final").
4. Swap glyph id/outline/advance via `MKFormChangeCommand`; the glyph's
   position stays put (no reflow — INV-1); a small automatic gap (0.08 em, tunable)
   is inserted by shifting the visually-following side only if the user enables
   "إزاحة تلقائية" (auto-nudge), otherwise geometry is untouched.

Truth table (letter with previous/next join state → default form):

| joinsPrevious | joinsNext | default form |
|---|---|---|
| true | true | medial |
| false | true | initial |
| true | false | final |
| false | false | isolated |

(For right-joining-only letters, `joinsNext` is structurally false.)

Restoring a join ("إعادة الوصل") re-resolves both letters' forms the same way and
clears `brokenByUser`.

### 7.4 Ligature detection recap

From §4.5: cluster kind `.ligature` = >1 non-mark codepoint realized by one glyph.
Mandatory lam-alif (لا لأ لإ لآ) always satisfies this in Arabic fonts; discretionary
ligatures appear only when the feature set enabled them pre-arrangement (§7.6).
Detection is purely observational — whatever Core Text fused is what becomes a
Ligature Group (no ligature whitelist to maintain).

**Nested/overlapping-ligature scope (DF-12).** The model is deliberately flat: one
`MKLigatureGroup` per Core-Text-fused cluster, never a Ligature Group *containing*
other Ligature Groups. Core Text does not itself produce nested/overlapping ligature
clusters in practice for the bundled font set, so this is a by-design simplification,
not an unhandled case. A consequence a reviewer might mistake for a bug: after
decomposing a ligature group, the resulting sibling `MKGlyphNode`s are ordinary
children and may end up visually overlapping their non-ligature neighbors (e.g. a
decomposed lam-alif's components stroke-overlapping the glyph before it) — this is
**accepted-by-design**, documented identically to the translate case in §7.2.1
(T-AR-32/33 pattern: "neighbor glyphs are not modified"), and covered by a dedicated
decompose-neighbor-overlap fixture (TEST_MATRIX).

### 7.5 Decomposition with fidelity offsets (D-108)

`MKLigatureDecomposer.decompose(_ group:, in:)`:

1. Read constituents from `provenance.codepoints` (logical order), e.g. `[0x0644,
   0x0627]` for لا.
2. Determine each constituent's *joining-preserving* target form: the ligature as a
   whole had `joining` (joins-previous/next captured at derivation). First
   constituent inherits joins-previous, last inherits joins-next; interior
   constituents are medial-context. Map through the §7.3 truth table → per-letter
   `MKJoiningForm`.
3. Resolve each constituent glyph via `MKFormResolver` (ZWJ contexts) → glyph ids,
   advances, outlines.
4. **Fidelity placement** (`fidelityMode = .matchOriginal`, the default per Q71) —
   **the normative n-ary placement algorithm is WS-04's single affine fit; the steps
   below are subordinate to and must match that spec exactly (D-221). Where this
   prose and WS-04 ever appear to diverge, WS-04's wording is canonical.**
   - Lay constituents on a provisional pen line RTL: x-cursor starts at the
     ligature's `layout.position.x + layout.advance.width`, each constituent placed
     at cursor minus its advance (visual RTL order = reverse of logical for these
     letters).
   - Compute union bounds `U` of provisional outlines; original ligature outline
     bounds `L` (both at same em scale).
   - **Single affine fit**: one uniform-scale factor `s = clamp(L.width / U.width,
     0.85, 1.15)` applied to *advances only* (letterforms are not distorted); the
     first and last components are edge-aligned to `L.minX`/`L.maxX`, and interior
     components' x-offsets are derived *from the fit itself* (not placed by separate
     "proportional spacing" prose — the fit's uniform scale plus edge alignment
     determines every interior offset algebraically). Vertical `Δy` aligns each
     component baseline to the ligature baseline, plus for lam-alif specifically the
     alef component receives the `Δy` that best matches the original crossing height
     (least-squares on outline extrema — a 2-term fit, closed form).
   - **Pre-flight clamp-refusal fallback (D-221)**: the clamp check runs *before*
     committing to fidelity placement. If the natural (unclamped) fit ratio
     `L.width / U.width` falls outside `[0.85, 1.15]`, fidelity mode is **refused**
     for that ligature — decomposition automatically falls back to
     `fidelityMode = .defaultForms` (step 5) and surfaces the existing "cannot match
     original look" notice UX (mirrors the R-21.9 pattern), rather than silently
     applying an out-of-range scale. R-8.10's "looks unchanged / Δ ≤ 0.5 pt"
     acceptance criterion holds **only within the clamp** — it is reworded in PRD to
     that scope and stays P0 within it.
   - Per-component `fidelityOffsets[id] = Δ` is the offset actually applied by the
     fit above (first/last edge-aligned, interior from the fit, vertical `Δy` as
     described) — stored for exact reproducibility, not recomputed at render time.
   - Result: the decomposed pair *visually approximates the ligature* until the user
     moves parts (BRIEF: "Decomposition preserves original ligature look by default
     via positioning/kerning"), and only when the natural fit is within the clamp.
5. `fidelityMode = .defaultForms` (explicit opt-out, Q71, or automatic pre-flight
   fallback per step 4): skip step 4; place constituents at natural advances from the
   ligature origin, no offsets, no scaling.
6. Re-anchor marks: each id in `attachedMarks` re-points `attachedTo` to the
   component whose outline x-center is nearest the mark's captured anchor x; offsets
   recomputed to preserve world position.
7. Emit `MKLigatureDecomposeCommand` storing the prior `.composed` state — inverse =
   instant recompose.

### 7.6 Recomposition & feature control

- **Recompose** ("دمج المركّب"): restore `original` composed state; component-level
  user edits are discarded after a confirmation if any component was touched. **Dirty
  check (D-221, amended)**: compares FULL node state against the post-decomposition
  baseline — both `transform ≠ baseline.transform` AND `style ≠ baseline.style`
  (fill/stroke/opacity/shadow) — not transform alone; confirmation fires on any delta
  in either. (The transform-only check silently dropped style-only edits — e.g. a
  user recoloring one decomposed letter without moving it — which this fixes.) Marks
  re-anchor back to the group on confirm.
- **Discretionary ligatures** are a *pre-arrangement* text property (D-108):

```swift
public struct MKFontFeatureSet: Hashable, Sendable, Codable {
    public var standardLigatures: Bool = true      // rlig/liga — lam-alif etc.
    public var discretionaryLigatures: Bool = false // dlig
    public var contextualAlternates: Bool = true    // calt
    /// Rendered into CTFontDescriptor:
    /// kCTFontFeatureSettingsAttribute: [[kCTFontOpenTypeFeatureTag: "dlig",
    ///                                    kCTFontOpenTypeFeatureValue: 1], …]
    /// plus legacy AAT pair [kCTFontFeatureTypeIdentifierKey: kLigaturesType,
    /// kCTFontFeatureSelectorIdentifierKey: kRareLigaturesOnSelector] for AAT-only fonts.
    func descriptorAttributes() -> [CFString: Any] { /* as documented above */ }
}
```

Toggling features on a Live Text node re-shapes (allowed — it is live); toggling is
disabled on arranged nodes (INV-1), where the equivalent operation is
decompose/recompose per group.

---

## 8. Bidi Model

### 8.1 Principles (D-109)

Makhtoot performs **no bidi resolution of its own**. Core Text's UBA implementation
resolves runs [^24]; the engine records the outcome and preserves it. The paragraph
base direction comes from `NSParagraphStyle.baseWritingDirection`, default
`.rightToLeft` for all new text objects (Arabic-first product).

### 8.2 Captured structure

```swift
public struct MKBidiMap: Hashable, Sendable {
    public var baseDirection: MKBaseDirection          // .rightToLeft | .leftToRight | .rightToLeftOverride
    public var runs: [MKBidiRun]                       // visual order (CTLine run order, D-109)
}
public struct MKBidiRun: Hashable, Sendable {
    public var utf16Range: Range<Int>                  // logical range (CTRunGetStringRange)
    public var level: UInt8                            // even = LTR, odd = RTL
    public var isRTL: Bool                             // kCTRunStatusRightToLeft
    public var visualOrdinal: Int
}
```

`level` derivation: Core Text exposes only the RTL bit per run, not the full embedding
level. `MKBidiMap` assigns level 1 to RTL runs and level 2 to LTR runs inside an RTL
paragraph (0 for LTR-in-LTR) — sufficient because Makhtoot needs *relative* ordering
and directionality, not nested-embedding reconstruction; explicit directional controls
typed by the user simply flow through Core Text and land in `.control` clusters.

### 8.3 Arranged bidi snapshot

```swift
public struct MKBidiSnapshot: Hashable, Sendable, Codable {
    public var baseDirection: MKBaseDirection
    public var childVisualOrder: [MKNodeID]            // left→right at derivation
    public var levels: [MKNodeID: UInt8]
}
```

Uses:

- **Coherent sub-run selection**: "select word/run" expands selection across children
  sharing a bidi run, in visual order, so a Latin phrase inside Arabic selects as one
  contiguous visual block (BRIEF: mixed Arabic-English stays coherent).
- **Arrow-key/nudge traversal** in the inspector's letter level follows logical order;
  canvas tab-cycling follows `childVisualOrder`.
- **Numerals**: Arabic-Indic digits (U+0660–0669) are RTL-run members with LTR digit
  ordering handled by the UBA before capture — nothing special in the model; Latin
  digits form LTR runs. Both verified in T-BIDI tests with mixed strings.

### 8.4 Paragraphs and multiple lines

`MKTextFrameSpec.width` produces multiple `MKShapedLine`s; line order is visual top-
down, each line carrying its own runs. Line origins stack by
`ascent + descent + leading` × `lineHeightMultiple` (group-level line height per
BRIEF lives on `MKGroupNode.lineHeightOverride` for arranged compositions and on
typography for live text). Hard newlines split paragraphs; each paragraph reuses the
node's base direction (no per-paragraph auto-detection in v1 — documented limitation,
seam in §24).

---

## 9. Path Text Engine

### 9.1 Problem statement

Core Text has no curved-baseline support; Makhtoot computes per-glyph transforms along
a user-editable Bézier path (market study §4 confirms this is the standard, solvable
approach and flags RTL glyph-order handling as the care point). Path Text
stays fully reflowable — retype, restyle, or edit the path and layout recomputes —
until the user arranges it (D-110), at which point placements freeze into an
Arranged Composition like any other (§5).

### 9.2 Path model

```swift
// MKPathText — value-type path, Codable, editable control points
public struct MKBezierPath: Hashable, Sendable, Codable {
    public var segments: [MKBezierSegment]     // connected cubic segments
    public var isClosed: Bool                  // circles/ellipses import as closed
    public struct MKBezierSegment: Hashable, Sendable, Codable {
        public var start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint
    }
    public func cgPath() -> CGPath { /* moveTo start, addCurve per segment */ }
}
```

Built-ins (circle, arc, wave, line) are constructors producing ordinary segments —
no special-case layout. Quadratic input (from SVG import) is elevated to cubic on
construction.

### 9.3 Arc-length parameterization (D-110)

```swift
public struct MKArcLengthTable: Sendable {
    /// Samples per segment: adaptive subdivision until chord-vs-arc error < 0.05 pt,
    /// min 16 / max 256 samples per segment. Stores cumulative length s_i at
    /// parameter t_i (global t = segIndex + localT).
    let samples: [(t: Double, s: Double)]
    public let totalLength: Double

    public init(_ path: MKBezierPath) { /* subdivision as documented */ }

    /// Inverse map: arc length → t, binary search + linear interpolation. O(log n).
    public func parameter(atLength s: Double) -> Double
    public func point(atLength s: Double) -> CGPoint          // De Casteljau at t(s)
    public func tangent(atLength s: Double) -> CGVector       // normalized derivative; §9.6 for degenerate points
}
```

Rebuild triggers: any control-point/segment mutation (live editing drags rebuild only
the touched segment's samples — table is per-segment cumulative, so downstream offsets
shift by a delta, O(segments)).

### 9.4 Layout algorithm with logical reading order pen advance (DF-6a)

Input: shaped capture of the source text as a single line (`.singleLine` frame —
path text never soft-wraps), plus:

```swift
public struct MKPathLayoutOptions: Hashable, Sendable, Codable {
    public var startOffset: Double        // arc-length inset from path start (pt)
    public var side: Side                 // .baselineOnPath | .above | .below (baseline shift normal to path)
    public var glyphSpacing: Double       // extra advance per glyph (adds to tracking)
    public var overflow: Overflow         // .clip | .continueTangent (glyphs past end follow exit tangent)
    public enum Side: String, ... ; public enum Overflow: String, ...
}
```

**Algorithm `MKPathLayoutEngine.layout`** — the pen walks the path in *path
direction*; glyphs are consumed in **reading order**, which for RTL content means
walking the captured runs so the logically-first cluster is placed first:

```swift
public struct MKPathGlyphPlacement: Hashable, Sendable {
    public var address: MKGlyphAddress
    public var pathPoint: CGPoint          // arc point for glyph's advance midpoint
    public var tangentAngle: Double        // radians
    public var transform: MKTransform2D    // final glyph transform (position+rotation)
}

func layout(line: MKShapedLine, table: MKArcLengthTable,
            options: MKPathLayoutOptions) -> [MKPathGlyphPlacement] {
    // 1. Build reading-order glyph sequence:
    //    for each run in line.runs (CTLine visual order):
    //      RTL run → iterate glyph indices REVERSED (visual order within an RTL run
    //                is reverse of logical [^23]); LTR run → forward.
    //    Then order runs by their logical start (MKBidiMap.utf16Range.lowerBound)
    //    so mixed-direction text reads continuously along the path.
    // 2. Pen advance:
    var s = options.startOffset
    var out: [MKPathGlyphPlacement] = []
    for g in readingOrderGlyphs {
        let w = g.advance.width + options.glyphSpacing
        let mid = s + w / 2                            // anchor at advance midpoint:
        guard mid <= table.totalLength || options.overflow == .continueTangent else { break }
        let p  = table.point(atLength: min(mid, table.totalLength))
        let tv = table.tangent(atLength: min(mid, table.totalLength))
        // 3. Orientation: rotate so the glyph's baseline lies along the tangent.
        //    RTL reading along the path is achieved by ADVANCING the pen and rotating
        //    by the tangent — the glyph's own outline handles its directionality;
        //    we do NOT negate the tangent for RTL (letters would flip). The visual
        //    result: text starts at path start and reads letter-by-letter along it.
        let angle = atan2(tv.dy, tv.dx)
        // 4. Position: arc point minus half-advance along tangent (so outline is
        //    centered on its arc span), plus normal offset for .above/.below side.
        let n = CGVector(dx: -tv.dy, dy: tv.dx)        // left normal
        let sideShift = options.side.baselineShift     // 0 | +ascent-ish | −descent-ish
        let origin = CGPoint(x: p.x - cos(angle) * w/2 + n.dx * sideShift,
                             y: p.y - sin(angle) * w/2 + n.dy * sideShift)
        out.append(.init(address: g.address, pathPoint: p, tangentAngle: angle,
                         transform: MKTransform2D(position: origin, rotation: angle,
                                                  scale: .init(width: 1, height: 1))))
        s += w
    }
    return out
}
```

Key correctness points:

- **Advance-midpoint anchoring** (not leading-edge) keeps glyphs visually centered on
  curvature and dramatically reduces inter-glyph gap/overlap on tight curves; the
  half-advance back-shift restores correct pen metrics on straight sections
  (identical to flat layout — golden test T-PATH-flatline).
- **Joining on curves**: connected Arabic letters remain *shaped* as connected forms
  (shaping happened on the flat line), but on high-curvature paths the joint strokes
  can gap. Mitigation (documented UX, not engine): curvature indicator in the path
  inspector when `|Δangle|` between adjacent glyph midpoints exceeds 12°; optional
  "تراكب الوصلات" (joint overlap) slider adds negative `glyphSpacing`.
- Marks ride with their base: mark placements reuse the base glyph's arc frame —
  offset applied in the rotated glyph frame, so a fatha stays above its letter
  even on a vertical tangent.

### 9.5 Live editing & arrange-on-path

- Live: control-point handles are canvas gizmos editing `MKBezierPath` through
  coalesced commands; each mutation → table rebuild → relayout → re-render.
  Budget: ≤2 ms for a 200-glyph path text on A15 (fits the 8.3 ms frame, D-115).
- Retype: text change → reshape → relayout (path unchanged).
- **Arrange** (D-110): `MKPathTextArranger` feeds the current placements into
  `MKArrangeDeriver.derive(…, pathPlacements:)`; each glyph's frozen
  `layout.position`/`transform.rotation` come from its placement,
  `layout.pathTangentAngle` is recorded, the path itself is stored (frozen copy) in
  `derivedFrom: .pathText(path)` for provenance/revert. After arrangement the path is
  no longer editable (INV-1); revert restores the live Path Text node with its path.

### 9.6 Degenerate geometry

Zero-length segments, cusps (zero derivative): tangent falls back to
secant over ±0.5 pt arc length; coincident control points are perturbed by 1e-4 on
table build (never persisted). Closed paths wrap `s` modulo length when
`overflow == .continueTangent`.

---

## 10. Canvas & Interaction

### 10.1 View stack (D-100, D-114)

```
SwiftUI EditorScreen (RTL layout, panels, inspector, toolbars)
 └─ MKCanvasHostRepresentable (UIViewControllerRepresentable)
     └─ MKCanvasViewController (UIKit)
         └─ UIScrollView (zoom 2.5%–6400%, pan, rubber-banding)
             └─ MKCanvasView (content view, canvas-sized)
                 ├─ CALayer tree (one layer per top-level node, §11.2)
                 ├─ MKGuideOverlayView (alignment guides, snap flashes)
                 ├─ MKSelectionOverlayView (marquee, handles, rotation knob)
                 └─ MKTextEditingOverlay (UITextView, present only while editing text §4.8)
```

Zoom uses `UIScrollView` native pinch (`viewForZooming`); at gesture end, layer
contents re-render at the new scale (§11.3). The canvas view is LTR internally
(geometry is geometry); *UI chrome* (panels, handles labeling, rulers) is RTL via
the app-wide `ar` layout direction — deliberate split so canvas math never mirrors.

### 10.2 Gesture routing

`MKGestureRouter` owns one tap, one double-tap, one pan, one pinch-rotate composite,
and one long-press recognizer on the canvas, and resolves intent by phase:

| Gesture | Context | Action |
|---|---|---|
| Tap | empty | deselect |
| Tap | node | select (respecting groups: first tap selects outermost group) |
| Tap | selected group | drill into child (second tap) |
| Double-tap | live/path text | enter text editing overlay |
| Double-tap | arranged composition | enter composition scope (children selectable) |
| Pan | on selection | move (translate command, coalesced §14.3) |
| Pan | on handle | resize/rotate per handle role |
| Pan | empty | marquee select |
| Pinch/rotate | selection | scale/rotate about gesture centroid |
| Long-press | node | context menu (duplicate, lock, hide, arrange, order) |
| Two-finger tap | anywhere | undo (platform convention); three-finger redo |

All transforms operate in *canvas space*; the router converts via
`scrollView.convert` + zoomScale once per gesture, not per event.

### 10.3 Hit testing

```swift
// MKRender.MKHitGeometry — pure functions over MKSceneSnapshot geometry
public struct MKHitTester: Sendable {
    /// Top-most first. tolerance in canvas points (view 22pt / zoomScale, min 2 pt).
    public func hits(at p: CGPoint, in scene: MKScene, scope: MKHitScope,
                     tolerance: CGFloat) -> [MKHitResult]
}
public enum MKHitScope: Sendable {
    case topLevel                          // nodes & groups as units
    case insideGroup(MKNodeID)             // children of one group
    case insideComposition(MKNodeID)       // arranged children (glyph/mark/ligature)
}
public struct MKHitResult: Sendable, Hashable {
    public var nodeID: MKNodeID
    public var part: Part
    public enum Part: Hashable, Sendable { case body, strokeEdge, markInflatedZone }
}
```

Algorithm per node (reverse z-order, early exit unless collecting for tap-cycling):

1. Transform `p` by the node chain's inverse affine (`MKTransform2D.affine.inverted()`)
   into node-local space — O(1), no path transforms.
2. Cheap reject: local-space bounding box inflated by tolerance.
3. Precise test by kind: shapes/glyphs → `CGPath.contains(_:using:.winding)` on the
   cached CGPath, plus stroke test via `path.copy(strokingWithWidth:...)` when stroke
   present; images/backgrounds → rect; live text → line fragment rects (glyph-precise
   only inside compositions, where outlines exist).
4. Marks: §6.5 inflated zone.
5. Hidden nodes are skipped; locked nodes are skipped by canvas tap hit-testing —
   taps fall through to the node below (PRD R-4.6). A locked node remains
   selectable from the layers panel, shown with a lock badge (corrected in Run 3
   to match PRD R-4.6; see docs/impl-log/WS-06.md).

Tap-cycling: repeated taps within 1.5 s at ≤8 pt distance walk the `hits` array so
occluded objects are reachable.

### 10.4 Selection, handles, transforms

`MKSelectionController` (`@MainActor`) publishes
`Set<MKNodeID>` + derived `selectionBounds` (union of world-space OBBs). Handles:
8 resize + 1 rotate knob; modifiers: aspect-lock default ON for glyph nodes
(letterform integrity), OFF for shapes; Alt-style duplicate-drag is long-press+pan.
Numeric inspector binds directly to decomposed transform fields (D-111) with
Arabic-Indic or Latin numeral entry both accepted (`NumberFormatter` locale `ar`).

### 10.5 Guides & snapping

`MKGuideEngine` computes candidate snap lines each pan frame from: canvas edges/center,
other nodes' edges/centers (visible, unlocked, within viewport, max 200 candidates by
proximity), and equal-spacing triples. Snap threshold 6 view-pt (zoom-normalized);
hysteresis 2 pt to prevent flicker; haptic tick on engage (`UIImpactFeedbackGenerator
(.light)`). Spatial candidates are indexed in a simple sorted-array-by-x/y structure
rebuilt on scene change (O(n log n), n ≤ 5,000 → sub-ms).

### 10.6 Layers panel contract

The panel is SwiftUI, driven by a `MKLayerListModel` projection of the scene: rows =
top-level nodes (recursively disclosable groups and compositions, virtualized with
`LazyVStack` beyond 200 rows per D-116's virtualization principle). Row controls map
1:1 to commands: visibility (`MKSetHiddenCommand`), lock, rename, reorder
(drag-and-drop → `MKReorderCommand`), with arranged children (glyphs/marks/ligatures)
appearing as nested rows with their provenance labels (letter names via
`Unicode.Scalar.properties.name` localized table, e.g. "حاء — وسطية").

---

## 11. Rendering & Preview

### 11.1 Renderer core (D-114)

```swift
// MKRender — the ONLY drawing entry point (INV-2, INV-6)
public struct MKSceneRenderer: Sendable {
    public func render(_ snapshot: MKSceneSnapshot,
                       region: CGRect,                 // canvas-space region to draw
                       into ctx: CGContext,            // bitmap, PDF, or layer context
                       scale: CGFloat) throws -> MKRenderReport
}
```

Draw order: background node → `nodes` array ascending (index 0 backmost) → per node:
save gstate, concat node affine, apply opacity via transparency layer when
`opacity < 1` or shadow present (`ctx.setShadow` then `beginTransparencyLayer` so
group shadows composite correctly), dispatch by case:

- **shape/image/background**: CGPath fill/stroke; raster assets via `CGImage` drawn
  with interpolation `.high` at export, `.medium` in preview; vector PDF assets via
  `CGPDFDocument` page draw; SVG assets via pre-parsed `MKAssetVectorProgram`
  (MKAssets parses bundled/imported SVG once into path commands — the same parser
  feeding the SVG *writer's* element model, §16.6).
- **liveText**: shape (cache hit expected) → per run: set fill → `CTFontDrawGlyphs`
  with positions offset by line origin. Stroke/shadow on live text draw per-glyph
  paths instead (outline needed) — automatic internal switch, geometry identical.
- **pathText**: placements (§9.4) → per glyph: concat placement transform →
  `CTFontDrawGlyphs` single glyph at origin (or path fill when stroked).
- **arranged**: per child in z-order (glyphs/ligatures first per z, marks per
  `stackIndex` within their base, D-220): concat the world affine per §5.3's
  normative chain — `composition.affine ∘ child.affine` for glyphs/ligatures, or
  `composition.affine ∘ base.affine ∘ translate(relativeOffset) ∘ mark.affine` for a
  following mark (`relativeOffset` is base-local, never world-space; §5.3/§6.3) —
  then fill/stroke the stored `outline` path (`MKPathData.cgPath(at:)` cached per
  (node, size)); never consult the font at render time (INV-13).

`MKRenderReport` carries per-node timing + any substitution events (missing asset,
missing outline) — surfaced in debug HUD and asserted empty in export tests.

### 11.2 Layer tree for interactive canvas (D-114)

`MKLayerTreeController` maintains `CALayer` per **top-level** node (not per glyph —
5,000 CALayers would sink compositing):

- Layer geometry = node bounds; `layer.setAffineTransform(node.transform.affine)`.
  Pure transform edits (drag/rotate/scale — the 60/120 Hz hot path) mutate layer
  properties only, with `CATransaction` disabling implicit animations; scene commits
  happen at gesture end (§14.3). This is what makes manipulation cheap (D-114).
- Layer contents = bitmap rendered by `MKSceneRenderer` for that node subtree at
  `contentsScale = screenScale × zoomBucket` (§11.3), produced on the render queue,
  assigned on main.
- Arranged compositions get one layer; child edits invalidate the composition layer
  only. During an *in-composition* drag, the moving child is temporarily promoted to
  its own transient layer over a "composition minus child" underlay bitmap, then
  recomposited on gesture end — constant-cost glyph dragging in 1,000-glyph
  compositions.
- Dirty tracking via `MKSceneDiffer` (§3.7): transform-only diffs → property update;
  content diffs → re-render that layer; structure diffs → insert/remove layers.

### 11.3 Zoom buckets & tile cache

Re-rendering all layers continuously during pinch is wasteful; during the gesture
layers scale visually (CA transform), then on `scrollViewDidEndZooming` contents
re-render at the nearest **zoom bucket** (powers of √2 from 0.025× to 64×). Nodes
larger than 4,096² px at current bucket switch to `CATiledLayer`-style manual tiling
via `MKTileCache` (256-pt tiles, LRU byte-capped, cost = bytes; integrated with the
degradation ladder — stage 1 drops offscreen tiles first, D-116).

### 11.4 Degradation controller (D-116 hooks)

`MKDegradationController` exposes `fidelity: MKRenderFidelity` (`.full`, `.reduced`)
consumed by the renderer: `.reduced` → half-resolution layer bitmaps
(`contentsScale / 2`), shadows approximated (no transparency layer; flat offset fill
at 30% alpha), image interpolation `.low`, tile prefetch off. Transitions are driven
by the memory ladder (§12.4) and never by entitlement (BRIEF: engineering safeguard,
not a feature cap).

---

## 12. Performance & Memory

### 12.1 Budgets restated (D-115 — gates live in TEST_MATRIX)

| Budget | Value | Gate context |
|---|---|---|
| Manipulation frame time | ≤ 8.3 ms on ProMotion hardware; ≤ 16.6 ms floor on A12-class | drag/rotate/scale of any selection incl. 1,000-glyph composition |
| Typing echo | < 50 ms keystroke → visible glyph | UITextView overlay + mirror pipeline |
| Open typical project (≤100 nodes) | < 1 s | tap → editable canvas |
| Open heavy project (5,000 nodes) | < 3 s | tap → editable canvas (progressive render allowed after first paint) |
| Incremental autosave | < 100 ms, off main thread | per mutation batch |
| 4K PNG export | < 10 s on A15 | tiled pipeline §16.4 |
| Peak editor memory | < 60% of `os_proc_available_memory()` before degradation begins | continuous sampling |

### 12.2 Engineering consequences per budget

- **8.3 ms manipulation** ⇒ the hot path may not allocate scene copies, shape text, or
  render bitmaps. Achieved by: layer-property-only transforms (§11.2), gesture
  coalescing into a single command at gesture end (§14.3), snap candidate index
  precomputed (§10.5), hit testing O(n) with bbox early-out. Instruments signposts
  (`os_signpost` intervals `mk.gesture.frame`) wrap the pan handler; TEST_MATRIX
  reads them via `xctrace`.
- **50 ms typing echo** ⇒ typing renders through the native UITextView (zero engine
  work in the echo path, D-104); shaping capture for the underlying node is async and
  cancellable (`Task` per keystroke burst, cancel-previous).
- **<1 s / <3 s open** ⇒ document open = read manifest + scene.json decode + first
  visible-viewport render only; offscreen layer contents render lazily; asset decode
  deferred to first draw with placeholder tint; heavy-project decode uses a streamed
  `JSONDecoder` pass (nodes array is decoded incrementally; §13.4 layout keeps nodes
  as a flat top-level array partly for this).
- **<100 ms autosave** ⇒ journal append (§14.4) is the per-mutation cost (~1 KB write,
  fsync-less); full scene.json serialization runs debounced (≤2 s, D-112) on the
  persistence queue over a snapshot; encode of a 5,000-node scene is budgeted <350 ms
  *off-main* and does not count against the 100 ms incremental gate.
- **<10 s 4K export** ⇒ tiled strips sized to keep each `CGBitmapContext` ≤ 64 MB
  (§16.4), glyph outline paths pre-resolved from the snapshot (no font I/O in the
  loop), JPEG/PNG encode via ImageIO incremental destination.
- **<60% memory ceiling** ⇒ every cache is byte-accounted and registered with
  `MKMemoryGovernor` (shaping cache, tile cache, outline CGPath cache, asset image
  cache, undo stack estimate); the governor enforces proportional eviction before the
  OS pressure source fires.

### 12.3 Memory governor & instrumentation

```swift
// MKFoundation
public protocol MKMemoryAccountable: AnyObject, Sendable {
    var accountedBytes: Int { get }
    func evict(toFraction: Double)     // 0 = drop all
}
public final class MKMemoryGovernor: Sendable {
    public func register(_ c: any MKMemoryAccountable, priority: EvictionPriority)
    /// Samples os_proc_available_memory() every 2 s while editor is frontmost,
    /// plus immediately on DispatchSource memory-pressure events (D-116).
    public func start(ladder: MKMemoryLadderDelegate)
}
```

`.warning`-event semantics (D-223): the `DispatchSource` `.warning` event is a coarse
OS-level signal, not itself an `MKMemoryStage`. On `.warning`, the governor forces an
**immediate sample** of `os_proc_available_memory()` and, regardless of what
`usedFraction` that sample reports (even if it comes back below the 0.70 stage-1
threshold), forces entry into **stage1** — a deliberately conservative reaction to a
signal that historically precedes real pressure. `.critical` events map directly to
`MKMemoryStage.critical` (§12.4) and are never downgraded.

`VERIFY-AT-IMPLEMENTATION` (DF-12): `MKMemoryLadder` and `MKMemoryGovernor` are
declared `final class … : Sendable`/actor-adjacent types that mutate stage state from
a `DispatchSource` callback queue (`.global(qos: .utility)`) while being read from the
main actor (UI banners) and from render/export tasks (fidelity checks); under Swift 6
strict concurrency this needs an explicit isolation story (actor vs. manually-audited
`@unchecked Sendable` with a lock) — confirm the concrete isolation mechanism at
implementation, not assumed here.

### 12.4 Memory-pressure ladder implementation (D-116)

```swift
public enum MKMemoryStage: Int, Sendable { case normal = 0, stage1 = 1, stage2 = 2, critical = 3 }

final class MKMemoryLadder: MKMemoryLadderDelegate {
    // Thresholds over usedFraction = 1 - available/total budget:
    //   ≥0.70 → stage1 ; ≥0.85 → stage2 ; DispatchSource .critical event → critical.
    // Hysteresis: step down only after 10 s below (threshold − 0.05).
    let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                         queue: .global(qos: .utility))
    func transition(to stage: MKMemoryStage) async {
        // INV-17: a completed save happens FIRST, degrade second — but the save's
        // *shape* differs by stage (D-223, amends D-116/D-210's claim). Stages 1–2
        // still afford a full debounced-save-equivalent flush; the critical stage
        // does not, because a full scene re-encode is itself a large allocation on
        // the path we're trying to relieve.
        switch stage {
        case .normal:
            degradation.fidelity = .full
        case .stage1:
            await autosave.flushNow(reason: .memoryPressure(stage))   // full scene.json flush
            governor.evictOffscreen()            // bitmap tiles, shaping cache
        case .stage2:
            await autosave.flushNow(reason: .memoryPressure(stage))   // full scene.json flush
            degradation.fidelity = .reduced      // half-res layers, simplified shadows
            banner.show("الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا")   // D-116 exact copy
        case .critical:
            // D-223: critical stage is JOURNAL-FLUSH-ONLY. No flushNow() here — no
            // full-scene re-encode, no new large allocations; append-only journal
            // write is the entire save operation, still satisfying INV-17's
            // save-before-degrade ordering with a bounded, small allocation.
            await journal.flushSync()            // synchronous journal flush only
            governor.evictAll()
        }
    }
}
```

**INV-17 wording (amended, D-223)**: "Every memory-ladder stage transition (D-116)
triggers a completed save *appropriate to that stage* — a full autosave/journal flush
at stages 1–2, a synchronous journal-only flush at critical — before any cache
eviction or fidelity degradation takes effect." *Test:* instrumented pressure
simulation asserting save-completes-before-evict ordering at *every* stage, including
critical.

Recovery after termination: relaunch → `MKDocumentStore` detects journal newer than
`scene.json` → replay (§14.5) → exact restore (BRIEF: "no-loss recovery after
termination").

### 12.5 No artificial caps

There are no premium/entitlement branches anywhere in MKRender, MKCanvas, or the
governor (BRIEF: no artificial caps on canvas size/glyph/object count). Warnings near
hardware limits are informational + autosave-backed (Q76). The only size-bounded
resource is export bitmap *strips*, bounded by RAM math, not policy (§16.4).

---

## 13. Persistence & Documents

### 13.1 The `.makhtoot` file package (D-112)

A project is a directory package (UTI `net.binjamshid.makhtoot.project`, conforms to
`com.apple.package`; extension `.makhtoot`; UTI string is FD-01 applied):

```
MyPoster.makhtoot/
├── manifest.json          # small, fast-open metadata (below)
├── scene.json             # full Codable scene graph, schemaVersion 1 (§13.4)
├── journal.mkj            # crash-recovery journal; absent/empty after clean flush (§14.4)
├── assets/
│   ├── sha256-3f9a…b2.jpg   # content-addressed imported raster
│   ├── sha256-77c1…09.svg   # imported SVG (original bytes, verbatim)
│   └── sha256-a4d0…5e.pdf   # imported PDF asset
├── backups/
│   ├── rescue-2026-07-17T09-31-04Z.scene.json   # rescue snapshots (ring of 5)
│   └── …                  # (Source Text Backups live INSIDE scene nodes, D-112)
└── thumbnail.png          # 512-pt-max preview, regenerated on save
```

- **Content addressing**: asset filename = `sha256-<hex>.<ext>`; import dedupes by
  digest; nodes hold `MKAssetRef(digest, ext)`. Deleting the last referencing node
  does NOT delete the asset until package "compact on close" GC runs (undo safety);
  export snapshots hard-link assets (§3.5).
- **Rescue snapshots**: a full copy of `scene.json` before destructive multi-step
  operations (revert of arrangement, schema migration) — ring buffer of 5, oldest
  pruned.
- Package lives under `Documents/Projects/<projectUUID>.makhtoot`. Folders are
  *metadata* (SwiftData), not filesystem nesting — moving a project between folders
  never touches the package (cheap, sync-friendly).

### 13.2 Example `manifest.json`

```json
{
  "manifestVersion": 1,
  "projectID": "5B2A7C0E-9C1D-4F7A-B7E3-2D1A8F6C4E90",
  "schemaVersion": 1,
  "title": "بطاقة تهنئة العيد",
  "canvas": { "width": 1080, "height": 1350, "presetID": "social.portrait.4x5" },
  "createdAt": "2026-07-01T10:22:41Z",
  "modifiedAt": "2026-07-17T09:31:04Z",
  "appBuild": "1.0 (100)",
  "thumbnail": "thumbnail.png",
  "counts": { "nodes": 14, "arrangedGlyphs": 63, "assets": 2 },
  "fontsUsed": [
    { "fontID": "bundled.amiri.regular", "postScriptName": "Amiri-Regular", "checksum": "9a44f1c2" },
    { "fontID": "user.sha256-77aa…", "postScriptName": "MyCalligraphy", "checksum": "1b0c9d3e", "premiumLocked": false }
  ],
  "premiumContentPresent": false,
  "rescueSnapshots": ["backups/rescue-2026-07-17T09-31-04Z.scene.json"]
}
```

`premiumContentPresent` is the precomputed D-119 gating marker (recomputed on save);
`fontsUsed` powers the project browser's missing-font/locked-font badges without
opening `scene.json`.

### 13.3 Asset store

`MKAssetStore` (per open package) provides `store(data:ext:) -> MKAssetRef` (digest,
write-if-absent), `url(for:)`, `gc(referencedBy:)`. Imported SVG/PDF keep original
bytes (INV re-export fidelity); a parsed `MKAssetVectorProgram` cache sits beside in
`Library/Caches` keyed by digest (never inside the package — packages contain only
user data).

### 13.4 `scene.json` schema (schemaVersion 1)

Encoding rules: `MKNode` encodes as `{"kind": "<case>", …payload}`; ids are UUID
strings; colors are `{"space":"srgb","r":…,"g":…,"b":…,"a":…,"swatch":null}`; path
data per §3.6. The normative JSON Schema (draft 2020-12) — TEST_MATRIX validates
fixture documents against it verbatim:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "makhtoot.scene.v1",
  "title": "Makhtoot scene.json, schemaVersion 1",
  "type": "object",
  "required": ["schemaVersion", "canvas", "nodes"],
  "properties": {
    "schemaVersion": { "const": 1 },
    "canvas": {
      "type": "object",
      "required": ["size"],
      "properties": {
        "size": { "$ref": "#/$defs/size" },
        "presetID": { "type": ["string", "null"] }
      }
    },
    "nodes": { "type": "array", "items": { "$ref": "#/$defs/node" } }
  },
  "$defs": {
    "uuid": { "type": "string",
      "pattern": "^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$" },
    "point": { "type": "object", "required": ["x", "y"],
      "properties": { "x": { "type": "number" }, "y": { "type": "number" } } },
    "size": { "type": "object", "required": ["width", "height"],
      "properties": { "width": { "type": "number", "exclusiveMinimum": 0 },
                      "height": { "type": "number", "exclusiveMinimum": 0 } } },
    "transform": { "type": "object", "required": ["position", "rotation", "scale"],
      "properties": { "position": { "$ref": "#/$defs/point" },
                      "rotation": { "type": "number" },
                      "scale": { "$ref": "#/$defs/size" } } },
    "color": { "type": "object", "required": ["space", "r", "g", "b", "a"],
      "properties": { "space": { "const": "srgb" },
        "r": { "type": "number" }, "g": { "type": "number" },
        "b": { "type": "number" }, "a": { "type": "number", "minimum": 0, "maximum": 1 },
        "swatch": { "type": ["string", "null"] } } },
    "style": { "type": "object", "required": ["fill", "opacity"],
      "properties": {
        "fill": { "oneOf": [
          { "type": "object", "required": ["kind"], "properties": { "kind": { "const": "none" } } },
          { "type": "object", "required": ["kind", "color"],
            "properties": { "kind": { "const": "solid" }, "color": { "$ref": "#/$defs/color" } } } ] },
        "stroke": { "type": ["object", "null"], "required": ["color", "width", "join", "cap"],
          "properties": { "color": { "$ref": "#/$defs/color" },
            "width": { "type": "number", "minimum": 0 },
            "join": { "enum": ["miter", "round", "bevel"] },
            "cap": { "enum": ["butt", "round", "square"] } } },
        "shadow": { "type": ["object", "null"], "required": ["color", "blur", "offset"],
          "properties": { "color": { "$ref": "#/$defs/color" },
            "blur": { "type": "number", "minimum": 0 },
            "offset": { "$ref": "#/$defs/point" } } },
        "opacity": { "type": "number", "minimum": 0, "maximum": 1 },
        "blendMode": { "enum": ["normal"] } } },
    "nodeBase": { "type": "object",
      "required": ["id", "name", "transform", "style", "isLocked", "isHidden"],
      "properties": { "id": { "$ref": "#/$defs/uuid" }, "name": { "type": "string" },
        "transform": { "$ref": "#/$defs/transform" }, "style": { "$ref": "#/$defs/style" },
        "isLocked": { "type": "boolean" }, "isHidden": { "type": "boolean" } } },
    "pathData": { "type": "object", "required": ["commands", "unitsPerEm"],
      "properties": { "commands": { "type": "array", "items": { "type": "number" } },
                      "unitsPerEm": { "const": 1000 } } },
    "bezierPath": { "type": "object", "required": ["segments", "isClosed"],
      "properties": { "isClosed": { "type": "boolean" },
        "segments": { "type": "array", "items": { "type": "object",
          "required": ["start", "c1", "c2", "end"],
          "properties": { "start": { "$ref": "#/$defs/point" }, "c1": { "$ref": "#/$defs/point" },
                          "c2": { "$ref": "#/$defs/point" }, "end": { "$ref": "#/$defs/point" } } } } } },
    "fontRef": { "type": "object", "required": ["fontID", "postScriptName"],
      "properties": { "fontID": { "type": "string" }, "postScriptName": { "type": "string" } } },
    "glyphRef": { "type": "object", "required": ["glyphID", "font", "fontChecksum"],
      "properties": { "glyphID": { "type": "integer", "minimum": 0, "maximum": 65535 },
        "font": { "$ref": "#/$defs/fontRef" }, "fontChecksum": { "type": "string" },
        "variationCoordinates": { "type": ["object", "null"],
          "additionalProperties": { "type": "number" } } } },
    "provenance": { "type": "object",
      "required": ["clusterID", "codepoints", "utf16Start", "utf16Length",
                   "bidiLevel", "visualIndex", "logicalIndex"],
      "properties": { "clusterID": { "$ref": "#/$defs/uuid" },
        "codepoints": { "type": "array", "items": { "type": "integer", "minimum": 0, "maximum": 1114111 } },
        "utf16Start": { "type": "integer", "minimum": 0 },
        "utf16Length": { "type": "integer", "minimum": 0 },
        "bidiLevel": { "type": "integer", "minimum": 0, "maximum": 125 },
        "visualIndex": { "type": "integer" }, "logicalIndex": { "type": "integer" } } },
    "joining": { "type": "object", "required": ["form", "joinsPrevious", "joinsNext", "brokenByUser"],
      "properties": { "form": { "enum": ["isolated", "initial", "medial", "final"] },
        "joinsPrevious": { "type": "boolean" }, "joinsNext": { "type": "boolean" },
        "brokenByUser": { "type": "boolean" } } },
    "glyphLayout": { "type": "object", "required": ["position", "advance"],
      "properties": { "position": { "$ref": "#/$defs/point" },
        "advance": { "$ref": "#/$defs/size" },
        "pathTangentAngle": { "type": ["number", "null"] } } },
    "glyphNode": { "type": "object",
      "required": ["id", "glyph", "layout", "transform", "style", "provenance",
                   "joining", "isHidden", "isLocked"],
      "properties": { "id": { "$ref": "#/$defs/uuid" }, "glyph": { "$ref": "#/$defs/glyphRef" },
        "outline": { "oneOf": [{ "$ref": "#/$defs/pathData" }, { "type": "null" }] },
        "layout": { "$ref": "#/$defs/glyphLayout" }, "transform": { "$ref": "#/$defs/transform" },
        "style": { "$ref": "#/$defs/style" }, "provenance": { "$ref": "#/$defs/provenance" },
        "joining": { "$ref": "#/$defs/joining" },
        "isHidden": { "type": "boolean" }, "isLocked": { "type": "boolean" } } },
    "markNode": { "type": "object",
      "required": ["id", "glyph", "relativeOffset", "followsBase", "transform",
                   "style", "provenance", "markClass", "stackIndex", "isHidden", "isLocked"],
      "properties": { "id": { "$ref": "#/$defs/uuid" }, "glyph": { "$ref": "#/$defs/glyphRef" },
        "outline": { "oneOf": [{ "$ref": "#/$defs/pathData" }, { "type": "null" }] },
        "attachedTo": { "oneOf": [{ "$ref": "#/$defs/uuid" }, { "type": "null" }] },
        "relativeOffset": { "$ref": "#/$defs/size" }, "followsBase": { "type": "boolean" },
        "transform": { "$ref": "#/$defs/transform" }, "style": { "$ref": "#/$defs/style" },
        "provenance": { "$ref": "#/$defs/provenance" },
        "markClass": { "enum": ["tashkeel", "quranicAnnotation", "otherCombining"] },
        "stackIndex": { "type": "integer" },
        "isHidden": { "type": "boolean" }, "isLocked": { "type": "boolean" } } },
    "composedLigature": { "type": "object", "required": ["glyph", "layout", "decomposable"],
      "properties": { "glyph": { "$ref": "#/$defs/glyphRef" },
        "outline": { "oneOf": [{ "$ref": "#/$defs/pathData" }, { "type": "null" }] },
        "layout": { "$ref": "#/$defs/glyphLayout" }, "decomposable": { "type": "boolean" } } },
    "ligatureGroup": { "type": "object",
      "required": ["id", "state", "provenance", "transform", "style",
                   "attachedMarks", "isHidden", "isLocked"],
      "properties": { "id": { "$ref": "#/$defs/uuid" },
        "state": { "oneOf": [
          { "type": "object", "required": ["kind", "composed"],
            "properties": { "kind": { "const": "composed" },
                            "composed": { "$ref": "#/$defs/composedLigature" } } },
          { "type": "object", "required": ["kind", "components", "fidelityMode", "original"],
            "properties": { "kind": { "const": "decomposed" },
              "components": { "type": "array", "items": { "$ref": "#/$defs/glyphNode" } },
              "fidelityOffsets": { "type": "object", "additionalProperties": { "$ref": "#/$defs/size" } },
              "fidelityMode": { "enum": ["matchOriginal", "defaultForms"] },
              "original": { "$ref": "#/$defs/composedLigature" } } } ] },
        "provenance": { "$ref": "#/$defs/provenance" },
        "transform": { "$ref": "#/$defs/transform" }, "style": { "$ref": "#/$defs/style" },
        "attachedMarks": { "type": "array", "items": { "$ref": "#/$defs/uuid" } },
        "isHidden": { "type": "boolean" }, "isLocked": { "type": "boolean" } } },
    "arrangedChild": { "oneOf": [
      { "type": "object", "required": ["kind", "glyph"],
        "properties": { "kind": { "const": "glyph" }, "glyph": { "$ref": "#/$defs/glyphNode" } } },
      { "type": "object", "required": ["kind", "mark"],
        "properties": { "kind": { "const": "mark" }, "mark": { "$ref": "#/$defs/markNode" } } },
      { "type": "object", "required": ["kind", "ligature"],
        "properties": { "kind": { "const": "ligature" }, "ligature": { "$ref": "#/$defs/ligatureGroup" } } } ] },
    "sourceText": { "type": "object", "required": ["string", "styleRuns", "baseDirection"],
      "properties": { "string": { "type": "string" },
        "styleRuns": { "type": "array" },
        "baseDirection": { "enum": ["rightToLeft", "leftToRight", "rightToLeftOverride"] } } },
    "typography": { "type": "object",
      "required": ["font", "pointSize", "tracking", "baselineShift", "lineHeightMultiple", "features"],
      "properties": { "font": { "$ref": "#/$defs/fontRef" },
        "pointSize": { "type": "number", "exclusiveMinimum": 0 },
        "tracking": { "type": "number" },
        "kerningOverrides": { "type": "array" },
        "baselineShift": { "type": "number" },
        "lineHeightMultiple": { "type": "number", "exclusiveMinimum": 0 },
        "features": { "type": "object",
          "required": ["standardLigatures", "discretionaryLigatures", "contextualAlternates"],
          "properties": { "standardLigatures": { "type": "boolean" },
            "discretionaryLigatures": { "type": "boolean" },
            "contextualAlternates": { "type": "boolean" } } } } },
    "node": { "oneOf": [
      { "type": "object", "required": ["kind", "base", "children"],
        "properties": { "kind": { "const": "group" }, "base": { "$ref": "#/$defs/nodeBase" },
          "children": { "type": "array", "items": { "$ref": "#/$defs/node" } },
          "lineHeightOverride": { "type": ["number", "null"] } } },
      { "type": "object", "required": ["kind", "base", "text", "frame", "typography"],
        "properties": { "kind": { "const": "liveText" }, "base": { "$ref": "#/$defs/nodeBase" },
          "text": { "$ref": "#/$defs/sourceText" }, "frame": { "type": "object" },
          "typography": { "$ref": "#/$defs/typography" } } },
      { "type": "object", "required": ["kind", "base", "text", "typography", "path", "layout"],
        "properties": { "kind": { "const": "pathText" }, "base": { "$ref": "#/$defs/nodeBase" },
          "text": { "$ref": "#/$defs/sourceText" }, "typography": { "$ref": "#/$defs/typography" },
          "path": { "$ref": "#/$defs/bezierPath" }, "layout": { "type": "object" } } },
      { "type": "object",
        "required": ["kind", "base", "backup", "children", "clusterTable", "bidi", "derivedFrom"],
        "properties": { "kind": { "const": "arranged" }, "base": { "$ref": "#/$defs/nodeBase" },
          "backup": { "type": "object",
            "required": ["text", "typography", "contentHash"],
            "properties": { "text": { "$ref": "#/$defs/sourceText" },
              "typography": { "$ref": "#/$defs/typography" },
              "frame": { "type": ["object", "null"] },
              "pathLayout": { "type": ["object", "null"] },
              "contentHash": { "type": "string" } } },
          "children": { "type": "array", "items": { "$ref": "#/$defs/arrangedChild" } },
          "clusterTable": { "type": "array" },
          "bidi": { "type": "object" },
          "derivedFrom": { "type": "object" } } },
      { "type": "object", "required": ["kind", "base", "geometry"],
        "properties": { "kind": { "const": "shape" }, "base": { "$ref": "#/$defs/nodeBase" },
          "geometry": { "type": "object" } } },
      { "type": "object", "required": ["kind", "base", "asset", "imageKind"],
        "properties": { "kind": { "const": "image" }, "base": { "$ref": "#/$defs/nodeBase" },
          "asset": { "type": "object", "required": ["digest", "ext"] },
          "imageKind": { "enum": ["raster", "vectorPDF", "vectorSVG"] },
          "isPhotoBackgroundUse": { "type": "boolean" } } },
      { "type": "object", "required": ["kind", "base", "content"],
        "properties": { "kind": { "const": "background" }, "base": { "$ref": "#/$defs/nodeBase" },
          "content": { "type": "object" } } } ] }
  }
}
```

Migration: `MKSceneCoder.decode` reads `schemaVersion`; version 1 is current; future
versions register `MKSceneMigrator` steps (v(n) → v(n+1) pure JSON transforms) run
before typed decode, with a rescue snapshot taken first. Unknown *higher* versions
open read-only with banner "أُنشئ هذا المشروع بإصدار أحدث" (created by a newer
version).

### 13.5 Atomic writes (INV-7)

```swift
func atomicWrite(_ data: Data, to url: URL) throws {
    let tmp = url.deletingLastPathComponent()
        .appendingPathComponent(".tmp-\(UUID().uuidString)")
    try data.write(to: tmp, options: [.atomic])         // belt
    _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)  // suspenders (rename(2) semantics)
}
```

Save order: assets first (content-addressed = naturally idempotent), `scene.json`,
`manifest.json` last (manifest's `modifiedAt` is the commit marker), then journal
truncate. A crash between scene and manifest leaves a newer scene with an older
manifest — benign (manifest regenerated from scene on next open when
`scene.mtime > manifest.modifiedAt`).

### 13.6 SwiftData metadata models (INV-14; D-112)

```swift
// MKPersistence — metadata ONLY; store in Application Support, no CloudKit mirroring
// (sync is CKSyncEngine over packages, §20 — NOT SwiftData's automatic sync).
@Model final class MKProjectRecord {
    @Attribute(.unique) var projectID: UUID
    var title: String
    var folderID: UUID?
    var createdAt: Date
    var modifiedAt: Date
    var canvasWidth: Double
    var canvasHeight: Double
    var thumbnailPath: String?           // Library/Caches derived copy
    var searchText: String               // title + node names + live-text strings' *user-visible* excerpt? NO —
                                         // titles and layer names only (INV-14: no scene content); text search
                                         // within projects runs on-demand over open packages.
    var premiumContentPresent: Bool
    var packageRelativePath: String      // "Projects/<uuid>.makhtoot"
    var syncState: Int                   // raw MKSyncState (§20.4)
    var lastSyncedChangeTag: String?
}
@Model final class MKFolderRecord {
    @Attribute(.unique) var folderID: UUID
    var name: String
    var sortOrder: Int
}
@Model final class MKExportRecord {      // export history (BRIEF, all users)
    @Attribute(.unique) var exportID: UUID
    var projectID: UUID
    var date: Date
    var format: String                   // "jpeg"|"png"|"pngAlpha"|"svg"|"pdf"|"pdfPrint"
    var pixelWidth: Int
    var pixelHeight: Int
    var presetID: String?
    var wasPremium: Bool
    var outputBookmark: Data?            // security-scoped bookmark if saved outside container
}
@Model final class MKFontCatalogRecord { // catalog cache + download state (§17.2)
    @Attribute(.unique) var fontID: String
    var displayNameAr: String
    var postScriptName: String
    var category: String                 // naskh|ruqah|thuluth|diwani|kufi|maghrebi|display|quranStyle|handwriting|bilingual
    var tier: Int                        // 0 bundled, 1 premium, 2 userImported
    var downloadState: Int
    var localPath: String?
    // No separate licenseID: license lookup joins on `fontID` directly against
    // MKLicenseRecord.fontID (D-227 — canonical shape is keyed by font). User-
    // imported fonts (tier 2) simply have no MKLicenseRecord at all (§17.5).
    var isFavorite: Bool
    var tags: [String]
    var coverageClass: Int               // §17.6 coverage summary
    var lockedByExpiry: Bool
}
@Model final class MKAnalyticsCounterRecord { // §21
    @Attribute(.unique) var key: String  // "fontUsage.<fontID>.<isoWeek>"
    var count: Int
}
@Model final class MKConsentRecord {
    var kind: String                     // "analytics"
    var version: Int
    var grantedAt: Date?
    var revokedAt: Date?
}
@Model final class MKTrialMirrorRecord { // display cache only; truth = Keychain (§19.2)
    var firstLaunchAt: Date
    var lastObservedWallClock: Date
    var extensionDays: Int
}
```

Search note baked into the model comment: full-text search across project *content*
(strings inside scene.json) is performed by streaming decode of manifests+scenes on
demand with results cached in memory — not persisted to SwiftData — to honor INV-14
while still meeting the BRIEF "search" requirement (title/folder search is instant
via SwiftData; content search shows a progress row).

---

## 14. Undo/Redo & Autosave

### 14.1 Command model (D-112)

```swift
// MKPersistence
public protocol MKCommand: Sendable {
    var id: UUID { get }
    var title: String { get }                  // Arabic, for undo menu ("تحريك حرف")
    var coalescingKey: MKCoalescingKey? { get } // §14.3
    func apply(to scene: inout MKScene) throws
    func inverted(against scene: MKScene) -> any MKCommand   // computed BEFORE apply
}
```

Concrete commands (closed catalog; TEST_MATRIX property-tests each against INV-8):
`MKInsertNodeCommand`, `MKRemoveNodeCommand`, `MKReorderCommand`,
`MKTransformCommand` (node/child delta), `MKStyleCommand`, `MKTextEditCommand`
(live text replace-range), `MKTypographyCommand`, `MKPathEditCommand`,
`MKArrangeCommand`, `MKRevertCommand`, `MKFormChangeCommand`,
`MKJoinBreakCommand`/`MKJoinRestoreCommand`, `MKLigatureDecomposeCommand`/
`MKLigatureRecomposeCommand`, `MKMarkAttachCommand`/`MKMarkDetachCommand`,
`MKGroupCommand`/`MKUngroupCommand`, `MKLockHideCommand`, `MKCanvasSpecCommand`,
`MKBatchCommand` (ordered sub-commands, single undo unit).

### 14.2 Stack

```swift
@MainActor public final class MKUndoStack {
    private(set) var undo: [any MKCommand] = []   // stores INVERSES of applied commands
    private(set) var redo: [any MKCommand] = []
    /// Unbounded within memory budget (D-112): registered with MKMemoryGovernor;
    /// eviction drops OLDEST undo entries (never redo of recent work), 25% at a time.
    public func perform(_ c: any MKCommand, on session: MKDocumentSession) throws {
        let inverse = c.inverted(against: session.scene)
        try session.mutate { try c.apply(to: &$0) }        // triggers diff → layers, journal, autosave
        undo.append(inverse); redo.removeAll()
    }
}
```

Undo pops an inverse, computes *its* inverse (the redo), applies. iOS system gestures
(three-finger swipe / two-finger double tap per §10.2) and toolbar buttons route here;
`UndoManager` is intentionally not used (value-type stack is simpler under strict
concurrency and identical UX) — D-203 (corrected citation: D-203 is the value-type
scene graph + snapshot rendering decision this undo design rests on; D-202 is the
unrelated ZWJ joining-form decision).

### 14.3 Gesture coalescing

Continuous gestures emit high-frequency *previews* (layer-property updates only,
§11.2) and exactly one command at end (`MKTransformCommand` with total delta).
Keystroke bursts in live text coalesce by `coalescingKey =
.textEdit(nodeID)` within a 700 ms window into one `MKTextEditCommand` (undo granularity =
burst, like system text editors). Slider drags in the inspector coalesce by
`.style(nodeID, field)`.

### 14.4 Autosave & journal format (D-112)

Two cooperating mechanisms:

1. **Journal (`journal.mkj`)** — synchronous-ish durability at command granularity.
   Append-only, JSON Lines; each line:

```json
{"seq":142,"ts":"2026-07-17T09:31:02.114Z","baseRev":"c41d…","cmd":{"type":"transform","nodeID":"…","delta":{"position":{"x":12.5,"y":-3},"rotation":0.0,"scale":{"width":1,"height":1}}},"crc32":"9f3a11b0"}
```

   - `baseRev` = structural hash of the scene revision the batch applies to (guards
     against replaying onto the wrong base).
   - Append is a single `write(2)` on the persistence queue (<1 ms typical; the
     <100 ms incremental budget covers worst-case with fsync on stage≥2 pressure).
   - Every command's *forward* form is journaled (not inverses).
2. **Debounced full save** — ≤2 s after last mutation, plus immediately on
   scenePhase background, document close, memory ladder transitions (INV-17), and
   before export. Writes scene.json/manifest per §13.5 then truncates the journal
   (`ftruncate` to 0) — the truncation is the "flushed" marker.

### 14.5 Crash recovery

On open: if `journal.mkj` is non-empty → decode lines, verify `crc32` per line and
`baseRev` chain starting from the persisted scene's hash; replay valid prefix
(stop at first mismatch, report count); write recovered scene via normal save;
banner: "تم استرجاع التغييرات غير المحفوظة" (unsaved changes recovered). Corrupt
journal beyond the valid prefix is preserved as `journal.mkj.damaged-<ts>` for
diagnostics, never blocking open. Kill-injection tests sweep crash points
(TEST_MATRIX T-PERS-*).

---

## 15. Color Management

### 15.1 Working spaces (D-117)

- **Document/working space**: extended sRGB. Every persisted color is
  `{"space":"srgb", r,g,b,a}` (components may exceed [0,1] from P3 pickers; encoder
  clamps only at export to formats that require it).
- **Display**: SwiftUI/UIKit render sRGB values on P3 screens through the OS color
  pipeline (no app work); the eyedropper samples in sRGB.
- **Print export**: sRGB → CMYK ICC conversion at PDF-write time only (§15.3). The
  editor never shows CMYK (no soft-proofing in v1, D-117; documented limitation,
  verification via external tooling in TEST_MATRIX).

```swift
// MKColor
public struct MKColor: Hashable, Sendable, Codable {
    public var r: Double, g: Double, b: Double, a: Double  // extended sRGB
    public var swatch: String?                             // optional named swatch
    public func cgColor() -> CGColor {                     // display path
        CGColor(colorSpace: CGColorSpace(name: CGColorSpace.extendedSRGB)!,
                components: [r, g, b, a])!
    }
}
```

### 15.2 ICC profile handling

```swift
public struct MKICCProfile: Sendable {
    public let name: String                // e.g. "ISO Coated v2 (ECI)" — FD-03
    public let iccData: Data               // loaded from bundle Resources/Profiles/
    public let colorSpace: CGColorSpace    // CGColorSpace(iccData: iccData as CFData)
    public let isCMYK: Bool                // must have .model == .cmyk

    public static func loadBundled() -> MKICCProfile {
        // FD-03: the founder-selected profile file, if licensed and present,
        // else Apple Generic CMYK fallback:
        if let url = Bundle.mkColor.url(forResource: MKFeatureFlags.cmykProfileResource,
                                        withExtension: "icc"),
           let data = try? Data(contentsOf: url),
           let cs = CGColorSpace(iccData: data as CFData), cs.model == .cmyk {
            return MKICCProfile(name: cs.name.map(String.init) ?? "bundled", iccData: data,
                                colorSpace: cs, isCMYK: true)
        }
        let generic = CGColorSpace(name: CGColorSpace.genericCMYK)!  // documented lower-fidelity fallback (D-117)
        return MKICCProfile(name: "Apple Generic CMYK",
                            iccData: generic.copyICCData()! as Data,
                            colorSpace: generic, isCMYK: true)
    }
}
```

Profile redistribution licensing (ECI/ISO profiles) is a **founder decision +
verification task (FD-03)**; the architecture never assumes a specific profile ships —
`VERIFY-AT-SUBMISSION`. The market study flags CMYK fidelity as a documented pain
point on iOS [^40][^41][^42]; BRIEF Q75 overrides its defer-recommendation, so the
pipeline below is v1 scope with conservative accuracy claims in UI copy.

### 15.3 RGB→CMYK conversion flow

```swift
public struct MKCMYKConverter: Sendable {
    let profile: MKICCProfile
    /// Relative colorimetric via Core Graphics conversion (D-117):
    public func cmyk(from c: MKColor) -> [CGFloat] {   // [C,M,Y,K]
        let src = c.cgColor()
        let dst = src.converted(to: profile.colorSpace,
                                intent: .relativeColorimetric,
                                options: nil)!
        return dst.components!.map { $0 }              // 4 comps + alpha (dropped)
    }
}
```

Two conversion sites in the print-PDF path (§16.5), both intent-matched to
`.relativeColorimetric` (D-117, tightened D-226): (a) **vector colors** convert
per-color via `MKCMYKConverter` (which already sets `intent: .relativeColorimetric`
above) and are set with `ctx.setFillColor(cmykColor)` in the profile's colorspace;
(b) **raster assets** convert whole-image via `CGImage` redraw into a
`CGContext(data:…, space: profile.colorSpace, bitmapInfo: CMYK 8-bit)` — this raster
path additionally calls `ctx.setRenderingIntent(.relativeColorimetric)` **explicitly**
before the redraw (D-226), so the whole-image conversion cannot silently default to a
different Core Graphics intent than the per-color vector path uses.
`VERIFY-AT-IMPLEMENTATION` (D-226): confirm `CGContext(data:space:CMYK)` bitmap-context
construction is actually supported on-device on the target iOS versions — this is a
blocking spike for WS-08 task 12, not assumed here. Verification strategy
(TEST_MATRIX): known-swatch fixtures round-tripped against reference CMYK values
computed once by an external ICC-aware tool (littleCMS `transicc` or Argyll `xicclu` —
exact tool recorded at implementation) using the same profile and relative-colorimetric
intent, checked into the fixture corpus; plus a discriminator fixture (fully saturated
out-of-gamut `#00FF00`) asserted to diverge from the `.perceptual`-intent result by
more than tolerance; plus manual preflight of exported PDFs in external tools
(Acrobat/Ghostscript) per D-117.

### 15.4 Color pipeline summary table

| Surface | Space | Conversion point |
|---|---|---|
| Editor canvas / preview | extended sRGB → OS display pipeline | none (OS) |
| JPEG / PNG export | sRGB (profile embedded, `kCGImagePropertyProfileName` sRGB) | clamp extended → sRGB at encode |
| SVG export | sRGB hex + `rgb()` | clamp at serialize |
| Standard vector PDF | sRGB (`outputIntent` none) | none |
| Print CMYK PDF | bundled/fallback CMYK ICC | §15.3, OutputIntent embedded (§16.5) |

---

## 16. Export Pipelines (JPEG/PNG/PDF/SVG/CMYK)

### 16.1 Service shape

```swift
// MKExport
public actor MKExportService {
    public func export(_ request: MKExportRequest,
                       snapshot: MKSceneSnapshot) async throws -> MKExportResult
}

public struct MKExportRequest: Hashable, Sendable {
    public var format: MKExportFormat
    public var pixelSize: CGSize            // resolved from preset/custom dims (§16.8)
    public var dpi: Double                  // metadata + PDF media box math
    public var background: Background       // .canvas | .transparent (PNG-alpha only)
    public var colorTarget: ColorTarget     // .srgb | .cmykPrint (pdfPrint only)
    public enum MKExportFormat: String, Sendable, Codable, Hashable {
        case jpeg, pdfRaster            // free tier (≤ 2 MP effective, D-118)
        case pngOpaque, pngAlpha, svg, pdfVector, pdfPrintCMYK   // premium
    }
}

public struct MKExportResult: Sendable {
    public var fileURL: URL
    public var report: MKExportReport       // INV-15 carrier: every fallback, per element
    public var pixelSize: CGSize
    public var durationMS: Double
}
```

### 16.2 Gating (D-119, INV-9)

`MKExportGate` runs before any rendering:

1. `entitlement = snapshot.entitlement` (frozen at snapshot creation — one read).
2. Free tier: format ∈ {jpeg, pdfRaster}; `pixelSize` clamped so
   `width × height ≤ 2_000_000` (effective 2 MP cap — aspect preserved, downscale
   factor √(2MP/requested)).
3. Free tier + `manifest.premiumContentPresent` → throw
   `MKExportError.premiumContentBlocked(items:)` with the replace-or-subscribe item
   list (locked fonts, photo background, premium assets) for the UI flow.
4. Premium/trial/grace/billingRetry/lifetime: full matrix, no dimension caps beyond
   hardware guard (§16.4) per Q76.

### 16.3 Single render path (D-118, INV-2, INV-6)

Every format funnels through `MKSceneRenderer.render(snapshot:region:into:scale:)`
with a format-specific `CGContext`. There is no per-format drawing code — only
per-format *context construction and encoding*.

### 16.4 Tiled raster strips (JPEG/PNG, huge canvases)

```swift
struct MKRasterTiler: Sendable {
    /// Strip height chosen so bytesPerRow × stripHeight ≤ 64 MB
    /// (bytesPerRow = width × 4, 8-bit RGBA/premultiplied; CMYK path uses ×4 too —
    /// and, per §15.3/D-226, any CMYK raster context this tiler feeds must call
    /// ctx.setRenderingIntent(.relativeColorimetric) explicitly before redraw, same
    /// as the print-PDF raster-asset site).
    func exportRaster(_ req: MKExportRequest, snapshot: MKSceneSnapshot,
                      to url: URL) throws -> MKExportReport {
        let scale = req.pixelSize.width / snapshot.scene.canvas.size.width
        let stripH = max(256, Int(64 * 1024 * 1024 / (Int(req.pixelSize.width) * 4)))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, req.format.utType.identifier as CFString, 1, nil)!
        // ImageIO cannot append strips to one image; therefore:
        //  - sizes where a single context fits the 64 MB budget → single context.
        //  - larger sizes → render strips into a mapped file (vImage-style manual
        //    assembly): allocate a file-backed buffer (mmap, F_NOCACHE) of
        //    width×height×4 bytes on disk, wrap each strip window in its own
        //    CGBitmapContext(data: basePtr + offset, …), render with ctx.translateBy
        //    (0, -stripOrigin), then create one CGImage over the full mapping via
        //    CGDataProvider(directInfo:) and encode once.  Output limited by disk,
        //    not RAM (D-116).
        …
    }
}
```

- Strip render sets `ctx.interpolationQuality = .high`, flips to top-left origin, and
  clips to the strip rect so the renderer's region parameter culls nodes (renderer
  intersects node world bounds with `region` — O(visible)).
- PNG-alpha: `CGImageAlphaInfo.premultipliedLast`, no background fill when
  `.transparent`; opaque variants composite the background node first (D-118).
- JPEG quality 0.9; both embed sRGB profile + `kCGImagePropertyDPIWidth/Height =
  req.dpi`.
- Free `pdfRaster` = the JPEG strip pipeline rendered at ≤2 MP then wrapped in a
  single-page PDF (image XObject) — free PDFs carry no vectors (cap semantics
  identical to JPEG; simplest honest implementation of "rasterized PDF").
- Near-limit warning (Q76): before rendering, if predicted transient memory
  (strip + encoder + caches) > 45% of `os_proc_available_memory()`, show
  "قد يستهلك هذا التصدير ذاكرة كبيرة — تم الحفظ تلقائيًا" and autosave; proceed
  unless critically low (then require confirmation).
- **Export-under-pressure policy (D-223 — the written version of the "documented
  policy" T-MEM-6 references)**: strip sizing is **static** at the 64 MB budget
  above; there is no mid-export strip-height shrinking (D-210's "the memory monitor
  can shrink strip height mid-export" claim is **struck** — static sizing plus the
  pause below is the actual mechanism). If the memory ladder (§12.4) reaches
  **stage-3/critical** while an export is in flight: the strip currently rendering is
  allowed to **complete** (never torn mid-strip), then the export **pauses** before
  starting the next strip until pressure drops back below stage-2, with a cancel
  option offered to the user during the pause. This composes with §12.4's
  critical-stage journal-only flush — pausing an export is cheap (no new
  allocations), unlike shrinking strip geometry mid-flight would have been.

### 16.5 Vector PDF (premium) with per-license text-vs-outline switch

```swift
struct MKPDFWriter: Sendable {
    func export(_ req: MKExportRequest, snapshot: MKSceneSnapshot, to url: URL) throws -> MKExportReport {
        var mediaBox = CGRect(origin: .zero,
                              size: CGSize(width: req.pixelSize.width / req.dpi * 72.0,
                                           height: req.pixelSize.height / req.dpi * 72.0))
        var aux: [CFString: Any] = [
            kCGPDFContextTitle: snapshot.manifestTitle,
            kCGPDFContextCreator: "Makhtoot (مخطوط)",
        ]
        if req.colorTarget == .cmykPrint {
            let profile = MKICCProfile.loadBundled()
            // `VERIFY-AT-IMPLEMENTATION` (D-226): the exact `kCGPDFContextOutputIntent`
            // aux-dictionary key name and value shape (single dictionary vs. an array
            // of dictionaries, as PDF/X OutputIntents formally allow multiple) is a
            // blocking spike for WS-08 task 12 — the shape below is illustrative, not
            // yet confirmed against the current CG PDF context API.
            aux[kCGPDFContextOutputIntent] = [                     // OutputIntent (D-117)
                kCGPDFXOutputIntentSubtype: "GTS_PDFX",
                kCGPDFXOutputConditionIdentifier: profile.name,
                kCGPDFXInfo: profile.name,
                kCGPDFXDestinationOutputProfile:
                    CGDataProvider(data: profile.iccData as CFData)!,
            ] as [CFString: Any]
        }
        let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, aux as CFDictionary)!
        ctx.beginPDFPage(nil); defer { ctx.endPDFPage(); ctx.closePDF() }
        …renderer.render(snapshot, region: canvasRect, into: ctx, scale: ptScale)…
    }
}
```

Content rules (D-118):

- **Vector everything**: shapes, glyph outlines, path data draw as PDF vector ops —
  resolution-independent (market study confirms vector-first PDF is the simplest
  correct approach [^41], study §7 table).
- **Live Text nodes** — the per-license switch:

```swift
enum MKTextEmbedPolicy {
    /// OFL-verified fonts (license record `embeddingRights.contains(.pdf)`, D-227):
    /// draw as text with subset embedding — CTFontDrawGlyphs into a CGContext-PDF
    /// embeds a subset automatically; text remains selectable/searchable.
    case embedSubset
    /// Any font whose license record lacks `.pdf` in `embeddingRights`, all
    /// user-imported fonts (rights unknowable), and locked premium fonts:
    /// draw glyph outlines (CTFontCreatePathForGlyph) — report entry
    /// reason "fontEmbeddingRestricted" (INV-15).
    case outline(reason: MKOutlineReason)
}
```

  Resolution: `MKLicenseStore.embeddingRights(fontID) -> MKEmbeddingRights` (D-227,
  amends D-118 — replaces the earlier `embedRights` boolean-pair accessor) →
  `.contains(.pdf)` selects the policy per node. Market study: OFL explicitly permits
  embedding; commercial licenses must be checked per-font [^26][^28] (study §7 "Font
  embedding in exported PDF" row).
- **Arranged compositions / transformed glyphs / decomposed ligatures**: always
  outlines (their geometry is no longer a text run) — reason `arrangedGeometry`
  (documented fallback per BRIEF Q73 list, never silent).
- **Raster assets**: embedded at ≥300 DPI effective for print target (floor per
  D-118); JPEG passthrough where source ≥ target density, else flagged in report
  (`rasterBelowPrintDPI` warning, not an error).
- **CMYK target**: all fills/strokes convert per §15.3 before `setFillColor`; raster
  assets redraw through the CMYK context; OutputIntent as above. PDF/X *full*
  compliance is NOT claimed in v1 UI copy (subset: CMYK + OutputIntent + no
  transparency groups where avoidable) — remaining gaps documented in the export
  report and APP_STORE_CHECKLIST wording. `VERIFY-AT-SUBMISSION`: final marketing
  copy for print claims.

### 16.6 Custom SVG serializer (premium)

No system SVG writer exists (market study §7 [^ study table]); `MKSVGSerializer` is a
hand-rolled, dependency-free XML emitter. Element mapping (normative):

| Scene element | SVG output | Provenance attributes |
|---|---|---|
| Canvas | `<svg width height viewBox xmlns … xmlns:mk="https://makhtoot.example/ns/mk">` (namespace URI FD-01 applied) | `data-mk-schema="1"` |
| Background solid | `<rect>` fill | `data-mk-kind="background"` |
| Group | `<g transform="…">` | `data-mk-kind="group" data-mk-id` |
| Shape | `<path d="…">` (all geometry normalized to path) | `data-mk-kind="shape"` |
| Image (raster) | `<image href="data:image/…;base64,…">` embedded | `data-mk-kind="image"` |
| Image (vector SVG asset) | inlined `<g>` of original asset markup (sanitized: script/foreignObject/event attrs stripped) | `data-mk-asset-digest` |
| Image (vector PDF asset) | rasterized `<image>` at 2× target (no PDF-in-SVG) — report reason `pdfAssetRasterized` | idem |
| **Live Text (untransformed beyond node transform)** | `<text>` with `direction="rtl"`, `unicode-bidi="plaintext"`, x/y per line origin, `font-family`, `font-size`, `letter-spacing`; per-style-run `<tspan>`; `@font-face` with a **computed subset** (matching the PDF path's subset-embedding approach, §16.5) raw base64 `font/ttf`, embedded **only when** `MKLicenseStore.embeddingRights(fontID).contains(.svg)` (D-227), else fallback ↓ | `data-mk-kind="liveText" data-mk-source-text="<string>" data-mk-font="<psName>"` |
| Live Text (no embed rights) | `<g>` of `<path>` per glyph — reason `fontEmbeddingRestricted` | + `data-mk-outlined="fontEmbeddingRestricted"` |
| Path Text (live) | `<text><textPath href="#mkpath-N" …>` with the Bézier emitted as `<path id="mkpath-N" fill="none">`; glyph-exact fidelity is NOT guaranteed by renderers → also emits `data-mk-layout="pathText"`; when fidelity matters more than editability the user toggle "دقة المسار" switches to outline group — reason `pathTextFidelity` | `data-mk-source-text`, `data-mk-path-data` |
| **Arranged composition** | `<g data-mk-kind="arranged" data-mk-source-text="<backup string>">` containing, per child, a **per-glyph-group** `<g data-mk-schema="1" data-mk-kind="glyph\|mark\|ligature" …>` wrapping that child's own `<path d transform fill …>` (D-227(2) — canonical WS-08 schema; corrects this document's earlier comma-separated codepoints and bare-`<path>` attribute placement) | provenance attributes (`data-mk-codepoints`, `data-mk-cluster`, `data-mk-form="medial"`, `data-mk-font`, `data-mk-glyph-id`) live on the **per-glyph-group `<g>`**, not on the `<path>`; `data-mk-codepoints` is **space-separated hex** Unicode scalars, e.g. `"0644 0627"` — never comma-separated; the group carries `data-mk-schema="1"` (versioned) |
| Mark node | its own per-glyph-group `<g data-mk-schema="1" data-mk-kind="mark" data-mk-attached-to data-mk-mark-class data-mk-codepoints="…">` (same scheme as Arranged composition, above) wrapping one `<path>` | attributes on the group, per D-227(2) |
| Ligature (composed) | one per-glyph-group `<g data-mk-schema="1" data-mk-kind="ligature" data-mk-codepoints="0644 0627">` wrapping one `<path>` | idem |
| Ligature (decomposed) | `<g data-mk-kind="ligature-decomposed">` of per-component per-glyph-groups (each per the scheme above) + `data-mk-fidelity-mode` on the outer `<g>` | component provenance as glyphs |
| **Emoji / color glyph** (COLR/CBDT/sbix) | `<image href="data:image/png;base64,…">` rasterized bitmap, in **ALL** contexts, including as a child of an arranged/ligature group — a deliberate carve-out to the "arranged is always outlined" rule (D-227(4), reconciles R-21.10) | `data-mk-kind="emojiGlyph"` + report reason `colorGlyphRasterized` (INV-15) |
| **Live Text using a locked (expired premium/imported) font** | export uses `lastShapedCache` (§17.7 sidecar) — **never re-shapes** at export time; if no cache exists for that node, export is **blocked** at `MKExportGate` with the replace-or-subscribe flow before serialization begins (D-227(6)) | none emitted for that node until resolved |
| Stroke/shadow | stroke → attrs; shadow → `<filter><feDropShadow>` referenced per element | — |

Rules:

- Every outline fallback sets `data-mk-outlined="<reason>"` AND appends a
  `MKExportReport` entry — the two must agree (INV-15 test hook).
- Editability intent (Q73): `<text>` wherever feasible; outlines only for the
  documented cases: arranged/transformed glyphs, custom ligature decomposition,
  font-embedding restrictions, user fidelity toggle — exactly the BRIEF list.
- Numeric formatting: 3 decimals max, no scientific notation; output is UTF-8 with
  Arabic strings raw (not entity-escaped) except XML-required escapes.
- Round-trip: the serializer's provenance attributes are sufficient to re-import a
  Makhtoot-authored SVG *as assets* (not as live scene reconstruction — out of v1
  scope; documented in §24.2 seam).
- **Subset embedding + Reserved Font Names (D-227(3))**: the `@font-face` payload is a
  computed subset, not the full font file (matching §16.5's PDF subset behavior).
  Whether subsetting an OFL font with Reserved Font Names still satisfies the RFN
  clause is **not** asserted here as a legal conclusion — recorded as
  `VERIFY-AT-SUBMISSION`, same posture as the other licensing gaps in §17.

**v1-OFL note (D-227(5))**: v1's premium-catalog fonts are OFL, so embedding rights in
already-exported files do not lapse when the exporting device's entitlement later
lapses — an exported SVG/PDF keeps whatever it embedded. §17.4 carries the forward-note
that a future commercial-foundry provider (FD-07) will require re-deciding this
export-time license boundary; it is not inherited automatically from the OFL case.

### 16.7 Export report

```swift
public struct MKExportReport: Sendable, Codable {
    public struct Entry: Sendable, Codable {
        public var nodeID: MKNodeID
        public var event: String        // "outlined", "rasterBelowPrintDPI", "pdfAssetRasterized", …
        public var reason: String       // MKOutlineReason raw value etc.
    }
    public var entries: [Entry]
    public var colorTarget: String
    public var profileName: String?
}
```

Shown post-export in a collapsible "تفاصيل التصدير" sheet when non-empty; persisted
into `MKExportRecord` (§13.6) alongside history.

### 16.8 Presets

`MKExportPreset` table (BRIEF list): social square 1080×1080, story/status 1080×1920,
static-reel 1080×1920, messaging-status 1080×1920, wallpaper (device-derived),
print A-series at 300 DPI (A5/A4/A3), custom exact dimensions (premium). Free-tier
presets resolve to their ≤2 MP equivalents (e.g. 1080×1350 → 1264×1580 is >2 MP →
scaled to 1263×1579 ≈ 1.99 MP). All presets are data (`presets.json` in MKExport
resources), not code.

### 16.9 Sharp-Arabic verification

TEST_MATRIX carries the visual gate from BRIEF ("verify sharp Arabic output visually
at print resolution across all formats"): fixture projects render at 300 DPI through
each pipeline; zoomed crops of glyph joints/marks are manually reviewed per the
Arabic-script verification checklist (Q59 gate).

---

## 17. Fonts Subsystem

### 17.1 Identity model

```swift
// MKFonts
public struct MKFontRef: Hashable, Sendable, Codable {
    public var fontID: String            // "bundled.amiri.regular" | "premium.<catalogID>" | "user.<digest>"
    public var postScriptName: String
}
public enum MKFontTier: Int, Sendable, Codable { case bundled = 0, premium = 1, userImported = 2 }
```

`fontID` is the stable key across catalog, scene documents, analytics counters, and
license records. PostScript name is advisory (display, SVG/PDF text output); resolution
always goes through the registry, never `CTFontCreateWithName` on a bare name (avoids
system-font hijack of similarly named fonts).

### 17.2 Registry & runtime

```swift
public actor MKFontRegistry {
    /// Registers all bundled fonts at launch and premium/user fonts on demand:
    /// CTFontManagerRegisterFontURLs(url as CFURL, .process, &error)   // D-122, amended by D-219
    /// (per-process scope: no system pollution, no Fonts capability needed for
    /// in-app-only use — market study §12 [^61])
    public func registerBundled() throws
    public func register(_ ref: MKFontRef) throws
    public func unregister(_ ref: MKFontRef) throws          // expiry locking path
    public var fontsDidChange: AsyncStream<Void> { get }     // cache invalidation (§4.7)
}

public final class MKFontRuntime: Sendable {   // per-isolation-domain materializer (§1.3)
    public func ctFont(_ ref: MKFontRef, size: Double,
                       features: MKFontFeatureSet) throws -> CTFont {
        // CTFontDescriptor from file URL attributes + kCTFontFeatureSettingsAttribute
        // (§7.6) + variation dict when ref carries axis coordinates,
        // then CTFontCreateWithFontDescriptor(desc, size, nil).
    }
    public func ref(for ctFont: CTFont) -> MKFontRef          // reverse lookup by URL attr
}
```

### 17.3 Bundled starter set (D-120)

Candidates (Amiri, Amiri Quran, Noto Naskh/Kufi/Sans Arabic, Scheherazade New, Lateef,
Harmattan, Reem Kufi, Aref Ruqaa, Mada, Tajawal, Almarai, El Messiri, Markazi Text,
Rakkas, Katibeh, Jomhuria, Mirza, Qahiri) ship **only after** the WS-09 verification
protocol captures, per font: license file (OFL.txt), source URL, commit/version,
reserved-font-name note, verification date, verifier. Verified so far by the market
study: Amiri OFL 1.1 [^28][^30], Noto Naskh Arabic OFL 1.1 [^25][^26], broader Noto
Arabic family OFL 1.1 [^27]; Alif Type repos are candidates pending per-repo checks
[^37]. KFGQPC/Uthmani fonts are prohibited (non-commercial EULA [^31][^32]).

**Canonical shape (D-227, amends D-118/D-122): matches WS-09 T2 verbatim** — this is
the one true `MKLicenseRecord` definition; §16.5/§16.6 consume it only through the
`embeddingRights` accessors below, never through ad hoc booleans:

```swift
public struct MKEmbeddingRights: OptionSet, Sendable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let pdf = MKEmbeddingRights(rawValue: 1 << 0)   // drives §16.5 embedSubset policy
    public static let svg = MKEmbeddingRights(rawValue: 1 << 1)   // drives §16.6 @font-face embedding
    public static let commercialUse = MKEmbeddingRights(rawValue: 1 << 2)
}

public struct MKLicenseRecord: Sendable, Codable {
    public var fontID: String                 // MKFontRef.fontID — one record per font (D-227)
    public var familyName: String
    public var licenseType: String            // e.g. "OFL-1.1"
    public var copyrightNotice: String         // copyright line(s), license *requirement* to surface
    public var reservedFontNames: [String]     // OFL RFN list, if any
    public var sourceRepoURL: String
    public var licenseFileBundlePath: String   // bundle-relative path to full license text
    public var verificationDate: String        // ISO date of WS-09 verification
    public var verifiedBy: String
    public var redistributionConfirmed: Bool
    public var embeddingRights: MKEmbeddingRights   // bitset — replaces separate embedPDF/embedSVG/commercialUse
}
```

`MKLicenseStore` bundles these records (one per font, keyed by `fontID`) as
`licenses.json` + verbatim license texts, surfaced at Settings → Support → Licensing
(Q66) — attribution + OFL text display is a license *requirement* [^26][^28], so the
screen is architecture, not chrome.

### 17.4 Premium catalog & downloads (D-121)

- Static JSON manifest + font files on founder-controlled HTTPS storage (FD-04).
  Manifest: `catalog.json` — array of `{fontID, displayNameAr, category, tags,
  fileURL, sha256, bytes, previewText, version}` — signed by nothing in v1 (HTTPS +
  sha256 pinning of each file against the manifest; manifest tampering risk accepted
  and documented, RSK-09). License lookup joins on `fontID` directly against
  `MKLicenseRecord.fontID` (D-227's canonical shape is keyed by font, not by a
  separate `licenseID`), so no extra manifest field is needed for it.
- `MKFontDownloadService`: `URLSession` background-capable downloads, resume data,
  sha256 verification before install, then content-addressed copy →
  register → `MKFontCatalogRecord.downloadState = installed`.
- Downloads gated: `await entitlements.currentState().isPremium` checked at request
  time (D-121 "download after entitlement confirmation"; direct download of
  content-not-code is App-Store-compliant per market study §8/§12 framing —
  `VERIFY-AT-SUBMISSION` for guideline text current at submission). Fallback
  documented (D-121): bundle premium fonts behind the entitlement if hosting isn't
  ready (build-flag `premiumFontsBundled`).
- **Manifest freshness (DF-7 cross-reference)**: the catalog manifest itself is kept
  current by `MKCatalogManifestFetchService` (WS-09; fetch-on-foreground, 24 h
  staleness TTL, disk cache) — see PRD for the zero-manifest-ever offline empty state.
- **v1-OFL rights don't lapse (D-227(5))**: exported files (PDF/SVG) that embedded a
  v1 catalog font keep those embedding rights after the fact, because every v1
  catalog font is OFL-verified; embedding rights are a property of the font at
  export time, not of the user's entitlement afterward. **Forward-note (FD-07)**: a
  future commercial-foundry provider (§24.6) is a different license regime and will
  require re-deciding the export-time license boundary this note describes — the
  OFL conclusion above does not generalize automatically.

### 17.5 User import (premium-only, Q64; D-122)

`MKFontImportService` flow: `UIDocumentPickerViewController` (UTTypes: `.font`,
`public.truetype-ttf-font`, `public.opentype-font`, ttc) → security-scoped read →
`MKFontValidator`:

```swift
public struct MKFontValidator: Sendable {
    public enum Verdict: Sendable {
        case ok(faces: [MKValidatedFace])                 // ttc → multiple faces
        case reject(MKFontRejectReason)
    }
    /// sfnt sanity: magic (0x00010000 | 'OTTO' | 'ttcf'), table directory bounds,
    /// required tables (head, cmap, glyf|CFF, hmtx, name), fvar detection (variable),
    /// cmap has Arabic block coverage probe (§17.6). Rejects: woff/woff2 (magic
    /// 'wOFF'/'wOF2'), bitmap-only (EBDT without outlines), corrupt directories.
    public func validate(_ data: Data) -> Verdict
}
public enum MKFontRejectReason: Sendable {
    case webFontFormat        // "صيغة خط ويب غير مدعومة — استخدم ttf أو otf"
    case bitmapOnly           // "هذا الخط نقطي فقط ولا يمكن استخدامه"
    case corrupt              // "ملف الخط تالف أو غير مكتمل"
    case unsupported          // generic, with docs link
}
```

Accepted → content-addressed copy into
`Application Support/Fonts/user/sha256-….ttf` → register → catalog entry
`tier: .userImported` with **no `MKLicenseRecord`** for that `fontID` at all (D-227 —
absence, not a sentinel value, since redistribution rights are unknowable);
`MKLicenseStore.embeddingRights(fontID)` returns the empty set for such fonts, which
`§16.5/§16.6`'s policies read as "no embed rights" → export outline.

### 17.6 Coverage, previews, search

- Coverage probe at install: cmap sampled against required sets — Arabic block
  U+0600–06FF core letters, harakat U+064B–0652, Qur'anic annotations U+06D6–06ED,
  Arabic-Indic digits, lam-alif ligature presence (shape "لا" and check
  `.ligature` cluster) → `coverageClass` bitmask stored on the catalog record and
  shown as chips ("تشكيل كامل", "علامات قرآنية", "أرقام هندية").
- Preview rendering uses the engine itself (shaping capture at 28 pt of
  "بسم الله الرحمن الرحيم" or user-set preview string) — previews are pixel-honest.
- Favorites/tags/search: SwiftData-backed (§13.6), category filter = BRIEF's ten
  categories.

### 17.7 Expiry locking (D-119, INV-13)

`MKFontLockController` observes entitlement stream; on transition to `free`:
premium + userImported records → `lockedByExpiry = true`; registry keeps fonts
*registered* (rendering cached geometry is fine and arranged outlines don't need the
font at all) but `MKFontRuntime.ctFont` throws `MKError.fontLocked` for **new
shaping** requests; UI shows lock badges; re-subscribe or "استبدال الخط" (replace
font — reshapes affected Live Text with a chosen free font via normal commands)
clears the block. Live Text nodes in locked fonts render from the last shaped capture
persisted in a lightweight `lastShapedCache` sidecar inside the package
(`cache/shaped-<nodeID>.json`, refreshed on every successful save while entitled) —
the concrete mechanism for "render with last cached shaping + lock badge".

---

## 18. StoreKit & Entitlements

### 18.1 Product topology

| Product id (FD-01 applied) | Type | Price anchor |
|---|---|---|
| `net.binjamshid.makhtoot.premium.monthly` | auto-renewable, group "Makhtoot Premium" | $2.99/mo |
| `net.binjamshid.makhtoot.premium.annual` | auto-renewable, same group | $29.99/yr |
| `net.binjamshid.makhtoot.premium.lifetime` | non-consumable | $89.99 |

Price anchors are the nearest Apple price-point tiers to the founder's $3/$30/$90
intent (D-216). Apple storefront price localization is automatic from the base tier (market study §8
[^45]-adjacent; no engineering beyond tier selection). Lifetime alongside
subscriptions is an approved pattern [^45][^46][^47]. Family Sharing ON/OFF is
irreversible per product → FD-06, decided in App Store Connect before first
submission [^46][^49].

### 18.2 Entitlement resolver (D-113, INV-9)

```swift
// MKStore
public actor MKEntitlementResolver: MKEntitlementProviding {
    public private(set) var current: MKEntitlementState = .free
    private let trial: MKTrialController

    public func start() {
        Task { for await update in Transaction.updates { await ingest(update) } }
        Task { await recompute() }        // launch-time pass
    }

    private func recompute() async {
        var lifetime = false
        var subState: Product.SubscriptionInfo.RenewalState? = nil
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }   // on-device JWS check (D-113)
            if tx.productID.hasSuffix(".premium.lifetime"), tx.revocationDate == nil { lifetime = true }
        }
        if let statuses = try? await Product.SubscriptionInfo
                .status(for: "Makhtoot Premium") {                    // subscription group status
            // Highest-privilege status wins within the group:
            subState = statuses.compactMap { try? $0.state }.max(by: privilegeOrder)
        }
        let new: MKEntitlementState =
              lifetime                          ? .lifetime
            : subState == .subscribed           ? .subscribed
            : subState == .inGracePeriod        ? .inGracePeriod
            : subState == .inBillingRetryPeriod ? .inBillingRetry
            : await trial.isActive()            ? .trial
            :                                     .free
        publish(new)                             // precedence exactly D-113
    }
}
```

- **Verification position (D-113, decided)**: on-device StoreKit 2 verification via
  `VerificationResult` JWS checking in v1; `.unverified` transactions are ignored
  (fail-closed to the next-lower state) and logged. App Store Server API
  cross-validation is an extension seam (§24.5) since no backend exists — the market
  study's server-side recommendation [^43] is acknowledged and deferred by D-113.
- Offline caching: last resolved state + `expirationDate`/`gracePeriodExpirationDate`
  persisted (Keychain, same item family as trial §19.2); on launch without
  connectivity, cached premium honored until cached expiry + 3-day tolerance, then
  degrade to `free` with banner (risk RSK-10 documents the tradeoff).
- Grace period / billing retry: premium retained + banner "هناك مشكلة في تجديد
  الاشتراك" deep-linking to Apple subscription management [^43]. Exact current grace
  durations are a known research gap — copy avoids concrete day counts,
  `VERIFY-AT-SUBMISSION` (BRIEF known-gaps).
- **`pendingApproval` is never an entitlement state (D-228(5))**: the `.pending`
  Ask-to-Buy case surfaced in §18.3 ("بانتظار الموافقة") is paywall-UI state only —
  it never appears in `MKEntitlementState` above, and `recompute()`'s output is
  unchanged by it; entitlement advances only when a verified transaction actually
  arrives via `Transaction.updates`.

### 18.3 Purchase, restore, messaging

`MKStoreService` wraps `Product.products(for:)`, `product.purchase()`, result
handling (`.success(.verified)` → `transaction.finish()` after recompute;
`.userCancelled`; `.pending` → "بانتظار الموافقة" for Ask-to-Buy), and
`AppStore.sync()` behind an explicit "استعادة المشتريات" button (mandatory UI, D-113;
Guideline 3.1.2(c) restore requirement [^45][^47]). Expiration/cancellation states
render exact Arabic messaging from a single `MKEntitlementMessaging` table —
APP_STORE_CHECKLIST carries the 3.1.2 paywall copy requirements (price+term adjacent
to CTA, visible dismiss, content-before-paywall) [^50][^51][^52].

### 18.4 Paywall state machine

`MKPaywallModel` states: `hidden` → `presented(context:)` (contexts: premium-feature
tap, trial-expiry prompt, settings) → `purchasing(productID)` → `confirmed` |
`failed(error)` | `dismissed`. The paywall never auto-presents before the user has
created or opened at least one project (compliance posture per market study §8 [^50];
APP_STORE_CHECKLIST verifies).

### 18.5 StoreKit testing

`Makhtoot.storekit` configuration file in-repo (all three products, sandbox price
points, subscription group) powering unit/UI tests via `SKTestSession`-style
`StoreKitTest` (`Transaction` injection, renewal simulation, refund/revocation,
billing-retry entry) — the Q59 sandbox gate. Sandbox Apple-ID manual pass scripted in
APP_STORE_CHECKLIST.

---

## 19. Trial & Referral

### 19.1 Trial semantics (D-123)

App-side 7-day trial from **first launch**, applying premium capabilities to everyone
(monthly + annual framing per Q37); post-trial the free tier retains full editing
with free fonts/solid backgrounds and 2 MP JPEG/PDF export (Q41). This is *not* an
App Store introductory offer: no intro offer is configured in v1 (D-123) to avoid
double-trial divergence — the app-side trial is a feature-unlock window controlled by
Makhtoot, while Apple intro offers are per-subscription-group, consume Apple-side
eligibility (`isEligibleForIntroOffer` [^43][^44]), and start at purchase, not at
launch. The difference is user-visible (our trial requires no purchase intent) and is
documented for the paywall copy in APP_STORE_CHECKLIST (no "free trial" wording that
implies an Apple intro offer; copy: "٧ أيام مزايا كاملة عند أول استخدام").

### 19.2 Trial persistence (Keychain + iCloud KVS)

```swift
// MKStore
struct MKTrialRecord: Codable, Sendable {
    var firstLaunchAt: Date            // trial anchor (earliest wins)
    var lastObservedWallClock: Date    // rollback guard high-water mark
    var lastObservedBoottime: TimeInterval  // ProcessInfo.systemUptime at write (D-224; wired below)
    var extensionDays: Int             // referral only; 0 while flag OFF
    var recordVersion: Int             // 1
    var deviceFirstSeen: String        // random per-record UUID — NOT a device id; dedup only
}

actor MKTrialController {
    // Storage 1 — Keychain (truth): kSecClassGenericPassword,
    //   service "net.binjamshid.makhtoot.trial" (placeholder-derived),
    //   kSecAttrAccessibleAfterFirstUnlock (D-123: survives reinstall because
    //   keychain items persist across app deletion on-device),
    //   NOT kSecAttrSynchronizable (cross-device handled by KVS explicitly).
    // Storage 2 — NSUbiquitousKeyValueStore key "trial.record" (mirror; propagates
    //   the anchor across the user's devices).
    // Merge rule on every launch/foreground and KVS change notification:
    //   firstLaunchAt = min(keychain, kvs, now)        // earliest wins (D-123)
    //   lastObservedWallClock = max(all observed)
    //   extensionDays = max(...) capped at 28 (4 × 7, D-124 abuse cap)
    //   → write merged record back to BOTH stores.

    func isActive() async -> Bool {
        let r = merged()
        let expiry = r.firstLaunchAt.addingTimeInterval(Double(7 + r.extensionDays) * 86_400)
        return clockNow(r) < expiry
    }

    /// Wall-clock high-water mark + uptime cross-check (D-123, INV-10; hardened by
    /// D-224). Renamed from an earlier "monotonic guard" description — a raw
    /// monotonic clock alone only protects a single boot session; what actually
    /// survives across launches is the wall-clock high-water mark below, now
    /// corroborated by the reserved `lastObservedBoottime` field (previously stored
    /// but unused).
    private func clockNow(_ r: MKTrialRecord) -> Date {
        let wall = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        let uptimeDelta = uptime - r.lastObservedBoottime      // >= 0 iff same boot session
        let wallDelta = wall.timeIntervalSince(r.lastObservedWallClock)
        if uptimeDelta >= 0, uptimeDelta > wallDelta + rollbackTolerance {
            // D-224: the device was demonstrably powered on for longer than the wall
            // clock admits — the wall clock was rolled back mid-session. Uptime-
            // elapsed is authoritative for trial aging: advance the high-water mark
            // by the (unforgeable, same-session) uptime delta instead of the
            // manipulated wall delta.
            return r.lastObservedWallClock.addingTimeInterval(uptimeDelta)
        }
        if wall < r.lastObservedWallClock {
            // Rollback with no same-session uptime evidence (reboot + rollback, or
            // first-ever divergence): freeze at high-water mark — trial neither
            // extends nor advances; banner "يبدو أن ساعة الجهاز تغيّرت".
            return r.lastObservedWallClock
        }
        return wall
        // Caller persists lastObservedWallClock = max(lastObservedWallClock, result)
        // and lastObservedBoottime = uptime after each observation (merge step).
    }
}
```

Properties this yields (TEST_MATRIX T-TRIAL-*):

- Reinstall on same device → Keychain survives → same anchor (BRIEF: reinstall cannot
  trivially reset).
- New device, same iCloud → KVS delivers the anchor → earliest wins.
- Set clock back a year → `clockNow` freezes at high-water mark → remaining days
  never increase (INV-10).
- Set clock forward and back → forward observation raises the high-water mark; trial
  may *expire* early from the user's own manipulation (accepted; never in the
  generous direction).
- KVS unavailable (no iCloud): Keychain alone suffices; per-device anchors may
  diverge across devices — accepted, documented weakness (no server, D-123).

**Honesty limits (D-211; DF-3).** This design defends against the *trivial* resets
(reinstall, device migration, ordinary clock rollback) but does not, and cannot
without a server, defend against a determined user. Recorded residual holes: (1) a
full device wipe without restoring a backup clears the Keychain; (2) signing out of
iCloud (or disabling KVS) plus a local wipe, or a device never signed into iCloud,
leaves no KVS anchor; (3) a different Apple ID on a wiped device is indistinguishable
from a fresh user by any observable signal; (4) jailbroken Keychain editing. Combined,
a determined user can reset the trial by wiping a device or cycling Apple IDs —
accepted because the protected asset (a 7-day trial of a $3/mo tool) does not justify
the disproportionate fixes (server-side identity, unconditional DeviceCheck) that
would be required to close it fully.

**Extension seam (D-211)**: DeviceCheck/App Attest bits are the designated
proportionate hardening if trial abuse ever becomes measurable — two bits per device
survive a wipe without requiring an owned server. Not implemented in v1; this is the
seam future work attaches to, not a promise of when.

**Residuals added by D-224's uptime cross-check** (on top of D-211's list above):
(a) *sustained pre-launch rollback* — the uptime cross-check only holds within a
single boot session; a user who reboots the device before rolling the wall clock back
defeats it (recorded honestly as a residual, not claimed as closed by D-224). (b)
*subscribe-then-refund trial re-entry* — trial is not consumed by purchase (D-228);
re-entry after a refund or lapse within the original 7-day window is intended
behavior, not abuse, and is bounded to ≤7 days by construction.

### 19.3 Trial state machine

`trialState = active(daysLeft: Int) | expired` derived, never stored. Transitions
evaluated on: launch, foreground, KVS change, midnight local-time crossing (timer).
Expiry transition fires exactly one paywall prompt (context `.trialExpired`) and a
non-blocking banner thereafter (compliance posture §18.4).

### 19.4 Referral module design (D-124, flag OFF)

Location: `MKStore/Sources/Referral/` — one folder, compiled always, inert without
the flag (INV-16). Public surface:

```swift
public enum MKReferral {
    public static var isEnabled: Bool { MKFeatureFlags.referralProgram }   // false in v1
}
public struct MKReferralCode: Sendable, Codable {   // e.g. "MKT-7Q4F-9Z2A"
    public let code: String            // 8 chars base32 (no 0/O/1/I), derived from
                                       // random seed at first generation; stored Keychain
}
actor MKReferralController {
    /// Referrer side: generate + share code (ShareLink). Local generation only.
    func myCode() -> MKReferralCode
    /// Invitee side: manual code entry. v1 design is server-independent → attribution
    /// is honor-based code exchange (documented weakness, D-124): entering a code
    /// records a pending qualifying event LOCALLY on the invitee device; the REFERRER
    /// reward requires the referrer to redeem a confirmation code the invitee's app
    /// displays only after the qualifying action (paid conversion) — a two-code
    /// handshake that stays offline. Rewards: +7 days extensionDays on the referrer's
    /// MKTrialRecord, max 4 extensions total (cap enforced in merge, §19.2).
    func enterInviteCode(_ code: String) throws
    func redeemConfirmation(_ code: String) throws  // referrer device; +7d, capped
}
```

Anti-abuse: extension cap (4 × 7 d = 28 d, D-124); confirmation codes derived
HMAC-style from (invitee code seed + qualifying-event nonce) so they can't be
mass-generated without an actual invitee device; self-referral blocked (own code
rejected); all writes route through `MKTrialRecord.extensionDays` so INV-10 caps hold.

### 19.5 Review-risk containment

The mechanic rewards the **referrer only**, on a **qualifying paid action** — the
pattern the documented rejection precedent treats as acceptable, versus rewarding the
invitee for signup/download, which is documented rejection territory [^53][^54]
(market study §8; the restriction is inferred from Guideline 3.1.1/3.2.2 enforcement
precedent, not a quoted clause — treat as inferred risk). Activation requires FD-05:
reconfirmation against the *current* App Review Guidelines text at that time —
`VERIFY-AT-SUBMISSION`, and the flag stays OFF for v1 regardless. Review notes
template + risk memo live in APP_STORE_CHECKLIST §Referral.

### 19.6 Flag isolation & removal procedure

- Flag: `MKFeatureFlags.referralProgram` — compile-time `false`; no remote fetch, no
  runtime toggle in release builds (local server-independent flag per BRIEF).
- Isolation rules (CI-enforced): only the app-target settings screen and paywall may
  `import` the referral symbols, and only behind `if MKReferral.isEnabled`; referral
  code never touches `MKTrialController` internals except through the two capped
  entry points above.
- **Removal procedure** (documented per BRIEF "easy removal"): delete
  `MKStore/Sources/Referral/`, delete the flag constant, delete the two settings/
  paywall call sites (compiler finds them), delete `extensionDays` consumers? — NO:
  `extensionDays` field stays in `MKTrialRecord` (schema stability; value simply
  remains 0). CI job `referral-removal-check` performs this deletion on a branch and
  asserts the build stays green (INV-16 test).

---

## 20. CloudKit Sync

### 20.1 Scope & posture (D-112, D-113 adjacent)

Premium-only project sync via **CKSyncEngine** in the user's own iCloud private
database (container `iCloud.net.binjamshid.makhtoot`, FD-01 applied). No
separate account, no SIWA (Q77; avoids Guideline 4.8 entirely per market study §8/§9
[^56][^57]). Sync is engaged only when: entitlement `isPremium` AND user toggled
"مزامنة iCloud" ON AND `CKContainer.accountStatus() == .available` — enforced as an
explicit gate at engine start, not just a scheduling suggestion (§20.4, D-229(4)).

`VERIFY-AT-IMPLEMENTATION` (DF-12): `CKSyncEngine` has its own minimum-OS
availability floor; confirm it is compatible with whatever iOS deployment target D-100
ultimately locks (BRIEF's "iOS 18" framing, §1.1) before this becomes a blocking
integration surprise.

### 20.2 Record mapping

Zone: custom `CKRecordZone(zoneName: "MakhtootProjects")` (single zone → atomic
per-zone changes, zone-wide fetch). One record per project (D-112):

| CKRecord field | Type | Content |
|---|---|---|
| recordType | — | `"Project"` |
| recordName | — | project UUID string |
| `title` | String | project title (queryable) |
| `modifiedAtClient` | Date | client modification clock for LWW (§20.3) |
| `schemaVersion` | Int64 | scene schema version |
| `manifest` | CKAsset | `manifest.json` (encrypted-at-rest by CK private DB) |
| `scene` | CKAsset | `scene.json` compressed (zstd via `NSData.compressed(using: .zlib)` — Apple algo enum; ~6–10× on JSON) |
| `thumbnail` | CKAsset | `thumbnail.png` |
| `assetDigests` | [String] | content digests referenced by the scene |
| `folderID` | String? | metadata folder assignment |

Per-asset records: recordType `"ProjectAsset"`, recordName `"<digest>"`, fields
`payload: CKAsset`, `refCount` unnecessary (content-addressed; orphan GC compares
digests across all Project records during periodic maintenance). Assets are
deduplicated across projects for free by digest-keyed record names. All user content
rides the **private** database (INV-12); FOUNDATION's "encrypted-asset payloads" is
satisfied by CloudKit private-DB at-rest encryption plus the app not adding fields
that expose content in queryable form (only `title` is queryable — user-visible
metadata by definition).

### 20.3 Conflict policy (D-112)

Last-writer-wins per project by `modifiedAtClient`, with conflict-copy fallback:

1. `CKSyncEngine` reports a server record change conflicting with unpushed local
   changes (save failure `.serverRecordChanged`).
2. If local scene hash == server scene hash → merge trivially (metadata only, take
   max dates).
3. Else compare `modifiedAtClient`: strictly older side loses **but is not
   destroyed**: the losing scene is written into a *new* project package titled
   `"<الاسم> (نسخة متعارضة)"` (FOUNDATION exact string) with a fresh UUID, synced as
   a new record; the winning record proceeds. The user sees both in the browser with
   a conflict badge — no data loss, no merge editor in v1.

### 20.4 Engine integration

```swift
// MKSync
actor MKSyncService: CKSyncEngineDelegate {
    var engine: CKSyncEngine!   // CKSyncEngine(configuration: .init(database: container.privateCloudDatabase,
                                //   stateSerialization: restoredState, delegate: self))
    let entitlements: any MKEntitlementProviding   // injected seam (D-230), same protocol MKExportGate uses

    /// Explicit entitlement gate at engine start (D-229(4)) — mirrors MKExportGate's
    /// pattern (§16.2): one entitlement read, frozen for the decision, BEFORE the
    /// engine is ever constructed or scheduled. Sync is never started speculatively
    /// and then torn down on a free result.
    func start() async {
        guard await entitlements.currentState().isPremium else {
            status = .notSynced          // free tier: engine never starts (INV-9)
            return
        }
        guard userToggledICloudSyncOn, CKContainer.default().accountStatus() == .some(.available) else {
            status = .notSynced
            return
        }
        engine = CKSyncEngine(configuration: .init(database: CKContainer.default().privateCloudDatabase,
                                                    stateSerialization: restoredState, delegate: self))
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let e): persist(e.stateSerialization)      // SwiftData blob
        case .accountChange(let e): await handleAccountChange(e)     // signOut → detach, keep local
        case .fetchedRecordZoneChanges(let e): await ingest(e.modifications, e.deletions)
        case .sentRecordZoneChanges(let e): await reconcile(e.savedRecords, e.failedRecordSaves)
        default: break
        }
    }
    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                   syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        // Build from dirty MKProjectRecord.syncState queue; package files staged
        // to immutable temp copies (CKAsset requires stable file) — snapshot rule again.
    }
}
enum MKSyncState: Int { case notSynced, pendingUpload, uploading, synced, conflict, error, detachedByExpiry }
```

- **Quota errors** (`.quotaExceeded`): pause queue, banner "مساحة iCloud ممتلئة"
  with Settings deep link; retry on account change/space notification (risk RSK-06).
- **Expiry**: on entitlement drop, `detachedByExpiry` — engine stops scheduling, local
  data untouched, records remain in iCloud (user's own storage); re-subscribe
  resumes with normal conflict handling.
- Rate/backoff, `.networkFailure`, `.zoneNotFound` (recreate zone) handled per
  CKSyncEngine retry-after metadata; all surfaced in `MKSyncStatusModel` for the
  sync status row in settings.

### 20.5 Sync × persistence interplay

Uploads always read the last *saved* package (post-autosave hook enqueues), never
in-memory state; downloads apply as a whole-package replace behind the document-open
lock: if the project is open, the incoming version is staged and the user is prompted
("تتوفر نسخة أحدث من iCloud") — applying performs the §20.3 policy with the open
document treated as local side.

---

## 21. Analytics

### 21.1 Consent & posture (D-125)

Default OFF. Settings switch "مشاركة إحصاءات استخدام الخطوط (مجهولة الهوية)" with
explainer sheet; consent stored as `MKConsentRecord(kind:"analytics", version:N)` —
version bumps re-prompt (never silently widen scope). No third-party SDK, no
tracking, no ATT surface (nothing crosses apps/sites; market study §9 [^57]-adjacent
posture). **Kill switch (corrected, D-207)**: `MKAnalyticsKillSwitch` is **not**
local-only — it is the local consent toggle **plus** a remote, serverless stop: an
`analyticsEnabled` flag record read from the CloudKit **public** database at upload
time (same container as §21.3's upload). Absence of the record = proceed (default
enabled); an explicit `false` halts uploads with no app update required. Offline
behavior: the last-known value is cached and used; if no value was ever fetched, the
default is enabled (consistent with "absence = proceed"). This is a deliberate
correction of this document's earlier "no remote config" claim — the remote stop
exists specifically so the founder can halt uploads without shipping a build.

### 21.2 On-device aggregation

Counter increments at exactly two call sites: font applied to a node (once per
node-font pair per session) and font used in a completed export. Key =
`"fontUsage.<fontID>.<isoWeek>"` (ISO-8601 week, e.g. `2026-W29`) →
`MKAnalyticsCounterRecord.count += 1` (§13.6). Nothing else is counted in v1.

### 21.3 Upload design (CloudKit public DB, weekly buckets)

```swift
// MKAnalytics
struct MKUsageBatch: Codable, Sendable {
    var schema: Int = 1
    var week: String                    // "2026-W29" — coarsest time granularity (D-125)
    var counts: [String: String]        // fontID → BUCKETED count: "1-9"|"10-49"|"50-199"|"200+"
}
actor MKAnalyticsUploader {
    /// Weekly task (BGAppRefresh opportunistic; else on-launch when a completed
    /// ISO week has unuploaded counters AND consent active):
    func uploadIfDue() async {
        // MKAnalyticsKillSwitch.enabled (D-207) checks local consent AND fetches/
        // caches the public-DB `analyticsEnabled` record; offline uses the cached
        // last-known value, defaulting to enabled if none was ever fetched.
        guard consent.isGranted, await MKAnalyticsKillSwitch.enabled else { return }
        let batch = aggregator.closeWeek()                 // buckets raw counts, INV-11
        let record = CKRecord(recordType: "FontUsageBatch",
                              recordID: .init(recordName: UUID().uuidString))  // random ephemeral (D-125)
        record["schema"] = 1 as CKRecordValue
        record["week"] = batch.week as CKRecordValue
        record["counts"] = try JSONEncoder().encode(batch.counts) as CKRecordValue // Data field
        // PUBLIC database, no CKReference to any user record, no userRecordID lookup ever:
        try? await CKContainer.default().publicCloudDatabase.save(record)
        aggregator.markUploaded(batch.week)                // delete raw counters after upload
        // Failure → counters retained, retried next window; after 8 weeks unuploaded
        // counters are DELETED (data minimization beats completeness).
    }
}
```

Anonymity analysis (goes to PRD §18 + APP_STORE_CHECKLIST privacy labels): the public
DB write is performed by the user's iCloud identity at the transport layer (CloudKit
requirement) but the record carries no user reference and creator identity is not
queryable by the app; bucketing + week-coarse timing prevents fingerprinting via
count uniqueness. Founder-side aggregation reads the public DB via CloudKit console/
dashboard. Never uploaded (INV-11): text, projects, identifiers, font files, device
info, fine timestamps.

---

## 22. Design System

### 22.1 Token architecture (D-126)

```swift
// MKDesignSystem
public protocol MKTheme: Sendable {
    var colors: MKSemanticColors { get }        // paper, ink, accent, surface, outline,
                                                // success/warn/error, selection, canvasBackdrop
    var type: MKTypeRamp { get }                // UI ramp on SF Arabic (system), sizes/weights/leading:
                                                // largeTitle…caption2, numeric variants (Arabic-Indic aware)
    var spacing: MKSpacingScale { get }         // 4-pt grid: 4,8,12,16,24,32,48
    var radii: MKRadiusScale { get }            // 4,8,12,20, capsule
    var elevation: MKElevationScale { get }     // shadow tokens
    var motion: MKMotionScale { get }           // durations 120/200/320 ms + curves
}
public struct MKInkPaperTheme: MKTheme { … }     // "حبر ورق" baseline (FD-02, editable)
```

Injected via SwiftUI `Environment(\.mkTheme)`; **no view reads a literal color/size**
(lint rule in CI greps `Color(red:`/`.padding(1`-style literals inside app+DS
targets). Re-theming = swapping one value (BRIEF: themeable layer with swappable
tokens; visual identity comes from a separate design process).

### 22.2 RTL-first component kit

`MKPanel`, `MKInspectorField` (numeric, Arabic-Indic/Latin input, stepper),
`MKSlider`, `MKChipRow`, `MKSegment`, `MKToolbarButton`, `MKBanner`, `MKSheetHeader` —
all built leading/trailing (never left/right), verified under `ar` layout direction
only (D-100: `ar` is the only localization; development region `ar`). Canvas-adjacent
chrome (rulers, handles) mirrors positions via `MKRTL` helpers while canvas geometry
itself stays unmirrored (§10.1). UI font is system SF Arabic (D-126) — *used via
system APIs, never bundled* (SF Arabic is not redistributable as a file, market study
§5 [^21][^34]); display/preview fonts come from the catalog.

### 22.3 Adaptive layout

iPhone: bottom tool ribbon + sheet inspector. iPad: leading layers sidebar +
trailing inspector column, pointer/keyboard support (⌘Z/⇧⌘Z routed to the undo
stack, arrow-key nudge). Same SwiftUI screens, `horizontalSizeClass`-switched
containers — one codebase, genuinely adaptive (BRIEF platform bullet).

---

## 23. Security & Privacy

- **Data-at-rest**: documents under the app container (`NSFileProtectionComplete
  UntilFirstUserAuthentication` default; no explicit downgrade anywhere). Keychain
  items: trial record + entitlement cache (`kSecAttrAccessibleAfterFirstUnlock` —
  needed pre-unlock on relaunch after background termination).
- **Network surface** (INV-3): exactly three clients — font catalog/download
  (`URLSession`, HTTPS only, ATS default-strict, sha256 verification §17.4), CloudKit
  private DB (sync), CloudKit public DB (analytics). No other endpoint exists; no
  webviews except `SFSafariViewController` for license source links in Settings.
- **Input hardening**: font import validator (§17.5) treats user files as hostile
  (bounds-checked table parsing, 32 MB size cap, no parsing on main thread,
  crash-isolated by running validation in a child task with timeout); SVG import
  sanitizes (no scripts/external refs, entity expansion capped); PDF assets rendered
  via CGPDFDocument only (no JS surface).
- **Privacy report inputs** (APP_STORE_CHECKLIST owns the submission artifact): no
  data collection when analytics OFF; when ON — "Product Interaction, not linked to
  identity, no tracking" is the truthful nutrition-label posture given §21.3;
  `VERIFY-AT-SUBMISSION` against current label taxonomy.
- **No accounts**: nothing to phish; premium state derives from StoreKit/iCloud
  (Q77). Referral codes (if ever enabled) contain no personal data (random seeds).
- **Logging**: `MKLog` categories never log user text or file paths at `.default`
  level; `.debug` builds only for content-bearing logs (audited by grep rule
  `mk-log-privacy`).

---

## 24. Extension Seams (v2)

Seams only — named protocols and insertion points, zero v1 behavior. Each seam is a
compile-checked surface (the protocol exists; v1 registers no/trivial implementations)
so v2 work starts from a stable joint instead of a refactor.

### 24.1 Animation / video (v2)

- **Seam**: `MKTimelineProviding` in `MKModel`:
  `protocol MKTimelineProviding: Sendable { func value(of property: MKAnimatableProperty, at time: TimeInterval, node: MKNodeID) -> Double? }`
  plus `MKRenderIntent` already carrying an optional `time: TimeInterval?` (nil in
  v1). `MKSceneRenderer.render` consults the provider before reading node
  transform/style; v1 registers `MKStaticTimeline` (always nil → stored values).
- **Insertion points**: `MKSceneSnapshot.timeline` field (defaulted), export request
  enum gains `.video` case *later* (not present now). Scene schema reserves no fields
  (animation data will be a sibling document — decided now to keep scene.json v1
  frozen).

### 24.2 Templates

- **Seam**: `MKTemplateProviding` in `MKPersistence`:
  `protocol MKTemplateProviding { func instantiate(templateID: String) throws -> MKScene }`.
  The project browser's "new project" flow calls
  `templateProvider.instantiate("blank")`; v1 ships exactly one provider
  (`MKBlankTemplateProvider`) returning an empty scene at the chosen preset size.
  Templates later = new provider + browser grid; no model change (a template is just
  a scene).

### 24.3 Multi-page

- **Seam**: `manifest.json` already carries `counts` and a single implicit page;
  `MKProjectPackage` exposes `var pages: [MKPageHandle]` — v1 hardcodes one handle
  bound to `scene.json`. v2 adds `pages/page-<n>.json` beside it; `MKPageHandle`
  isolates every consumer (editor, export, sync) from the file layout today.
  `MKCanvasSpec` deliberately excludes page identity.

### 24.4 Metal renderer

- **Seam**: `MKRendererBackend` in `MKRender`:
  `protocol MKRendererBackend: Sendable { func draw(_ display: MKDisplayList, into target: MKRenderTarget) throws }`
  where `MKSceneRenderer` internally lowers the scene to `MKDisplayList` (flat draw
  ops: path/fill/image/glyph-run) and v1's only backend is `MKCoreGraphicsBackend`.
  Metal adoption (only if D-115 gates fail, per D-114) implements the same display
  list against `MTLRenderCommandEncoder` — exports stay on Core Graphics.

### 24.5 App Store Server API

- **Seam**: `MKEntitlementVerifying` in `MKStore`:
  `protocol MKEntitlementVerifying: Sendable { func crossValidate(_ jws: VerificationResult<Transaction>) async -> MKVerificationVerdict }`.
  v1 registers `MKOnDeviceVerifier` (JWS result passthrough, D-113). A future
  backend implements `MKServerAPIVerifier` calling App Store Server API; the
  resolver already funnels every transaction through the protocol, so the swap is
  registration-only. Offline-cache semantics (§18.2) are defined on the resolver, not
  the verifier — unchanged by the swap.

### 24.6 Commercial foundry catalog hooks (FD-07)

- **Seam**: `MKFontSourceProviding` in `MKFonts`:
  `protocol MKFontSourceProviding: Sendable { var sourceID: String { get }; func catalog() async throws -> [MKCatalogEntry]; func download(_ entry: MKCatalogEntry) async throws -> URL; func licenseRecord(_ entry: MKCatalogEntry) -> MKLicenseRecord }`.
  v1 providers: `MKBundledSource`, `MKStaticHTTPSSource` (D-121). A foundry
  integration is a third provider; `MKLicenseRecord.embeddingRights` (D-227) already
  models per-license rights as a bitset, and `MKFontCatalogRecord.tier` already
  reserves the id space. **No commercial foundry license is verified today** (BRIEF
  known gaps; v1 catalog = OFL-verified only, D-120/FD-07). §17.4's forward-note
  applies: v1's OFL rights don't need re-deciding, but a commercial provider will
  require re-deciding the export-time license boundary this seam assumes.

### 24.7 Minor reserved joints

- Paragraph-level auto base-direction (§8.4 limitation): `MKSourceText.baseDirection`
  is per-object; adding `.auto` is a schema-compatible enum extension (decoder
  tolerates unknown → fallback documented in migration notes).
- SVG re-import as live scene (§16.6): provenance attributes are versioned
  (`data-mk-schema`) precisely so a future importer can attempt reconstruction.
- Soft-proofing (D-117 limitation): `MKColorPipeline` exposes
  `previewTransform: MKColorTransform?` — nil in v1.

---

## 25. Risks & Mitigations

Owner-phase codes reference PLAN.md phases (P0–P15) and workstreams (WS-xx).

| ID | Risk | Likelihood | Impact | Mitigation | Owner/Phase |
|---|---|---|---|---|---|
| RSK-01 | **Arabic shaping edge cases**: fonts with incomplete `init/medi/fina` coverage, exotic mark stacking (mkmk chains), tatweel interactions, ZWJ contexts yielding unexpected clusters in §7.2 | High | High (core differentiator credibility) | Fixture corpus per bundled font (WS-09 provides coverage classes §17.6); form-resolver verification step §7.2.1 fails soft (disabled chip, never wrong glyph); cluster model never assumes 1:1 (§4.5); manual Arabic-script verification checklist is a release gate (Q59) | WS-03/WS-04 · P3–P6 |
| RSK-02 | **CTRun cluster ambiguities**: fused base+mark single glyphs (no separable Mark Node), one codepoint → multiple glyphs, ligatures spanning style-run boundaries splitting runs | Medium | Medium-High | `.baseWithMarks` clusters with fused glyphs become a single Glyph Node with `codepoints` including the mark (selectable as one — honest, documented in PRD edge cases); `decomposable=false` guards non-reshapable fusions (§3.4); style-run splits tested (T-TXT cluster suite); never crash on unexpected topology — fall back to per-cluster nodes | WS-03 · P3, hardened P6 |
| RSK-03 | **Variable-font path extraction**: `CTFontCreatePathForGlyph` on variable fonts must use the correctly-instantiated descriptor; axis defaults drifting across OS versions could change outlines vs captured geometry | Medium | Medium | `MKGlyphRef.variationCoordinates` pins axis values at derivation; outlines persisted in scene (INV-13) so rendering never re-derives; `fontChecksum` detects file drift and flags instead of silently re-extracting | WS-03/WS-09 · P3/P9 |
| RSK-04 | **CMYK fidelity**: iOS lacks soft-proofing; conversion accuracy vs print expectation; ICC profile redistribution license unresolved (FD-03) | High | Medium (reputation with print users) | Conservative UI claims (§16.5); Apple Generic CMYK fallback path always available (D-117); swatch round-trip tests + external preflight in TEST_MATRIX; FD-03 blocks only print-PDF QA, not release of other formats; market study documents the pain points [^40][^41][^42] | WS-08 · P10, QA P14 |
| RSK-05 | **Huge-canvas exports**: mmap-backed strip assembly (§16.4) hitting disk-space limits, file-mapping limits, or ImageIO encoder memory spikes on 12K+ outputs | Medium | Medium | Pre-flight disk/memory prediction with Q76 warning + autosave; strip sizing is static (64 MB budget, D-223 — no mid-export shrinking); at stage-3 pressure the in-flight strip completes then the export pauses before the next strip until pressure drops below stage-2, with a cancel option (§16.4, D-223); export cancellable + resumable-safe (temp file, atomic finalize); budget gate 4K<10 s with 8K/12K measured informally | WS-08 · P10/P14 |
| RSK-06 | **CKSyncEngine quotas/limits**: user iCloud quota exhaustion, CKAsset size limits, throttling on large scene.json churn | Medium | Medium | Compressed scene payloads (§20.2); quota → paused queue + Arabic banner + local-first guarantee (nothing lost); per-project record granularity keeps deltas small; backoff per engine metadata | WS-11 · P12 |
| RSK-07 | **StoreKit offline caching**: cached premium honored past actual revocation (refund/cancel while offline), or false lockout when offline past tolerance | Medium | Medium (revenue vs UX) | 3-day tolerance window after cached expiry (§18.2), fail-closed after; revocation ingested immediately on reconnect via `Transaction.updates`; lifetime cached indefinitely (non-consumable, revocation-checked on reconnect); tolerance documented in DECISIONS_LOG | WS-10 · P11 |
| RSK-08 | **App-side trial perceived as dark pattern** (3.1.2 scrutiny of "trial" language without intro offer) | Low-Medium | High (rejection) | Copy never says "اشتراك تجريبي مجاني" in purchase context; paywall discloses price/term per 3.1.2 [^50][^51]; trial is app-feature unlock, not purchase term; APP_STORE_CHECKLIST carries reviewer-notes wording; `VERIFY-AT-SUBMISSION` | WS-10/WS-15 · P11/P15 |
| RSK-09 | **Font catalog integrity**: static HTTPS manifest tampering (no signing in v1) | Low | Medium | HTTPS+ATS, per-file sha256 in manifest, install-time revalidation; bundle-fallback election (FD-04/D-121) removes the surface entirely if chosen; signing seam noted for v1.1 | WS-09 · P9 |
| RSK-10 | **Journal/schema corruption**: partial journal lines, migration bugs eating arranged geometry | Low | High | CRC per line + baseRev chain (§14.4); valid-prefix replay, damaged tail preserved (§14.5); rescue snapshots before migration (§13.1); kill-injection test sweep (INV-7) | WS-02 · P2, regression every phase |
| RSK-11 | **Performance on A12-class floor**: 5,000-node scenes with compositions breaching 16.6 ms | Medium | Medium | Layer-property hot path (§11.2), transient-layer glyph drag, degradation ladder as safety valve (never feature cap), Metal seam §24.4 as the documented escape hatch; profiling gate before ship (Q59) | WS-07 · P14 |
| RSK-12 | **Referral activation risk** (if FD-05 ever flips) | Low (flag OFF) | High if activated carelessly | Referrer-only qualifying-action design (§19.4) per precedent [^53][^54]; mandatory guideline recheck (FD-05); removal procedure rehearsed in CI (INV-16) | WS-10 · post-v1 |
| RSK-13 | **UITextView overlay metric mismatch** vs engine render (D-104 seam) | Medium | Low-Medium (visible "jump" on commit) | Golden metric tests per bundled font (§4.8); overlay styled from the same `MKTypography` resolver; known-divergence list (e.g., TextKit hyphenation off, `usesFontLeading` matched) maintained in code comments + tests | WS-06 · P4/P5 |
| RSK-14 | **N-ary ligature fidelity heuristic**: WS-04's single affine-fit clamp `[0.85, 1.15]` (§7.5, D-221) may reject legitimate wide/narrow ligature geometry in some fonts, forcing an unwanted default-forms fallback instead of the fidelity placement the user expected | Medium | Low-Medium (visual regression on decompose, never data loss or a crash) | Pre-flight clamp check refuses fidelity mode outside the range with the existing notice UX (mirrors the R-21.9 pattern, §7.5) rather than applying an out-of-range scale silently; per-font round-trip fixtures (T-AR-36..38, D-222) surface clamp-triggering fonts before ship; the fallback path (`.defaultForms`) is always geometrically safe | WS-04 · P6 |

---

## Traceability

Mapping BRIEF.md requirement bullets → sections/invariants of this document.
(PRD.md carries the user-behavior mapping; this table covers architecture coverage.)

| BRIEF.md requirement (§/bullet) | Architecture coverage |
|---|---|
| Identity: Makhtoot/مخطوط naming, placeholder bundle id, themeable design-system layer | §0 header, §22 (tokens, FD-02); placeholder ids §13.1, §18.1, §20.1 |
| Platform: universal iPhone+iPad, iOS 18, adaptive, one codebase | §1.1, §22.3 (D-100) |
| v1 static only; animation/video seams | §1.6, §24.1 |
| Arabic-only RTL UI | §22.2, INV-18 |
| Offline-complete; network only fonts/sync/analytics | §1.1, INV-3, §23 |
| No accessibility scope v1 | §1.6 |
| No templates; seam only; shapes/ornaments in v1 | §24.2, §2.2 (MKAssets) |
| Typing like native text field (shaping, ligatures, tashkeel, bidi, numerals) | §4 (D-103/D-104), §8 |
| Arrange Mode derivation with full shaped state + source backup + revert | §5 (D-106), INV-1, INV-4 |
| No auto-reflow; every glyph/mark/ligature independently transformable (position/rotation/scale/opacity/fill/outline/shadow) | §3.4, §5.3, §6.4, INV-1 |
| Both levels (shaped-glyph + Unicode-letter), lossless switching | §3.4 `MKProvenance`, §5.2, §13.4 clusterTable |
| Joining preserved by default; explicit break; 4-form visual selector | §7.2 (D-107 exact ZWJ contexts), §7.3 |
| Tashkeel + full Qur'anic marks: attach/follow/detach/move/transform | §6 (ranges U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED) |
| Ligatures: combined objects + decomposition preserving look, opt-out (Q71) | §7.4–7.6 (D-108 fidelity offsets) |
| Per-object kerning/tracking/baseline/line-height/scale/rotation/opacity/outline/shadow/fill | §3.2–3.3 (`MKTypography`, `MKStyle`), §3.3 group line height |
| Curved/freeform Bézier path text, live until arranged (Q72) | §9 (D-110 arc-length + §9.4 logical-reading-order pen advance, DF-6a) |
| No preloaded Qur'anic content | §1.6 (explicit exclusion incl. market-study §6 override) |
| Canvas: drag/resize/rotate/multi-select/guides/snap/layers/group/lock/hide/undo/zoom/pan | §10, §14 |
| Layers panel incl. arranged glyphs/marks | §10.6 |
| Numeric inspector | §10.4 (D-111 decomposed transforms) |
| Autosave, duplicate, folders, search, export history | §13.6, §14.4; search note §13.6 (INV-14-compatible) |
| Premium iCloud sync, not SIWA | §20 (Q77) |
| Imports: raster/SVG/PDF; custom fonts premium-only | §13.3, §17.5 (Q64) |
| Four font mechanisms; formats ttf/otf/ttc/variable; reject unsafe | §17 (D-120/121/122), §24.6 |
| Catalog previews/styles/tags/favorites/search; 10 categories | §17.6, §13.6 |
| Licensing at Settings→Support→Licensing (Q66) | §17.3 |
| Expiry: viewable/editable, fonts lock, export falls back (Q27) | §17.7, §16.2, INV-13 |
| Verified font acquisition; never invent licenses; KFGQPC prohibited | §17.3 (WS-09 protocol; [^25]–[^32]) |
| Export free JPEG+rasterized PDF 2 MP; premium PNG/alpha/SVG/print PDF | §16.2, §16.4–16.6 (D-118/119) |
| Hi-res 4K+/300 DPI/no artificial caps, memory warnings + autosave (Q76) | §16.4, §12.5 |
| SVG editable-text preservation, documented outline fallbacks (Q73) | §16.6, INV-15 |
| True CMYK ICC PDF (Q75 override) | §15, §16.5 (FD-03) |
| Presets + premium custom dims | §16.8 |
| Free gating: resolution/formats/premium content/photo backgrounds (Q34) | §16.2, §3.3 (`isPhotoBackgroundUse`), D-119 |
| Sharp Arabic print verification | §16.9 |
| Performance: no caps, pressure monitoring, degradation, budgets | §12 (D-115/116), INV-17 |
| Monetization: $2.99/$29.99/$89.99, localization, StoreKit 2 full surface | §18 ([^43]–[^52]) |
| 7-day trial at first launch, reinstall-resistant, intro-offer differences documented | §19.1–19.3 (D-123), INV-10 |
| Post-trial free tier retained | §16.2, §19.1 (Q41) |
| Referral: architect, flag OFF, referrer-only, anti-abuse, removal docs | §19.4–19.6 (D-124), INV-16 ([^53][^54]) |
| On-device vs Server API position | §18.2 (decided: on-device, D-113), seam §24.5 |
| No mandatory account; CloudKit on user's iCloud | §20.1 |
| Analytics: anonymous, aggregated, opt-in, font-usage only | §21 (D-125), INV-11 |
| No ads | no ad surface exists in any module (§2) |
| Engineering: SwiftUI-first + UIKit/Core Text/CG; no ground-up shaper | §1.3, §4, INV-5 |
| Tools: Xcode/xcodebuild/gh only | §2.3 (D-101) |
| Persistence decisive recommendation | §13 (D-112 elaborated) |
| Gates (Q59) | §12.1, §16.9, §18.5 (TEST_MATRIX owns) |
| Distribution automation, codebase-memory ADRs | out of this doc's scope → PLAN.md/WS-15; ADR ids D-2xx noted §1 header |
| Known research gaps (grace periods, OFL per-font, ICC licensing, referral guidelines, foundry licenses) | §18.2, §17.3, §15.2, §19.5, §24.6 — each marked `VERIFY-AT-SUBMISSION`/FD |

**New architecture-level decisions introduced (for DECISIONS_LOG.md):**
D-230 `MKStoreAPI` protocol seam placement (§2.1) · D-231 composition-root assembly
(§2.1). (§14.2's value-type undo stack rests on the existing D-203 document-model
decision, not a new local id — corrected from an earlier "D-202" mislabel.)

*End of ARCHITECTURE.md.*










