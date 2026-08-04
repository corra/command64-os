# DEBUG REU Access and Address Syntax Implementation Plan

**Status:** Unified draft for review

**Created:** 2026-08-03

**Primary implementation:** `src/external/debug/debug.s`
**Source proposals:**

- `brain/plans/2026-08-03-debug-reu-access.md`
- `brain/plans/2026-08-03-debug-memory-address-syntax.md`

This document combines the REU-access and memory-address syntax proposals into
one implementation and verification boundary. Until this unified draft is
approved, the source proposals remain review inputs. After approval, mark both
source proposals as superseded by this document, but retain them as decision
history.

## 1. Objective

Bring Command64 DEBUG closer to MS-DOS DEBUG syntax while adding explicit,
safe access to VMM-managed REU memory.

The implementation will:

1. Accept optional MS-DOS-style `=` execution-address syntax for `G`, `T`,
   and `P` without breaking existing bare-address commands.
2. Add `XA`, `XD`, `XM`, and `XS` as an adapted expanded-memory command
   family backed exclusively by Command64 VMM APIs.
3. Let `XM` address a DEBUG allocation with either a flat byte offset or an
   allocation-relative 4KB `page:offset` operand.
4. Keep all existing memory, assembly, execution, and file commands confined
   to the 6510's base 64KB address space.
5. Validate complete commands and transfer windows before execution or DMA.
6. Preserve DEBUG relocation, zero-page ownership, and existing command
   behavior.

## 2. Authoritative Scope

### 2.1 Permissive Execution Syntax

The following forms are equivalent:

```text
G 4000
G =4000

T 4000
T =4000

P 4000
P =4000
```

No-argument behavior remains unchanged:

```text
G       ; execute at currentAddr
T       ; trace at regPC
P       ; proceed at regPC
```

Whitespace is accepted around `=`:

```text
G=4000
G =4000
G= 4000
G = 4000
```

The `=` prefix is recognized only by `G`, `T`, and `P`. It is not added to
ordinary memory, file, assembler, or REU commands.

Unsupported MS-DOS arguments remain errors:

```text
G =4000 4500   ; no G breakpoint list in this work
T =4000 10     ; no trace count in this work
P =4000 10     ; no proceed count in this work
```

This is permissive compatibility, not strict MS-DOS parsing. A bare `G 4000`
continues to mean "execute at `$4000`" rather than "set a breakpoint at
`$4000`."

### 2.2 REU Command Family

Implement these commands:

| Command | Command64 meaning |
|---|---|
| `XA paragraphs` | Allocate a VMM block and return a DEBUG-local handle |
| `XD handle` | Release a VMM block owned by DEBUG |
| `XM handle offset address length R|W` | Transfer between an allocation and base RAM |
| `XM handle page:offset address length R|W` | Transfer using a page-relative allocation offset |
| `XS [handle]` | Show VMM status and DEBUG-owned allocations |

`R` means REU-to-C64 read/fetch. `W` means C64-to-REU write/stash.

Example:

```text
-XA 0100
0: SEG=20 BANK=00 PARA=0100 PAGES=01 SIZE=1000

-XM 0 0000:0000 3000 0080 R
-D 3000 L 0080
-E 3000 DE AD BE EF
-XM 0 0000 3000 0080 W
-XS 0
-XD 0
```

### 2.3 Address-Space Boundary

Ordinary 16-bit addresses always mean C64 base memory. The following commands
remain base-memory-only:

```text
D E F M C S A U G T P L W
```

REU memory is accessible only through `XA`, `XD`, `XM`, and `XS`. Users stage
REU data through a selected base-RAM buffer before using existing DEBUG
commands on it.

Do not accept page syntax in base-memory commands:

```text
D 0001:0020       ; error
E 0001:0020 FF    ; error
G =0001:0020      ; error
```

Do not implement direct REU variants of `D`, `E`, `F`, `M`, `C`, `S`, `A`,
`U`, `G`, `T`, `P`, `L`, or `W`. The 6510 cannot execute REU-resident code,
and DEBUG cannot install live `BRK` breakpoints in REU memory.

## 3. Address Model

### 3.1 DEBUG Handles

