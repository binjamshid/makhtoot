# Makhtoot (مخطوط) — APP_STORE_CHECKLIST.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.
## The Complete App Store Submission Playbook (Run-1 Deliverable, executed in Run 3)

**Conforms to:** `FOUNDATION.md` (D-113, D-121, D-123, D-124, D-125, FD-01..FD-07),
`_input/BRIEF.md`. Compliance evidence base: `docs/makhtoot-market-study.md` §8 and §9 —
citations in the form `[MS ^NN]` refer to that document's numbered references. Any
policy/legal claim in this checklist either carries an `[MS ^NN]` citation or is marked
**VERIFY-AT-SUBMISSION** (consolidated list in §15). Never assert an uncited,
unverified guideline fact to Apple or in metadata.

**How Run 3 uses this document.** Run 3 executes this checklist top to bottom, driving
App Store Connect (ASC) through Chrome automation and `xcodebuild`/App Store Connect API
where possible. Every item is a checkbox tagged:

- **[AGENT]** — automatable by the agent: ASC web UI via Chrome control, App Store
  Connect API with a founder-provisioned key, `xcodebuild`, Simulator, file generation.
  The agent performs it and records evidence (screenshot/log path) next to the checkbox.
- **[FOUNDER]** — must be performed by the founder personally: anything involving
  credentials or 2FA, legal/agreement acceptance, payments or banking/tax data,
  irreversible product configuration, and final visual/copy approval (BRIEF: Q56, Q84).
  The agent pauses, states exactly what is needed, and waits.

**Hard boundary (non-negotiable):** the agent never types, stores, or is shown the
founder's Apple ID password, 2FA codes, banking details, or tax identifiers. The founder
signs in to ASC in the controlled Chrome profile themselves; the agent operates only
inside an already-authenticated session and stops at any re-authentication prompt.

**Item numbering** is `§section.item` (e.g., 3.07) so Run 3 logs and rejection responses
can reference steps precisely.

---

## 1. Prerequisites — Apple Developer account, agreements, certificates, profiles

### 1A. Account and agreements (founder-only zone)

- [ ] 1.01 **[FOUNDER]** Confirm active Apple Developer Program membership (Account
      Holder role) and that the membership will not lapse during the review window.
      Individual vs Organization enrollment affects the seller name shown on the store
      ("Seller: <name>") — founder confirms which entity ships Makhtoot.
- [ ] 1.02 **[FOUNDER]** Accept the current **Apple Developer Program License
      Agreement** in ASC if a new version is pending (blocking: new app records and
      builds cannot be submitted with a pending agreement).
- [ ] 1.03 **[FOUNDER]** Sign the **Paid Applications Agreement** (Agreements, Tax, and
      Banking → Paid Apps). Makhtoot has paid IAP from day one; without this agreement
      IAPs cannot reach "Ready to Submit". Founder also completes **banking** and **tax**
      forms (US tax forms + any local forms ASC requests for the founder's entity;
      Oman-based founder — ASC will present the applicable withholding/tax interview).
      The agent never sees or enters any of this data.
- [ ] 1.04 **[FOUNDER]** Decide and register the **real bundle ID** (FD-01 — replaces
      the placeholder `net.binjamshid.makhtoot` everywhere). This propagates to: app target,
      `MakhtootKit` config, IAP product IDs (`<bundleid>.premium.monthly` / `.annual` /
      `.lifetime`), CloudKit container (`iCloud.<bundleid>`), and the `.makhtoot` UTI.
      IRREVERSIBLE once a build with that bundle ID is uploaded to a live app record.
- [ ] 1.05 **[FOUNDER]** Create an **App Store Connect API key** (Users and Access →
      Integrations → App Store Connect API) with **App Manager** role, download the
      `.p8` once, and place it at an agreed local path outside the repo. Record Key ID +
      Issuer ID for the agent. This key is what lets the agent run `xcodebuild`
      uploads and ASC API calls without ever touching the founder's Apple ID password.
- [ ] 1.06 **[AGENT]** Verify the API key works: authenticated `GET /v1/apps` via the
      ASC API returns 200. Store the evidence log.

### 1B. Identifiers, capabilities, signing

- [ ] 1.07 **[AGENT]** Register the App ID (Certificates, Identifiers & Profiles →
      Identifiers) with the FD-01 bundle ID. Enable capabilities:
      - **iCloud** → CloudKit, container `iCloud.<bundleid>` (premium project sync per
        D-112/MKSync, and the public-database analytics upload per D-125).
      - **iCloud Key-Value Storage** (trial timestamp mirror per D-123).
      - Keychain access is default-entitled; **no** push notifications, **no** Sign in
        with Apple (no accounts in v1 — market study recommendation to keep Guideline
        4.8 entirely out of scope [MS ^56][MS ^57][MS ^58][MS ^59]), **no** Associated
        Domains (referral links ship inert per D-124 — do NOT register a universal-link
        domain in v1; adding one would create reviewable surface for a disabled feature).
      - Note: the "Fonts" capability (system-wide font installation) is NOT required —
        Makhtoot registers fonts per-process via `CTFontManagerRegisterFontURLs(.process)`
        (D-122, amended by D-219); the capability is only for installing fonts system-wide [MS ^61].
- [ ] 1.08 **[AGENT]** Create the CloudKit container in the developer portal and verify
      the production container exists in CloudKit Console; deploy the record type
      schema from development to **production** BEFORE submission — a build reviewed
      against a missing production schema fails silently. This covers the analytics
      record type schema (D-125) **and** the premium project-sync record types
      `Project` / `ProjectAsset` (D-112/MKSync) — both must be promoted, not analytics
      alone.
- [ ] 1.09 **[FOUNDER]** Signing strategy sign-off: recommended = **automatic signing
      with the ASC API key** (`xcodebuild -allowProvisioningUpdates
      -authenticationKeyPath ... -authenticationKeyID ... -authenticationKeyIssuerID ...`),
      which lets Xcode manage the Apple Distribution certificate and App Store
      provisioning profile without manual certificate handling. If the founder prefers
      manual signing, the founder personally creates/downloads the Apple Distribution
      certificate (private key custody is founder-only) and the agent references it.
- [ ] 1.10 **[AGENT]** Dry-run archive with distribution signing (no upload) to prove
      the signing chain end-to-end: `xcodebuild archive` succeeds with
      `CODE_SIGN_IDENTITY="Apple Distribution"` resolved. Log the resolved profile name.

---

## 2. App record creation

- [ ] 2.01 **[AGENT]** ASC → My Apps → "+" → New App. Fields:
      - **Platforms:** iOS (covers iPhone + iPad universal per D-100).
      - **Name:** `مخطوط` (Arabic; App Store name field, ≤30 chars — 5 chars, safe).
        See §10 for the full metadata package including subtitle.
      - **Primary language:** **Arabic** (`ar`). This is the storefront default
        language; Makhtoot is Arabic-only (BRIEF), so no other localization is added in
        v1. (Optional English (U.S.) metadata localization is a founder decision — see
        2.06 — but the app binary remains `ar`-only per D-100.)
      - **Bundle ID:** the FD-01 registered ID.
      - **SKU:** `makhtoot-ios-001` (internal, never public; any stable string).
      - **User Access:** Full Access (solo founder team).
- [ ] 2.02 **[AGENT]** App Information:
      - **Primary category: Graphics & Design.** Rationale: the product is a design
        composition tool; every serious competitor in the market study (Phonto, ArabiKhat,
        Ana Muhtarif Al Khat) lives in this space.
      - **Secondary category: Photo & Video** (image export/social-format presets) —
        editable founder preference; Productivity is the alternate.
      - **Content rights:** declare that the app does not contain, show, or access
        third-party content requiring rights Makhtoot lacks. TRUE for v1: all bundled
        fonts are OFL-verified with captured license files (D-120), ornaments/assets are
        license-clear originals (MKAssets), no preloaded Qur'anic or third-party content
        (BRIEF Q67–68). Font licenses displayed in-app at Settings → Support → Licensing.
- [ ] 2.03 **[AGENT]** **Age rating questionnaire** — answers for Makhtoot (a design
      tool with zero built-in content feeds; users type their own text locally):
      | Question | Answer |
      |---|---|
      | Cartoon/fantasy violence | None |
      | Realistic violence | None |
      | Prolonged graphic/sadistic violence | None |
      | Profanity or crude humor | None |
      | Mature/suggestive themes | None |
      | Horror/fear themes | None |
      | Medical/treatment information | None |
      | Alcohol, tobacco, drug use or references | None |
      | Simulated gambling | None |
      | Sexual content or nudity | None |
      | Graphic sexual content/nudity | None |
      | Contests | None |
      | Unrestricted web access | No (network use is only font downloads, CloudKit sync, opt-in analytics — no browser) |
      | Gambling with real money | No |
      | Loot boxes / random purchases | No |
      | Users can create content visible to others / user interaction | No (all creations are local/private; no sharing platform, no messaging) |
      Expected resulting rating: **4+**. The exact questionnaire wording changes
      periodically — re-read each question at submission time (VERIFY-AT-SUBMISSION
      V-01) and answer truthfully rather than pattern-matching this table.
- [ ] 2.04 **[AGENT]** App Privacy section — complete per §5 of this checklist.
- [ ] 2.05 **[FOUNDER]** Review and approve the completed app record (name rendering,
      category, rating) before any build is attached. Name conflicts: if `مخطوط` is
      taken as an App Store name, founder chooses the fallback form (e.g.,
      `مخطوط — تصميم عربي`); the agent must not improvise a public-facing name.
