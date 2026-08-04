# DEBUG REU/Address Syntax WP2 Walkthrough

**Status:** Confirmed by user 2026-08-04

**Build:** DEBUG 0.4.0 build 1119

**Branch:** `feature/debug-reu-address-wp2`

## Automated Evidence

- `cmake --build build --target debug image_d64 test_image_d64` passed with
  no warnings or errors attributable to WP2.
- DEBUG rebuilt clean at 6,885 code bytes and 762 relocation points -- byte-
  identical to the runtime bytes recorded for Increment 3's build 1119.
- The configured 8KB `MAIN` envelope was not changed.
- Static grep of `src/external/debug/debug.s` found zero references to
  `DOS_ALLOC_MEM`, `DOS_FREE_MEM`, `DOS_VMM_READ`, `DOS_VMM_WRITE`, or
  `DOS_GET_SYSTEM_INFO`. No VMM or system-information API is reachable from
  any `X` stub.
- Static read of `cmdReuAlloc`, `cmdReuFree`, `cmdReuMove`, and
  `cmdReuStatus` confirms each is `jmp reuStub`, and `reuStub` calls only
  `API_PRINT_STR`. No stub can write registry, zero-page, or BSS state.
- VICE 3.10 booted `build/image.d64`, displayed the Command64 0.4.1 banner,
  and launched DEBUG 0.4.0 build 1119 by name from the shell.
- VICE matrix results:
  - Accepted: `XA`, `XD`, `XM`, `XS`, `XA 0100`, `XD 0`,
    `XM 0 0000 6000 0001 R`, `XS 0`, and lowercase `xa` all printed
    `not yet implemented`.
  - Rejected: `X`, `X A`, `XX`, `X?`, `XAA`, `XMAP`, `XA0100`, and `XA:0100`
    all printed `error` with no stub text.
  - WP1 regression: `G =6000` (RTS fixture) returned cleanly; `T =6100` and
    `P =6100` (NOP/RTS fixture) traced and proceeded to `PC=$6101` as
    expected; `Q` returned to `c64[8]:>`.

## Safe Test Setup

Do not use the legacy `$4000/$5000` test ranges. Current DEBUG occupies
approximately `$3800-$52E4`. Use these commands at the DEBUG prompt:

```text
E 6000 60
E 6100 EA EA EA 60
```

This installs:

- `$6000`: `RTS`, for the `G` regression case.
- `$6100-$6103`: NOP/NOP/NOP/RTS, for the `T`/`P` regression cases.

## Extended Dispatch Confirmation

Run:

```text
XA
XD
XM
XS
xa
xd
xm
xs
XA 0100
XD 0
XM 0 0000 6000 0001 R
XS 0
```

Expected: every line prints `not yet implemented`. No registry byte changes
and no VMM activity occur.

Run:

```text
X
X A
XX
X?
XAA
XMAP
XA0100
XA:0100
```

Expected: every line prints `error`. No `not yet implemented` text appears
for any of these.

## Registry Zero-State Confirmation

At the first prompt after DEBUG loads (before any other command), inspect
the registry directly through the machine monitor:

```text
D 52D1 52E4
```

Expected: all 20 bytes read `00`. (Substitute the current build's registry
range if DEBUG's relocated size has changed; Increment 3 recorded
`$52D1-$52E4` for build 1119 at the standard `$3800` load address.)

## WP1 Regression Confirmation

Run:

```text
G =6000
T =6100
P =6100
Q
```

Expected:

- `G =6000` executes the installed `RTS` and returns to the `-` prompt
  without printing an error.
- `T =6100` traces to `PC=$6101` and disassembles `NOP`.
- `P =6100` proceeds to `PC=$6101` and disassembles `NOP`.
- `Q` returns to a shell prompt matching `c64[<device>]:>`.

## Confirmation Gate

The user confirmed this walkthrough on 2026-08-04. WP2 Increment 4 and the
overall WP2 task are marked complete in the wiki task, `brain/task.md`, and
Taskwarrior UUID `91036469-8479-4a27-83ab-e74158f2fdea`.
