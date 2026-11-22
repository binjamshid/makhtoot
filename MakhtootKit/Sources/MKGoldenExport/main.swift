// Work item 0.2 (android/, ANDROID_TASK_PACKETS/BATCH-0.md). Entry
// point: drives every category exporter below in a fixed, deterministic
// order and writes `android/fixtures/DETERMINISM_EXCLUSIONS.json`, the
// machine-readable exclusion list `gate.sh` (Agent 1.1, later batch) needs
// to know which categories/extensions are exempt from the byte-identical
// second-run requirement (G0, ANDROID_SPINE.md §6).
//
// NOTE on the `swift test --no-parallel` wedge (EXECUTION_PLAN_2026-07-28.md
// ground rule 3): that hang is specific to XCTest's parallel worker-process
// scheduling colliding with Core Text's process-wide font-registration
// state. This target is a plain `swift run` executable, not `swift test` —
// it never spawns parallel XCTest workers, so the wedge does not apply to
// *running* this tool. It DOES apply if a future agent tries to exercise
// this target's logic from inside a test target; note left here so nobody
// re-discovers that the hard way.

import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--local-pdf"] {
    await runCategory("local PDF") { try exportLocalPDFs() }
    exit(0)
}
guard arguments.isEmpty else {
    print("Usage: swift run MKGoldenExport [--local-pdf]")
    exit(2)
}

print("[MKGoldenExport] repo root: \(RepoPaths.repoRoot.path)")
print("[MKGoldenExport] fixtures root: \(RepoPaths.fixturesRoot.path)")
RepoPaths.ensure(RepoPaths.fixturesRoot)

let start = Date()

// Each category export is a synchronous or async top-level function defined
// in its own `<Category>Export.swift` file. Order is fixed (alphabetical by
// category directory name) purely for deterministic console log output —
// categories do not depend on each other's output.

await runCategory("arrange") { try await exportArrange() }
await runCategory("assets") { try exportAssets() }
await runCategory("canvas") { try exportCanvas() }
await runCategory("export") { try await exportRasterVectorGoldens() }
await runCategory("joining") { try await exportJoining() }
await runCategory("ligature") { try await exportLigature() }
await runCategory("marks") { try exportMarks() }
await runCategory("pathtext") { try exportPathText() }
await runCategory("render") { try exportRender() }
await runCategory("scenecodec") { try exportSceneCodec() }
await runCategory("shaping") { try exportShaping() }

try DeterminismManifest.write()

let elapsed = Date().timeIntervalSince(start)
print("[MKGoldenExport] done in \(String(format: "%.1f", elapsed))s")

// MARK: -

func runCategory(_ name: String, _ body: () async throws -> Void) async {
    let t0 = Date()
    do {
        try await body()
        print("[MKGoldenExport] \(name): ok (\(String(format: "%.1f", Date().timeIntervalSince(t0)))s)")
    } catch {
        print("[MKGoldenExport] \(name): FAILED — \(error)")
        exit(1)
    }
}