- [ ] 2.06 **[FOUNDER]** Decide whether to add an **English (U.S.) metadata-only
      localization** (description/keywords in English while the app stays Arabic).
      Recommendation: YES for discoverability and reviewer comprehension (reviewers are
      not guaranteed to read Arabic — see §12.3), but this is founder-owned copy scope.

---

## 3. In-App Purchases — subscriptions, lifetime, pricing, Family Sharing

### 3A. Subscription group and auto-renewable products

- [ ] 3.01 **[AGENT]** Create subscription group: **"Makhtoot Premium"** (reference
      name; per FOUNDATION §0). Add App Store localization for the group display name:
      Arabic — **«مخطوط بريميوم»**. The group display name is user-visible in
      subscription management UI; keep it stable.
- [ ] 3.02 **[AGENT]** Create auto-renewable subscription 1:
      - Reference name: `Makhtoot Premium Monthly`
      - Product ID: `<bundleid>.premium.monthly` (FD-01-derived; FOUNDATION §0)
      - Duration: 1 month · Group: Makhtoot Premium · **Level 1** (same level as
        annual — they are interchangeable tiers of the same access, not an upgrade path;
        both grant identical premium entitlement per D-113).
      - Price: select the **USD $2.99 base price point** (the closest tier to the locked
        "$3/mo"; Apple price points are fixed tiers) and accept **Apple's automatic
        price localization** for all other storefronts (BRIEF: "Apple storefront price
        localization everywhere"). No manual per-storefront overrides in v1.
      - Arabic localized display name: **«بريميوم — شهري»**, description:
        **«جميع ميزات مخطوط المدفوعة: خطوط إضافية، تصدير عالي الجودة PNG وSVG وPDF للطباعة، خلفيات صور، ومزامنة iCloud.»**
- [ ] 3.03 **[AGENT]** Create auto-renewable subscription 2:
      - Reference name: `Makhtoot Premium Annual`
      - Product ID: `<bundleid>.premium.annual`
      - Duration: 1 year · Group: Makhtoot Premium · Level 1
      - Price: **USD $29.99 base price point**, Apple auto-localization everywhere.
      - Arabic localized display name: **«بريميوم — سنوي»**, description:
        **«اشتراك سنوي بجميع ميزات مخطوط المدفوعة — يوفّر أكثر من ٪16 مقارنة بالاشتراك الشهري.»**
- [ ] 3.04 **[AGENT]** **Do NOT configure any Introductory Offer, promotional offer, or
      offer code for either subscription.** This is deliberate (D-123), not an
      oversight. Makhtoot's 7-day trial is **app-side**: it starts at first app launch
      for every user (BRIEF Q37), is persisted in Keychain
      (`kSecAttrAccessibleAfterFirstUnlock`, survives reinstall) mirrored to iCloud KVS
      with earliest-timestamp-wins and a clock-rollback guard, and simply unlocks
      premium features locally for 7 days — **no purchase, no payment sheet, no
      StoreKit transaction is involved in the trial**.
      **Explanation for reviewers/testers (include in Review Notes, §11.08):**
      An App Store Connect introductory free trial is a property of a *subscription
      purchase*: the user commits to the subscription, Apple manages eligibility
      (`isEligibleForIntroOffer`, one intro offer per subscription group per Apple ID),
      and billing starts when the trial lapses [MS ^43][MS ^44]. Makhtoot's trial
      instead requires **no commitment and no Apple ID interaction**: every new user
      gets 7 days of premium from first launch, then reverts to the genuinely useful
      free tier (full editing, free fonts, solid backgrounds, 2 MP JPEG/PDF export —
      BRIEF Q41). Running BOTH would create double-trial and eligibility-divergence
      states (an app-side-trial user later purchasing would get a second, Apple-managed
      free week; a resubscribing user would see "free trial" copy they're ineligible
      for), so v1 ships app-side only (D-123). Consequence for paywall copy: the CTA
      must state the real billing terms — payment starts immediately at purchase — and
      must never imply Apple will bill "after your free trial ends" (§4.03).
- [ ] 3.05 **[AGENT]** For each subscription, upload the **review screenshot** (the
      in-app paywall screen showing that product with price/term — capture from
      Simulator at required resolution) and fill the per-IAP **Review Notes** field
      referencing the master note (§11.08).

### 3B. Lifetime non-consumable

- [ ] 3.06 **[AGENT]** Create non-consumable IAP:
      - Reference name: `Makhtoot Premium Lifetime`
      - Product ID: `<bundleid>.premium.lifetime`
      - Price: **USD $89.99 base price point**, Apple auto-localization everywhere.
      - Arabic localized display name: **«بريميوم — مدى الحياة»**, description:
        **«دفعة واحدة تفتح جميع ميزات مخطوط المدفوعة بشكل دائم، مع كل التحديثات القادمة.»**
      - Compliance basis: Apple explicitly supports a one-time unlock alongside
        subscriptions; non-consumables must honor restore across the user's Apple
        Account, and a lifetime purchaser must never be asked to pay again
        [MS ^45][MS ^46][MS ^47]. D-113 enforces this: entitlement precedence is
        lifetime > subscribed > grace > billingRetry > trial > free.
- [ ] 3.07 **[AGENT]** Upload review screenshot + notes for the lifetime IAP (paywall
      screen showing the lifetime option).

### 3C. Family Sharing — FD-06 decision gate (IRREVERSIBLE)

- [x] 3.08 **[FOUNDER]** ⚠️ **IRREVERSIBLE DECISION — FD-06. RESOLVED 2026-07-19.**
      **Founder decision: Family Sharing = OFF for all three products.**
      - `net.binjamshid.makhtoot.premium.monthly` (auto-renewable) — Family Sharing: **OFF**
      - `net.binjamshid.makhtoot.premium.annual` (auto-renewable) — Family Sharing: **OFF**
      - `net.binjamshid.makhtoot.premium.lifetime` (non-consumable) — Family Sharing: **OFF**
      This setting is irreversible per product once configured in App Store Connect.
      OFF → ON remains available later as a marketable upgrade; ON → OFF requires
      product recreation under a new ID which strands existing purchasers [MS ^46][MS ^47].
      **Agent action (Run 3):** verify toggle state = OFF for each product in ASC
      and record screenshot evidence. Do NOT touch the toggle; only verify it.
- [ ] 3.09 **[AGENT]** After FD-06 is executed, verify all three products reach
      **"Ready to Submit"** status (requires: Paid Apps agreement signed (1.03),
      localization complete, price set, screenshot uploaded). IAPs must be attached to
      the app version submission the first time (§11.10).

### 3D. StoreKit configuration parity

- [ ] 3.10 **[AGENT]** The repo's `.storekit` configuration files have been updated
      (P15 FD-01 sweep, 2026-07-19) to mirror the real ASC product IDs
      (`net.binjamshid.makhtoot.premium.monthly/.annual/.lifetime`), prices, and group.
      Verify local StoreKit testing and sandbox testing exercise these identifiers.
      Run the TEST_MATRIX StoreKit sandbox suite (BRIEF gate Q59) against sandbox
      before submission: purchase monthly, upgrade-crossgrade annual, purchase lifetime,
      restore on wiped simulator, expiry lapse → free tier, grace-period banner.

---

## 4. StoreKit review compliance — paywall and subscription UX (Guideline 3.1.2)

Evidence base: market study §8 "Paywall / subscription-information compliance"
[MS ^50][MS ^51][MS ^52][MS ^45]. These are BUILD requirements — Run 2/3 must verify
the shipped binary satisfies each before upload; App Review checks the binary, not
just metadata.

- [ ] 4.01 **[AGENT]** **In-binary subscription disclosure:** the paywall displays, for
      each product, the subscription **title, length, and price** in the binary itself
      (not only ASC metadata) [MS ^45][MS ^50]. Prices must come from
      `Product.displayPrice` (storefront-localized), never hardcoded "$3".
- [ ] 4.02 **[AGENT]** **Price + term adjacent to the CTA:** the exact billed amount
      and renewal term sit directly beneath/beside each purchase button — e.g.
      **«٢٫٩٩ $ شهريًا — يتجدد تلقائيًا، الإلغاء في أي وقت من إعدادات Apple»**
      (localized price substituted at runtime). Reviewers reject flows where the price
      is buried, minimized, or shown only after commitment [MS ^50][MS ^51].
- [ ] 4.03 **[AGENT]** **Truthful trial copy (D-123 interaction):** because the 7-day
      trial is app-side and no ASC intro offer exists, purchase CTAs must NOT say
      "free trial then billing" — billing starts at purchase. Trial messaging lives
      outside the purchase buttons (e.g., banner: **«تجربتك المجانية: باقي ٥ أيام»**).
      Rejected pattern to avoid: making a paid app appear permanently free or blurring
      trial vs. purchase [MS ^51].
- [ ] 4.04 **[AGENT]** **Visible dismiss control:** the paywall has an unambiguous,
      immediately visible close button (✕) at standard placement. Hidden/delayed/
      low-contrast dismiss controls are a documented rejection trigger [MS ^50][MS ^51].
- [ ] 4.05 **[AGENT]** **No pre-content hard paywall:** the first-run flow lands the
      user in the project browser/editor where they can create and export a design with
      free-tier tools before any paywall appears; paywalls appear only on premium-
      feature touchpoints or explicit "Premium" entry. Reviewers specifically reject
      paywalls shown before any app content [MS ^50][MS ^51]. (Makhtoot's app-side
      trial makes day-0 experience fully premium anyway — the paywall is inherently
      non-blocking at first run.)
- [ ] 4.06 **[AGENT]** **No dark patterns:** no countdown timers, fake urgency,
      pre-selected most-expensive plan with obscured alternatives, or misleading
      "free" labels [MS ^51].
- [ ] 4.07 **[AGENT]** **Restore Purchases is mandatory UI** (Guideline 3.1.2(c)
      requirement per market study [MS ^45][MS ^47]; D-113): a clearly labeled
      **«استعادة المشتريات»** button on the paywall AND in Settings, calling
      `AppStore.sync()` / transaction refresh, with success/failure feedback.
- [ ] 4.08 **[AGENT]** **Functional Privacy Policy + Terms links in-app:** paywall and
      Settings both link to the hosted privacy policy and Terms of Use/EULA; links must
      resolve (no 404, no placeholder) at review time [MS ^45][MS ^50]. Same URLs go
      into ASC metadata (§10.07, §5.08). If using Apple's standard EULA, the Terms link
      may target Apple's standard EULA URL — founder choice in 5.10.
- [ ] 4.09 **[AGENT]** **Subscription-management deep link:** Settings → «إدارة
      الاشتراك» opens the system subscription management surface — prefer
      `showManageSubscriptions(in:)` (StoreKit 2 sheet), fallback URL
      `https://apps.apple.com/account/subscriptions`. Also shown from the
      grace-period/billing-retry banner (D-113: grace and billing-retry retain premium
      + banner deep-linking to payment management [MS ^43]).
- [ ] 4.10 **[AGENT]** **Expiry/cancellation messaging:** on lapse, the app shows the
      free-tier transition state (fonts lock, export matrix reverts — D-119/BRIEF Q27)
      with re-subscribe and restore paths; no data is destroyed. Verify strings exist
      for every D-113 entitlement state: `lifetime`, `subscribed`, `inGracePeriod`,
      `inBillingRetry`, `trial`, `free`.
- [ ] 4.11 **[AGENT]** Do not hardcode grace-period duration in any user-facing copy —
      the commonly cited "up to 16 days" is third-party guidance and must be re-verified
      before appearing in UX text [MS ^43] (BRIEF "known research gaps";
      VERIFY-AT-SUBMISSION V-02). Copy should say «فترة سماح» without a day count.

---

## 5. Privacy — nutrition label, policy, ATT, account deletion

### 5A. App Privacy "nutrition label" — line-by-line answers

Makhtoot's ACTUAL data flows (FOUNDATION D-125, BRIEF "Accounts, data, privacy"):
(1) opt-in, anonymous, aggregated font-usage counters uploaded in batches to the
CloudKit **public** database — random ephemeral batch UUID, no user record link,
week-granularity only, bucketed counts; (2) premium users' project files synced to the
**user's own private iCloud** (CloudKit private DB) — the developer has no access;
(3) premium font downloads over HTTPS (no identifiers sent); (4) no ads, no third-party
SDKs, no accounts, no tracking. Market study §9 confirms this minimal-collection,
no-account posture is the compliance-simplest architecture [MS ^56][MS ^57].

- [ ] 5.01 **[AGENT]** Answer "Do you or your third-party partners collect data from
      this app?" → **Yes** (solely because of the opt-in analytics upload; "collected"
      means transmitted off-device in a way accessible to the developer — the CloudKit
      public DB batches are readable by the developer, so they count).
