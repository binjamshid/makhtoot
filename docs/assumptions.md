# Assumptions & decision journal

Pattern source: ClassTranscriber's `docs/assumptions.md` (portfolio house standard,
matrix row 7 — "the cheapest high-value steal in the portfolio"). A journal that
marks its own ignorance: every entry that can only be verified by running something
— a build, a live network call, an external tool — is marked **UNVERIFIED** with the
exact command that would confirm or refute it. "An agent wrote it and it
type-checks" is not verification; this file is where that gap gets written down
instead of silently assumed away.

Started 2026-07-20 during the portfolio house-standard pass (repo git-init, CI
scaffolding, ratchets). Entries are dated; nothing here is retroactively edited to
look more confident than it was on the date it was written.

---

## 2026-07-20 — Portfolio house-standard pass (repo bring-up)

- **CONFIRMED — `MakhtootKit` package builds clean on this machine.** Ran
  `cd MakhtootKit && swift build` during this session: `Build complete! (3.58s)`,
  zero errors. This only covers the SwiftPM library targets, not the app target
  (see next entry).

- **UNVERIFIED — the `Makhtoot` app target itself builds under `xcodebuild`.**
  Every phase gate in `PLAN.md` (`G-BUILD`) and `DECISIONS_LOG.md` asserts the app
  target builds clean under Swift 6 strict concurrency; this session verified only
  the `MakhtootKit` SwiftPM package (previous entry), not the `.xcodeproj` app
  target, which needs a simulator destination and was out of scope/time for a
  git-hygiene-and-CI-scaffolding pass. Confirm with:
  `xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -destination 'generic/platform=iOS Simulator' build`

- **UNVERIFIED — no credential-shaped content is in the tree being committed.**
  Before `git init`, this session ran a keyword grep across text-ish extensions
  (`*.swift *.md *.json *.plist *.entitlements`) for `api[_-]?key|secret|password|
  token|BEGIN (RSA|PRIVATE)` and found nothing beyond expected non-secret hits
  (StoreKit "token" as in `NSObjectProtocol` observer token, doc-comment mentions
  of the word "secret" in prose about there being none). This is a keyword scan,
  not an entropy/pattern-based secret scanner, and it did not inspect binary
  assets (24 MB of `.ttf` font files, `.png` app icon, `.icc` slot placeholders)
  byte-for-byte. Confirm with a real secret-scanning pass before ever adding a
  remote: `gitleaks detect --source . --no-git` (or `trufflehog filesystem .`) run
  against the committed tree.

- **UNVERIFIED — the two localization/token-linter ratchet baselines
  (`Scripts/check-localization.sh` BASELINE=1, `Scripts/check-design-tokens.sh`
  BASELINE=1) are the TRUE current counts, not an artifact of the regexes being
  too loose or too tight.** Each script's flagged line was manually read and
  cross-checked against its surrounding code in this session (see each script's
  header comments for the specific rationale per flagged line), but the detection
  patterns are new and unaudited by a second pass. Confirm by re-deriving the
  count independently: `grep -rn '"Debug"' Makhtoot --include='*.swift'` for the
  localization one; `grep -rn 'foregroundStyle(.white)' Makhtoot/AppShell
  --include='*.swift'` for the token one — and by watching whether the count only
  ever moves down across the next few real feature PRs, never silently up via a
  raised `BASELINE`.

## Open founder-decision placeholders (context, not new findings)

The repo already tracks its own known-placeholder external references far better
than most first passes: `MakhtootKit/Sources/MKAnalytics/MKLegalLinks.swift` and
`Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift`/`SupportSettingsView.swift`
all carry a grep-able `PLACEHOLDER-FD-01` marker for the privacy/terms/support URLs
pending the FD-01 domain decision, and
`MakhtootKit/Sources/MKFonts/MKPremiumDelivery.swift`'s `placeholderManifestURL`
points at an intentionally-invalid `.invalid` domain pending FD-04 (font hosting).
These are not entered here as UNVERIFIED assumptions because they are already
tracked, deliberate, and self-documenting — the opposite failure mode this file
exists to catch. Listed for completeness so a future reader of this file doesn't
independently "discover" and re-log them as new findings.
