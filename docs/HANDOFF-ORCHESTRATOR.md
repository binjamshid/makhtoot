# Makhtoot — Run-3 Coordinator Handoff (2026-07-21)

You are taking over as Run-3 orchestrator for Makhtoot (مخطوط), a native iOS 18+
Arabic typography app. Repo: `/path/to/makhtoot`. Read this
whole file, then `PLAN.md` §5 (execution model) and the memory file at
`~/.claude/projects/-Users-binjamshid-Desktop-Apps-makhtoot/memory/makhtoot-program-state.md`
before doing anything.

## Non-negotiable house rules
- Product name Makhtoot / مخطوط — NEVER "Masoon". No Qur'anic content/features.
- Locked decisions live in FOUNDATION.md + DECISIONS_LOG.md (66+ records). Agents/you
  never contradict them; conflicts = stop and record, don't improvise.
- Every work session appends evidence to `docs/impl-log/WS-*.md` (ADRs, test tails,
  deviations proposed-never-silent). `MakhtootKit/CONTRACTS.md` is cross-module API truth.
- Gate discipline: independently re-run builds/tests before accepting any agent's
  claim of green. Arabic strings carry a Latin gloss on first use.
- If subagents are available, delegate file-writing to them and review; if not, write
  directly but keep the same evidence discipline.

## Current state (verified 2026-07-21)
- Phases P0–P13 COMPLETE and gate-verified. Suite was 960/960 (159 suites) at P11
  exit; P12 (MKSync, fake-transport seam) and P13 (MKAnalytics + Settings) landed
  after. FD-01 (bundle id `net.binjamshid.makhtoot`), FD-03 (Apple Generic CMYK),
  FD-05/D-225 (referral compiled out of Release), FD-06 (Family Sharing OFF) all
  founder-resolved.
- App runs end-to-end on simulators (installed on iPhone 17 sim, UDID
  `287ACD7E-26EC-453D-93DF-0C903189A9D7`).
- **P14 (hardening) was IN FLIGHT via a background agent that dies with the old
  session.** Check `docs/impl-log/WS-07.md` for a partial "P14" session; continue or
  relaunch. P14 scope: real memory monitoring (os_proc_available_memory +
  DispatchSource) wired into MKMemoryGovernor/MKMemoryLadder + cache registration +
  D-223 journal-only critical actions with ballast tests; MKSignpost gaps (MKArrange
  case); simulator T-PRF budget sweep vs D-115 (mark SIMULATOR-INDICATIVE, list
  device-gated items); backlog burn-down (MKSync queue → SwiftData-backed [WS-11 §5],
  stroke-width scaling fix, MKArrangeEngineProviding into CONTRACTS.md, WS-13
  paywall/MKLegalLinks one-liner if open); 5000-node memory-stress drive with
  save-before-degrade + zero-loss relaunch evidence.

## After P14 gate passes → TestFlight upload (founder-approved, run unattended)
All credentials are provisioned:
- Team `54T3MDUR7H`; valid "Apple Distribution: Abdulrahman Al-Rashdi" cert in keychain.
- ASC API key `~/.appstoreconnect/private_keys/AuthKey_KEY_ID.p8`, key ID
  `KEY_ID`, Issuer ID `ISSUER_ID`.

  **Do not use key `KEY_ID`** — it is dead. Every call with it now returns HTTP
  401 `Unauthenticated` / `No Accounts with App Store Connect Access`, and the two
  failed upload attempts recorded in `docs/impl-log/WS-15.md` (2026-07-22 and
  2026-07-23) were this, not the role/permission gap those entries diagnosed at the
  time. `87T2CQVS85` is also 401. `KEY_ID` is the only live key of the three in
  `~/.appstoreconnect/private_keys/`; `xcrun altool --list-apps` with it returns
  `net.binjamshid.makhtoot` among the team's apps, and it uploaded build
  `20260729.3` cleanly on 2026-07-29.
- ASC app record exists. Legal URLs stay as PP placeholders for TestFlight
  (real URLs required only before App Store submission — founder said so explicitly).