- [ ] 5.02 **[AGENT]** Declare exactly ONE data type: **Usage Data → Product
      Interaction** (font-usage counters = interaction with app features).
      - Used for: **Analytics** only.
      - **Linked to the user's identity? NO.** Justification: batches carry a random
        ephemeral UUID, no user/device identifier, no CloudKit user-record link, counts
        bucketed, timestamps coarsened to week (D-125). Nothing can be joined back to
        an identity by the developer.
      - **Used for tracking? NO.** (No linking with third-party data, no data brokers,
        no cross-app/site tracking — see 5.05.)
      - Collection is **optional/opt-in** (default OFF, explicit Settings switch with
        versioned consent record — D-125); state this in the ASC "optional disclosure"
        affordances where the questionnaire allows and in the privacy policy.
- [ ] 5.03 **[AGENT]** Every other category — **Not collected.** Explicit justifications
      the agent records for the submission dossier:
      | Category | Answer | Why |
      |---|---|---|
      | Contact info (name, email, phone…) | Not collected | No accounts, no forms (BRIEF: no mandatory account; SIWA not used in v1) |
      | Health & fitness | Not collected | N/A |
      | Financial info | Not collected | Payments are Apple IAP; the app never sees payment data |
      | Location | Not collected | No location APIs used |
      | Sensitive info | Not collected | N/A |
      | Contacts / User content (messages, photos…) | Not collected | Projects, imported images/fonts, and text stay on-device or in the user's own private iCloud; the developer never receives them (D-125: "Never upload text, projects, identifiers, font files, user content") |
      | Browsing / Search history | Not collected | In-app font-catalog search is local only |
      | Identifiers (user ID, device ID) | Not collected | Analytics batches are explicitly identifier-free (D-125) |
      | Purchases | Not collected | Entitlement resolution is on-device StoreKit 2 (D-113); no purchase data leaves via developer channels |
      | Diagnostics (crash, performance) | Not collected | No crash SDK in v1 (no third-party dependencies, D-101); Apple's own opt-in crash reporting is Apple-collected, not developer-declared |
      | Other data | Not collected | — |
      Nuance to re-confirm on the live questionnaire: Apple's definitions page for
      "collect" and the private-CloudKit carve-out language change over time; re-read
      the current definitions before answering (VERIFY-AT-SUBMISSION V-03). The
      **substance** (what Makhtoot actually transmits) is fixed by D-125 and does not
      change with the form wording.
- [ ] 5.04 **[FOUNDER]** Approve the completed nutrition label before publish — the
      label is a public legal representation by the developer entity.

### 5B. Tracking & ATT

- [ ] 5.05 **[AGENT]** **No AppTrackingTransparency prompt, no
      `NSUserTrackingUsageDescription`.** Justification: "tracking" means linking
      user/device data with third-party data for advertising or sharing with data
      brokers, or cross-app/website tracking. Makhtoot has no ads, no third-party SDKs,
      no data leaves the Apple first-party stack, and the only collected datum is
      anonymous and aggregated — the market study explicitly notes first-party,
      non-tracking aggregate analytics avoids ATT/tracking-consent UX entirely
      [MS ^56][MS ^57] (market study §9). Verify the binary contains no ATT symbols.

### 5C. Privacy policy (required metadata URL)

- [ ] 5.06 **[AGENT]** Draft the privacy policy in **Arabic (authoritative) + English
      (courtesy)** from this outline; founder approves and hosts (5.08):
      1. **من نحن** (Who we are) — developer entity, contact email.
      2. **مبدأنا: تطبيق يعمل دون حساب ودون تتبّع** — Makhtoot requires no account,
         collects nothing by default, works fully offline.
      3. **ما لا نجمعه أبدًا** — texts, designs/projects, imported fonts or images,
         names, emails, identifiers, location, payment data (payments handled by Apple).
      4. **الإحصاءات الاختيارية** (Opt-in analytics) — if and only if the user enables
         the switch in الإعدادات, the app uploads anonymous, aggregated font-usage
         counts (which fonts are used, bucketed counts, week granularity), with a
         random one-time batch ID and no link to the user; purpose: deciding which
         fonts to add; the switch can be turned off anytime; consent is versioned.
      5. **مزامنة iCloud** — for premium users, projects sync to the user's OWN iCloud
         (Apple's CloudKit); the developer cannot read this data; Apple's iCloud terms
         apply; sync is optional.
      6. **تنزيل الخطوط** — premium font downloads are plain HTTPS file fetches; no
         identifiers are attached.
      7. **المشتريات** — processed entirely by Apple (App Store/StoreKit); see Apple's
         privacy policy for payment data.
      8. **حقوقك والتواصل** — how to ask questions/complaints; data deletion request
         handling (trivially satisfiable: there is no user-linked data to delete;
         local data is deleted by deleting the app; analytics batches are anonymous
         and unlinkable by design).
      9. **التغييرات على هذه السياسة** — versioning and effective date.
      10. English mirror of 1–9.
- [ ] 5.07 **[FOUNDER]** Legal review/approval of the policy text (it is a legal
      document of the founder's entity; the agent drafts, the founder owns).
- [ ] 5.08 **[FOUNDER]** Host the policy at a stable HTTPS URL the founder controls
      (any static hosting; can share the FD-04 font-hosting decision infrastructure).
      Provide the URL to the agent for ASC metadata and the in-app links (4.08).
- [ ] 5.09 **[AGENT]** Enter the privacy policy URL in ASC (App Privacy → Privacy
      Policy URL) and verify it resolves publicly (not behind auth) from a clean
      network.
- [ ] 5.10 **[FOUNDER]** Choose Terms of Use: Apple's standard EULA (zero drafting; the
      default when no custom EULA is provided) vs. custom EULA (needed only if the
      founder wants font-license-specific use terms surfaced contractually).
      Recommendation: **standard Apple EULA for v1**; font license terms are already
      surfaced informationally at Settings → Support → Licensing (BRIEF Q66).

### 5D. Account deletion rule — N/A justification

- [ ] 5.11 **[AGENT]** Record the account-deletion analysis for the submission dossier:
      Apple's account-deletion requirement applies to apps that **support account
      creation**. Makhtoot has **no accounts of any kind**: no sign-up, no login, no
      SIWA (deferred to a hypothetical future backend — BRIEF Q77), no third-party
      auth; premium sync rides the user's existing iCloud session implicitly
      [MS ^56][MS ^57] (market study §9's recommended no-account architecture,
      adopted). Therefore the deletion requirement is **not applicable**. The exact
      current guideline clause number for account deletion must be quoted from the
      live guidelines if a reviewer raises it (VERIFY-AT-SUBMISSION V-04) — respond
      with the substance: "the app has no account system; all data is on-device or in
      the user's own iCloud; deleting the app deletes the data."

---

## 6. Downloadable premium fonts — compliance and reviewer access

Basis: FOUNDATION D-121 (premium catalog = static JSON manifest + font files over
HTTPS after entitlement confirmation; fallback = bundle in-app) and D-122
(per-process registration).

- [ ] 6.01 **[AGENT]** Compliance position (state in Review Notes, §11.08): downloaded
      premium fonts are **data resources, not executable code** — static `.ttf`/`.otf`
      /`.ttc` files rendered through Apple's own Core Text; nothing downloaded is
      executed, interpreted, or changes app behavior/features beyond making additional
      typefaces available to the SAME already-reviewed features. Download happens only
      **after StoreKit 2 entitlement confirmation** (D-119/D-121) — it is content
      delivery for a purchased IAP, not feature unlocking outside IAP. The guideline
      governing downloadable executable code (historically 2.5.2) should be re-read at
      submission to confirm current wording (VERIFY-AT-SUBMISSION V-05); the design
      position (data-not-code) is architecture-fixed and compliant under any reading
      the market study surfaced.
- [ ] 6.02 **[FOUNDER]** Execute **FD-04**: choose premium-font hosting (any static
      HTTPS origin the founder controls) OR elect the documented fallback — **bundle
      premium fonts inside the app behind the entitlement gate** (D-121 explicitly
      pre-authorizes this fallback if hosting is not ready at submission). Decision
      needed before the Run-3 build freeze.
- [ ] 6.03 **[AGENT]** If hosted: verify from a clean network that the manifest and
      every font file download over valid TLS with correct checksums; the catalog
      must degrade gracefully (cached catalog + clear offline error) when unreachable
      — App Review may test in poor connectivity. If ANY premium font's license cannot
      be verified for redistribution by freeze, it ships nowhere (D-120: v1 = OFL-
      verified only; never invent licenses — BRIEF).
- [ ] 6.04 **[AGENT]** Reviewer-access plan — **Review Notes text** (drafted here,
      finalized in 11.08):
      > "Premium features (font catalog downloads, PNG/SVG/print-PDF export, photo
      > backgrounds, iCloud sync) unlock via the included auto-renewable subscriptions
      > or the lifetime purchase. **In the review environment, purchases run against
      > the App Store sandbox automatically — no credentials from us are required:**
      > tap Settings → «بريميوم» or any premium feature → the paywall → purchase any
      > product with your sandbox Apple Account; the sandbox purchase completes without
      > real charge and premium unlocks immediately, including the font-catalog
      > downloads. Additionally, every fresh install receives an automatic 7-day
      > premium trial starting at first launch (no purchase needed), so all premium
      > functionality is also directly accessible on first run. Restore Purchases is
      > at the bottom of the paywall and in Settings."
