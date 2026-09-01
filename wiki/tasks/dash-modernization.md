# DASH Modernization

Status: [/]
Taskwarrior: parent `94ec17b3-3d55-4ea6-a720-a1c51dec1e9d`
Plan: `brain/plans/2026-09-01-dash-modernization.md`

## Goal

Bring DASH from "works, dual-assembler-safe, but written before CASM had
cheap locals / computed constants / assertions" to a well-designed
utility that uses the shared CASM/ca65 feature set idiomatically and has
a cleaner internal structure, with **no regression** to what a user sees
on screen or to the relocation contract.

Runs now, before Phase 14 WP92 (user decision 2026-09-01); on
`feature/casm-phase14`; WP92's consolidated gate covers both efforts.

## Work Packages

- [x] **WP1 - CASM `.ASSERT` ca65-compatible action keyword.** Taskwarrior
      `4e682aa2-3930-47f3-9b5b-8999fadf2104`. `.ASSERT expr, ACTION[,
      "msg"]` (ERROR/WARNING/LDERROR/LDWARNING) now parses under native
      CASM; keyword discarded, all forms pass-time-fatal. `compareTokenText`
      exported from lexer.s. 7 `casmakw*` fixtures + 2 legacy regression,
      live-verified `CASM V0.5.2.1404`. ca65 cross-checked. Source-complete,
      awaiting sign-off. Plan: `brain/plans/2026-09-01-dash-mod-wp1-casm-
      assert-ca65-keyword.md`. Walkthrough: `brain/walkthroughs/2026-09-01-
      dash-mod-wp1-casm-assert-ca65-keyword.md`.
- [x] **WP2 - DASH full `@local` migration (output-preserving).** 84
      routine-local helper labels demoted to `@local` across `dscr.s`
      (13), `dsys.s` (14), `dapp.s` (10), `dvmm.s` (44), `dmain.s`
      (3, `DISPATCHPAGE` only). Byte-identical to the pre-increment
      manifest (sha256 `3238b786`, 4766 bytes) under ca65 `dash_ref` and
      native `CASM V0.5.2.1404` (`FILES COMPARE OK`), triple-checked;
      manifest regenerated, source hashes only. `DRAWFRAME` /
      `DAPPPRINTFLAGS` / event-loop label sets deferred to WP4/WP5.
      **Closed — user-approved 2026-09-01.** Plan: `brain/plans/2026-09-01-
      dash-mod-wp2-full-local-migration.md`. Walkthrough: `brain/
      walkthroughs/2026-09-01-dash-mod-wp2-full-local-migration.md`.
- [x] **WP3 - DASH computed constants + `.ASSERT` invariants.** ~110
      named constants across all 7 sources (`dmain.s` prologue) + 16
      ca65-only structural `.assert`s in `dash_wrapper.s` (CASM has no
      comparison operator; byte cross-check covers the CASM side).
      Output-preserving: byte-identical to the pre-WP3 manifest
      (`3238b786`, 4766 bytes) under ca65 `dash_ref` and native `CASM
      V0.5.2.1404` (`INPUT VALIDATED`, `FILES COMPARE OK`), 3-way.
      Manifest regenerated, hashes only. Key-ladder / `SELECT*` /
      `DRAWFRAME` literals deferred to WP4/WP5. AGENTS.md gained two
      dual-assembler notes (no comparison operator; constant-def RHS must
      be a bare literal). **Closed — user-approved 2026-09-01.** Plan:
      `brain/plans/2026-09-01-dash-mod-wp3-computed-constants-assert-invariants.md`.
      Walkthrough: `brain/walkthroughs/2026-09-01-dash-mod-wp3-computed-constants-assert-invariants.md`.
- [x] **WP4 - DASH event loop / key dispatch / page dispatch refactor.**
      `dmain.s`: MARKREDRAW helper; F1/F3/F5 -> computed page select
      (SELECTSYS/APP/VMM collapsed); T/R/Q double-compares -> `AND #$DF`
      case-fold. Behaviour-preserving, live-verified at the $3800
      relocated base (nav / redraw / VMM test PASSED / clean exit). ca65
      == native CASM byte-for-byte. **First shipping-byte change since
      WP91: 4766->4713 B, 3238b786->08f8f7ce, 465->459 reloc entries.**
      Manifest re-baselined. **Closed -- user-approved 2026-09-01.** Plan:
      `brain/plans/2026-09-01-dash-mod-wp4-event-loop-dispatch-refactor.md`.
      Walkthrough: `brain/walkthroughs/2026-09-01-dash-mod-wp4-event-loop-dispatch-refactor.md`.
- [x] **WP5 - DASH frame / renderer helper refactor.** `DRAWFRAME`'s 7
      row loops -> `COPYFRAMEROW`; `DAPPPRINTFLAGS` -> `APPFLAGMASKS`/
      `APPFLAGCHARS` table loop; `dsys.s` 12 row openers -> `DSYSLABEL`;
      dead `PRINTAT` removed; `dvmm.s` surveyed (deferred). Pixel-
      identical, live-verified at `$3800`. ca65 == native CASM
      byte-for-byte. **4713->4579 B (net -134), 08f8f7ce->4a49612e,
      459->443 reloc, -30 labels.** Manifest re-baselined.
      **Closed -- user-approved 2026-09-01.** Plan:
      `brain/plans/2026-09-01-dash-mod-wp5-renderer-helper-refactor.md`.
      Walkthrough: `brain/walkthroughs/2026-09-01-dash-mod-wp5-renderer-helper-refactor.md`.
- [ ] **WP6 - Consolidated gate + re-baseline.** ca65<->CASM byte
      identity, manifest regen, user runtime sign-off, relocation audit,
      AGENTS.md rewrite, CHANGELOG, DASH version bump.

## Verification contract (every WP)

1. ca65 `dash_ref` == native CASM `DASH.PRG`, byte-for-byte.
2. WP2 == pre-increment shipping manifest; WP3-5 deltas predicted and
   justified per WP, re-baselined only at WP close.
3. Runtime: all 3 pages render, F1/F3/F5 nav, R redraw, T VMM test, Q
   exit -- at `$3400` and one relocated address; final pass is a user
   runtime sign-off.
