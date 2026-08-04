# Task Spec: DEBUG REU/Address Syntax WP4

## Objective

Implement `XS`/`XS handle` status reporting, per
`brain/plans/2026-08-05-debug-reu-address-syntax-wp4.md`.

Taskwarrior UUID: `4141acb7-d8a7-4cb1-babd-9628f24616df`

## Scope

- `XS handle`: print one active allocation's summary (same format as `XA`'s
  output line), reject invalid/inactive/out-of-range handles and trailing
  input before any OS call.
- Bare `XS`: query `DOS_GET_SYSTEM_INFO` for VMM active/inactive status and
  total/allocated/free page counts, then list every active DEBUG
  allocation (or print `NONE` if none are active).
- No OS Memory Control Table access; no `DOS_VMM_READ`/`DOS_VMM_WRITE` call.
- Preserve WP1/WP2/WP3 behavior.

## Increments

- [ ] Increment 1: `XS handle` single-record report, build, and VICE
      verification.
- [ ] Increment 2: bare `XS` system section and registry sweep, build, and
      VICE verification.
- [ ] Increment 3: full regression, artifact audit, documentation, DOX, and
      user-confirmed walkthrough.

## Acceptance

- [ ] `XS handle` output is byte-identical to that allocation's `XA` line.
- [ ] Bare `XS` reports accurate VMM status and page counters.
- [ ] Bare `XS` lists every active allocation, or prints `NONE`.
- [ ] No new VMM/system-info-adjacent private zero-page state; BSS growth
      is exactly 24 bytes (`sysInfoBuf`).
- [ ] DEBUG remains relocatable and inside its existing linker envelope.
- [ ] The user confirms the walkthrough before WP4 is marked complete.