DEBUG exposes small numeric handles for allocations it owns. Raw VMM
`SegHi:Bank` identity is informational output, not the primary command input.

Recommended capacity: four simultaneous handles.

Four handles keep the registry and cleanup loops compact while supporting
normal interactive use. Capacity can be revisited before approval, but must
not change during implementation without updating this plan and its tests.

### 3.2 Flat Allocation Offsets

The original `XM` form accepts a 16-bit byte offset relative to the start of
the selected allocation:

```text
XM 0 1020 3000 0080 R
```

### 3.3 Page-Relative Allocation Offsets

The alternate `XM` form accepts:

```text
page:offset
```

Definitions:

- `page` is a zero-based 4KB page number relative to the allocation.
- `offset` is a byte offset from `$0000-$0FFF` within that page.
- The normalized flat offset is `page * $1000 + offset`.
- A single DEBUG allocation is capped at 64KB, so `page` is `$0000-$000F`.
- The normalized offset must still lie within the selected allocation.

Equivalent examples:

```text
0000       == 0000:0000
0FFF       == 0000:0FFF
1000       == 0001:0000
1020       == 0001:0020
FFFF       == 000F:0FFF
```

This is a Command64 adaptation, not x86 segment arithmetic. MS-DOS segments
advance in 16-byte paragraphs and may overlap. Command64 `page:offset`
advances in fixed 4KB VMM pages and is relative to one DEBUG allocation.

## 4. Design Decisions

1. Use `DOS_ALLOC_MEM`, `DOS_FREE_MEM`, `DOS_VMM_READ`, and `DOS_VMM_WRITE`
   through `OS_API`; never access `$DF00-$DF0A` directly.
2. DEBUG owns only allocations created by its own `XA` commands.
3. Keep raw `SegHi:Bank` out of command addressing; show it only for
   diagnosis in `XA`/`XS` output.
4. Keep execution, assembly, disassembly, and file commands base-RAM-only.
5. Route `Q` through cleanup of every active DEBUG allocation.
6. If cleanup fails, report the failure and remain in DEBUG rather than exit
   while silently leaking an allocation.
7. Preserve active allocations after individual command errors so users can
   inspect, retry, or free them.
8. Reject stale, inactive, out-of-range, and unowned handles before any OS
   call.
9. Reject zero-sized allocations and zero-length transfers.
10. Reject transfer windows that exceed the allocation, the 64KB
    single-allocation ceiling, or the C64 address space.
11. Do not provide an implicit base-RAM fallback when VMM is unavailable.
12. Parse both flat and `page:offset` `XM` forms in the initial release;
    avoid a temporary flat-only public grammar.
13. Require complete command consumption for every new or modified command.
14. Keep carry semantics uniform in new helpers: carry clear on success;
    carry set with an internal error selector in `A`.
15. Increment DEBUG's minor version for the combined user-facing feature.
16. Let the normal build process update `BUILD_DEBUG`; do not edit generated
    build includes manually.

## 5. Command Contracts

### 5.1 `G`, `T`, and `P`

Grammar:

```text
G [address|=address]
T [address|=address]
P [address|=address]
```

Behavior:

- A bare and `=` address produce identical target state.
- A missing address after `=` is an error.
- More than four hex digits is an error.
- A non-hex address is an error.
- Trailing non-space input is an error.
- Invalid input must not execute code or change `regPC`.
- Existing no-argument behavior is retained.

`G` continues through its existing indirect execution path. `T` and `P`
continue through `cmdTraceProceedCommon` and `launchProgram`; breakpoint and
ROM-safety behavior is not redesigned by this work.

### 5.2 `XA`

Grammar:

```text
XA paragraphs
```

Behavior:

- Accept one hexadecimal paragraph count.
- One paragraph is 16 bytes, matching `DOS_ALLOC_MEM`.
- Permit `$0001-$1000` paragraphs: 16 bytes through 64KB.
- Reject `$0000`, values above `$1000`, and trailing input.
- Find a free DEBUG registry slot before allocation.
- Call `DOS_ALLOC_MEM` with `X/Y = paragraphs`.
- Record active state, returned `SegHi`, returned `Bank`, requested
  paragraphs, and any derived capacity metadata needed for bounds checks.
