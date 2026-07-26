---
feature: casm-dash-wp7-applications-page
created: 2026-07-26
status: draft
---

# Plan: DASH WP7 - Applications Page

## Objective

Enumerate all public application slots and render each occupied application as
a bounded row containing name, inclusive range, size, and `U/R/V/S` flags.
Highlight running applications only when the approved API provides truthful
running state.

Prerequisites: approved WP1/WP3 API and approved WP4/WP5 completion.

## Mandatory Activation Review

Re-read final app record/statuses, name encoding, size/end semantics, running-
flag behavior, DASH screen geometry, and loader registration. Any material
discrepancy in row capacity, status meaning, record version, naming, flags, or
relocated self-range stops work, requires amendment, and requires renewed
approval.

## Expected Files

- `src/external/dash/dapp.s`
- `src/external/dash/ddata.s`
- `src/external/dash/dfmt.s`, only for approved formatting changes
- `src/external/dash/dscr.s`, only for approved page geometry/labels

## Row Geometry

Freeze exact columns before coding. Recommended interior shape:

```text
NAME        RANGE     SIZE FLAGS
1234567890 3400-3FFF 0C00 UR--
```

- Reserve one header and 16 data rows.
- Define name display width and visible truncation policy.
- Never scan beyond the public name field/length.
- Keep one spare row/status area for page-wide errors if geometry permits.

## Enumeration Contract

1. Draw heading; initialize slot=0 and output row.
2. For slots 0-15, save slot before the OS call.
3. Set the frozen destination pointer/reserved input exactly.
4. Occupied: validate record version/size and render one row.
5. Empty: skip silently.
6. Invalid for an input 0-15: page-contract failure; stop enumeration.
7. Unavailable/malformed: follow frozen status policy and render bounded
   summary without private access.
8. If no records are occupied, display `NO APPLICATIONS`.

Use the normalized API end field if WP1 provides it. If local calculation is
required, prove size nonzero, perform carry-aware `load+size-1`, and render a
defensive marker on overflow.

## Name and Flag Rules

- Convert public PETSCII to screen code only within the bounded display width.
- Stop according to frozen name length/termination rules.
- Pad with spaces; never read stale trailing bytes.
- Render U/R/V/S only from public normalized bits.
- Do not infer running state by comparing the name to `DASH`.
- Highlight the row when public R is set; if R is reserved/unavailable, omit
  the highlight and document the limitation.

## Failure Handling

- Empty is not a page error.
- Invalid status for a valid slot stops enumeration with `APP QUERY ERROR`.
- Short/unsupported record is bounded and cannot over-read.
- Zero size and overflow never display `$FFFF` via wraparound.
- More than 16 rows is impossible by contract; stop rather than overwrite the
  frame if geometry/state disagrees.
- Query failure never exits DASH.

## Atomic Increments

1. Freeze row columns, name width, truncation, and error row.
2. Implement slot loop and empty handling.
3. Implement bounded name conversion/rendering.
4. Implement load/end/size hex rendering.
5. Implement U/R/V/S display.
6. Implement running-row highlight if truthful.
7. Implement malformed/unavailable states.
8. Verify full 16-slot capacity.
9. Verify DASH's self-row at three relocated addresses.

## Verification

- Exactly 16 possible service calls; reserved inputs set every time.
- Slot state survives API clobbers.
- Destination pointer relocates correctly.
- Every name read is bounded by record and display width.
- No zero-size subtraction or end overflow wraps.
- No direct `AptSeg`, MCT, VMM-table offset, or REU-register access.
- All 16 rows remain inside the content area.
- WP3 occupied/empty/invalid/unavailable/malformed tests pass.
- At `$3400/$4000/$5000`, DASH displays its actual registered range and all
  other loaded applications correctly.
- Empty slots do not expose stale names.
- Full table does not overwrite frame/status.
- `R` refresh reflects approved table changes.

## Stop Conditions

- App status or record semantics are not frozen.
- Row geometry cannot fit all 16 slots.
- Name rendering needs unbounded scanning.
- Correct behavior requires private app-table/VMM access.
- Running state is claimed but not truthful.
- DASH self-range is wrong at any address.
- Size semantics ambiguously include R6 metadata.

## Completion Gate

Present exact row geometry, bounded-name proof, all slot-status tests, full-
capacity visual evidence, and relocated self-row results. Ask whether WP7 is
complete before WP8 activation.
