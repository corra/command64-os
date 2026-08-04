# Task Spec: DEBUG REU/Address Syntax WP5

## Objective

Implement `XM`'s full grammar and preflight window validation (no DMA), per
`brain/plans/2026-08-06-debug-reu-address-syntax-wp5.md`.

Taskwarrior UUID: `a4809e03-ee37-4973-8fc6-2896bf2ea69c`

## Scope

- Parse `XM handle offset|page:offset address length direction`.
- `parseVmmOffset`: flat and `page:offset` forms normalize identically.
- Validate the REU-side window against the selected allocation's exact
  capacity, including the `$1000`-paragraph (65536-byte) boundary case.
- Validate the C64-side window rejects a wrap past `$FFFF`.
- No `DOS_VMM_READ`/`DOS_VMM_WRITE` call anywhere — that's WP6.
- Preserve WP1-WP4 behavior.

## Increments

- [ ] Increment 1: `parseVmmOffset`, flat/page equivalence, build, and
      VICE verification.
- [ ] Increment 2: full grammar (address/length/direction/`requireEnd`),
      build, and VICE verification.
- [ ] Increment 3: window validation (`validateReuWindow`,
      `validateC64Window`), build, and VICE verification.
- [ ] Increment 4: full regression, artifact audit, documentation, DOX,
      and user-confirmed walkthrough.

## Acceptance

- [ ] Flat and `page:offset` forms normalize to byte-identical state for
      every equivalent pair.
- [ ] Every malformed operand rejects with the documented selector before
      window validation runs.
- [ ] `validateReuWindow`/`validateC64Window` accept/reject exactly the
      documented boundary cases.
- [ ] No new VMM API call (`DOS_VMM_READ`/`DOS_VMM_WRITE`); no new private
      zero-page state; BSS growth is exactly 8 bytes.
- [ ] DEBUG remains relocatable and inside its existing linker envelope.
- [ ] The user confirms the walkthrough before WP5 is marked complete.
