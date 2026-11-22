# Project priorities

| Area | Next useful contribution | What would demonstrate progress |
| --- | --- | --- |
| Arabic lettering on iOS | Reduce a joining, diacritic-placement or export inconsistency to a small fixture. | Exact Unicode text, font/version, expected rendering and the first operation that changes it. See the [test guide](typography-testing.md). |
| Project interchange | Document or exercise a real saved project against the provided scene and migration fixtures. | A repeatable round trip with text, glyph placements and version handling checked. See the [format guide](document-format.md). |
| Android port | Connect one scaffolded operation to its implementation and compare it to the reference data. | A focused platform test for the affected operation and a clear account of remaining gaps. See the [architecture guide](architecture-guide.md). |
| Fonts and distributable examples | Resolve a provenance or packaging gap for one family, asset or example. | Upstream/version, permission, correct notices and comparison to the actual shipped files. See [asset rights](asset-rights.md). |

These are contribution opportunities. The maintainer agrees on scope in the issue or PR. Older plans in the repository preserve design decisions and estimates; a release commitment belongs in a dated release announcement.
