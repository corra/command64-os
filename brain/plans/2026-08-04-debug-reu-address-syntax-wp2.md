# DEBUG REU and Address Syntax WP2 Detailed Plan

**Status:** Approved; implementation in progress

**Created:** 2026-08-04

**Parent plan:** `brain/plans/2026-08-03-debug-reu-and-address-syntax.md`

**Work package:** WP2, Extended Dispatch and REU Registry

**Implementation target:** `src/external/debug/debug.s`

**Implementation branch:** `feature/debug-reu-address-wp2`

## 1. Purpose

Establish the internal structure required by later DEBUG REU commands without
allocating, freeing, reporting, or transferring REU memory yet.

WP2 adds exact `XA`/`XD`/`XM`/`XS` dispatch, a four-slot DEBUG-owned allocation
registry, startup initialization, handle/record helpers, and internal error
selectors. Each recognized command routes to a distinct temporary stub until
its implementing work package lands.

## 2. Confirmed Baseline

1. `dispatch` leaves `Y` immediately after the first command character.
2. Existing first-character dispatch normalizes shifted/unshifted command
   letters before comparing lowercase command constants.
3. Unknown commands print `errUnknown` and return to the prompt.
4. `requireEnd`, `skipSpaces`, and `parseHexArg` are available from WP1.
5. `parseHexArg` returns one-to-four-digit values in `HexValLo/HexValHi` and
   leaves `Y` at the first non-hex byte.
6. DEBUG has no separate BSS source module; its linked ordinary variables and
   `.res` buffers are declared at the end of `debug.s`.
7. DEBUG's private zero-page `$70-$7F` is fully occupied. WP2 adds no zero-page
   state and does not retain state in OS parameter cells `$66-$6C`.
8. The merged WP1 binary is DEBUG build 1114, 6,595 code bytes with 723
   relocation points inside the existing 8KB `MAIN` envelope.
9. `DOS_ALLOC_MEM`, `DOS_FREE_MEM`, `DOS_VMM_READ`, and `DOS_VMM_WRITE` are
   public through `OS_API`, but WP2 must not call them.

## 3. Scope

### 3.1 Included

- Add first-character `X` dispatch.
- Add `cmdExtended` with exact second-character dispatch.
- Normalize shifted/unshifted `A`, `D`, `M`, and `S` consistently with current
  command dispatch.
- Require a token boundary after the second command character.
- Add distinct `cmdReuAlloc`, `cmdReuFree`, `cmdReuMove`, and `cmdReuStatus`
  stubs.
- Add a four-slot allocation registry using ordinary linked storage.
- Explicitly clear every registry field at DEBUG startup.
- Add `parseReuHandle`, `findFreeReuHandle`, and `getReuRecord`.
- Add internal REU error selectors and one common error reporter.
- Build and inspect DEBUG size, relocation, and storage growth.
- Verify exact routing and malformed-token rejection under VICE.

### 3.2 Excluded

- Calling any VMM or system-information API.
- Allocating or freeing REU memory.
- Implementing `XA`, `XD`, `XM`, or `XS` command behavior.
- Transfer state or `page:offset` parsing.
- Cleanup-on-`Q` behavior.
- New user-facing diagnostics beyond the temporary stub and generic error.
- DEBUG version changes; the combined release version remains deferred.
- New private zero-page state.

## 4. Fixed Registry Contract

WP2 uses four simultaneous DEBUG handles, numbered `$0-$3`.

Define:

```text
REU_HANDLE_COUNT = 4
```

Add parallel ordinary-storage arrays:

```text
reuActive[4]
reuSegHi[4]
reuBank[4]
reuParagraphLo[4]
reuParagraphHi[4]
```

Total registry growth is exactly 20 bytes.

Field meanings:

- `reuActive`: zero means free; nonzero means DEBUG owns a live VMM grant.
- `reuSegHi`: segment-high identity returned by `DOS_ALLOC_MEM` in later WP3.
- `reuBank`: REU bank returned by `DOS_ALLOC_MEM` in later WP3.
- `reuParagraphLo/Hi`: exact requested paragraph capacity used by later bounds
  checks.

