# WS-07 P14 Run 3 — evidence reconstruction, independent re-verification &
backlog closure

Date: 2026-07-22. This file is referenced by name, in advance of its own
existence, from code comments already committed-uncommitted across the
tree (`git grep -n "WS-07-p14-run3"` at the time of writing hits
`PaywallView.swift`, `MakhtootKit/CONTRACTS.md`, `MakhtootKit/Package.swift`,
`ArrangeDeriver.swift`, `ExportCoordinator.swift`, `MKLog.swift`,
`AutosaveController.swift`, `PathTextDrawer.swift`, `ShapeDrawer.swift`,
`StylePainting.swift`, `RenderSignposts.swift`, and
`MKSyncEngineController.swift`) — this is that file, written to close the
gap.

## Context: a background P14 session died before writing its own evidence

A prior background-agent session ran a substantial P14 ("hardening pass")
implementation and was killed (host session death, not a code failure)
before it wrote `docs/impl-log/WS-07-p14-run3.md` or ran any of its own
gates. What it left behind, as uncommitted working-tree changes, was
internally coherent and traceable to real P14 backlog items
(`docs/HANDOFF-ORCHESTRATOR.md`'s P14 scope list): a new
`MKMemoryGovernor` actor (`MakhtootKit/Sources/MKFoundation/
MKMemoryGovernor.swift`) plus its test coverage
(`MKFoundationTests/MKMemoryGovernorTests.swift`,
`MKRenderTests/MemoryGovernorIntegrationTests.swift`); a stroke-width
scale-compensation fix across the render/drawer stack
(`StylePainting.swift`, `ShapeDrawer.swift`, `PathTextDrawer.swift`) with
its own regression suite (`MKRenderTests/StrokeWidthCompensationTests.swift`);
`arrangeDerive`/export signposts hoisted onto `MKFoundation.MKSignpost`
(`MKLog.swift`, `RenderSignposts.swift`, `ArrangeDeriver.swift`,
`ExportCoordinator.swift`); the WS-11 §5 MKSync pending-queue durability
fix (`markDurablyDirtyIfAlreadySynced`, `MKSyncEngineController.swift`)
with its own test file (`MKSyncTests/MKSyncDurableDirtyMarkingTests.swift`);
an `MKArrangeEngineProviding` documentation-parity section added to
`CONTRACTS.md`; a real bug fix in `PaywallView.swift` (hardcoded legal
URLs replaced with `MKLegalLinks`); and `EditorViewModel.swift` wiring the
governor + degradation controller ahead of layer-tree construction and
registering the live layer tree with it.

Per this program's own house rule ("independently re-run builds/tests
before accepting any agent's claim of green" —
`docs/HANDOFF-ORCHESTRATOR.md`), this session did not take any of that on
faith — there was not even a claim of green to take on faith, since no log
existed at all. Every diff was read by hand first; the diffs below record
what independent re-verification against the actual host found, plus this
session's own additions to close the remaining P14 backlog items.

## P14 backlog items — numbering used by the source-comment cross-references

Every `// P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item N)`
comment already scattered across the tree (see the file list above) cites
an item number from `docs/HANDOFF-ORCHESTRATOR.md`'s own P14 scope
sentence, which lists five semicolon-separated items in this order. Listed
here explicitly, once, so every existing "item N" cross-reference resolves
against a real, numbered list rather than an implicit one:

1. **Real memory monitoring** — `os_proc_available_memory` + `DispatchSource`
   wired into `MKMemoryGovernor`/`MKMemoryLadder` + cache registration +
   D-223 journal-only critical actions with ballast tests. Delivered by
   the inherited pass: `MKMemoryGovernor.swift` (new),
   `MKMemoryGovernorTests.swift` (new),
   `MemoryGovernorIntegrationTests.swift` (new), plus the
   `BitmapCache.swift`/`DegradationController.swift`/`LayerTreeBuilder.swift`
   cache-registration wiring and `EditorViewModel.swift`'s governor
   construction/registration (see "Context" above).
2. **MKSignpost gaps (the MKArrange case)** — `arrangeDerive`/export
   signposts hoisted onto `MKFoundation.MKSignpost`. Cited by comments in
   `MKLog.swift`, `RenderSignposts.swift`, `ArrangeDeriver.swift`,
   `ExportCoordinator.swift`, `AutosaveController.swift`, and
   `PathTextDrawer.swift`.