Sequence (see APP_STORE_CHECKLIST.md ~lines 760-780 for the documented commands):
1. `xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot -configuration Release
   -destination 'generic/platform=iOS' archive -archivePath <path>
   -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_KEY_ID.p8
   -authenticationKeyID KEY_ID
   -authenticationKeyIssuerID ISSUER_ID
   -allowProvisioningUpdates`
2. `xcodebuild -exportArchive` with an app-store-connect method ExportOptions.plist
   (same three auth flags).
3. Upload with `xcrun altool --upload-app` (or `-exportArchive` destination upload)
   using apiKey/apiIssuer.
4. Before archiving, run the two guards: `bash Scripts/stub-source-audit.sh` and
   `bash Scripts/referral-release-grep.sh <built .app>` — both must PASS.
5. Report the build number once processing in ASC.

## Founder-pending after upload (do not do these yourself)
- Create the 3 IAPs in ASC: `net.binjamshid.makhtoot.premium.monthly` ($2.99/mo,
  group "Makhtoot Premium"), `.annual` ($29.99/yr, same group), `.lifetime`
  ($89.99 non-consumable). Family Sharing OFF each; no intro offers.
- Real privacy-policy/terms URLs + support email (placeholders in MKLegalLinks.swift).
- Device-hardware perf verification (list produced by P14).
- Post-FD-01 sync re-verification with the real CloudKit container
  (APP_STORE_CHECKLIST item 11.06b) — needs real devices/account.
- Sandbox StoreKit suite (9 SKTestSession tests auto-skip off-host; eventual local
  host = the app scheme's empty TestAction, a known WS-01 gap) + checklist 3.10/11.07.
- Final visual approval, App Store metadata/screenshots, submission.

## Ops lessons (they will bite you otherwise)
- Full-package `swift test` can wedge the host's fontd → prefer
  `swift test --filter <Target>` per target, serially. If a run shows ~0% CPU for
  minutes: `sample <pid>` to confirm.
  **Root-caused 2026-07-23 (WS-15 session 7): this host regularly runs multiple
  concurrent Claude Code sessions across different projects at once, all contending
  for the same system CoreText/fontd service — that contention, not a Makhtoot code
  defect, is what actually wedges the run (log always stalls right after a
  `.SFArabic` CoreText fallback note). Check `ps aux | grep -i "xcodebuild\|swift-test"`
  and `uptime` first.** Killing the wedged process: **do NOT** blindly
  `pkill -9 -f "swift-test|swift-build|swiftpm-testing-helper"` — that pattern matches
  by process name only, with no project scoping, so on this shared host it can (and
  demonstrably has) killed a *different* session's legitimate in-flight build/test
  run. Instead, find the specific stuck PID (`ps aux | grep swiftpm-testing-helper`),
  confirm it's actually yours with `lsof -p <pid> -a -d cwd` (its cwd/test-bundle-path
  should point into *this* repo), and `kill -9` only that PID.
- A corrupted `.build/build.db` (e.g. after disk-full) hangs ALL SPM commands at
  startup → `rm -rf MakhtootKit/.build`.
- Never delete `~/Library/Caches/org.swift.swiftpm` (dangling `~/.swiftpm/cache`
  symlink hangs SPM); recreate the dir if missing.
- Disk fills fast (DerivedData + sims). Safe cleanup: DerivedData, /tmp scratch.
  Ask the founder before touching simulator devices.
- Run EVERY long command with a self-kill bound:
  `(cmd & pid=$!; (sleep 420 && kill -9 $pid) & w=$!; wait $pid; kill $w)`.
- Background subagents die with the session; their transcripts are lost — re-brief
  fresh agents from `docs/impl-log/*` evidence, and check file mtimes before
  assuming/duplicating work (a duplicate-launch near-miss already happened once).
- Perf-budget tests are `.serialized` with a one-retry pattern — keep budgets strict.

## Update trail
Keep `makhtoot-program-state.md` (memory) current at every phase transition; that
file is how sessions survive breaks. Append, don't rewrite history.