- Print handle, VMM identity, paragraph count, 4KB-page count, and byte
  capacity.
- Distinguish VMM unavailable, out-of-memory, and registry-full failures.
- If allocation succeeds but registration cannot complete, immediately free
  the grant to avoid a leak.

The page count shown by `XA` is the number of 4KB pages covering the requested
paragraph capacity. Bounds checks remain based on the requested paragraph
capacity, not rounded page capacity, unless the finalized OS allocation
contract proves that only granted-page capacity is authoritative. Resolve and
document that point before implementation.

### 5.3 `XD`

Grammar:

```text
XD handle
```

Behavior:

- Require exactly one active DEBUG handle.
- Reject an out-of-range, inactive, or already-freed handle before OS access.
- Call `DOS_FREE_MEM` with the stored `SegHi:Bank`.
- Clear the record only after successful release.
- Preserve the active record after failure so cleanup can be retried.
- Reject trailing input.

### 5.4 `XS`

Grammar:

```text
XS
XS handle
```

Behavior:

- `XS` reports VMM availability and every active DEBUG allocation.
- `XS handle` reports one active allocation.
- Reject invalid handles and trailing input.
- Use `DOS_GET_SYSTEM_INFO` where its finalized contract supports reporting:
  - VMM active/probed flags
  - total pages
  - allocated pages
  - free pages
- For each allocation, print handle, `SegHi`, bank, paragraphs, page count,
  and byte capacity.
- Do not inspect or expose the OS Memory Control Table directly.
- If global system counters are not reliably available, report VMM
  availability and DEBUG-local allocations only; settle this before coding.

### 5.5 `XM`

Grammar:

```text
XM handle offset address length R
XM handle offset address length W
XM handle page:offset address length R
XM handle page:offset address length W
```

Behavior:

- `R` fetches REU data into C64 RAM.
- `W` stashes C64 RAM data into REU.
- Parse one handle, one allocation-relative offset, one C64 address, one
  nonzero length, and exactly one direction.
- Accept a flat 16-bit offset or normalize a 4KB `page:offset` operand.
- Require end-of-input after the direction.
- Validate the complete REU and C64 windows before the first DMA.
- Reject C64-side wrap rather than continue at `$0000`.
- Split successful requests into bounded chunks.
- Restage every OS parameter before every API call.
- Stop immediately on runtime OS failure.
- Report transferred progress, or at minimum preserve advanced transfer
  cursors for diagnosis.

Recommended maximum chunk size: 256 bytes. This keeps arithmetic predictable,
prevents accidental zero-as-64KB behavior at the REU layer, and makes page and
address boundary tests tractable.

## 6. Parser Architecture

### 6.1 Preserve `parseHexArg`

Keep `parseHexArg` responsible only for parsing one-to-four-digit 16-bit
hexadecimal component. Do not make it globally ignore `=` or `:`.

Callers must validate delimiters and end-of-input. This prevents changes to
`D`, `E`, range parsing, assembler operands, and other existing grammars.

### 6.2 `requireEnd`

Add one reusable helper.

Contract:

- Input: `Y` is the current index in `inputBuf`.
- Skip trailing spaces.
- Return carry clear if the next byte is the null terminator.
- Return carry set otherwise.
- Leave `Y` at the first non-space byte or terminator.
- Document all register and flag clobbers.

Use it in `G`, shared `T`/`P`, `XA`, `XD`, `XM`, and `XS`.

### 6.3 `parseOptionalEquals`

Add a helper scoped to execution commands.

Contract:

- Input: `Y` points after the command character.
- Skip spaces.
- If the current character is `=`, consume it and following spaces.
- Return with `Y` at the address or terminator.
- Return carry set if `=` was consumed and carry clear otherwise.
- Do not parse the address.
- Callers use the carry result to distinguish a valid no-argument command from
  a missing address after `=`.

Apply only in `cmdGo` and `cmdTraceProceedCommon`.

### 6.4 Extended Command Dispatch

Extend `dispatch` to recognize `x`, then add `cmdExtended` to parse and
normalize the second command character.

Requirements:

