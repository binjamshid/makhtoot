# Architecture Decision Records

Gated ADRs (portfolio house standard, matrix row 6). Pattern sources: ClassTranscriber's
`docs/adr/0005-pdf-renderer.md` (pre-registered no-go trigger, reserved fallback budget)
and badan's `docs/adr/` (numeric re-evaluation gate, `Supersedes:` header line).

An ADR here is for a genuinely **reversible-but-expensive** architectural bet — the kind
where motivated reasoning ("it's basically working, let's just keep going") is the real
risk, not a lack of documentation. Use `DECISIONS_LOG.md` for the day-to-day D-1xx/D-2xx
decision stream; promote a decision to a gated ADR here specifically when it needs:

1. **A pre-registered no-go trigger** — written down *before* the spike/build, so a later
   "it's basically working" doesn't quietly override what the founder would have said in
   advance, with no evidence pressure yet applied.
2. **A reserved fallback budget** — what ships instead, and roughly how much work that
   costs, decided in advance rather than discovered under deadline pressure.
3. **A `Supersedes:` header** — when a new ADR replaces an earlier one, point to it by id;
   never silently orphan the old file.
4. **A numeric re-evaluation gate** — a concrete, falsifiable trigger ("adopt X if ≥3
   fixture-divergence incidents," "re-check at P10 exit"), not a vague "revisit later."

Use `TEMPLATE.md` for new ADRs. Status values: `Proposed` (gated, spike/trigger pending) ·
`Accepted` · `Superseded` (by the ADR named in a later `Supersedes:` header) · `Rejected`.

## Index

| id | title | status |
|---|---|---|
| [0001](0001-cmyk-print-pdf-color-pipeline.md) | CMYK print-PDF color pipeline: ICC conversion at export, Apple Generic CMYK fallback | Accepted (retroactive) |
