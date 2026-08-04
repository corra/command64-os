# CASM Phase 10 - Symbol Map and Listing

Status: [ ]
Taskwarrior: 34 (`32e09eea-691d-40bc-aa7a-7d2299fe093b`)
Plan: `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`

## Goal

Implement deterministic `/M` symbol-map output and native `/L` listing files
without changing generated static or R6 PRG bytes. This is the CASM master
plan's Phase 10 and the gated CASM 0.2 developer-usability milestone.

The governing plan is approved. No production work package is active; each WP
requires a dedicated detailed plan and explicit user approval.

## Approved Contract

- `/M` prints `SYMBOL MAP`, `$HHHH LABEL` rows in definition order, and a
  decimal symbol total.
- `/L` derives a `.LST` name from the final PRG output name and rejects overflow
  or collision before source loading.
- Listings use raw PETSCII, CR row terminators, and at most 40 bytes per row.
- Every physical source line appears in traversal order; synthetic top-level
  separator newlines do not.
- Included files retain full filename and physical-line provenance.
- Four emitted bytes and 14 exact source bytes fit the primary detail row;
  emitted bytes and source text continue independently.
- `/L` uses one 65,536-byte metadata VMM store and one 65,536-byte emitted-byte
  mirror, with a 4,096 listed-line-occurrence limit.
- A post-finalization listing failure deletes only the incomplete listing,
  retains the valid PRG, suppresses `/M`, and exits with failure.
- Phase 10 completion promotes verified CASM `0.1.56` to `0.2.0` through a
  separate completion-only version change.

## Work Packages

- [/] `ad82f04d-0d34-4902-9a2c-ae27292902cf`: WP50 contract reconciliation
      and ABI freeze. Active under approved plan
      `brain/plans/2026-07-29-casm-phase10-wp50-contract-reconciliation.md`.
      No production behavior changes; completion target `0.1.51`.
- [x] `a64fa847-1b46-44fd-be3b-8ad7b1055c92`: WP51 listing stores and capture
      events. Complete at CASM `0.1.52` build 1222, user-approved
      2026-08-03, per
      `brain/plans/2026-07-29-casm-phase10-wp51-listing-stores-capture.md` and
      `brain/walkthroughs/2026-08-03-casm-phase10-wp51-listing-stores-capture.md`.
- [ ] `0bf2e86b-0bd0-443a-b84b-b2c258e98181`: WP52 deterministic symbol map;
      approved plan:
      `brain/plans/2026-07-29-casm-phase10-wp52-deterministic-symbol-map.md`.
      Completion target `0.1.53`; blocked by WP51.
- [ ] `aa57f461-36a9-455c-966f-ac484ec57b41`: WP53 listing naming,
      serialization, and cleanup. Approved plan:
      `brain/plans/2026-07-29-casm-phase10-wp53-listing-serialization-cleanup.md`.
      Completion target `0.1.54`; blocked by WP52.
- [ ] `f4b598fd-bab1-4394-9415-c71e3ea1cfa5`: WP54 production integration;
      approved plan:
      `brain/plans/2026-07-29-casm-phase10-wp54-production-integration.md`.
      Completion target `0.1.55`; blocked by WP53.
- [ ] `94d98a2b-7ad4-49f0-bf33-38702690eca9`: WP55 verification, walkthrough,
      and phase gate; approved plan:
      `brain/plans/2026-07-29-casm-phase10-wp55-verification-walkthrough-completion-gate.md`.
      Completion target `0.1.56`. Blocked by WP54.
- [ ] Obtain explicit Phase 10 completion approval.
- [ ] Apply the separate completion-only `0.2.0` promotion.

## Acceptance

- [ ] `/M` output is exact, deterministic, and supports 0-512 symbols.
- [ ] `/L` output obeys the exact file-header, detail-row, continuation,
      PETSCII, CR, and filename contracts.
- [ ] Blank, comment, label, directive, multi-root, include, and final partial
      physical lines retain correct PC and provenance.
- [ ] 4,096/4,097 line and emitted-byte endpoint bounds fail before wraparound.
- [ ] `/M`, `/L`, `/M /L`, `/S`, and `/O` combinations preserve PRG bytes and
      R6 relocation records.
- [ ] Listing failures preserve primary diagnostics, clean incomplete listings,
      retain finalized PRGs, and leak no handles or VMM allocations.
- [ ] Existing CASM regression suites and all Phase 10 harnesses pass.
- [ ] The complete implementation review passes before runtime acceptance.
- [ ] The user completes the native walkthrough and explicitly approves Phase
      10 completion.

Do not mark this task done until every acceptance item is checked and the user
explicitly approves the completed walkthrough.