- Dispatch exactly `XA`, `XD`, `XM`, or `XS`.
- Require token termination after the second character.
- Reject `X`, `XMAP`, `XAA`, and unknown subcommands.
- Accept shifted and unshifted command letters consistently with existing
  dispatch behavior.
- Leave `Y` positioned for the selected handler's first argument.

### 6.5 `parseReuHandle`

Contract:

- Parse one hexadecimal handle.
- Require the value to fit the configured registry capacity.
- Optionally require the selected record to be active, based on caller mode.
- Return the handle in `X` or a dedicated BSS byte.
- Return carry clear on success.
- Return carry set with a specific invalid/inactive selector in `A`.

### 6.6 `parseVmmOffset`

Accepted forms:

```text
hhhh
page:offset
```

Contract:

- Return a normalized 16-bit flat allocation offset in dedicated transfer
  state.
- Return `Y` after the complete operand.
- Return carry clear on success.
- Return carry set with a syntax/range selector in `A` on failure.

Algorithm:

1. Parse the first hexadecimal component.
2. Inspect the next byte.
3. If the next byte is not `:`, require a valid operand delimiter and retain
   the first component as the flat offset.
4. If the next byte is `:`, consume it and require a second hexadecimal
   component.
5. Require `page <= $000F`.
6. Require `offset <= $0FFF`.
7. Compute `page << 12` without losing overflow state.
8. Add the within-page offset.
9. Store the normalized offset.
10. Leave allocation-capacity validation to `validateReuWindow`.

Distinguish these cases:

- `0001:`: malformed syntax.
- `0001:1000`: invalid within-page offset.
- `0010:0000`: exceeds the 64KB relative address space.
- `0003:0000`: syntactically valid, but possibly beyond the allocation.

### 6.7 Error Selectors

Define internal selectors at least for:

- syntax error
- missing argument
- trailing input
- value out of range
- invalid handle
- inactive handle
- registry full
- VMM unavailable
- VMM out of memory
- invalid page offset
- allocation-window overflow
- C64-window overflow
- invalid direction
- partial transfer failure
- cleanup failure

Multiple selectors may initially map to the existing `error` message, but
their internal distinction must be preserved so user-facing diagnostics can
be improved without redesigning helper contracts.

## 7. State and Memory Layout

### 7.1 Existing Zero Page

Do not expand or repurpose DEBUG's private `$70-$7F` allocation for persistent
REU state. It is fully occupied and heavily aliased by current command,
assembler, and disassembler paths.

### 7.2 Allocation Registry

Add ordinary linked BSS storage. For four handles, use parallel arrays unless
code-size measurement proves a packed record is smaller overall:

```text
reuActive[4]
reuSegHi[4]
reuBank[4]
reuParagraphLo[4]
reuParagraphHi[4]
```

Add granted-page or exact-capacity fields only if needed after confirming the
allocator's returned-capacity contract. Avoid storing values that can be
derived cheaply and safely.

### 7.3 Transfer State

Add ordinary BSS fields for:

- selected handle
- direction
- normalized REU offset
- C64 address
- remaining length
- chunk length
- transferred count or diagnostic cursors
- temporary 17-bit/end-exclusive validation state where required

Do not retain DEBUG-owned state in OS parameter cells `$66-$6C`.

### 7.4 OS Parameter Staging

Immediately before every `DOS_VMM_READ` or `DOS_VMM_WRITE`, stage:

```text
VmmSegLo = 0
VmmSegHi = selected allocation SegHi
VmmBank  = selected allocation Bank
VmmOffLo/Hi = current normalized REU offset
HexValLo/Hi = current chunk length
X/Y = current C64 address
```

Assume `OS_API` may clobber `A`, `X`, `Y`, carry, and `$66-$6C`. Restage all
parameters for every chunk.

### 7.5 Initialization and Cleanup

- Clear every `reuActive` entry explicitly in `start`.
- Do not rely only on zero-filled PRG/BSS storage.
- `freeAllReu` attempts to release every active record.
- Clear each record only after successful release.
- If any release fails, report cleanup failure and return to DEBUG's prompt.
- Exit through `API_EXIT` only after all records are inactive.

## 8. Arithmetic and Safety