3. **Simulator T-PRF budget sweep vs. D-115** — mark SIMULATOR-INDICATIVE,
   list device-gated items. Covered under "This session's own additions"
   below and in full in `docs/impl-log/WS-07-p14.md`'s own appended
   section.
4. **Backlog burn-down** — MKSync queue durability (`MKSyncEngineController
   .markDurablyDirtyIfAlreadySynced`), the stroke-width scaling fix
   (`StylePainting.swift`/`ShapeDrawer.swift`), `MKArrangeEngineProviding`
   documentation parity in `CONTRACTS.md`, and the WS-13 paywall/
   `MKLegalLinks` one-liner (`PaywallView.swift`). All four covered under
   "Context" above.
5. **5000-node memory-stress drive** with save-before-degrade + zero-loss
   relaunch evidence. Covered under "This session's own additions" below
   (`MemoryStressDriveTests.swift`).

## Verification performed this session

### `swift build` — clean

Zero errors. The inherited P14 sources were already in a buildable state
before this session touched anything — confirmed both by an initial full
build and, again, by a final incremental build immediately before writing
this file (`swift build` → `Build complete! (0.57s)`, i.e. already
up to date, nothing to recompile), log at `/tmp/mk_run3_build_check.log`.

### Per-target `swift test` — NOT full-package

Full-package `swift test` (`MakhtootKitPackageTests.xctest`, all targets
in one binary) reliably wedges this host under the concurrent multi-agent
load it is currently carrying (load average sampled at ~50 over 15 min at
one point tonight): a `swiftpm-testing-helper` process parks at ~0% CPU
indefinitely and the run never completes. This matches
`docs/HANDOFF-ORCHESTRATOR.md`'s own documented "Ops lesson" ("Full-package
`swift test` can wedge the host's fontd"). The proven workaround, followed
for every run in this session: `swift test --filter <TargetName>` per
target, never run concurrently with another `swift`/`xcodebuild`
invocation, each preceded by
`pkill -9 -f "swift-test|swift-build|swiftpm-testing-helper"; sleep 1`.

Of MakhtootKit's 17 test targets, 7 (`MKFoundationTests`, `MKRenderTests`,
`MKSyncTests`, `MKPersistenceTests`, `MKArrangeTests`, `MKExportTests`,
`MKStoreTests`) were independently run and confirmed green earlier this
session, before this file was written:

| Target | Result |
|---|---|
| MKFoundationTests | 35/35 |
| MKRenderTests | 90/90 (89 pre-existing + 1 new — see "5000-node memory-stress drive" below) |
| MKSyncTests | 92/92 |
| MKPersistenceTests | 57/57 |
| MKArrangeTests | 48/48 |
| MKExportTests | 94/94 |
| MKStoreTests | 42/42 (9 skipped — StoreKit-daemon-unavailable-outside-Xcode-host, a pre-existing, documented environment limit, not a P14 regression) |

The remaining 10 targets were run this session, per-target, with the same
hygiene:

| Target | Result | Suites | Notes |
|---|---|---|---|
| MKModelTests | 26/26 passed | 7 | 0.015 s |
| MKDesignSystemTests | 6/6 passed | 1 | 0.002 s |
| MKTextEngineTests | 84/84 passed | 12 | 4.490 s |
| MKCanvasTests | 136/136 passed | 16 | 0.188 s |
| MKAssetsTests | 85/85 passed | 15 | 1.110 s |
| MKFontsTests | 69/69 passed | 15 | 0.752 s |
| MKColorTests | 19/19 passed | 3 | 0.021 s |
| MKAnalyticsTests | 33/33 passed | 6 | 0.010 s |
| WS16CursiveTests | 9/9 passed | 3 | 1.862 s |
| MKPathTextTests | **did not complete** | — | reproducible process wedge, not a test failure — see below |

Combined with the 7 targets verified earlier, **16 of 17 MakhtootKit test
targets are confirmed clean this session.** `MKPathTextTests` is the one
outstanding target.

### `MKPathTextTests` — reproducible wedge, not a recorded assertion failure

Four independent `swift test --filter MKPathTextTests` attempts, each with
the standard pkill-before hygiene, none completed:

1. 150 s bounded attempt — killed; ~10 tests had printed passed before the
   stall.
2. 300 s bounded attempt — killed; still incomplete.
3. A fresh 150 s attempt after confirming host load average had already
   dropped from ~50 to the 2.7–10.4 range — 0 of 42 discovered tests
   completed.