WP2 stores no page count or byte capacity because those values can be derived
from the paragraph count. Registry records remain DEBUG-local; raw identities
never become command handles.

## 5. Startup Initialization

Add `initReuRegistry` and call it from `start` after `currentAddr` is initialized
and before the welcome message is printed.

Contract:

- Clear all five fields for all four slots explicitly.
- Do not rely on PRG/BSS zero fill.
- Input: none.
- Output: every registry byte is zero.
- Clobber: `A`, `X`, processor flags.
- Preserve: `Y`.
- Return carry has no defined meaning.

Clearing all fields, not only `reuActive`, gives deterministic helper and VICE
inspection evidence without changing the ownership rule that only active state
authorizes a record.

## 6. Extended Dispatch

### 6.1 First Character

Add `x` to the existing command registry immediately before the unknown-command
fallback:

```text
X -> cmdExtended
```

Preserve all existing command ordering and behavior.

### 6.2 `cmdExtended`

Input:

- `Y` points immediately after `X`.

Algorithm:

1. Read the second byte without skipping spaces.
2. Reject null or space, so bare `X` and `X A` are malformed tokens.
3. Normalize shifted/unshifted command letters using the same PETSCII approach
   as first-character dispatch.
4. Accept only `A`, `D`, `M`, or `S`.
5. Increment `Y` past the second character.
6. Require the next byte to be null or a space.
7. Reject every other byte before calling a subcommand stub.
8. Skip argument-leading spaces only after token termination is proven.
9. Jump to the selected distinct stub with `Y` at its first argument or null.

Accepted routing tokens:

```text
XA
XD
XM
XS
XA <arguments>
XD <arguments>
XM <arguments>
XS <arguments>
```

Rejected tokens:

```text
X
X A
XMAP
XAA
XX
X?
XA:0100
XA0100
```

Malformed tokens must reach the common REU error reporter without touching the
registry or printing the temporary implementation stub.

## 7. Temporary Command Stubs

Add four labels:

```text
cmdReuAlloc
cmdReuFree
cmdReuMove
cmdReuStatus
```

Each stub must be structurally distinct so VICE checkpoints can prove routing.
For WP2, each may load the shared `msgStub`, print `not yet implemented`, and
return. Do not parse or mutate arguments in the stubs.

The stubs are replaced incrementally by WP3-WP6. Their temporary acceptance of
arbitrary argument text is not a public command contract; only dispatch-token
exactness is under verification in WP2.

Do not add `X` commands to the public help text until at least their lifecycle
handlers exist. This avoids advertising nonfunctional commands.

## 8. Internal Error Selectors

Define stable internal selectors for the parent plan's error classes:

```text
REU_ERR_SYNTAX
REU_ERR_MISSING_ARG
REU_ERR_TRAILING_INPUT
REU_ERR_VALUE_RANGE
REU_ERR_INVALID_HANDLE
REU_ERR_INACTIVE_HANDLE
REU_ERR_REGISTRY_FULL
REU_ERR_VMM_UNAVAILABLE
REU_ERR_VMM_NOMEM
REU_ERR_PAGE_OFFSET
REU_ERR_ALLOC_WINDOW
REU_ERR_C64_WINDOW
REU_ERR_DIRECTION
REU_ERR_PARTIAL_TRANSFER
REU_ERR_CLEANUP
```

Values must be unique, nonzero bytes. Their numeric values are internal and may
be contiguous.

Add `reuError`:

- Input: `A` contains the selector.
- Print the existing generic `error` message in WP2.
- Restore the selector to `A` after printing.
- Return carry set.
- Preserve `X`.
- `Y` may be clobbered by string printing.

This preserves machine-visible error distinctions while deferring expanded
user diagnostics.

## 9. Helper Contracts

### 9.1 `parseReuHandle`

Input:

- `Y`: first handle operand byte or leading spaces.
- `A`: zero permits an inactive slot; nonzero requires an active slot.

Output on success:

- `X`: handle `$0-$3`.
- `Y`: first byte after the hexadecimal handle.
- `A`: zero.
- Carry clear.

Output on failure:

- `A`: `REU_ERR_MISSING_ARG`, `REU_ERR_VALUE_RANGE`, or
  `REU_ERR_INACTIVE_HANDLE`.