### 8.1 Allocation Capacity

`XA 1000` represents 4,096 paragraphs, or 65,536 bytes. This capacity cannot
be represented as a 16-bit byte count. Use paragraph comparisons, a page
count, or explicit 17-bit state where necessary.

Do not infer that a 16-bit zero capacity means an empty allocation when the
paragraph count is `$1000`.

### 8.2 REU Window Validation

Validate before DMA:

```text
endExclusive = normalizedOffset + length
```

Required rules:

- `length != 0`
- `normalizedOffset <= $FFFF`
- `endExclusive <= $10000`
- `endExclusive <= exact allocation capacity`

`offset + length == $10000` is valid only when the allocation has 64KB and
the request ends exactly at its boundary. Preserve the carry or an explicit
17th bit during addition.

### 8.3 C64 Window Validation

Validate before DMA:

```text
ramEndExclusive = c64Address + length
```

Reject requests where `ramEndExclusive > $10000`. A request ending exactly at
`$10000` is valid; one crossing it is not. Do not wrap to `$0000`.

### 8.4 Page Normalization

Required limits:

- `page <= $000F`
- `pageOffset <= $0FFF`
- `flatOffset = page * $1000 + pageOffset`

Page parsing proves only that the address fits the 64KB relative format.
`validateReuWindow` separately proves that it belongs to the selected
allocation.

### 8.5 Chunk Progress

For each successful chunk:

1. Add chunk length to the normalized REU offset.
2. Add chunk length to the C64 address.
3. Subtract chunk length from remaining length.
4. Add chunk length to the transferred count if one is retained.
5. Restage the next API request from BSS state.

No parser, handle, direction, or preflight bounds error may begin DMA. A
runtime OS error after one or more successful chunks may leave a partial
transfer; report or preserve exact progress for diagnosis.

## 9. Source Implementation Work Packages

### WP0: Approval, Decisions, and Tracking

1. Approve this unified command grammar.
2. Confirm four or eight allocation handles; recommendation: four.
3. Confirm `XA` uses hexadecimal paragraphs; recommendation: yes.
4. Confirm `XM` direction uses `R/W`; recommendation: yes.
5. Confirm zero transfer length remains invalid; recommendation: yes.
6. Confirm whether `XS` reports system-wide counters or DEBUG-local state
   only, based on `DOS_GET_SYSTEM_INFO` stability.
7. Confirm exact requested capacity versus allocator-rounded granted capacity
   as the authoritative bounds limit.
8. Create one measurable `wiki/tasks/` specification.
9. Synchronize it with Taskwarrior and `brain/task.md`.
10. Mark the two source proposals superseded only after this plan is approved.

Exit criterion: all public grammar and VMM capacity decisions are explicit.

### WP1: Parser Foundation and Permissive `=`

Detailed implementation plan:
`brain/plans/2026-08-03-debug-reu-and-address-syntax-wp1.md`.

1. Add `requireEnd` with documented register/carry contract.
2. Add `parseOptionalEquals` scoped to execution commands.
3. Update `cmdGo` to accept bare or `=` addresses.
4. Update `cmdTraceProceedCommon` likewise.
5. Parse into scratch state and commit `regPC` only after full validation.
6. Reject missing addresses and trailing arguments.
7. Build DEBUG.
8. Run focused `G`, `T`, and `P` compatibility tests.

Exit criterion: all valid bare and `=` forms are equivalent; invalid forms do
not execute or change target state.

### WP2: Extended Dispatch and REU Registry

Detailed implementation plan:
`brain/plans/2026-08-04-debug-reu-address-syntax-wp2.md`.

1. Add exact `X` subcommand dispatch.
2. Add registry BSS and explicit startup initialization.
3. Add `parseReuHandle`.
4. Add `findFreeReuHandle`.
5. Add `getReuRecord`.
6. Add common REU error dispatch.
7. Build and inspect BSS/linker growth.

Exit criterion: `XA`, `XD`, `XM`, and `XS` route to distinct stubs or handlers;
malformed `X` tokens are rejected without state changes.

### WP3: Allocation Lifecycle

Detailed implementation plan:
`brain/plans/2026-08-05-debug-reu-address-syntax-wp3.md`.