4. An isolated, monitored single-target probe: the log file was frozen at
   exactly 55 lines across three 20 s samples (60 s total), with the lone
   `swiftpm-testing-helper --filter MKPathTextTests` process pinned at
   0.0% CPU throughout.

No `#expect` ever failed and no "recorded an issue" line ever appeared in
any attempt — every symptom is a live process wedge (matching
`docs/HANDOFF-ORCHESTRATOR.md`'s documented fontd-contention phenomenon),
reproduced even after host load had measurably subsided and even in full
single-target isolation, so it cannot be attributed solely to the known
concurrent full-package-load wedge. Fully killed and cleaned before moving
on, per instruction, rather than left running. Logs preserved at
`/tmp/mk_target_MKPathTextTests*.log` and
`/tmp/mk_target_MKPathTextTests_probe.log`. This needs follow-up — possibly
via the Xcode GUI test runner, which may not share the CLI `swift test`
process model — before `MKPathTextTests` can be called verified.

### App-level build sanity (`xcodebuild`, Makhtoot scheme)

`xcodebuild -scheme Makhtoot -configuration Debug -destination
'generic/platform=iOS'` → **BUILD SUCCEEDED**, zero `error:` lines. Two
benign, diff-unrelated warnings only: the `Info.plist`
`LSSupportsOpeningDocumentsInPlace` declaration note, and an AppIntents
metadata-extraction-skipped notice (both pre-existing, both already noted
in earlier impl logs). Code signing and validation completed normally.
This confirms the four `Makhtoot/AppShell` diffs
(`EditorViewModel.swift`, `PaywallView.swift`, `ProjectBrowserView.swift`,
`EditorScene.swift`) compile against the real app target, not just the
Swift package in isolation. Log: `/tmp/mk_appbuild.log`.

### `Scripts/stub-source-audit.sh` — run directly by this session

```
$ bash Scripts/stub-source-audit.sh
stub-source-audit: scanning /Users/binjamshid/Desktop/Apps/makhtoot/Makhtoot for AlwaysPremium*/AlwaysFree* stub types...
  checking declaration gate: /Users/binjamshid/Desktop/Apps/makhtoot/Makhtoot/Stubs/AlwaysPremiumEntitlementStub.swift
  checking for live references to: AlwaysPremiumEntitlementStub
PASS: every stub declaration is #if DEBUG-gated; no live reference outside its own file.
$ echo $?
0
```

**PASS**, exit code 0, run fresh (not transcribed from an earlier claim).

## This session's own additions closing the remaining P14 backlog

### 5000-node memory-stress drive

Added `MakhtootKit/Tests/MKRenderTests/MemoryStressDriveTests.swift` (one
new `@Test`, in a dedicated `@Suite struct MemoryStressDriveTests`),
closing the P14 backlog item "5000-node memory-stress drive with
save-before-degrade + zero-loss relaunch evidence" as a deterministic,
host-runnable integration test rather than a live-device memory-pressure
drive.

**Why a host-runnable test and not a live device/simulator memory-pressure
drive**: this program's established P11–P14 exit pattern (see
`docs/HANDOFF-ORCHESTRATOR.md`'s own "device-hardware perf verification"
line, and the "Environment-deferred items" / "device-gated items" lists in
`docs/impl-log/WS-07-p14.md`) is to mark genuine device-only verification
as explicitly environment-deferred rather than block a phase on hardware
this host does not have. Real `os_proc_available_memory()` behavior under
actual OS-issued memory pressure cannot be produced by a simulator or a
`swift test` host process — that specific gap is itemized by name in
`docs/impl-log/WS-07-p14.md`'s device-gated list and remains open. What
this test DOES prove, deterministically and repeatably on this host: a
real `DocumentPackage`/`AutosaveController`/`CommandJournal` (not fakes),
driven through a forced stage-1→critical walk on a real
`MKDegradationController` against a 5 000-node scene, produces the correct
save-before-evict ordering, and a subsequent `MakhtootDocument.open`
reload recovers the identical node count and content with zero loss. That
is the logic-level guarantee this backlog item asked for; the remaining
gap is real-device timing under genuine OS memory pressure, which stays on
the device-gated list.

