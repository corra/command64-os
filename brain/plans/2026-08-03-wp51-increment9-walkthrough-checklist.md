---
feature: casm-phase10-wp51-listing-stores-capture
created: 2026-08-03
status: checklist
---

# WP51 Increment 9 -- Runtime Walkthrough Checklist

Companion to `brain/reviews/2026-08-03-casm-wp51-implementation-review.md`
(the static half of Increment 9, already complete). This is the live half:
confirm under real VICE emulation that nothing regressed since increments
3/4/6's own live passes, now that increments 5, 7, and 8 have added the
production wiring and tightened envelopes on top of what was tested then.

No source has changed since increment 6's harnesses last ran green, so no
new bugs are expected -- this is a confirmation pass, not exploratory
debugging. If anything fails, stop and report exactly what you saw rather
than guessing a fix.

## 0. Fresh build

```
rm -rf build && cmake -B build && cmake --build build -j4
```
Confirm zero errors. (Already done once in Increment 8's own verification,
but re-run if you've touched anything since.)

## 1. `test_casm_listing` (Increments 3-4 harness, 11 fixtures)

Boot `test.d64` on device 8 as usual, attach
`build/casm_listing_test.d64` on device 9 (non-bootable, matches the
existing two-drive convention). Load and run the listing harness PRG from
device 9.

**Expect:** `CASM LISTING: PASS`, no fixture failures reported.

This harness hasn't changed since Increment 4; this run exists to confirm
the tightened `test_casm_listing` envelope ($1300, already the minimum
before WP51 started) and the whole-object rebuild still produce identical
runtime behavior.

## 2. `test_casm_listcap` (Increment 6 harness, 7 fixtures)

Same disk (device 9), load and run the listcap harness PRG.

**Expect:** `CASM LISTCAP: PASS`, all seven fixtures
(`fixEmpty`/`fixNewlineVariants`/`fixFinalUnterminated`/`fixDeferredData`/
`fixLabelsInclude`/`fixRootsSynthetic`/`fixPrgIdentity`) reported passing.

This is the more important re-run: Increment 7 changed
`test_casm_passcheck`'s envelope (not this one), and Increment 8's audit
found zero code changes -- so this should reproduce increment 6's own
first-attempt clean pass exactly. A failure here would mean something
about the rebuilt object files behaves differently than what increment 6
tested, which would be a real finding.

## 3. Production `casm` regression sanity

Boot `image.d64` (device 8) through the normal `COMMAND64` shell (external
apps can't run from bare BASIC LOAD/RUN -- shell load/run only). Run `CASM`
against any ordinary existing `.s`/`.seq` source you'd normally assemble,
without `/L` (still rejected -- WP54's job, not reachable yet).

**Expect:** assembly behaves exactly as before WP51 -- same diagnostics,
same PRG output, no new prompts, no crash, no slowdown. `listingCaptureInit`
is never called from production `casm.s` yet (confirmed in the
implementation review), so this is really confirming that linking
`listing.s` whole into `casm.prg` (required since Increment 3, for
`emitByte`'s unconditional `listingMirrorByte` call) has zero observable
effect on ordinary use.

## Reporting back

For each of the three steps, a plain pass/fail is enough:
- Step 1: PASS or the exact fixture/diagnostic that failed.
- Step 2: PASS or the exact fixture/diagnostic that failed.
- Step 3: works normally, or describe what looked different.

Once all three come back clean, Increment 9 is complete and WP51 moves to
Increment 10 (version bump to `0.1.52`, synchronize records, request
closure) pending your explicit completion approval.