1. Implement `XA` preflight validation and slot selection.
2. Call `DOS_ALLOC_MEM` and register successful grants.
3. Roll back an unregistrable successful grant.
4. Implement `XD` with clear-after-success semantics.
5. Implement `freeAllReu`.
6. Route `Q` through cleanup.
7. Handle unavailable VMM, out-of-memory, registry-full, invalid-handle, and
   cleanup-failure paths.
8. Verify minimum, normal, and 64KB allocations.

Exit criterion: allocations cannot leak through registration failure, normal
`XD`, or successful `Q`.

### WP4: Status Reporting

Detailed implementation plan:
`brain/plans/2026-08-05-debug-reu-address-syntax-wp4.md`.

1. Implement `XS` and `XS handle`.
2. Report VMM availability.
3. Report each active DEBUG allocation.
4. Add system-wide counters only if the approved API contract supports them.
5. Format output for the 40-column C64 display.
6. Verify output with no allocations, multiple allocations, invalid handles,
   and VMM disabled.

Exit criterion: users can identify each handle's capacity and page count
before issuing page-relative `XM` commands.

### WP5: Unified `XM` Parsing and Preflight

Detailed implementation plan:
`brain/plans/2026-08-06-debug-reu-address-syntax-wp5.md`.

1. Add dedicated transfer BSS state.
2. Implement `parseVmmOffset` for both flat and `page:offset` forms.
3. Parse C64 address, length, and direction.
4. Require end-of-input.
5. Implement exact allocation-window validation.
6. Implement C64-window validation.
7. Verify parsing and boundaries without DMA.
8. Prove equivalent flat/page forms normalize identically.

Exit criterion: every invalid command fails before DMA, and both public offset
forms produce the same normalized state.

### WP6: Chunked `XM` Transfers

1. Implement chunk selection with a maximum of 256 bytes.
2. Implement `stageReuTransfer`.
3. Implement `advanceReuTransfer`.
4. Implement REU-to-C64 `R` transfers.
5. Implement C64-to-REU `W` transfers.
6. Restage OS parameters before every chunk.
7. Stop and preserve/report progress on runtime OS failure.
8. Verify transfers across chunk, page, and final-allocation boundaries.

Exit criterion: round-trip transfer is byte-exact for flat and page-relative
commands, with no wrap or out-of-bounds DMA.

### WP7: Integrated Regression and Documentation

1. Build shipping and test disk images.
2. Inspect relocation and linker output.
3. Run the existing DEBUG regression suite.
4. Run `=` syntax tests.
5. Run REU-enabled tests.
6. Run REU-disabled tests.
7. Update all user, test, memory-map, changelog, and state documents.
8. Perform the mandatory DOX closeout.
9. Produce the manual walkthrough.
10. Ask the user whether the task is complete before marking it done.

Exit criterion: all automated/static checks and the user-confirmed manual
walkthrough pass.

## 10. Verification Matrix

### 10.1 Build and Static Verification

1. Configure through CMake.
2. Build `image_d64`.
3. Build `test_image_d64` where applicable.
4. Confirm no warnings or errors.
5. Confirm DEBUG remains within its linker envelope.
6. Confirm relocation generation succeeds.
7. Inspect BSS growth and relocation entries.
8. Confirm no new private zero-page allocation.
9. Confirm version/build output is correct.

Do not invoke assembler or linker tools directly without separate explicit
permission; use the project build system.

### 10.2 Permissive `=` Cases

Valid forms:

```text
G=4000
G =4000
G= 4000
G = 4000
G 4000
T=4000
T =4000
T 4000
P=4000
P =4000
P 4000
```

Negative forms:

```text
G =
G ==
G =G000
G =10000
G =4000 EXTRA
T =4000 02
P =4000 02
G =0001:0000
```

Pass criteria:

- Equivalent valid forms target the same address.
- Existing no-argument behavior remains unchanged.
- Invalid `G` forms do not execute.
- Invalid `T`/`P` forms do not change `regPC` or install breakpoints.

### 10.3 Allocation Cases