**One-line `Package.swift` change required to unblock it**: `MKRenderTests`
did not previously depend on `MKPersistence`. Added it
(`.testTarget(name: "MKRenderTests", dependencies: ["MKFoundation",
"MKModel", "MKTextEngine", "MKRender", "MKPersistence"])`), following the
same precedent `MKArrangeTests` already sets (a test target depending on
whatever helps it test, not a `Sources/MKRender` dependency-graph change —
the shipped library target's own dependencies are untouched). `swift
build` was re-confirmed clean before writing the test, and again after.

**Verification**: `swift test --filter MKRenderTests` — 90/90 green (89
pre-existing + 1 new), the new test itself completing in ~1.1 s.

### Simulator T-PRF budget sweep / SIMULATOR-INDICATIVE marking

Closed the P14 backlog item asking for the simulator-vs-device T-PRF
budget numbers to be marked unambiguously as simulator-indicative rather
than implicitly read as device-verified. Added a literal
`SIMULATOR-INDICATIVE:` tagged doc comment to every D-115 budget-asserting
test/suite across six files, matching the tone and framing
`PerfHarnessTests.swift` already used for its own budgets — each addition
explains that the number was measured on the `swift test` host (Xcode
Simulator or macOS host process, never real device hardware) and stands in
for the real D-115 device budget.

Files annotated, confirmed comment-only by diff review:

| File | What was added |
|---|---|
| `MakhtootKit/Tests/MKRenderTests/PerfHarnessTests.swift` | Suite-level doc comment + inline comments on `syncTo100NodeSceneMeetsSimulatorBudget` / `syncTo5KNodeSceneMeetsSimulatorBudget` |
| `MakhtootKit/Tests/MKPersistenceTests/MakhtootDocumentTests.swift` | Doc comment on the `MakhtootDocumentPerfGateTests` suite |
| `MakhtootKit/Tests/MKPersistenceTests/AutosaveControllerTests.swift` | Doc comment on the `AutosaveControllerPerfGateTests` suite |
| `MakhtootKit/Tests/MKPathTextTests/PerfTests.swift` | Suite-level doc comment |
| `MakhtootKit/Tests/MKAssetsTests/MKAssetThumbnailTests.swift` | Inline doc comment on `firstRenderIsBelowBudgetAndSubsequentRendersAreCached` |
| `MakhtootKit/Tests/MKTextEngineTests/ShapingServiceTests.swift` | Inline comment on `singleLineCaptureIsFarUnderTheFiftyMillisecondTypingEchoBudget` |

Verified this session, via `git diff`, that this addition touched zero
`#expect`/budget-constant/algorithm lines in `PerfHarnessTests.swift`,
`MKAssetThumbnailTests.swift`, `PerfTests.swift`, and
`ShapingServiceTests.swift` (each shows exclusively added `///`/`//`
lines). `MakhtootDocumentTests.swift` and `AutosaveControllerTests.swift`
carry a larger uncommitted diff in the working tree, but that additional
diff is `docs/impl-log/WS-02.md` Session 4's already-logged
(2026-07-21) `.serialized`-suite/retry-once flake fix, landed and recorded
before this pass touched either file — this pass's own contribution to
both files is the same single added doc-comment line pattern as the other
four, confirmed by locating that exact line in isolation
(`MakhtootDocumentTests.swift:78`, `AutosaveControllerTests.swift:143`).
Neither `Package.swift`, `Sources/`, nor `MemoryStressDriveTests.swift` was
touched by this particular pass — the `Package.swift` modification present
in the working tree predates it (the memory-stress-drive item above).

The full measured-margin table (real `swift test --filter <Target>` runs:
`MKRenderTests` 90/90 green in 1.179 s total, `MKPersistenceTests` 57/57
green in 0.211 s total, `MKAssetsTests` 85/85 green in 2.060 s total) and
the superset-consistent "device-gated items" list (the existing
"Environment-deferred items" list plus two newly-itemized-by-name entries
— real `os_proc_available_memory()` behavior under genuine OS memory
pressure, and Instruments `xctrace` signpost capture per
`MKSignpost`/`MKRenderSignpost` category) are recorded in full in
`docs/impl-log/WS-07-p14.md`'s own appended section, "P14 backlog closure —
simulator T-PRF budget sweep vs D-115," rather than duplicated verbatim
here.

**`MKPathTextTests` and `MKTextEngineTests` could not be re-verified live
during that pass** despite five total bounded attempts (three and two
respectively, sequential, each with pkill-before hygiene) — every attempt
stalled indefinitely partway through. `sample <pid>` showed every thread
parked in `mach_msg2_trap` (a live IPC wait, 0% CPU), the same wedge
phenomenon this file's own verification section reproduced independently
against `MKPathTextTests` tonight, correlated at the time with a
concurrent sibling session's iOS Simulator process at 80–97% CPU. Since
both files' edits from that pass are comment-only (confirmed by diff),
there is no behavioral regression risk from the inability to capture a
fresh green run — the previously-established budgets and behavior in both
files are unchanged.

## Known non-blocking observations for the founder (recorded, not fixed)

**(a) Stale provisioning profile referencing the retired "masoon" name.**
`~/Library/MobileDevice/Provisioning Profiles/
C2T9K5NMZC-masoon-appstore.mobileprovision` exists on this host (confirmed
present tonight) and references team id `C2T9K5NMZC` — not this project's
real team, `54T3MDUR7H`. Automatic signing should ignore a profile from a
different team, so this is not expected to be a blocker, but it references
the retired name and a foreign team id and should eventually be deleted
from this keychain/profile store.

**(b) The simulator UDID named in `docs/HANDOFF-ORCHESTRATOR.md`
(`287ACD7E-26EC-453D-93DF-0C903189A9D7`) no longer exists.** Confirmed
tonight via `xcrun simctl list devices` — that UDID is gone; the
currently-booted simulator is a different device, "iPhone 17 Pro Max"
(`EE4E2CBC-BFB5-425D-99E5-4835CF4A3D19`, iOS 26.5). Not a blocker; any
future orchestrator instructions naming the old UDID literally should be
updated to the currently-booted one instead.

**(c) `Info.plist` has no `NSPhotoLibraryUsageDescription`, and
`APP_STORE_CHECKLIST.md` 11.04 expects one for image import.** A
repo-wide search of `Makhtoot/` tonight for
`PHPickerViewController`/`UIImagePickerController`/`PHPhotoLibrary`/
`PhotosPicker` found zero matches — the image-import feature the checklist
item anticipates does not appear to exist yet in this build. Not adding a
usage-description string for a feature that isn't there; flagging for
founder awareness. Adding the feature itself would be inventing scope, out
of bounds for a hardening pass.

**(d) Unrelated, harmless finding from this session's own diff review:**
`Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` gained a new `import
MKAnalytics` line as part of the inherited P14 diff, but nothing in the
file's current diff or body references `MKAnalytics` — it appears to be an
unused import (confirmed: `grep -n "MKAnalytics"
Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` matches only the
`import` line itself). Harmless (the app-level `xcodebuild` build above
succeeded cleanly with it present — Swift does not error on unused module
imports), and out of this pass's scope to remove without knowing whether a
sibling change intended to add analytics instrumentation to the paywall's
legal links and simply didn't finish. Recorded for whoever next touches
this file.

## P14 exit — recommendation, not adjudication

The findings below inform the independent phase exit review required by `PLAN.md` §5.

- 16 of 17 MakhtootKit test targets are independently confirmed green this
  session (7 verified earlier tonight, 9 verified in this file's own
  verification pass), with real, itemized test counts for every one.
- The 17th, `MKPathTextTests`, reproducibly wedges the host process rather
  than failing an assertion — four independent attempts in this session's
  own verification pass (above) plus three more in the earlier T-PRF
  budget-sweep pass (see "Simulator T-PRF budget sweep" above), seven in
  total across two separate passes tonight, under both contended and
  measurably-quieter host-load conditions. No evidence of a real test
  regression — every symptom is a process-level IPC stall — but it has not
  been re-confirmed live since the P14 diffs landed, and that gap should be
  named plainly rather than assumed away.
- `swift build` is clean, the app-level `xcodebuild` build succeeds, and
  `Scripts/stub-source-audit.sh` passes, all independently re-run tonight.
- All P14 backlog items from `docs/HANDOFF-ORCHESTRATOR.md`'s scope list
  are addressed: memory monitoring/`MKMemoryGovernor` wiring with cache
  registration, the stroke-width scaling fix, the `MKSignpost`/`arrangeDerive`
  hoist, `MKArrangeEngineProviding` documentation parity, the WS-13
  paywall/`MKLegalLinks` fix, the MKSync durable-dirty-marking fix, the
  5000-node memory-stress drive (logic-level, host-runnable), and the
  simulator T-PRF budget sweep with SIMULATOR-INDICATIVE marking and an
  explicit device-gated-items list.
- Three founder-facing observations are recorded above (stale provisioning
  profile, stale simulator UDID in the handoff doc, missing photo-library
  usage description for a feature that does not yet exist) — none of them
  block a TestFlight upload on their own, but all three should be read
  before that upload proceeds.

The one open item this session leaves genuinely unresolved is
`MKPathTextTests`'s live-green status. Everything else described above is
independently, freshly verified as of this session.
