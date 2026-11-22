# Prohibited fonts — never bundle, never re-add

This list exists so no future agent or contributor re-adds a font that fails
Makhtoot's licensing bar. Auto-fail at VERIFICATION_PROTOCOL.md step 1 — do
not run the rest of the protocol for anything on this list.

## KFGQPC Uthmanic Script HAFS (and the wider KFGQPC Uthmanic family)

- Publisher: King Fahd Glorious Qur'an Printing Complex (KFGQPC).
- License: proprietary freeware, **non-commercial use only** (EULA explicitly
  prohibits redistribution inside paid/commercial software).
- Status: **PROHIBITED**. Makhtoot is a commercial (paid + subscription) app;
  bundling this font, or any derivative of it, would violate the EULA.
- This applies to every variant sometimes seen under this family's name
  (Uthmanic Hafs, Uthman Taha Naskh, and similar KFGQPC-published Mushaf
  typefaces).

## General rule

Any font whose license is:
- a proprietary/freeware EULA that restricts commercial use or redistribution,
- unclear, unverifiable, or sourced only from an aggregator/mirror site
  (protocol step 1 explicitly disqualifies aggregator mirrors as an
  authoritative source — e.g. general "free font download" sites are never
  treated as ground truth for licensing terms), or
- anything other than OFL 1.1 (v1 scope; FD-07 commercial-foundry licensing
  is a post-v1 hook only, not active in v1),

...is prohibited from `Resources/Fonts/` regardless of how well it performs,
how popular it is, or how closely it matches the product's aesthetic goals.
No font ships without a captured, verbatim license file and a completed
`MKLicenseRecord` produced by the full protocol in `VERIFICATION_PROTOCOL.md`.