- [ ] 6.05 **[AGENT]** Sandbox verification pass mirroring the reviewer path: fresh
      install → trial active → premium catalog downloads work; simulate trial expiry
      (debug clock override removed from release builds — verify no test hooks ship)
      → sandbox purchase → downloads work; restore on second device/simulator.
- [ ] 6.06 **[AGENT]** Verify expiry lock behavior matches D-119/BRIEF Q27 (premium +
      imported fonts lock, projects stay viewable/editable, export reverts to free
      matrix) — a reviewer probing lapsed states must never find destroyed user data.

---

## 7. Referral program — risk memo and ACTIVATION protocol (D-124, D-225, **D-327**)

> ⚠️ **STATUS CHANGED 2026-08-07 by D-327.** This section previously documented a
> dormancy protocol. FD-05 was granted for iOS and referral now **ships, present and
> user-reachable, in the Release build**. Every instruction below that told you to
> conceal, disable, or verify the absence of referral has been inverted. If you are
> working from a cached copy of this section, re-read it.

**Status shipped: ACTIVE on iOS. Architected, compiled, flag-ON, user-reachable.**
`MAKHTOOT_REFERRAL_ENABLED` is defined in the app target's Debug *and Release*
configurations and unconditionally on the `MKStore`/`MKStoreTests` package targets;
`MKFeatureFlags.referralProgram` defaults `true`; `ReferralSection` is reachable from
the Settings root. There is still **no server dependency** — attribution remains the
honor-code exchange of D-212, whose weaknesses the founder re-accepted in writing in
D-327. **Android remains dormant** under D-321, unchanged.

⚠️ **OUTSTANDING FOUNDER TASK — see 7.06.** D-327 granted the founder-sign-off half of
FD-05. It did **not** discharge the other half: the fresh recheck of current App Review
Guidelines text. That recheck is unperformed and is a blocking pre-submission gate.

### 7A. Risk memo (the evidence)