1. `XS` reports active VMM with no DEBUG allocations.
2. `XA 0001` allocates the minimum 16-byte request.
3. `XA 0100` allocates 4KB.
4. `XA 1000` allocates the 64KB boundary.
5. `XA 0000` is rejected.
6. `XA 1001` is rejected.
7. Allocation beyond available REU reports out-of-memory.
8. Registry exhaustion does not leak an OS grant.
9. `XD` releases a valid handle.
10. Repeated `XD` is rejected.
11. `XS` reflects allocation and release accurately.
12. `Q` releases all active allocations.
13. Cleanup failure keeps DEBUG active and preserves failed records.

### 10.4 Page Parser Cases

Equivalent forms:

```text
0000       == 0000:0000
0FFF       == 0000:0FFF
1000       == 0001:0000
1020       == 0001:0020
FFFF       == 000F:0FFF
```

Malformed or out-of-format forms:

```text
:
0001:
:0020
0001::0020
0001:1000
0010:0000
000G:0000
0001:000G
0001:0020X
```

Allocation-bound case:

- `0003:0000` parses successfully as an address form.
- It is rejected during preflight if the selected allocation has fewer than
  four pages or insufficient exact paragraph capacity.

### 10.5 Transfer Cases

1. Round-trip one byte at offset zero.
2. Round-trip one byte at the final valid allocation byte.
3. Transfer ending exactly at allocation capacity.
4. Reject a transfer extending one byte beyond capacity before DMA.
5. Transfer across a 256-byte chunk boundary.
6. Transfer across `0000:0FFF` to `0001:0000`.
7. Prove flat `0FF0` and `0000:0FF0` access identical data.
8. Prove flat `1000` and `0001:0000` access identical data.
9. Reject `0000:1000` as an invalid within-page offset.
10. Reject `000F:0FFF` plus length two.
11. Accept `000F:0FFF` plus length one only for a 64KB allocation.
12. Reject zero length.
13. Reject invalid direction.
14. Reject missing operands and trailing garbage.
15. Reject a C64-side address wrap before DMA.
16. Simulate or observe partial runtime failure and verify diagnostic progress.

### 10.6 Negative Environment

1. Boot with REU disabled.
2. Confirm `XS` reports unavailable.
3. Confirm `XA` and `XM` fail cleanly.
4. Confirm `XD` rejects nonexistent handles without OS access.
5. Confirm `G`, `T`, `P`, and ordinary DEBUG commands still work.
6. Confirm `Q` exits normally when no allocations exist.

### 10.7 Existing DEBUG Regression

Run the existing suites for:

- `D`, `E`, `F`, `M`, `C`, and `S`
- `A` and `U`
- `R` and `H`
- `N`, `L`, and `W`
- `G`, `T`, and `P`
- ROM target safeguards
- `Q` and shell return

The intended compatibility change is limited to accepting optional `=` and
rejecting trailing input that previously could be silently ignored. Record
any other behavior change as a regression.

### 10.8 VICE Procedure

VICE integration must follow `.agents/workflows/vice-mcp-testing.md`:

1. Boot Command64 first.
2. Prove the Command64 banner and shell prompt.
3. Launch `debug` by name from the Command64 shell.
4. Never launch DEBUG from BASIC or VICE Autostart.
5. Use bounded observation and evidence-based failure classification.
6. Test with REU enabled and disabled as separate environments.

## 11. Manual Walkthrough

1. Launch DEBUG from the Command64 shell.
2. Demonstrate `G`, `T`, or `P` bare and `=` forms against safe base-RAM
   routines and prove equivalent target behavior.
3. Run `XS` and confirm VMM availability.
4. Allocate at least two 4KB pages.
5. Fill `$3000-$307F` with a known pattern using `F`.
6. Copy the pattern into page 0 with flat-offset `XM ... W`.
7. Fill a different pattern and copy it into page 1 with
   `XM handle 0001:0000 ... W`.
8. Clear the RAM staging range.
9. Read page 0 back using page-relative syntax and verify with `D` or `C`.
10. Read page 1 back using flat offset `$1000` and verify the second pattern.
11. Run an out-of-bounds transfer and prove RAM remains unchanged.
12. Display allocation state with `XS handle`.
13. Free the handle with `XD`.
14. Allocate multiple handles, quit with `Q`, restart DEBUG, and confirm no
    DEBUG-owned allocations remain.
