# Walkthrough: DASH-MOD WP1 - CASM `.ASSERT` ca65-compatible action keyword

Plan: `brain/plans/2026-09-01-dash-mod-wp1-casm-assert-ca65-keyword.md`
Parent: `brain/plans/2026-09-01-dash-modernization.md`
Taskwarrior: WP1 `4e682aa2-3930-47f3-9b5b-8999fadf2104`
Branch: `feature/casm-phase14`

## What this WP delivers

CASM's `.ASSERT` grammar now also accepts ca65's required form:

```
.ASSERT expr, ACTION [, "message"]      ACTION in {ERROR, WARNING, LDERROR, LDWARNING}
```

The keyword is matched (case-folded, via `compareTokenText`), consumed,
and **discarded** -- CASM evaluates every form at pass time and is fatal
on a false result. No `emit.s` change, no new state, no version bump.
Every pre-existing `.ASSERT` spelling is unchanged.

### Changes

- `lexer.s`: `.export compareTokenText` (was a lexer internal).
- `parser.s`: `.import compareTokenText`; `ppsAssert`'s `@haveComma`
  branch reworked -- after the first `,`, a `STRING` is still the
  message (legacy path untouched), an `IDENTIFIER` is matched against
  `ppsAssertMatchAction`'s four unrolled `compareTokenText` calls, then
  an optional `, "message"` follows; anything else is `SYNTAX ERROR` at
  that token. Four null-terminated keyword strings in a new parser.s
  `RODATA` block.
- `src/external/dash/AGENTS.md`: new "Dual-Assembler Subset" bullet --
  `.ASSERT` is shared in the ca65 action-keyword form only; the CASM
  legacy keyword-less forms are not ca65-compatible.

`casm.prg` +110 code bytes (24392 -> 24502); MAIN headroom ~1945 bytes,
still within `$7400`.

## Verification

### Build

`cmake --build build` fully clean -- the `compareTokenText` export did
not entangle any lexer-stubbing harness. Diagnostic table still "all 90
identifiers". `image_d64` + both CASM link configs clean.

### Live VICE -- 7 new fixtures on `casm_phase13_test.d64`, `CASM V0.5.2.1404`

| fixture | source | result |
| --- | --- | --- |
| `casmakw1` | `.ASSERT 1, ERROR` | `INPUT VALIDATED`, 3 bytes (assert emits none) |
| `casmakw2` | `.ASSERT 1, ERROR, "OK MSG"` | `INPUT VALIDATED` |
| `casmakw3` | `.ASSERT 0, ERROR, "BOOM"` | `CASM: ASSERTION FAILED: BOOM` at line 1 col 1 -- message threads through with an action present |
| `casmakw4` | `.ASSERT 0, WARNING` | `CASM: ASSERTION FAILED` -- WARNING is fatal, same as ERROR |
| `casmakw5` | `.ASSERT 1, LDERROR, "X"` | `INPUT VALIDATED` |
| `casmakwbad` | `.ASSERT 1, BOGUS` | `CASM: SYNTAX ERROR` at line 1 col 12 (`BOGUS`) |
| `casmakwbad2` | `.ASSERT 1, ERROR, 5` | `CASM: SYNTAX ERROR` at line 1 col 19 (`5`) |

### Legacy regression (live)

- `casmassert1` (`.ASSERT 1` / `.BYTE $AA`) -> `INPUT VALIDATED`, 3 bytes.
- `casmassertmsg` (`.ASSERT 0, "CUSTOM MESSAGE"`) -> `CASM: ASSERTION
  FAILED: CUSTOM MESSAGE`. Both keyword-less legacy forms still parse the
  exact same way.

### ca65 cross-check (de-risking WP3)

A throwaway `ca65` compile confirmed ca65 accepts every DASH-target
spelling, including `.assert PAGECOUNT = 1, error` with **no message**
and a **computed** `PAGECOUNT = (FOOEND - FOO)` under plain `error` (not
`lderror`). So WP3's `PAGECOUNT` and range invariants are known-good on
both assemblers.

## Overlay events

`test`/`testing` + `test`/`pass` for `dash-mod-wp1`, via curl (MCP down).

## Deferred to Phase 14 WP92

CHANGELOG entry and the CASM version bump -- this change ships as part of
that release, and WP92's consolidated gate re-verifies it alongside the
local-labels work.

## Sign-off requested

WP1 is source-complete and live-verified (7/7 new + 2 legacy regression,
ca65 cross-checked). Requesting approval to close WP1 and proceed to WP2
(full `@local` migration across DASH, output-preserving).