- [ ] 7.01 **[AGENT]** Record in the submission dossier (and keep current): Apple's
      review team has rejected referral mechanics with this documented reasoning,
      quoted in the market study: rewarding the **invitation sender** with digital
      content is acceptable, but **the person receiving the invitation must not
      receive rewards for downloading or registering**, because incentivized
      downloads distort reviews/chart ranking [MS ^53]. The same precedent thread
      shows that even conditioning the invitee's reward on *subscribing* was still
      treated as non-compliant incentivization [MS ^53]. A second thread ties referral
      promo distribution to Guideline 3.1.1 circumvention concerns (off-platform codes
      bypassing Apple's commission; gifting IAP entitlements separately restricted)
      [MS ^54]. Crucially, the market study notes there is **no single explicit
      "referrals banned" clause** in the public guidelines — the restriction is
      **inferred from 3.1.1/3.2.2 enforcement precedent**, so any future activation
      must re-validate against the then-current guideline text [MS ^55][MS ^53][MS ^54]
      (market study §8, referral risk assessment).
- [ ] 7.02 **[AGENT]** Confirm the compliant design constraints are what's architected
      (they are, per D-124, aligned with the market study's compliant variant
      [MS ^45][MS ^53]): reward goes to the **referrer only** (+7 trial days per
      qualifying event, capped at 4 extensions), never to the invitee; qualifying
      event is a genuine action, not mere install/registration; no core functionality
      is ever gated on referrals; removal = delete folder + flag.
- [ ] 7.02b **[AGENT]** Guideline 2.3.1 (accurate metadata / no hidden or dormant
      features) analysis — **REWRITTEN by D-327; the D-225 text it replaces is in git
      history.** D-225 closed the 2.3.1 exposure by *absence*: nothing referral-related
      shipped, so there was nothing to disclose. D-327 closes it by *completeness and
      disclosure* instead, which is the only other defensible position:
      - The feature is **present, complete and user-reachable** — `ReferralSection` is
        a live row in the Settings root, not dead code. There is no hidden or dormant
        functionality in the binary, because the functionality that is in the binary is
        exactly the functionality a reviewer can reach and exercise.
      - The half-shipped state — engine compiled in, UI excluded — would be a genuine
        2.3.1 violation and is **mechanically prevented**:
        `Scripts/referral-release-grep.sh` was inverted by D-327 to fail the build if
        referral engine symbols are present without referral UI strings.
      - D-225's **string-catalog isolation rule is retained**, not dropped: referral
        vocabulary (الدعوات / رمز الدعوة / تفعيل الرمز) lives in in-file literals under
        the same `#if`, never in `Localizable.xcstrings`. Verified 2026-08-07: the
        catalog contains zero referral strings.
      - Disclosure obligation is now **live** — see 7.03, which D-327 inverted from
        "do not mention referrals anywhere" to "you must describe the mechanic in
        Review Notes."

### 7B. What to disclose / not disclose at submission

- [ ] 7.03 **[AGENT]** ⚠️ **INVERTED by D-327 — the previous instruction was the exact
      opposite and is void.** You **must now disclose the referral mechanic in Review
      Notes**, honestly and in full, because it ships and is reachable. Concealing a
      live feature is the actual 2.3.1/2.3.7 violation. The Review Notes must state:
      the reward is **referrer-only** (+7 trial days, capped at 4 grants = 28 days
      maximum); **the invitee receives nothing** — this is the specific compliant
      variant the precedent in 7.01 requires; the reward is **trial days only, never
      money, never IAP content, never a discount on the subscription price**, so it
      does not touch Guideline 3.1.1's commission-circumvention concern; and no core
      functionality is gated on referrals. Do **not** mention referrals in App Store
      metadata, screenshots, or the promotional text — disclosure belongs in Review
      Notes, and marketing an incentive is a separate 3.1.1 risk. The privacy label is
      unchanged: the module is fully on-device and collects nothing.
- [ ] 7.04 **[AGENT]** ⚠️ **INVERTED by D-327.** Verify **presence and completeness**
      before upload, not inertness: run `Scripts/referral-release-grep.sh <built .app>`
      against the **Release** product and confirm exit 0 (it now fails on absence, and
      fails specifically on the engine-without-UI half-shipped case). Confirm
      `MKFeatureFlags.referralProgram` is `true`. Confirm the Settings → الدعوات row is
      reachable on device and the redeem flow returns a real result. Still confirm **no
      referral deep-link/universal-link route is registered** (see 1.07 — no Associated
      Domains; D-124's inert-links rule survives activation, since attribution is
      manual code entry, not links).
- [ ] 7.05 **[AGENT]** If a reviewer asks about the referral mechanic: answer plainly
      — "referral is a live, reachable feature in this build; it grants the referrer 7
      additional days of the app's own free trial per redeemed code, capped at 4; the
      invitee receives no reward of any kind; attribution is manual code entry with no
      server and no tracking." Do **not** use the old 'disabled scaffold' response ,
      it is now false and would be a misrepresentation to Apple.
- [ ] 7.05b **[AGENT/FOUNDER]** Know the accepted downside before you submit: D-327
      records that the D-212 attribution weaknesses are now **shipping** — one person
      with two devices can self-refer, and codes can be traded publicly. Both are
      bounded at 28 trial days and are non-monetary. If a reviewer raises abuse
      potential, this bound is the answer; do not claim the mechanism is verified,
      because it is not.

### 7C. Activation protocol — **HALF-DISCHARGED, still a hard gate**

FD-05 has two halves. D-327 discharged one. The other is **open and blocking**.

- [x] 7.06a **[FOUNDER]** ✅ **DISCHARGED 2026-08-07 (D-327).** Explicit founder
      sign-off to activate, including the written re-acceptance of the D-212
      attribution weaknesses that D-212 required as a precondition of any activation.
- [ ] 7.06b **[FOUNDER]** ⛔ **NOT DISCHARGED — BLOCKS APP STORE SUBMISSION.** A fresh
      recheck of the **then-current** App Review Guidelines text for 3.1.1 / 3.2.2 and
      any newer referral-specific clause (VERIFY-AT-SUBMISSION V-06). This has **not**
      been performed. It cannot be performed from documentation written in 2026-07 or
      from any model's training data — the market study itself notes there is no
      explicit "referrals banned" clause and the restriction is *inferred from
      enforcement precedent* [MS ^55][MS ^53][MS ^54], which is exactly the kind of
      thing that moves without the published text changing. **Read the live guidelines
      before submitting to App Review.**
      - **TestFlight vs App Store**: internal TestFlight testing does not go through
        App Review, so this gate does not block internal builds. **External** TestFlight
        testing *does* require Beta App Review — treat it as blocked by 7.06b too.
- [ ] 7.06c **[AGENT]** The activation submission must: confirm the flag is enabled in
      the reviewed build (7.04), add the honest Review Notes of 7.03, and re-run this
      §7 memo against the precedents [MS ^53][MS ^54].
- [ ] 7.06d **[FOUNDER]** Deactivation path, if review pushes back — two levers, in
      increasing order of cost: (1) set `MKFeatureFlags.referralProgram = false` to hide
      the UI (rebuild, but no architectural change); (2) remove the two
      `MAKHTOOT_REFERRAL_ENABLED` definitions to strip the feature from the binary
      entirely, restoring D-225 exactly — at which point
      `Scripts/referral-release-grep.sh` must be reverted to its pre-D-327 polarity in
      the same commit, or CI will fail on the now-correct absence.

No A/B, no partial rollout, and no server-side toggle exists that could flip any of
this (D-124: local flag, server-independent — a remote activation would itself be a
guideline-2.3.1-style misrepresentation risk and is architecturally impossible here by
design).

---

## 8. Territories and distribution scope

Locked intent (BRIEF Q46): distribute in **all territories that require no extra legal
documentation or local registration** by the founder.

### 8A. Decision procedure (run at submission time)

- [ ] 8.01 **[AGENT]** Start from ASC → Pricing and Availability → **select all
      territories**, then subtract using the flag list below.
- [ ] 8.02 **[AGENT]** For each territory in the flag list, check the authoritative
      source **inside ASC** (Pricing and Availability warnings, App Information →
      required disclosures, and any banner ASC raises on the territory) — ASC surfaces
      territory-specific requirements at configuration time; treat every ASC-raised
      requirement as "extra legal documentation" and EXCLUDE the territory unless the
      founder explicitly opts to satisfy it.
- [ ] 8.03 **[FOUNDER]** Approve the final territory list (it is a legal/commercial
      election by the seller entity).

### 8B. Known-flag list (each item VERIFY-AT-SUBMISSION in ASC — V-07)

- [ ] 8.04 **[FOUNDER]** **EU — trader status (DSA):** apps distributed in EU
      storefronts require the developer to declare trader/non-trader status and, if a
      trader, publish address/contact details on the product page. Makhtoot sells
      digital goods → almost certainly a **trader**. This is a legal self-declaration
      only the founder can make, entered in ASC (Business/App Information → Digital
      Services Act compliance section — locate the current form in ASC at submission,
      V-07a). If the founder declines trader disclosure, EU territories must be
      deselected — founder call.
- [ ] 8.05 **[AGENT]** **China mainland:** paid apps/IAP and hosted-content rules
      periodically require local licensing (e.g., ICP filing for network-served
      content — Makhtoot serves font downloads). Default: **EXCLUDE China mainland**
      unless ASC shows no additional requirement for this app profile (V-07b) — the
      font-download endpoint (FD-04 hosting) would also need to be reachable there.
- [ ] 8.06 **[AGENT]** **South Korea / Japan / Brazil and tax-registration flags:**
      Apple generally acts as merchant/collects VAT-JCT-style taxes via the Paid Apps
      agreement with no developer registration; if ASC raises ANY territory-specific
      tax-ID or registration prompt for the founder's entity, flag to founder and
      exclude pending decision (V-07c). Never assert a per-country tax fact from
      memory.
- [ ] 8.07 **[AGENT]** **Trade-sanctioned storefronts** are excluded by Apple
      automatically; no action, but do not attempt manual inclusion.
- [ ] 8.08 **[AGENT]** Record the final list + rationale per exclusion in the
      submission dossier; verify Oman (OM) is INCLUDED and — per market study §8 —
      check the OMR-localized price rendering on the Oman storefront at submission
      (V-08; also §13.02).

---

## 9. Export compliance (encryption)

Makhtoot's cryptography usage, exhaustively: TLS/HTTPS for font downloads (D-121),
Apple CloudKit transport/at-rest encryption (D-112/D-125), Keychain storage of the
trial record (D-123), StoreKit 2 JWS signature verification (D-113). No proprietary or
custom cryptography; no non-Apple crypto libraries (D-101: zero third-party
dependencies).

- [ ] 9.01 **[AGENT]** Answer the ASC export-compliance questionnaire:
      - "Does your app use encryption?" → **Yes** (it uses HTTPS/ATS and Apple OS
        crypto).
      - "Does your app qualify for any of the exemptions provided in Category 5,
        Part 2 of the U.S. Export Administration Regulations?" → **Yes** — the app
        only uses encryption (a) available in and provided by iOS ("made available by
        Apple") and (b) limited to standard HTTPS/TLS calls. No proprietary
        encryption is implemented.
      Exact current question wording/branching changes; answer the live form to the
      substance above (VERIFY-AT-SUBMISSION V-09).
- [ ] 9.02 **[AGENT]** Set `ITSAppUsesNonExemptEncryption = NO` in the app's
      Info.plist so every TestFlight/App Store build skips the per-build compliance
      prompt.
- [ ] 9.03 **[FOUNDER]** Note-and-decide: whether the founder's entity files any annual
      self-classification report for exempt encryption with U.S. authorities is a
      legal-counsel question outside Apple's flow — flag only, no assertion
      (VERIFY-AT-SUBMISSION V-10). France's former extra declaration for encryption
      apps: check whether ASC still asks a France-specific question at submission
      (V-10).

---

## 10. Metadata package — Arabic App Store copy (DRAFTS for founder approval)

All copy below is a **draft**: the agent enters it; the founder approves final wording
(2.05/10.09). Written for the target audience — Arabic designers, calligraphy lovers,
social-media creators, small businesses.

- [ ] 10.01 **[AGENT]** **App name** (≤30 chars): `مخطوط`
      Fallback if unavailable (founder picks, 2.05): `مخطوط — تصميم عربي` or
      `مخطوط: فن الحرف العربي`.
- [ ] 10.02 **[AGENT]** **Subtitle** (≤30 chars, appears under the name):
      `صمّم بالعربية، وتحكّم بكل حرف`
      (Alternates: `استوديو التصميم العربي` · `فن الخط بين يديك`)
- [ ] 10.03 **[AGENT]** **Promotional text** (≤170 chars, updatable without review):
      `جرّب مخطوط الآن: سبعة أيام كاملة من الميزات المدفوعة مجانًا — خطوط عربية أصيلة، تحكّم حرفًا بحرف، وتصدير عالي الجودة.`
- [ ] 10.04 **[AGENT]** **Description** (draft, corrected 2026-07-29 — see note below):

      ```
      مخطوط — استوديو التصميم العربي الذي يفهم الحرف

      صُمّم «مخطوط» من الألف إلى الياء للغة العربية: كتابة سليمة التشكيل
      والاتصال، وتحكّم لم تعرفه من قبل بكل حرف وتشكيلة وحرفٍ مركّب.

      اكتب كما تكتب في أي تطبيق — ثم ادخل «وضع التنسيق» وحرّك كل حرف
      على حدة: موضعه، دورانه، حجمه، لونه، ظله، وحدوده. حرّك الفتحة
      والضمة والشدة بشكل مستقل، فكّك «لا» إلى حرفيها أو أعدها كما كانت،
      واختر شكل الحرف: منفصل، أوّلي، وسطي، أو نهائي.

      أهم الميزات:
      • كتابة عربية سليمة: تشكيل كامل، أحرف متصلة، لغتان في سطر واحد،
        وأرقام عربية ومشرقية
      • وضع التنسيق: تحرير كل حرف وعلامة تشكيل ككائن مستقل — ميزة لا
        تجدها في تطبيقات التصميم العامة
      • الكتابة على المسارات: نصوص منحنية ودائرية وحرة قابلة للتعديل
      • لوحة كاملة: طبقات، محاذاة ذكية، تجميع، قفل وإخفاء، وسجل تراجع
        واسع لكل خطوة
      • خطوط عربية أصيلة: نسخ، رقعة، كوفي، وخطوط عصرية وثنائية اللغة —
        واستيراد خطوطك الخاصة (بريميوم)
      • أشكال وزخارف وإطارات وعناصر خطية جاهزة للإدراج
      • صورة خلفية من مكتبة الصور أو الملفات (بريميوم)
      • يعمل دون إنترنت بالكامل، ودون أي حساب أو تسجيل

      التصدير:
      • مجانًا: JPEG وPDF حتى ٢ ميغابكسل
      • بريميوم: PNG شفاف، SVG قابل للتحرير، وPDF للطباعة عالية الجودة
        بدقة عالية وألوان CMYK

      الاشتراك والتجربة:
      عند أول تشغيل تحصل تلقائيًا على سبعة أيام كاملة من جميع الميزات
      المدفوعة — دون دفع ودون إدخال أي بيانات. بعدها يبقى التطبيق مفيدًا
      مجانًا: التحرير الكامل، الخطوط المجانية، والتصدير الأساسي. ولمن
      يريد المزيد: اشتراك شهري أو سنوي، أو شراء دائم لمرة واحدة.

      خصوصيتك أولًا:
      لا حسابات، لا إعلانات، لا تتبّع. تصاميمك تبقى على جهازك — أو في
      حسابك أنت على iCloud إن اخترت المزامنة.

      مخطوط: حيث يصبح الحرف العربي تصميمًا.
      ```
      **FD-03 RESOLVED 2026-07-19 (founder):** Apple Generic CMYK elected for v1
      (licensed profile = v1.1 seam via `ICCProfileStore`) — see DECISIONS_LOG.md
      FD-03. Per D-117's conservative-claims obligation, this copy must not
      overstate fidelity given the Generic-profile + whole-page-raster-embed
      characteristics (WS-08 P10-COMPLETION: Apple Generic CMYK has zero
      rendering-intent differentiation; v1 CMYK PDFs are raster, not vector, at
      print resolution). "ألوان CMYK للطباعة" is acceptable as written; "احترافية"
      is too strong a fidelity claim and has been softened to "عالية الجودة" in the
      draft copy above. V-13 below is resolved on this basis — no further
      re-verification against an FD-03 outcome is needed pre-submission.

      **2026-07-29 correction — fact-checked against the shipped codebase, three
      claims in the original draft did not hold up and were fixed (false App Store
      copy is a rejection/complaint risk, not just a wording nitpick):**
      1. "استيراد الصور وSVG وPDF" (import images/SVG/PDF) — SVG and PDF import do
         not exist anywhere in the app (only SVG/PDF *export*). Image import is
         real but is background-image-only (`BackgroundImageSheet.swift`) and
         entirely premium-gated (`.photoBackgrounds`), not the free general-purpose
         feature the line implied. Replaced with an accurate, correctly-scoped
         bullet: "صورة خلفية من مكتبة الصور أو الملفات (بريميوم)".
      2. "نسخ، رقعة، ثلث، ديواني، كوفي، مغربي وغيرها" (Naskh/Ruqaa/Thuluth/Diwani/
         Kufi/Maghribi) — the bundled catalog (`catalog-seed.json`) only actually
         contains naskh (8), ruqah (2), and kufi (6) fonts; zero fonts exist in
         thuluth, diwani, or maghrebi categories (the one "premium catalog" entry
         is an unshipped test fixture pointing at an `.invalid` placeholder domain).
         Corrected to name only the three real styles plus the real modern/
         bilingual categories, without naming unavailable ones.
      3. "تراجع غير محدود" (unlimited undo) — `MKUndoStack` has a hard 500-entry
         default cap (`maxEntries`) that actively **shrinks** under memory
         pressure (`evictOffscreen()` halves it; `evictAll()` can wipe it
         entirely, D-116/D-223). Corrected to "سجل تراجع واسع لكل خطوة" (a deep
         multi-step undo history) — true regardless of memory state.
- [ ] 10.05 **[AGENT]** **Keywords** (≤100 chars incl. commas; no spaces after commas;
      do not repeat words from name/subtitle):
      `خط,خطوط,تصميم,مصمم,كاليغرافي,نسخ,رقعة,ثلث,ديواني,كوفي,تشكيل,زخرفة,ملصق,بوستر,شعار`
      (Agent verifies the exact character count ≤100 at entry time; trim from the tail.)
- [ ] 10.06 **[AGENT]** **What's New** (v1.0): `الإصدار الأول من مخطوط — أهلًا بكم.`
- [ ] 10.07 **[AGENT]** **Support URL** + **Privacy Policy URL** (from 5.08); Marketing
      URL optional (founder-owned site if any). Copyright: `© 2026 <founder entity>`.
- [ ] 10.08 **[AGENT]** **Screenshot shot-list** — capture from Simulator/device with
      real Arabic compositions (no lorem, no English UI leaks). Required device
      classes: current-generation 6.9"-class iPhone and 13"-class iPad sets (ASC
      auto-scales the rest; exact required pixel sizes per current ASC spec —
      VERIFY-AT-SUBMISSION V-11). Order tells the story:
      1. **Hero:** finished poster-grade Arabic composition (e.g., a Thuluth-style
         phrase with ornaments) + one-line overlay «صمّم بالعربية كما لم تفعل من قبل».
      2. **Arrange Mode:** a word mid-edit, one glyph selected and rotated, handles
         visible — the differentiator shot; overlay «تحكّم بكل حرف».
      3. **Tashkeel control:** marks selected/moved independently; overlay
         «حتى التشكيل… ككائن مستقل».
      4. **Ligature decomposition:** لا split view before/after; overlay «فكّك وركّب».
      5. **Path text:** circular composition; overlay «اكتب على أي مسار».
      6. **Fonts catalog:** the Arabic category chips (نسخ، رقعة، ثلث…); overlay
         «خطوط أصيلة مرخّصة».
      7. **Layers + inspector on iPad** (iPad set): full workspace showing pro depth.
      8. **Export sheet:** premium formats visible; overlay «صدّر للطباعة والنشر».
      **RTL composition notes:** device frames and captions read right→left — place
      caption text right-aligned; sequence panels R→L when composing multi-panel
      shots; UI screenshots must show the true RTL layout (leading = right); numerals
      in captions in Arabic-Indic form (٧ أيام); ensure no LTR-flipped chrome (page
      dots, back chevrons) sneaks in from a non-`ar` Simulator — set Simulator
      language/region to `ar` before capture.
- [ ] 10.09 **[FOUNDER]** Final visual + copy approval of the entire metadata package
      (BRIEF Q84: founder retains final visual approval).
- [ ] 10.10 **[AGENT]** **App preview video: SKIP in v1** (optional-v2). Rationale:
      previews require poster-frame + per-device capture pipelines; static shots
      carry the differentiator adequately; revisit for v1.1 marketing. Record as a
      deliberate deferral, not an omission.
- [ ] 10.11 **[AGENT]** English translations of promotional text + description
      (2026-07-29 draft, faithful to the corrected 10.03/10.04 Arabic above —
      founder approves before 2.06 is considered resolved):

      **Promotional text (EN, ≤170 chars, 146 used):**
      ```
      Try Makhtoot free for 7 days: the Arabic design app built letter-first. Authentic Arabic fonts, letter-by-letter control, and high-quality export.
      ```

      **Description (EN, ≤4000 chars, 1957 used):**
      ```
      Makhtoot — the Arabic design studio that understands the letter

      Makhtoot is built from the ground up for Arabic: correct shaping and
      joining as you type, plus a level of per-letter control you won't
      find anywhere else.

      Type exactly as you would in any app — then enter Arrange Mode and
      move every letter on its own: position, rotation, size, color,
      shadow, and outline. Move tashkeel marks (fatha, damma, shadda)
      independently, split a ligature like "لا" into its two letters or
      restore it, and choose each letter's contextual form: isolated,
      initial, medial, or final.

      Key features:
      • Correct Arabic writing: full tashkeel, connected letters, mixed
        Arabic/Latin text on one line, Arabic-Indic and Western numerals
      • Arrange Mode: edit every letter and diacritic as an independent
        object — a capability general design apps simply don't offer
      • Text on a path: editable curved, circular, and freeform text
      • A complete canvas: layers, smart alignment, grouping, lock/hide,
        and a deep multi-step undo history
      • Authentic Arabic fonts: Naskh, Ruqaa, Kufi, and modern/bilingual
        styles — plus your own custom fonts (premium)
      • Ready-to-place shapes, ornaments, frames, and decorative elements
      • Background images from your photo library or files (premium)
      • Fully usable offline, with no account or sign-in required

      Export:
      • Free: JPEG and PDF up to 2 megapixels
      • Premium: transparent PNG, editable SVG, and high-resolution CMYK
        print PDF

      Subscription and trial:
      Your first launch unlocks every premium feature free for 7 full
      days — no payment, no data entry. After that, the app stays
      genuinely useful for free: full editing, free fonts, and standard
      export. Want more? Choose a monthly or annual subscription, or a
      one-time lifetime purchase.

      Your privacy comes first:
      No accounts, no ads, no tracking. Your designs stay on your device
      — or in your own iCloud account if you choose to sync.

      Makhtoot: where the Arabic letter becomes design.
      ```
      If founder approves 2.06 more broadly, translate 10.02 (subtitle), 10.05
      (keywords), and 10.06 (What's New) too — not drafted here since only
      promotional text + description were requested so far.

---

## 11. Build, TestFlight, and submission mechanics

### 11A. Build and upload (xcodebuild path — D-101: no Fastlane/CI)

> **Entitlements trap — read before touching `Makhtoot/Config/Makhtoot.entitlements`.**
>
> `com.apple.developer.user-fonts` accepts **exactly two** values, and no others:
> `system-installation` and `app-usage`. Verified 2026-07-29 against Xcode's own
> capability database
> (`DVTPortal.framework/Resources/DVTPortalCachedPortalCapabilities.json`): capability
> `FONT_INSTALLATION` ("Fonts") → `profileKey com.apple.developer.user-fonts` → values
> "Install Fonts" and "Use Installed Fonts". Only `system-installation` is declared;
> that is what `MKFontRegistry.installFontSystemWide` needs.
>
> **Never add `font-enumeration` to that array.** It has already broken signing twice
> with:
> `Provisioning profile "iOS Team Provisioning Profile: net.binjamshid.makhtoot"`
> `doesn't match the entitlements file's value for the com.apple.developer.user-fonts`
> `entitlement.`
> The string appears nowhere in Apple's capability database, so no profile can ever
> contain it. When Xcode reports *"doesn't include the Font Enumeration capability"*,
> it is echoing the unknown string back as an invented capability name — not naming a
> real one. Font enumeration is a **separate, request-gated entitlement with its own
> key** (requested, awaiting Apple approval); take that key verbatim from Apple's
> approval mail and add it as its own `<key>`, never as a value in this array.
>
> This warning lives here because Xcode's Signing & Capabilities editor **deletes every
> comment** in the entitlements file each time a capability is toggled through its UI,
> so the in-file explanation cannot be relied on to survive.
>
> Related: the **Store** provisioning profile goes stale independently of the
> development one. On 2026-07-29 the dev profile carried `associated-domains`,
> `increased-memory-limit` and `user-fonts` while the Store profile (6 days older) had
> none of them, and `-exportArchive` failed on all three. `-allowProvisioningUpdates`
> (already in 11.02/11.03 below) regenerates it; without that flag the export fails
> with "doesn't include the … capability" even though the App ID is correctly
> configured.

- [ ] 11.01 **[AGENT]** Pre-flight the release build config: version `1.0`, build
      number monotonic (e.g., date-serial `20260717.1`), `ITSAppUsesNonExemptEncryption
      = NO` (9.02), release configuration strips all debug/trial-clock test hooks
      (6.05), FD-01 bundle ID everywhere, `ar` sole localization, referral flag OFF
      (7.04).
- [ ] 11.02 **[AGENT]** Archive:
      ```
      xcodebuild -project Makhtoot.xcodeproj -scheme Makhtoot \
        -destination 'generic/platform=iOS' -configuration Release \
        -archivePath build/Makhtoot.xcarchive archive \
        -allowProvisioningUpdates \
        -authenticationKeyPath <path/to/AuthKey_XXXX.p8> \
        -authenticationKeyID <KEYID> -authenticationKeyIssuerID <ISSUER>
      ```
- [ ] 11.03 **[AGENT]** Export + upload with an `ExportOptions.plist`
      (`method: app-store-connect`, `destination: upload`, automatic signing, same
      API-key auth flags):
      ```
      xcodebuild -exportArchive -archivePath build/Makhtoot.xcarchive \
        -exportOptionsPlist ExportOptions.plist -exportPath build/export \
        -allowProvisioningUpdates -authenticationKeyPath ... \
        -authenticationKeyID ... -authenticationKeyIssuerID ...
      ```
      (If the installed Xcode version's `destination: upload` misbehaves, fallback:
      export the `.ipa` then upload via `xcrun altool --upload-package` with the same
      API key, or Transporter as last resort — pick per the current toolchain,
      VERIFY-AT-SUBMISSION V-12 for the exact blessed CLI on the Run-3 Xcode.)
- [ ] 11.04 **[AGENT]** Confirm the build finishes ASC processing (poll via ASC API);
      resolve any post-processing warnings (missing usage-description strings, icon
      issues) — expected usage descriptions for v1: Photo Library access
      (`NSPhotoLibraryUsageDescription`, Arabic string — image import is
      premium-gated but present) and nothing else (no camera/mic/location).

### 11B. TestFlight internal pass (gate before submission)

- [ ] 11.05 **[AGENT]** Distribute the processed build to **internal testers**
      (founder's account + team). Internal TestFlight needs no beta review.
- [ ] 11.06b **[AGENT]** Post-FD-01-sweep sync re-verification: after the FD-01
      identifier sweep replaces placeholder bundle id/team/CloudKit container/product
      ids with the real values, re-run T-SYN-1 / T-SYN-2 / T-SYN-4 / T-SYN-6 against
      this TestFlight build using the **real** CloudKit container and **real** product
      ids (not the placeholder-era config) — confirms sync survived the identifier
      swap. Must pass before the founder's 11.06 GO below.
- [ ] 11.06 **[FOUNDER]** Install via TestFlight on personal iPhone AND iPad; run the
      manual Arabic-script verification checklist (BRIEF gate Q59 / TEST_MATRIX):
      shaping fidelity, arrange-mode manipulation, tashkeel behavior, export sharpness
      at print resolution, paywall flow, restore, sync. Founder gives explicit GO.
- [ ] 11.07 **[AGENT]** Sandbox StoreKit pass on the TestFlight build (3.10 suite) —
      TestFlight builds transact against sandbox; verify entitlement precedence
      (lifetime over subscription), grace-period banner, restore.

### 11C. Submission assembly

- [ ] 11.08 **[AGENT]** Compose the **App Review Information** panel:
      - Contact info: founder's name/phone/email **[FOUNDER]** supplies values.
      - Sign-in required: **NO** (no accounts — no demo credentials needed).
      - **Review Notes (master text, English)** — assembled from: trial explanation
        (3.04), sandbox premium access walkthrough (6.04), fonts-are-data statement
        (6.01), no-accounts note (5.11), plus: "The app's UI is Arabic-only (RTL) by
        design for its target market. Notes here are in English for your convenience.
        The 7-day trial is app-managed (starts at first launch, no purchase involved);
        subscriptions therefore have NO App Store introductory offer — this is
        intentional to avoid double-trial states. All purchases are standard StoreKit 2
        products; Restore Purchases is on the paywall and in Settings."
- [ ] 11.09 **[AGENT]** Attach the build to version 1.0; verify metadata completeness
      (screenshots all classes, privacy label, age rating, URLs).
- [ ] 11.10 **[AGENT]** Attach **all three IAPs** to this first version's submission
      (first-time IAPs are reviewed with the app version; they must ride the same
      submission).
- [ ] 11.11 **[AGENT]** **Release option: Phased Release for automatic updates — ON;
      release method: "Manually release this version" after approval.** Rationale:
      manual release lets §13 post-approval verification happen before public
      availability; phased release then staggers automatic-update rollout over 7 days
      with a pause lever if a critical defect appears. (Phased release applies to
      updates for existing users; for a brand-new app it is cheap insurance and the
      recommended default posture going forward.)
- [ ] 11.12 **[FOUNDER]** Click **Submit for Review** (the submission is a legal
      attestation of content/rights/export answers — founder-only click), after a
      final agent-prepared diff summary of everything being submitted.

---

## 12. Review-rejection contingency playbook

Most-likely rejection vectors for THIS app, with prepared responses. On any rejection:
the agent drafts the Resolution Center reply from the matching entry; the founder
approves and sends **[FOUNDER]** (Resolution Center replies are formal correspondence).

- [ ] 12.01 **[AGENT]** Maintain this playbook as `dossier/rejection-playbook.md` with
      the drafted responses below, updated after every reviewer interaction.

**Vector 1 — Guideline 3.1.2 family: "free trial" confusion (MOST LIKELY).**
A reviewer sees "7-day free trial" messaging in-app but finds no introductory offer
configured, or worries billing terms are unclear [MS ^50][MS ^51].
*Prepared response:* the trial is app-managed and requires no purchase — no StoreKit
transaction exists until the user actively subscribes at full disclosed price; all
purchase CTAs display exact price/term with immediate billing (screenshots attached);
this design *cannot* produce accidental billing, which is the harm 3.1.2 targets.
*Pre-emption:* 4.03's copy discipline + Review Note 11.08.

**Vector 2 — Guideline 2.1: reviewer cannot access premium content.**
Reviewer reports font downloads or premium export "not working" (often: they skipped
the sandbox purchase, or the FD-04 host hiccuped).
*Prepared response:* step-by-step sandbox walkthrough (6.04) + reminder that the
first-launch trial exposes all premium features with zero purchases; attach a screen
recording of the fresh-install premium path. *Pre-emption:* 6.03 hosting verification
from a clean network on submission day; if hosting reliability is doubtful, elect the
D-121 bundle-fallback (6.02) BEFORE submitting.

**Vector 3 — Paywall UX objection (dismiss/pre-content/placement) [MS ^50][MS ^51][MS ^52].**
*Prepared response:* annotated screenshots showing the visible close control, the
free-usable first-run flow, and price-adjacent CTAs; cite the specific reviewer
observation and, if reproducible, ship the metadata-only or binary fix rather than
arguing. *Pre-emption:* §4 checklist executed against the actual binary.

**Vector 4 — Privacy label mismatch (5.1.x family).**
Reviewer's automated scan flags network calls (CloudKit, font host) against a minimal
label. *Prepared response:* traffic inventory — CloudKit private sync (user's own
iCloud, not developer-collected), anonymous opt-in analytics (declared: Product
Interaction, not linked), TLS font file downloads (no identifiers) — matching D-125;
offer a network capture. *Pre-emption:* §5 justifications recorded in the dossier
before submission.

**Vector 5 — Downloadable-content objection to the font catalog.**
*Prepared response:* fonts are static data rendered by Core Text, not executable
code; delivery is entitlement-gated content fulfillment for reviewed IAPs (6.01). If
the reviewer holds firm regardless: execute the D-121 fallback — resubmit with
premium fonts bundled behind the entitlement (pre-authorized plan, fast turnaround).

**Vector 6 — Arabic-only comprehension friction.**
Reviewer struggles to evaluate an RTL Arabic-only app (misreads flows).
*Prepared response:* polite feature-by-feature English walkthrough with annotated
screenshots keyed to the Arabic labels. *Pre-emption:* thorough English Review Notes
(11.08) + optional English metadata localization (2.06).

**Vector 7 — 3.1.1 suspicion about referral remnants (LOW likelihood, §7).**
*Prepared response:* 7.05's statement; attach evidence that no UI path reaches the
module and the flag is compile-time OFF.

**Vector 8 — Metadata/screenshot accuracy (2.3 family).**
Screenshots must show the shipped UI; overlay captions are fine, fabricated UI is not.
*Pre-emption:* 10.08 captures come from the actual release build only.

- [ ] 12.02 **[AGENT]** If any rejection requires a binary change: fix → re-run
      affected TEST_MATRIX gates → new build number → 11.02–11.10 → founder resubmits.
      Never argue twice on the same point without a change; escalate to a phone call
      with App Review (founder-initiated) after a second identical rejection.
- [ ] 12.03 **[FOUNDER]** Approves every Resolution Center message and any App Review
      Board appeal (formal legal-adjacent correspondence).

---

## 13. Post-approval checklist

- [ ] 13.01 **[AGENT]** (Build approved, still unreleased per 11.11) — final smoke
      pass on the approved build via TestFlight; confirm the approved version string.
- [ ] 13.02 **[AGENT]** **Storefront price verification (sample):** after release,
      check the public product page price rendering on a sample of storefronts:
      **US ($2.99/$29.99/$89.99), OM (OMR — market study §8 flags the Muscat/Oman
      check specifically), SA, AE, EG, KW, QA, BH, JO, MA, DE, FR, GB, TR, IN, ID,
      PK, NG, BR, JP** — confirm Apple's auto-localized tiers look sane (no
      zero/absurd values) and the Arabic metadata renders correctly RTL on Arabic
      storefronts. Log a table with screenshots.
- [ ] 13.03 **[FOUNDER]** Release: click "Release this version" (with phased-release
      posture per 11.11).
- [ ] 13.04 **[AGENT]** **Sandbox → production entitlement smoke test:** on a real
      device with a real Apple ID (founder's device, founder performs the actual
      purchase tap — real money): purchase monthly ($2.99), verify premium unlocks +
      font download works in production; **[FOUNDER]** then immediately cancels via
      subscription management (4.09 deep link — also verifies it in production) and
      optionally requests a refund via reportaproblem.apple.com. Verify
      `Transaction.currentEntitlements` production parity with sandbox behavior
      (D-113), and that lifetime restore works on a second signed-in device if
      available.
- [ ] 13.05 **[AGENT]** Verify the production CloudKit container serves the analytics
      schema (1.08) and that an opt-in test upload lands in the public DB with the
      D-125 anonymity properties (inspect the record: no user link, week bucket).
- [ ] 13.06 **[AGENT]** Monitor for 7 days: crash reports in Xcode Organizer, App
      Store ratings/reviews (draft Arabic responses for founder approval), phased
      release progression; pause phased release on any critical defect.
- [ ] 13.07 **[AGENT]** Archive the complete submission dossier (all evidence
      screenshots, answers given, territory list, FD-06 record, review
      correspondence) into the repo per the codebase-memory conventions (BRIEF Q58) —
      this dossier is the input for every future update submission.
- [ ] 13.08 **[FOUNDER]** Post-launch decisions queue (non-blocking): revisit FD-06
      Family Sharing (OFF→ON possible later), FD-05 referral (§7C), app preview video
      (10.10), English metadata (if deferred).

---

## 14. Traceability (BRIEF.md → this checklist)

| BRIEF requirement | Checklist coverage |
|---|---|
| Name «مخطوط / Makhtoot» everywhere, never Masoon | 2.01, 10.01–10.06 (all copy uses مخطوط) |
| Bundle ID placeholder — founder supplies real one | 1.04 (FD-01), 3.02/3.03/3.06 product IDs, 11.01, 11.06b (post-sweep sync re-verification) |
| Universal iPhone+iPad, iOS 18, Arabic-only RTL | 2.01 (platform, `ar` primary), 10.08 (RTL screenshots), 11.08 (reviewer note) |
| Offline-first; network only fonts/sync/analytics | 5A justifications, 6.03 offline degradation, 9.01 encryption scope |
| Monetization: $3/mo, $30/yr, $90 lifetime; Apple price localization | 3.02, 3.03, 3.06; 13.02 storefront verification (mapped per D-216) |
| 7-day app-side trial at first launch (Q37, D-123); document trial vs intro-offer differences | 3.04 (no intro offer + explanation), 4.03, 11.08, Vector 1 |
| Post-trial free tier remains useful (Q41) | 4.05, 4.10, 6.06 |
| StoreKit 2 full surface: restore, precedence, grace, billing retry, messaging, sandbox testing | §4 entire, 3.10, 11.07, 13.04 |
| Referral: architected, flag OFF, review-risk docs, reactivation protocol (Q78, D-124) | §7 entire |
| Fonts: premium downloadable catalog, verify App Store policy, fallback = bundle (D-121) | §6 entire, Vector 5 |
| OFL-only bundled fonts, never invent licenses, licensing at Settings→Support→Licensing (Q66) | 2.02 content rights, 6.03, 5.10 |
| No accounts / SIWA not in v1 (Q77) | 1.07, 5.11, 11.08 |
| Analytics: anonymous, aggregated, opt-in font usage only (Q43/Q79, D-125) | §5A, 13.05 |
| No ads | 5.05 |
| Territories: all without extra legal documentation (Q46) + submission-time eligibility checklist | §8 entire |
| Distribution automated where possible; pause for founder credentials/legal/approval (Q56, Q84) | Header boundary, every [FOUNDER] tag, 10.09, 11.12 |
| Tools: xcodebuild + gh only, no Fastlane/CI (Q49, D-101) | §11A |
| Gates: build success, StoreKit sandbox tests, manual Arabic-script checklist (Q59) | 1.10, 3.10, 11.06b, 11.06, 11.07 |
| Known research gaps: grace-period duration, referral guideline text at submission | 4.11 (V-02), 7.06 (V-06) |
| No policy facts without market-study citation or VERIFY marker | `[MS ^NN]` citations throughout; §15 |
| FD-06 Family Sharing irreversible founder decision | 3.08 |
| FD-01/FD-04/FD-05 founder decisions | 1.04, 6.02, 7.06 |

## 15. VERIFY-AT-SUBMISSION — consolidated list

Facts/values that must be checked against live sources during Run 3, never asserted
from this document:

| ID | What to verify | Where |
|---|---|---|
| V-01 | Current age-rating questionnaire wording (answer to substance, 2.03) | ASC age rating form |
| V-02 | Current billing grace-period duration before any UX copy mentions days [MS ^43] | Apple documentation / ASC subscription settings |
| V-03 | Current App Privacy definitions ("collect", private-CloudKit treatment) before answering 5.01–5.03 | ASC App Privacy questionnaire + linked definitions |
| V-04 | Current guideline clause number for account-deletion requirement (substance: N/A, no accounts) | Live App Review Guidelines [MS ^55] |
| V-05 | Current guideline text on downloaded code/resources (fonts-are-data position, 6.01) | Live App Review Guidelines [MS ^55] |
| V-06 | (Only if FD-05 ever triggers) current 3.1.1/3.2.2 + referral-related text before flag-ON [MS ^53][MS ^54][MS ^55] | Live App Review Guidelines |
| V-07 | a) EU DSA trader-status form location/wording; b) China mainland requirements for this app profile; c) any territory tax/registration prompts | ASC Pricing & Availability + Business sections |
| V-08 | Oman storefront OMR price rendering (market study §8) | Public App Store OM storefront |
| V-09 | Current export-compliance questionnaire branching (substance: standard Apple crypto only) | ASC export compliance form |
| V-10 | Annual exempt-encryption self-classification obligations; any France-specific question | Founder legal counsel + ASC form |
| V-11 | Current required screenshot pixel dimensions per device class | ASC media manager spec |
| V-12 | Blessed upload CLI for the Run-3 Xcode version (exportArchive-upload vs altool) | Xcode release notes / toolchain trial (1.10, 11.03) |
| V-13 | **RESOLVED 2026-07-19** — FD-03 outcome: Apple Generic CMYK fallback elected for v1 (founder). 10.04's print-claims copy softened accordingly ("احترافية" → "عالية الجودة"); no further pre-submission re-verification needed. | D-117 color pipeline record / DECISIONS_LOG.md FD-03 |

---

*End of APP_STORE_CHECKLIST.md. Any conflict with FOUNDATION.md is resolved in favor of
FOUNDATION.md; expansions of D-113/D-121/D-123/D-124/D-125 rationale live in
DECISIONS_LOG.md under the same IDs.*
