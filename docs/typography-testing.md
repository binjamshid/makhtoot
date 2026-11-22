# Testing Arabic typography

Use this check when a change could affect Arabic joining, diacritics, reading order, arrangement, or export. The manual steps use the iPhone or iPad editor. Start with a square canvas and follow the [Arabic quick start](quick-start.ar.md) to insert text, arrange it, and export it. Keep **تقسيم النص حسب المسافات** off so each test line stays together.

## Manual checks

Paste each example as its own line and compare the committed text on the canvas. Start with the default font, then repeat the affected case with the font implicated in the change. Record the exact face, size, and font version where available. To check live shaping independently on iOS, compare the same input, face, and size in Pages where you can select that face.

| Check | Copy these examples | Expected result |
| --- | --- | --- |
| Contextual joining | `ب` / `بيت` / `حبل` / `قلب` | ب takes its isolated, initial, medial, and final forms respectively. Its dot stays below, and connections are continuous where the letters join. |
| Lam–alef | `لا` / `بلا` / `لأ` / `لإ` / `لآ` | Lam and alef form the required ligature. In `بلا` the ligature connects to ب. Each alef variant retains its hamza or madda. |
| Stacked marks | `مُحَمَّدٌ` / `شَدَّةٌ` | The shadda and fatha remain visible on the second م and on د, respectively. Other marks stay with their own letters. |
| Mixed direction | `مرحبا Hello ١٢٣ 123` / `هل جرّبت (النسخة التجريبية)؟` | The Arabic reads right to left. `Hello` and the digits in each number retain their internal order and digit forms. The parentheses enclose the intended phrase. |

1. Capture `مُحَمَّدٌ` on the canvas before and immediately after entering **الترتيب الحر**. Compare the word at the same zoom. The outlines, joins, spacing, and mark positions should match. Selection guides can differ.
2. With **أشكال** selected, move the fatha above ح. Only that mark should move. Undo once to check that the mark returns to its original position, then redo the move for the persistence check. If you also test moving one letter, expect neighboring glyphs to retain their original forms. A deliberate move can leave a visible gap at a join.
3. Close Arrange Mode, tap **تم** to return to **المشاريع**, and reopen the same project. The word and the adjusted mark should appear where you left them. Export **JPEG** and open the result in an image viewer. Compare the shaping and placement of the marks with the canvas at a comparable scale. JPEG compression can change edge pixels.

For more cases, including path text and format-specific export checks, see section 7 of the [test matrix](../TEST_MATRIX.md).

## Fixtures and focused tests

The package tests use copyable strings for stacked marks, lam–alef variants, and mixed-direction runs. [Text-engine fixture source](../MakhtootKit/Tests/MKTextEngineTests/Fixtures.swift)

The stored Core Text captures for Amiri provide structured references for shaping. [Lam–alef capture](../android/fixtures/shaping/amiri/F-1.json), [mixed-direction capture](../android/fixtures/shaping/amiri/F-5.json), [Amiri font notice](../MakhtootKit/Sources/MKFonts/Resources/Fonts/Amiri/LICENSE-OFL.txt)

The recorded export shows how connected Arabic and both digit sets can appear in one rendered image. [PNG reference](impl-log/evidence/WS-08/sample-opaque.png)

From the repository root on macOS, run the focused shaping check relevant to your change. See [build instructions](BUILD.md) for the toolchain.

```sh
cd MakhtootKit
swift test --filter 'JoiningAnalyzerTests|LigatureDetectorTests|MarkAttachmentTests|BidiMapTests'
```

For a change to the conversion into Arrange Mode, run `swift test --filter DerivationFidelityTests` from `MakhtootKit`. For a failure during reopen, the [`fixture-arranged-la.makhtoot` scene](../MakhtootKit/Tests/Fixtures/fixture-arranged-la.makhtoot/scene.json) is a minimal persistence fixture for a composed lam–alef and its source text. Its saved glyph lacks an outline, which is recorded in the [render report](../android/fixtures/render/fixture-arranged-la.report.json).

## Report a rendering problem

- Paste the exact input, including spaces, marks, and punctuation. Include Unicode code points if invisible characters or mark order matter.
- Record the app build or commit, platform and OS version, device or simulator model, and the exact font face, size, and version. For a variable font, include the weight or axis settings you used.
- Give the shortest reproduction steps and say what you expected and what you observed. Identify the first stage where it differs, such as text entry, the canvas after insertion, Arrange Mode, reopening, or export.
- Attach a before-and-after screenshot or a small `.makhtoot` example that you can share. If the issue appears in export, include the format, dimensions, viewer, and a shareable exported file. Use the example text above if it reproduces the issue.
