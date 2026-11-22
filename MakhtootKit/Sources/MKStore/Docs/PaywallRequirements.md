# Paywall compliance requirements — PW-01…PW-10 (T10)

These ten invariants are what `MKPaywallStateMachine` encodes as *state*
and what the WS-13 SwiftUI rendering (and any future paywall surface) MUST
satisfy structurally. They are cited by id from `APP_STORE_CHECKLIST.md`'s
paywall-compliance section and from `AGENT_TASK_PACKETS/WS-12-analytics-settings.md`'s
legal-links task. WS-10 is the assigning owner of ids 01–10 (the packet
that created this document); no prior authoritative numbered list existed
before this document.

| id | Requirement | Grounding |
|---|---|---|
| **PW-01** | A visible close/dismiss control is present on the paywall at all times — never hidden behind a modal-within-a-modal, never requiring a swipe gesture as the ONLY dismiss path. | Guideline 3.1.2 [^45][^47] |
| **PW-02** | Price and billing period are shown directly adjacent to each product's own purchase button — not on a separate screen, not requiring a tap to reveal. | Guideline 3.1.2 [^45][^50][^51] |
| **PW-03** | "Auto-renews. Cancel anytime in Settings" (or the exact Arabic equivalent) disclosure text appears adjacent to every subscription CTA. | Guideline 3.1.2 [^45][^52] |
| **PW-04** | Both auto-renewable options (monthly, annual) AND the lifetime option are shown together on the same paywall presentation, each with its own Apple-storefront-localized price string — never a subset. | BRIEF pricing; Guideline 3.1.2 |
| **PW-05** | A working link to the Privacy Policy is present on the paywall (or one tap away via a clearly labeled control), reachable from inside the binary without a purchase. | Guideline 3.1.2 [^45][^47] |
| **PW-06** | A working link to the Terms of Use (EULA) is present under the same standard as PW-05. | Guideline 3.1.2 [^45][^47] |
| **PW-07** | A "Restore Purchases" control is present and functional — mandatory, not optional UI (Guideline 3.1.2(c)). | D-113; Guideline 3.1.2(c) [^45][^47] |
| **PW-08** | The paywall is never presented before the user has seen genuine first app content — no paywall-gated app launch, no paywall as the very first screen of onboarding. | Market study §8 rejection-pattern guidance [^50][^51][^45] |
| **PW-09** | No countdown timers, artificial scarcity claims, or other urgency dark patterns appear anywhere on the paywall. | Market study §8 [^51] |
| **PW-10** | The free tier remains genuinely usable without any purchase (Q41: full editing, free fonts/solid backgrounds, 2 MP JPEG/PDF export) — paywall copy must never imply the app is unusable without purchasing. | BRIEF Q41 |

## How `MKPaywallStateMachine` encodes these

The state machine itself cannot *render* PW-01/02/04/05/06/08/09/10 (those
are UI-layer/copy concerns WS-13 owns), but it structurally supports
correct behavior:

- **PW-07 / PW-08 / PW-09** are behavioral, not visual, and the state
  machine IS the enforcement point: `dismiss()` always exists as a
  callable transition from any state (PW-01's underlying requirement —
  there is no state with no path to `.dismissed`); `restore()` is a first-
  class entry point returning a distinct `.nothingToRestore` state rather
  than being folded into a generic failure (PW-07); nothing in
  `MKPaywallStateMachine`'s context list auto-presents on app launch —
  every `MKPaywallContext` case is caller-triggered (a feature tap, an
  onboarding step's own explicit "show plans" action, a settings tap), so
  PW-08 cannot be violated by the state machine itself initiating
  presentation.
- **PW-02/03/04** are satisfied by `MKProductCatalog` always returning all
  three products together (`MKStoreIDs.all`, never a filtered subset) with
  `displayPrice`/`kind` (subscription period vs. non-consumable) attached
  per product — WS-13's rendering has everything it needs to lay out all
  three with price+period adjacent to each CTA in one pass.
- **PW-05/PW-06** are pure content (URLs/labels) WS-12/WS-13 own; this
  document is the cross-reference point both packets cite.
- **PW-09**: `MKPaywallStateMachine`'s states (`browsing, purchasing,
  pendingApproval, success, nothingToRestore, failed, dismissed`) contain
  no time-bounded/expiring state of any kind — there is structurally no
  "offer expires in 00:59" state to render, because no such state exists
  in the enum.
- **PW-10**: enforced entirely outside this module — WS-08 export gating's
  own free matrix (D-119) is the source of truth that free-tier editing
  stays functional; this document just records the paywall-copy-level
  constraint (never claim otherwise in paywall strings).

## Sign-off

This checklist is signed off against the WS-13 paywall UI build once that
UI exists and has been visually verified (RTL rendering, iPhone SE width,
all ten items present) — see `docs/impl-log/WS-10.md`'s gating-sweep
evidence section for the sign-off record, and `APP_STORE_CHECKLIST.md`'s
paywall-compliance section for the submission-time re-check.

[^45]: Market study §8, Guideline 3.1.2 paywall requirements overview.
[^47]: Market study §8, restore mechanism + lifetime/subscription coexistence precedent.
[^50]: Market study §8, in-binary price/term/restore disclosure precedent.
[^51]: Market study §8, dark-pattern/urgency rejection precedent.
[^52]: Market study §8, auto-renew disclosure precedent.
