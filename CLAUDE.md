# CLAUDE.md

Makhtoot / مخطوط — Arabic typography and design app for iPhone and iPad. A design tool
built *from* the Arabic letter outward, not a Latin-first tool with Arabic bolted on.

## Mandatory read order

`FOUNDATION.md` is the single source of truth. **If any other deliverable contradicts
it, the other deliverable is wrong.** Read in this order before planning or coding:

1. `FOUNDATION.md` — authoritative decisions and cross-document conventions (`D-1xx`)
2. `PROJECT_DESCRIPTION.md` — product, positioning, status
3. `ARCHITECTURE.md` — execution-ready technical design (`D-2xx` for new decisions)
4. `PLAN.md` / `EXECUTION_PLAN_2026-07-28.md` — current sequencing

Triggered reads: `PRD.md` for scope questions · `DECISIONS_LOG.md` before changing any
`D-###` · `FILE_MAP.md` / `DEPENDENCY_GRAPH.md` for where code lives ·
`APP_STORE_CHECKLIST.md` before anything submission-related ·
`MakhtootKit/CONTRACTS.md` for cross-module contracts.

## Identity

| Item | Value |
|---|---|
| Product | Makhtoot / مخطوط (**never** Masoon — different app in this portfolio) |
| Bundle ID | `net.binjamshid.makhtoot` |
| Swift package | `MakhtootKit`, module prefix `MK` |
| Document type | `.makhtoot` (UTI `net.binjamshid.makhtoot.project`) |
| Promise | "Where the Arabic letter becomes design" |

## Platform and scope

- **iPhone and iPad, and Android.** An Android port was authorized by the founder on
  2026-07-30, overriding this file's prior "no Android port" statement. See `D-300`–`D-325`
  in `DECISIONS_LOG.md` (summarized in `FOUNDATION.md` §13) and the frozen execution spec
  `ANDROID_SPINE.md` for the full register. Android code lives under `android/`; it never
  touches `MakhtootKit/` or `Makhtoot/`. D-100 ("Universal iPhone+iPad") stays authoritative
  for iOS, amended for Android only by D-300.
- **Arabic-only at launch** — UI, RTL, no localization into other languages. This is the
  strategic bet, not a gap to close later: be the best possible tool for Arabic text
  rather than an adequate one for many scripts.
- **No backend.** Makhtoot has no server of its own and is not on the platform-api
  identity/backup services the account-based apps in this portfolio share. Sync is
  CloudKit; purchases are StoreKit 2. Do not introduce a server without a new decision.

## Architecture

Local Swift package `MakhtootKit` with 16 library targets (`MKFoundation`, `MKModel`,
`MKTextEngine`, `MKPathText`, `MKArrange`, `MKCanvas`, `MKRender`, `MKExport`,
`MKFonts`, `MKAssets`, `MKColor`, `MKDesignSystem`, `MKPersistence`, `MKStore`,
`MKSync`, `MKAnalytics`). Swift 6, Core Text, StoreKit 2, CloudKit.

**Arrange Mode is the differentiator.** It is an explicit, reversible step that turns
normally-shaped Arabic text into a fully manipulable composition where every glyph,
tashkeel mark and ligature component is independently transformable — **without ever
breaking Arabic shaping rules unless the user explicitly asks to.** Any change near the
text engine must preserve that invariant.

## Quality bar

- Shaping correctness is non-negotiable: never ship a change that silently mis-shapes
  Arabic, drops tashkeel, or breaks a ligature.
- RTL-first, dynamic type, VoiceOver, 44pt targets.
- Test the text engine with golden fixtures — shaping regressions are invisible in review.

## Never

- Call this app Masoon, or borrow its conventions — they are unrelated products.
- Break Arabic shaping to make a manipulation easier — on Android this includes registering
  a Class-B shaping delta (any dropped/added/reordered mark, changed glyph id, broken or
  differently-composed ligature, changed joining form, or tashkeel loss) in
  `android/SHAPING_DELTAS.md`: it is a hard gate failure and can never be registered as
  acceptable, no matter which agent or reviewer proposes it (D-325).
- Add a backend, accounts, or a network dependency without a new `D-###`.
- Treat a document that contradicts `FOUNDATION.md` as correct.
- Localize into other scripts in v1.
- Ship a release AAB with the referral module, its Kotlin source set, or its Arabic strings
  present — referral is compile-time excluded from Release on Android exactly as it is on
  iOS, proven by `Scripts/android/referral-release-grep.sh` against the built binary, not
  just the source tree (D-321, mirrors D-225).

## Decision log

New architecture decisions get a `D-2xx` id in `DECISIONS_LOG.md` and must be mirrored
wherever they are elaborated. Ask before changing a locked `D-1xx`.