15. Repeat the unavailable-path checks with REU disabled.

Do not mark the task done until the user confirms this walkthrough.

## 12. Documentation and State Updates

Update documentation only after the grammar and command behavior are stable.

1. Rewrite `docs/debug-memory-map.md`:
   - Replace "REU usage: none."
   - Add the allocation registry and transfer state.
   - Add the `$66-$6C` staging relationship.
   - Add an `XA`/`XD`/`XM`/`XS` allocation and transfer diagram.
   - Preserve the base-RAM versus REU execution distinction.
2. Update `wiki/debug-utility.md` first and keep
   `docs/debug-utility.md` byte-identical:
   - permissive `=` grammar
   - REU command syntax
   - flat and `page:offset` examples
   - errors and cleanup behavior
   - inability to execute REU memory
   - removal of the claim that extended-memory commands are inapplicable
3. Update `wiki/debug-test-plan.md` first and keep
   `docs/debug-test-plan.md` byte-identical.
4. Update `wiki/vmm-api.md` and its `docs/` mirror only if implementation
   discovers an undocumented OS API contract.
5. Update `brain/MEMORY.md` with DEBUG's new BSS state and unchanged private
   zero-page ownership.
6. Update `CHANGELOG.md` and the appropriate dated changelog.
7. Update the unified task specification, Taskwarrior, and `brain/task.md`.
8. Mark both source plans as superseded by this plan after approval.
9. Perform the mandatory DOX closeout and update applicable `AGENTS.md` files
   only if behavior, ownership, workflow, or durable contracts changed.

## 13. Deferred Work

The following are outside this implementation:

- Strict MS-DOS interpretation of bare `G` addresses as breakpoints.
- `G` breakpoint lists.
- `T` and `P` repeat counts.
- Direct REU-aware `D`, `E`, `F`, `M`, `C`, `S`, `A`, `U`, `L`, or `W`.
- Execution, tracing, proceeding, assembly, or disassembly in REU memory.
- Raw `SegHi:Bank` command addressing.
- Direct REU register access at `$DF00-$DF0A`.
- Zero length as a special 64KB `XM` request.
- Implicit base-RAM fallback when VMM is unavailable.
- More than 64KB in one DEBUG allocation.

## 14. Approval Questions

Resolve these before implementation:

1. Is the four-handle registry approved?
2. Is hexadecimal paragraph count approved for `XA`?
3. Are `R/W` direction tokens approved for `XM`?
4. Is zero `XM` length confirmed invalid?
5. Should `XS` include system-wide VMM counters when available, or remain
   DEBUG-local for a stable initial contract?
6. Does transfer authorization use exact requested paragraph capacity or the
   allocator's rounded granted-page capacity?
7. Is the proposed 256-byte maximum transfer chunk approved?
8. Are both flat and allocation-relative 4KB `page:offset` forms required in
   the initial `XM` release?

## 15. Final Acceptance Criteria

The implementation is ready for user confirmation when:

- `G`, `T`, and `P` accept bare and optional `=` addresses.
- Existing bare-address and no-argument behavior remains compatible.
- Unsupported breakpoint/count arguments are rejected.
- `XA`, `XD`, `XM`, and `XS` satisfy their approved contracts.
- DEBUG owns and cleans up only its own VMM allocations.
- `XM` accepts both flat and allocation-relative 4KB `page:offset` operands.
- Flat and page-relative forms access byte-identical REU locations.
- Base-memory commands reject page syntax and never silently access REU.
- Syntax and preflight errors occur before execution or DMA.
- Runtime transfer failures preserve or report exact progress.
- 64KB, page, chunk, allocation, and C64 wrap boundaries are verified.
- REU-disabled operation fails cleanly without breaking ordinary DEBUG use.
- DEBUG builds without warnings or errors and remains relocatable.
- Existing DEBUG regressions pass except for explicitly approved stricter
  trailing-input rejection.
- User, test, memory-map, changelog, task, and state documentation is current.
- The DOX closeout is complete.
- The user approves the manual walkthrough before the task is marked done.
