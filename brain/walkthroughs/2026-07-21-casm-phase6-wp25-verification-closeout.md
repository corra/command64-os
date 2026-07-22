---
feature: casm-phase6-wp25-verification-closeout
created: 2026-07-22
status: complete
---

# Walkthrough: CASM Phase 6A WP25 Verification, Walkthrough, and Completion Gate

Plan: `brain/plans/2026-07-21-casm-phase6-wp25-verification-closeout.md`

Taskwarrior: `544a04bd-4ccb-47c6-9013-8af57aa37353`

## Outcome

WP25 built a standalone runtime fixture harness (`test_casm_vmm`) covering
the seven automatable cases of WP22's fixture matrix, ran it in VICE, and
in doing so exercised WP23/WP24's `vmm_store.s` code for the very first
time since it was written — both prior work packages explicitly deferred
any real call site. That first real run found three defects (documented
below) that no static review or ca65/ld65 build had caught. All were fixed
and the full matrix now passes. `vmmalloc4` and `vmmnoreu` are documented
as manually deferred, per the plan's own reconciliation.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp25` |
| Branch point | `feature/casm-phase6-wp24` at `3fd1f10` |
| Baseline version | `0.1.26.1099` |
| Plan approval | Approved as drafted, including both resolved open questions |

## Defects Found by the First Runtime Matrix

None of these were caught by ca65/ld65's build (both succeeded cleanly at
every step) or by the static review WP23/WP24 already went through —
consistent with those packages never having a real call site to exercise
this code before now.

1. **Test defect — `vmmalloc3` expected the wrong diagnostic.** The
   fixture's 9th-allocation check expected `CASM_DIAG_REGISTRY_FULL`, but
   `vmmStoreAlloc` deliberately collapses a registry-full
   `resourceRegisterVmm` rejection into `CASM_DIAG_VMM_ALLOC_FAILED` (after
   freeing the just-granted OS memory again), per its own documented WP23
   ABI. The mismatch made the fixture bail out *before* its free loop ran,
   permanently leaking all 8 registry slots and cascading into every later
   fixture failing (`..fffff` on the first real run). Fixed by correcting
   the test's expectation to `CASM_DIAG_VMM_ALLOC_FAILED`; the production
   code was already correct.
2. **Production defect — `vwPrepareTransfer` rejected the valid
   exact-65536-byte boundary.** The offset+count 16-bit overflow check
   (`bcs vwRejected` after the add) treated any carry-out as a rejection,
   but offset+count landing on exactly 65536 (the addressing cap, e.g. the
   last valid window of a full-cap allocation) also wraps the 16-bit add to
   zero with carry set — indistinguishable from a genuine over-cap request
   by carry alone. Fixed by checking whether the wrapped remainder is
   exactly zero (valid, true sum was exactly 65536) versus nonzero (true
   sum exceeds the cap). Caught by `vmmoffset1` (second real run:
   `...ff..`, then `...5f...` once this fix was in place, `vmmoffset1`
   passing).
