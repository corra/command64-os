# Task Spec: DEBUG REU/Address Syntax WP2

## Objective

Implement exact extended-command dispatch and the four-slot DEBUG REU registry
foundation defined by
`brain/plans/2026-08-04-debug-reu-address-syntax-wp2.md`.

Taskwarrior UUID: `91036469-8479-4a27-83ab-e74158f2fdea`

## Scope

- Dispatch exact `XA`, `XD`, `XM`, and `XS` tokens to distinct stubs.
- Reject malformed extended tokens without registry changes.
- Add and explicitly initialize four DEBUG-owned registry slots.
- Add handle, free-slot, record, and common error helpers.
- Call no VMM or system-information API before WP3.
- Preserve WP1 execution syntax and existing DEBUG behavior.

## Increments

- [x] Increment 1: exact extended dispatch, stubs, selectors, build, and VICE
      routing verification.
- [x] Increment 2: registry storage, explicit startup initialization, build,
      and zero-state verification.
- [x] Increment 3: registry helper implementation and contract verification.
- [x] Increment 4: full regression, artifact audit, documentation, DOX, and
      user-confirmed walkthrough.

## Acceptance

- [x] Only exact `XA`, `XD`, `XM`, and `XS` tokens route to stubs or handlers.
- [x] Malformed `X` tokens fail without state changes.
- [x] Four registry slots initialize deterministically.
- [x] Registry helpers satisfy documented carry/register/error contracts.
- [x] WP2 adds no VMM API call and no private zero-page state.
- [x] DEBUG remains relocatable and inside its existing linker envelope.
- [ ] The user confirms the walkthrough before WP2 is marked complete.

## Increment 1 Evidence

- Added exact first-character `X` routing, shifted/unshifted second-character
  normalization, token-boundary validation, four distinct handler stubs, and
  all parent-plan internal error selectors.
- The first build failed before assembly because the edit application omitted
  the selector definitions while adding their call sites. Adding the missing
  definitions resolved the root cause without changing dispatch design; build
  1115 is not a valid artifact.
- DEBUG build 1116 succeeded at 6,737 code bytes and 748 relocation points
  inside the unchanged 8KB `MAIN` envelope; `image_d64` also built.
- VICE booted `build/image.d64`, proved the Command64 banner, and launched
  DEBUG 0.4.0 build 1116 by name.
- `XA`, `XD`, `XM`, `XS`, and argument-bearing forms all printed
  `NOT YET IMPLEMENTED`; shifted/uppercase forms routed identically.
- `X`, `X A`, `XX`, `X?`, `XAA`, `XMAP`, `XA0100`, and `XA:0100` printed
  `ERROR` without stub output.
- `Q` returned to `c64[8]:>`. No registry state or VMM API call exists yet.

## Increment 2 Evidence

- Added `REU_HANDLE_COUNT = 4` and five four-byte arrays: `reuActive`,
  `reuSegHi`, `reuBank`, `reuParagraphLo`, and `reuParagraphHi`.
- Added `initReuRegistry` before the startup banner. It explicitly clears all
  20 bytes while preserving `Y`; no zero-page or OS parameter-cell state was
  added.
- DEBUG build 1117 succeeded at 6,783 code bytes and 754 relocation points.
  Growth from Increment 1 is 46 bytes: exactly 20 registry bytes and 26 bytes
  of initialization call/routine code. `image_d64` also built successfully.
- At standard `$3800` load address, the registry occupies `$526B-$527E`.
  VICE observed 20 zero bytes at the first DEBUG prompt.
- Monitor setup replaced all fields with `01..14`; `XA`, `XD`, `XM`, and `XS`
  stubs preserved the pattern exactly, proving no stub state mutation.
- After `Q` and a second shell-launched DEBUG session, all 20 registry bytes
  were zero again. Both sessions returned normally to `c64[8]:>`.
- DOX closeout added and indexed `src/external/debug/AGENTS.md` to record the
  new durable VMM ownership and registry-initialization contracts.

## Increment 3 Evidence

- Added `parseReuHandle`, `findFreeReuHandle`, and `getReuRecord` with explicit
  register, carry, selector, parser-position, and stack contracts.
- Exported only the three helper labels at object-link scope for deterministic
  monitor verification; this changed no runtime bytes or public OS API.
- DEBUG build 1119 succeeded at 6,885 code bytes and 762 relocation points,
  adding 102 helper bytes over Increment 2. Build 1118 had identical runtime
  bytes; 1119 adds verification metadata only. `image_d64` built successfully.
- Loaded-image tracing established `parseReuHandle=$39CE`,
  `findFreeReuHandle=$3A01`, `getReuRecord=$3A15`, registry `$52D1-$52E4`, and
  `inputBuf=$526C` for build 1119 at standard `$3800` load address.
- `parseReuHandle` accepted inactive-permitted handle 2, returned inactive
  selector 6 when active state was required, returned missing selector 2 for
  empty input, and returned range selector 4 for handle 4. The internal mode
  stack byte balanced on every path before the synthetic test RTS.
- `findFreeReuHandle` returned the lowest free slots 0 and 2 for controlled
  registry patterns, then returned registry-full selector 7 when all slots
  were active.
- `getReuRecord` returned `X=$AB`/`Y=$CD` for active handle 2, returned inactive
  selector 6 for handle 1, and invalid-handle selector 5 for handle 4 while
  preserving candidate `X` on both failures.
- Verification used direct monitor-controlled helper invocation and terminated
  the synthetic-stack session rather than resuming it. No VMM API was called.

## Increment 4 Evidence

- Rebuilt `debug` clean: 6,885 code bytes and 762 relocation points, identical
  to build 1119's runtime bytes; still inside the unchanged 8KB `MAIN`
  envelope. `image_d64` and `test_image_d64` both built with no warnings or
  errors attributable to WP2.
- VICE booted `build/image.d64`, proved the Command64 banner, and launched
  DEBUG 0.4.0 build 1119 by name.
- Accepted-token matrix: bare `XA`, `XD`, `XM`, `XS` and argument forms
  `XA 0100`, `XD 0`, `XM 0 0000 6000 0001 R`, `XS 0` all printed
  `not yet implemented`.
- Rejected-token matrix: `X`, `X A`, `XX`, `X?`, `XAA`, `XMAP`, `XA0100`, and
  `XA:0100` all printed `error` with no stub text.
- Shift/case form: lowercase `xa` normalized identically to `XA`.
- Static audit: `cmdReuAlloc`/`cmdReuFree`/`cmdReuMove`/`cmdReuStatus` each
  resolve to `jmp reuStub`, and `reuStub` calls only `API_PRINT_STR` -- no
  stub reaches a memory-writing instruction, so registry state cannot change
  through dispatch. `grep` for `DOS_ALLOC_MEM`, `DOS_FREE_MEM`,
  `DOS_VMM_READ`, `DOS_VMM_WRITE`, and `DOS_GET_SYSTEM_INFO` in `debug.s`
  returned zero matches.
- WP1 regression: `G =6000` (RTS fixture), `T =6100` and `P =6100` (NOP/RTS
  fixture) all executed and returned as documented; `Q` returned cleanly to
  `c64[8]:>`.
- No new private zero-page symbol was introduced; the registry remains the
  20-byte BSS block added in Increment 2.
