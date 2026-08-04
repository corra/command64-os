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
- [ ] Increment 3: registry helper implementation and contract verification.
- [ ] Increment 4: full regression, artifact audit, documentation, DOX, and
      user-confirmed walkthrough.

## Acceptance

- [ ] Only exact `XA`, `XD`, `XM`, and `XS` tokens route to stubs or handlers.
- [ ] Malformed `X` tokens fail without state changes.
- [ ] Four registry slots initialize deterministically.
- [ ] Registry helpers satisfy documented carry/register/error contracts.
- [ ] WP2 adds no VMM API call and no private zero-page state.
- [ ] DEBUG remains relocatable and inside its existing linker envelope.
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