- Carry set.
- `Y`: parser failure position.

Implementation requirements:

1. Preserve the active-required mode on the hardware stack across
   `skipSpaces` and `parseHexArg`.
2. Detect null before parsing and classify it as missing argument.
3. Reject parse failure as value/syntax range for WP2.
4. Require `HexValHi == 0` and `HexValLo < REU_HANDLE_COUNT`.
5. Return the low-byte handle in `X`.
6. If active mode is requested, reject `reuActive,X == 0`.
7. Balance the hardware stack on every success and failure path.
8. Leave delimiter and end-of-input validation to the command caller.

`parseReuHandle` must not call an OS API or alter any registry field.

### 9.2 `findFreeReuHandle`

Input: none.

Output on success:

- `X`: lowest-numbered inactive slot.
- `A`: zero.
- Carry clear.

Output on failure:

- `A`: `REU_ERR_REGISTRY_FULL`.
- Carry set.
- `X`: clobbered.

Scan exactly four entries and do not inspect stale metadata in inactive slots.

### 9.3 `getReuRecord`

Input:

- `X`: candidate handle.

Output on success:

- `X`: stored `SegHi`.
- `Y`: stored bank.
- `A`: zero.
- Carry clear.

Output on failure:

- `A`: `REU_ERR_INVALID_HANDLE` or `REU_ERR_INACTIVE_HANDLE`.
- Carry set.
- `X` remains the candidate handle on failure.

Validate `X < REU_HANDLE_COUNT` before indexing. Never return metadata for an
inactive record. Later WP3 callers use the returned `X/Y` pair directly for
`DOS_FREE_MEM`.

## 10. Atomic Implementation Increments

### Increment 1: Exact Extended Dispatch

1. Define REU error selectors and `reuError`.
2. Add first-character `X` routing.
3. Add `cmdExtended` exact token parsing.
4. Add four distinct temporary stubs.
5. Build DEBUG.
6. Verify valid tokens route and malformed tokens reject.

Exit criterion: only exact `XA`, `XD`, `XM`, and `XS` tokens reach their
distinct stubs; malformed `X` tokens report error.

### Increment 2: Registry And Startup Initialization

1. Add `REU_HANDLE_COUNT`.
2. Add the five four-byte arrays.
3. Add `initReuRegistry`.
4. Call initialization from `start` before the welcome message.
5. Build DEBUG and measure exact linked growth.
6. Use VICE memory inspection to prove all 20 bytes initialize to zero.

Exit criterion: deterministic empty registry state exists at every DEBUG start
without new zero-page ownership.

### Increment 3: Registry Helpers

1. Implement `parseReuHandle` with balanced-stack active mode.
2. Implement `findFreeReuHandle`.
3. Implement `getReuRecord`.
4. Add static call-contract comments.
5. Build DEBUG and inspect branch ranges and relocation changes.
6. Verify helpers through temporary checkpoints/register setup or a dedicated
   test-only path that does not ship.

Exit criterion: range, active-state, free-slot, full-registry, and record-return
paths satisfy their carry/selector contracts without OS access.

### Increment 4: WP2 Regression And Completion Gate

1. Build `debug`, `image_d64`, and `test_image_d64`.
2. Run exact dispatch and malformed-token VICE matrices.
3. Re-run WP1 `G`/`T`/`P` smoke cases.
4. Inspect registry storage, DEBUG envelope, and relocation output.
5. Confirm no VMM API call is reachable from any `X` stub.
6. Update task, changelog, state, and DOX records.
7. Produce the manual walkthrough and obtain user confirmation.

Exit criterion: WP2 routing and helper contracts pass with no allocation,
transfer, cleanup, or existing-command regression.

## 11. Build And Static Verification

Use CMake only; do not invoke ca65 or ld65 directly.

1. Build `debug` after each increment.
2. Build `image_d64` before VICE work.
3. Build `test_image_d64` at the completion gate.
4. Require no warnings or errors attributable to WP2.
5. Record DEBUG code bytes and relocation count.
6. Confirm the binary remains within the existing 8KB `MAIN` envelope.
7. Confirm registry storage adds exactly 20 bytes before helper/stub code
   effects.