3. **Production defect — `vmmReplay` clobbered its own stashed slot.**
   `vmmReplay` stashed the input slot in `CasmValue0Lo` across its internal
   `vmmWindowWrite`/`vmmWindowRead` calls, but both call
   `vwPrepareTransfer`, which documents `CasmValue0Lo`/`CasmValue0Hi` as its
   own clobbered offset+count scratch. The first call's `vwPrepareTransfer`
   overwrote the stashed slot with the offset+count sum (16, in this
   fixture's case), so the second call read back a corrupted, out-of-range
   "slot" that `vwPrepareTransfer`'s own bounds check correctly rejected.
   The same class of shared-scratch bug WP23 already caught twice
   (`vmmStoreFree`, `resourcesCleanup`'s VMM loop), now found a third time.
   Fixed by stashing in `CasmValue1Lo` instead, which neither
   `vwPrepareTransfer` nor its callees touch.

Found by adding temporary per-step diagnostic instrumentation to the
failing fixture (printing an ASCII digit for which internal check failed)
after live VICE debugging proved too fragile to trust in this session — a
stray leftover breakpoint from an earlier debugging attempt silently
paused a supposedly-fresh run, and an improvised direct-PC-jump (bypassing
the shell's own loader) produced a misleading, likely-corrupted state. Both
mistakes were mine; the instrumentation approach avoided needing any
further live stepping and was removed from the test once the bug was
confirmed fixed (`vmmreplay1` passing: `...5f...` -> clean pass).

User approved fixing all three in place within WP25 rather than opening a
separate remediation plan, given how narrow and well-understood each fix
was.

## Implementation

- `tests/src/casm_vmm/casm_vmm.s` (new): standalone fixture harness,
  isolated to `vmm_store.s` + `resources.s` + `common.inc` by exporting a
  trivial local `diagPrintFatal` stub — importing `resourceRegisterVmm`
  alone would otherwise pull in all of `resources.o`, whose
  `exitSuccess`/`exitFatal` reference the real `diagPrintFatal`
  (`diagnostics.s`), which itself transitively needs `lexer.s`/`source.s`.
  Matches WP20's `casm_expr.s` precedent of stubbing peripheral symbols
  rather than importing the real modules.
- Seven sequential fixtures (not an independent table, since VMM operations
  have real side effects on shared registry/REU state across one PRG
  execution): `vmmalloc1`, `vmmalloc2`, `vmmalloc3`, `vmmreplay1` (covering
  write/read/replay together), `vmmoffset1`, `vmmbounds1`, `vmmfree1`.
  `vmmalloc4` and `vmmnoreu` are documented in the harness's own header
  comment as manually deferred, not implemented.
- `CMakeLists.txt`: added the `casm_vmm` special case to the `TEST_CA65_SRCS`
  loop, matching `casm_expr`'s pattern exactly.
- `src/external/casm/vmm_store.s`: two defect fixes (above), unplanned but
  approved in place.

## Static Verification

- `od65 --dump-segsize vmm_store.o`: CODE grew from 325 to 336 bytes (the
  two fixes); BSS unchanged (32 bytes, `CasmVmmBuffer`); no RODATA/DATA/
  ZEROPAGE.
- `od65 --dump-imports/--dump-exports casm_vmm.o`: imports exactly
  `CasmVmmRegistry`, `CasmVmmBuffer`, `vmmReplay`, `vmmWindowWrite`,
  `vmmWindowRead`, `vmmStoreFree`, `vmmStoreAlloc`, `resourcesInit`,
  `__MAIN_START__`; exports exactly `diagPrintFatal`. Confirms the harness
  never pulled in `diagnostics.s`/`lexer.s`/`source.s`.
- `od65 --dump-imports resources.o` (within the test link): confirms
  `diagPrintFatal` resolves to the harness's own stub, not the real one.
- MAIN headroom (production `casm` target) after the two `vmm_store.s`
  fixes: 10,886/11,008 bytes at the approved `$2B00`, 122 bytes free — no
  MAIN size change needed.
- `test_casm_vmm` builds cleanly at both relocation bases.

## Runtime Verification

Three real runs in VICE, each after fixing what the previous run found:

| Run | Output | Result |
| --- | --- | --- |
| 1 | `..fffff` | `vmmalloc3`'s wrong diagnostic expectation cascaded into 5 failures |
| 2 (after fix 1) | `...ff..` | `vmmalloc3` now passes; `vmmreplay1`/`vmmoffset1` fail |
| 3 (after fixes 2+3, with temporary per-step instrumentation) | `...5f...` | isolated `vmmreplay1`'s failure to its internal step 5 (the `vmmReplay` call itself) |
| 4 (final, instrumentation removed) | `CASM VMM: PASS` | all 7 automated fixtures pass |

`test_image_d64` and `image_d64` both build and boot correctly with the
fixed `vmm_store.s`.

## Phase 6A Acceptance

Closed out in `wiki/tasks/casm.md`:

- [x] Phase 0C.4 VMM record contract and task hierarchy frozen by WP22.
- [x] Real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring replaces `cleanupVmmStub`
      (WP23).
- [x] Windowed `DOS_VMM_READ`/`DOS_VMM_WRITE` transfers are bounds-checked
      against each allocation's granted size (WP24, defect-fixed by WP25).
- [x] Bounded VMM records are written, read, and replayed without
      depending on source or symbol semantics — verified by `vmmreplay1`.
- [/] Allocation-exhaustion (registry-full) diagnostics are stable and
      exit cleanly with no partial ownership, verified by `vmmalloc3`.
      No-REU and real REU-capacity exhaustion remain manually deferred
      (`vmmnoreu`/`vmmalloc4`), not automated.
- [ ] User completes the WP25 runtime walkthrough and approves CASM
      Phase 6A.

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `tests`, `wiki`, and
`wiki/tasks` contracts rechecked. No `AGENTS.md` changed: WP25 introduces
no new directory boundary or durable operating rule.

## Manual Confirmation

The user ran `TEST.CASM.VMM` from `build/test.d64` in VICE four times
across this session (three investigative, one final), each from a full
disk boot through the Command 64 shell (matching the supported local
environment, not a raw emulator load). The final run reports
`CASM VMM: PASS` with all 7 dots and no `F`.

### Completion Dry-Run (`0.1.26` -> `0.1.27`)

| Measurement | Candidate (`0.1.26.1101`) | Dry run (`0.1.27.1102`) |
| --- | ---: | ---: |
| `BUILD_CASM` | 1101 | 1102 |
| PRG SHA-256 | `4b3c4a96...10916` | `67dad47a...cd3da` |

- `BUILD_CASM` incremented exactly once (1101 -> 1102) on the dry-run edit.
- Immediate no-change rebuild: stable at 1102 (no second increment).
- `cmp -l` reported exactly two changed bytes: the version-stage digit
  (`'6' -> '7'`) and the build-number digit (`'1' -> '2'`). No functional
  payload, storage, or relocation count changed.
- `test_image_d64` / `image_d64`: both pass at the `0.1.27.1102` dry-run
  state.
- Restoration via `git checkout -- src/external/casm/casm.s` plus restoring
  `BUILD_CASM` to its candidate content: rebuild reproduced the candidate
  PRG hash exactly (`4b3c4a96...10916`). Both images pass again at the
  restored candidate baseline.
- `git diff --check`: pass.
- No prohibited C64-testing MCP or web emulator used for any build/dry-run
  step (the earlier live-VICE debugging detour used the project's own
  supported VICE MCP tooling, not a prohibited one, but was abandoned as
  too fragile to trust for this session — see Defects Found, above).

## Approval

The user approved WP25 completion.

## Final Increment (post-approval)

| Measurement | Value |
| --- | --- |
| Applied version | `0.1.27` |
| Build number | 1102 |
| PRG SHA-256 | `67dad47a49bae623df2da3f4d467a57008e8d37de4e49dc63e8207a85e1cd3da` (matches the dry run exactly) |
| No-change rebuild | pass, held at 1102 across two additional rebuilds |
| `test_image_d64` | pass |
| `image_d64` | pass |

WP25 is complete. Taskwarrior (`544a04bd`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. **The CASM Phase 6A milestone
(`d68e6c58`) is complete**: WP22-WP25 all done, real
`DOS_ALLOC_MEM`/`DOS_FREE_MEM`/`DOS_VMM_READ`/`DOS_VMM_WRITE` wiring
verified end-to-end, and the Phase 6A completion gate satisfied. CASM
Phase 6B (symbol table and two-pass assembly) remains a separately gated,
unstarted phase — its work packages (WP26-WP31) are reserved in the
parent plan but not yet created in Taskwarrior, and require their own
approval to begin.