8. Confirm no new `$70-$7F` symbol or ownership.
9. Confirm no call to `DOS_ALLOC_MEM`, `DOS_FREE_MEM`, `DOS_VMM_READ`,
   `DOS_VMM_WRITE`, or `DOS_GET_SYSTEM_INFO` is added.
10. Let CMake update `BUILD_DEBUG`; never edit generated includes.

## 12. VICE Verification Matrix

Follow `.agents/workflows/vice-mcp-testing.md`: boot Command64 from the selected
image, prove the banner, launch DEBUG by name, and prove shell return.

### Accepted Tokens

```text
XA
XD
XM
XS
XA 0100
XD 0
XM 0 0000 6000 0001 R
XS 0
```

Expected in WP2: each exact token reaches its corresponding temporary stub and
prints `not yet implemented`.

### Shift/Case Forms

Enter each token through the keyboard forms already accepted by normal DEBUG
dispatch. Expected: second letters normalize consistently with first letters.

### Rejected Tokens

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

Expected: each prints `error`, no stub text, and no registry byte changes.

### Registry State

- At first DEBUG prompt, all 20 registry bytes are zero.
- Mutate the registry only through monitor-controlled test setup when exercising
  helper paths; command stubs themselves must leave it unchanged.
- Restart DEBUG and prove explicit initialization clears all fields again.

### Existing Command Smoke

- `G =6000` reaches a safe RTS-terminated routine.
- `T =6100` advances a safe NOP sequence.
- `P =6100` preserves proceed behavior.
- `Q` returns to `c64[<device>]:>`.

## 13. Documentation And Tracking

After plan approval and before source implementation:

1. Create a measurable `wiki/tasks/debug-reu-address-syntax-wp2.md` task.
2. Create and activate the matching Taskwarrior task.
3. Synchronize `brain/task.md`.

During implementation:

- Record build and verification evidence after each increment.
- Add `CHANGELOG.md` behavior only when exact `X` dispatch lands.
- Update `brain/MEMORY.md` when the 20-byte registry is added.
- Defer public DEBUG user-guide command syntax to the lifecycle work packages;
  WP2 stubs are intentionally not public functionality.
- Perform the mandatory DOX closeout. Applicable source contracts are root
  `AGENTS.md`, `src/AGENTS.md`, and `src/external/AGENTS.md`; task changes also
  require `wiki/AGENTS.md` and `wiki/tasks/AGENTS.md`.
- Update AGENTS files only if purpose, ownership, workflow, structure, or
  durable contracts change.

## 14. Risks And Controls

- **Token-prefix acceptance:** checking only the second character would let
  `XMAP` route as `XM`. Control: prove null/space immediately after byte two.
- **Shifted PETSCII mismatch:** a new normalization shortcut could differ from
  existing dispatch. Control: mirror the existing comparison/bit-clear path and
  verify shifted/unshifted input.
- **Stack imbalance in `parseReuHandle`:** mode preservation adds a stack byte
  across multiple failures. Control: one common unwind path per error class and
  static SP review.
- **Inactive-record leakage:** returning stale metadata could later free another
  allocation. Control: `getReuRecord` validates range and active state before
  reading identity fields.
- **Hidden OS coupling:** convenient helper tests might call VMM early. Control:
  graph/static audit proves no new VMM API call in WP2.
- **Envelope pressure:** dispatch, stubs, helpers, selectors, and 20-byte state
  grow DEBUG. Control: measure every increment against the existing 8KB limit.

## 15. Completion Gate

WP2 may be presented for user confirmation when:

1. Exact `XA`/`XD`/`XM`/`XS` dispatch is implemented.
2. Malformed `X` tokens fail without state mutation.
3. Four registry slots initialize deterministically.
4. `parseReuHandle`, `findFreeReuHandle`, and `getReuRecord` satisfy their
   documented carry/register/error contracts.
5. No VMM or system-information API is called.
6. No new private zero-page state exists.
7. DEBUG remains relocatable and inside its linker envelope.
8. WP1 execution syntax smoke tests still pass.
9. Task, changelog, memory, and DOX records are synchronized.
10. A manual walkthrough is available.

Do not mark WP2 complete until the user confirms the walkthrough.
