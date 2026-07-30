---
feature: casm-dash-system-dashboard
created: 2026-07-26
updated: 2026-07-30
status: complete (user-approved 2026-07-30, all WP1-WP10 closed)
---

# Plan: CASM Native Relocatable DASH System Dashboard

## Objective

Create `DASH`, a useful three-page Command 64 system dashboard assembled
natively by CASM as an R6 relocatable application. It will demonstrate CASM's
current multi-file assembly and relocation capabilities, use stable OS APIs,
run on a base C64, and enable its VMM test when an REU is available.

This document is recorded for review. It does not activate an implementation
work package or authorize source changes. Each CASM work package requires its
own detailed plan and explicit approval under `src/external/casm/AGENTS.md`.

## User-Confirmed Decisions

1. Command and on-disk name: `DASH`.
2. Scope: three pages -- System, Applications, and VMM Test.
3. Presentation: 40-column framed panel UI with color highlights and a status
   bar.
4. Refresh: input-driven; redraw after page changes or an explicit refresh.
5. Data access: add stable typed OS query services rather than read private OS
   memory directly.
6. VMM test: safe functional allocation/write/read/compare/free test.
7. Source structure: multiple ordered CASM top-level source files; do not wait
   for the unfinished `.INCLUDE` implementation.
8. Runtime target: C64 with optional REU; VMM functionality degrades
   gracefully when unavailable.
9. Application rows: name, address range, size, and flags.
10. V1 capacity reporting: logical 4096-page MCT allocator counts only; do not
    claim detected physical REU capacity.
11. Running state: implement a truthful lifecycle covering normal return and
    `DOS_EXIT` before displaying `R`.
12. Public app names: one length byte plus 16 bounded name bytes.
13. Shipping artifact: reviewed native-CASM-generated hex manifest converted
    reproducibly for host image packaging.
14. VMM coverage: test the full 4KB allocation for every pattern.
15. VMM RAM: use one 256-byte transfer buffer and regenerate expected bytes
    during comparison.

## Work-Package Plan Index

All plans remain drafts until separately reviewed and approved:

1. [WP1 - API Contract Freeze](2026-07-26-casm-dash-wp1-api-contract-freeze.md)
2. [WP2 - System Information API](2026-07-26-casm-dash-wp2-system-information-api.md)
3. [WP3 - Application Query API](2026-07-26-casm-dash-wp3-application-query-api.md)
4. [WP4 - Relocatable Skeleton](2026-07-26-casm-dash-wp4-relocatable-skeleton.md)
5. [WP5 - Panel UI and Formatting](2026-07-26-casm-dash-wp5-panel-ui-formatting.md)
6. [WP6 - System Page](2026-07-26-casm-dash-wp6-system-page.md)
7. [WP7 - Applications Page](2026-07-26-casm-dash-wp7-applications-page.md)
8. [WP8 - VMM Test Page](2026-07-26-casm-dash-wp8-vmm-test-page.md)
9. [WP9 - Integration and Relocation Audit](2026-07-26-casm-dash-wp9-integration-relocation-audit.md)
10. [WP10 - Documentation and Completion Gate](2026-07-26-casm-dash-wp10-documentation-completion-gate.md)

## Work-Package Activation Contract

Every WP must begin by re-reading its current dependencies and tracing the
relevant implementation paths. It must compare observed behavior against the
approved parent, predecessor, and dedicated WP plans rather than assuming the
plans remain current.

If a material discrepancy changes scope, expected files, ABI, memory/storage,
failure or cleanup behavior, verification, artifact provenance, or an inherited
decision, the WP must:

1. Stop before implementation continues.
2. Record expected versus observed behavior and root cause.
3. Identify affected predecessor and downstream plans.
4. Amend the dedicated plan with the minimal proposed resolution.
5. Obtain renewed explicit user approval.
6. Resume only after approval, then rerun the narrow failed check and the full
   WP verification matrix.

Minor observations that change no contract or work product may be recorded in
the walkthrough without plan amendment. No WP may silently repair a material
predecessor discrepancy.

## Planning Findings to Resolve

The detailed plan review identified issues intentionally left unresolved until
their owning WP activates:

- Current REU detection does not report physical capacity; DASH v1 reports
  logical MCT allocator counts only and must label them accordingly.
- App-table storage has no durable public bank/validity marker.
- WP3 must implement a truthful running lifecycle across normal return and
  `DOS_EXIT`; REU/stack flags still need truthful/reserved semantics.
- The public app record uses a length byte plus 16 bounded name bytes.
- The descriptive seven-file command below exceeds the shell's 80-byte command
  buffer; WP4 proposes short on-disk names and must freeze the exact command.
- CASM has no string literals, general equates, operational `.INCLUDE`, or
  indirect `JSR`; the DASH plans account for these constraints.
- Native CASM currently requires REU/VMM to assemble DASH, while the completed
  DASH runtime is still required to operate without an REU.
- No host `add_casm_app` path exists; WP4/WP9 use a reviewed hex manifest and
  must freeze source-to-manifest stale-artifact protection.

## Goals

1. Produce a real native Command 64 application rather than a synthetic
   relocation test.
2. Exercise CASM absolute, immediate low/high-byte, `.WORD`, branch, table, and
   forward/backward symbol relocation behavior.
3. Demonstrate stable OS service calls through `$1000`.
4. Add reusable public system-information APIs instead of coupling `DASH` to
   OS workspace, VMM app-table, or MCT implementation details.
5. Prove that one generated R6 binary runs at several page-aligned addresses.
6. Remain navigable and useful without an REU.

## Non-Goals

- No continuous full-screen telemetry loop.
- No direct reads from `$C000-$CFFF`, private app-table VMM storage, or private
  OS workspace by `DASH`.
- No direct REU-register access by `DASH`.
- No dependency on operational `.INCLUDE` support.
- No destructive VMM capacity probe.
- No completion or task closure without a user-approved walkthrough.

## User Interface

The initial screen shape is:

```text
+--------------------------------------+
| COMMAND 64 SYSTEM DASHBOARD          |
| SYSTEM   APPLICATIONS   VMM TEST     |
+--------------------------------------+
|                                      |
|       page-specific content          |
|                                      |
+--------------------------------------+
| F1/F3/F5 PAGE  R REFRESH  Q QUIT     |
+--------------------------------------+
```

Controls:

- `F1`: System page.
- `F3`: Applications page.
- `F5`: VMM Test page.
- `R`: Refresh the current page.
- `T`: Run the test while on the VMM page.
- `Q`: Exit through `DOS_EXIT`.
- Ignore unrecognized keys.

The screen is redrawn only after a page change or explicit refresh. This keeps
the interface deterministic and avoids full-screen flicker.

## Page Contracts

### System Page

Display:

- Command 64 version.
- Current device number.
- PAL or NTSC video standard.
- User-program range and protected ranges.
- VMM availability.
- REU capacity when reliably known.
- VMM page size.
- VMM total, allocated, and free page counts.
- Loaded application count and capacity.

Unavailable values display `N/A`, not a misleading zero.

### Applications Page

Display one compact row per occupied application slot:

```text
NAME             RANGE       SIZE FLAGS
DASH       3400-3FFF   0C00   UR--
DEBUG      4000-49FF   0A00   U---
```

Flag characters:

- `U`: slot used.
- `R`: currently running.
- `V`: REU-backed image.
- `S`: stack saved.

The displayed inclusive end address is `loadAddress + size - 1`. A malformed
zero-sized record must display a defensive marker rather than wrap to `$FFFF`.
Empty slots are skipped. The running `DASH` entry should identify its actual
relocated load range.

### VMM Test Page

Page states:

- `Unavailable`: no REU/VMM.
- `Ready`: VMM available, test not run.
- `Passed`.
- `Failed`.
- `Cleanup failed`.

Test sequence:

1. Request one 4KB page using `DOS_ALLOC_MEM`.
2. Save the returned page and bank immediately.
3. Fill a bounded C64 RAM buffer with a deterministic pattern.
4. Write it using `DOS_VMM_WRITE`.
5. Clear the local destination buffer.
6. Read the allocation back using `DOS_VMM_READ`.
7. Compare every transferred byte.
8. Repeat for `$00/$FF`, incrementing-byte, and `$55/$AA` patterns.
9. Free the allocation on every path where allocation succeeded.
10. Report the failing operation and expected/actual byte on mismatch.

Use bounded block DMA calls rather than byte-at-a-time REU access.

## Proposed Public OS APIs

Reserve final service numbers only during the API contract work package. The
current proposal follows the existing highest service, `$5B`:

```text
$5C DOS_GET_SYSTEM_INFO
$5D DOS_GET_APP_INFO
```

### `DOS_GET_SYSTEM_INFO`

Proposed ABI:

```text
A   = DOS_GET_SYSTEM_INFO
X/Y = destination pointer, low/high
C   = clear on success, set on error
```

Proposed versioned fixed-size output record:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 1 | Structure version |
| 1 | 1 | Structure size |
| 2 | 1 | OS version major |
| 3 | 1 | OS version minor |
| 4 | 1 | OS version stage |
| 5 | 1 | Current device |
| 6 | 1 | Capability flags |
| 7 | 1 | Video standard |
| 8 | 2 | User-program start |
| 10 | 2 | User-program limit |
| 12 | 2 | VMM page size |
| 14 | 2 | VMM total pages |
| 16 | 2 | VMM used pages |
| 18 | 2 | VMM free pages |
| 20 | 1 | Application slots used |
| 21 | 1 | Application slot capacity |

Capability flags should distinguish VMM initialized, REU detected, and
capacity valid. Version and size permit later record extension.

### `DOS_GET_APP_INFO`

Proposed ABI:

```text
A       = DOS_GET_APP_INFO
X       = slot index, 0-15
Y       = reserved, must be zero
$FB/$FC = caller destination pointer
C       = clear for a returned record, set for an error
A       = detailed status
```

Proposed output record:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 1 | Structure version |
| 1 | 1 | Structure size |
| 2 | 1 | Slot index |
| 3 | 1 | Flags |
| 4 | 16 | Null-terminated or padded application name |
| 20 | 2 | Load address |
| 22 | 2 | Byte size |
| 24 | 2 | Inclusive end address |

The API must distinguish occupied, empty, invalid, and VMM-unavailable states.
Exact status values, carry behavior, register preservation, buffer-overlap
rules, and malformed-record handling are frozen in WP1. The API copies and
normalizes private data; it never exposes an app-table VMM pointer.

## OS Implementation Scope

Expected source areas:

- `include/command64.inc`
- `include/ca65/command64.inc`
- `src/command64/api.asm`
- `src/command64/apptable.asm`
- `src/command64/vmm.asm`, only if page-count helpers are required
- `docs/api-reference.md`
- `docs/programmers-reference.md`
- Existing OS API test locations

Implementation requirements:

1. Define identical API constants and record offsets in both include dialects.
2. Add dispatcher branches without changing existing service behavior.
3. Implement a bounded system snapshot writer.
4. Implement app-record lookup and normalized copying through VMM routines.
5. Count MCT states without modifying the MCT.
6. Return explicit unavailable states when VMM initialization failed.
7. Document inputs, outputs, carry/zero behavior, preservation, and clobbers.
8. Test caller buffers with guard bytes before and after each record.
9. Update public API and memory-contract documentation.
10. Perform the required DOX pass.

## DASH Source Layout

Because `.INCLUDE` is not operational, demonstrate CASM's ordered top-level
source support:

```text
dash-main.s
dash-screen.s
dash-format.s
dash-system.s
dash-apps.s
dash-vmm.s
dash-data.s
```

Responsibilities:

- `dash-main.s`: entry point, initialization, event loop, and exit.
- `dash-screen.s`: clear screen, frames, cursor positioning, and colors.
- `dash-format.s`: hexadecimal and decimal conversion.
- `dash-system.s`: system query and System page renderer.
- `dash-apps.s`: application enumeration and table renderer.
- `dash-vmm.s`: VMM test state machine and cleanup.
- `dash-data.s`: strings, page descriptors, pointer tables, and buffers.

Expected command shape, to be confirmed against the live CASM CLI before the
application plan is frozen:

```text
CASM dash-main.s dash-screen.s dash-format.s dash-system.s dash-apps.s dash-vmm.s dash-data.s /O:dash
```

## Relocation Showcase Contract

The application should deliberately contain observable relocation cases:

- `JSR localRoutine`.
- `JMP eventLoop`.
- `LDX #<titleString`.
- `LDY #>titleString`.
- `.WORD drawSystemPage`, `.WORD drawAppsPage`, `.WORD drawVmmPage`.
- Relocatable string and data pointer tables.
- Absolute indexed table reads.
- Forward and backward branch targets.

The page-dispatch `.WORD` table is the central showcase: keyboard selection
resolves a relocated function pointer and invokes it through an indirect
trampoline.

Fixed targets must never receive relocation entries:

- `JSR $1000`.
- KERNAL jump-table addresses such as `$FFE4`.
- VIC, CIA, screen, and color hardware addresses.
- Documented OS zero-page ABI addresses.

## Memory Contract

Assemble at CASM's default `$3400` origin while remaining relocatable.

Initial bounded storage estimate:

- System record: 22-32 bytes after ABI freeze.
- App record: 26-32 bytes after ABI freeze.
- VMM write buffer: 256 bytes.
- VMM read buffer: 256 bytes.
- Formatting buffer: 8-16 bytes.
- UI state and scratch: under 64 bytes.
- Total code and data target: under 8KB.

Rules:

- Use only the approved external-application zero-page range `$70-$8F` for
  app-private scratch.
- Use OS-owned `$61-$6F` only according to documented API parameter contracts.
- Save persistent values before `$1000` calls that may clobber registers or
  shared zero page.
- Do not write the MCT or REU registers directly.
- Never assume the runtime load address equals the emission origin. CASM
  emits at `$3400`; `UserProgStart` is `$3800` and moves over time.
- Avoid self-modifying code unless a separately reviewed need appears.
- Represent internal pointers through relocation-aware `.WORD` values or
  `<`/`>` expressions.

## Failure and Cleanup Contract

- System query failure displays `SYSTEM INFO UNAVAILABLE`.
- App query failure displays a bounded status and continues where safe.
- No VMM disables `T` and displays `NO REU/VMM`.
- Allocation failure never calls free.
- Write/read failure preserves the primary error and then attempts free.
- Compare failure displays offset, expected byte, and actual byte.
- Free failure displays `CLEANUP FAILED` distinctly.
- Exit always uses `DOS_EXIT`.
- No path leaks a successful allocation unless `DOS_FREE_MEM` itself fails.

## Verification

### Build and Binary Verification

1. Build the OS and API tests with zero errors.
2. Assemble all DASH files natively through CASM.
3. Inspect the output load header, R6 table, footer base, count, and magic.
4. Confirm every relocation offset targets an eligible high-byte operand or
   relocatable word high byte.
5. Confirm fixed OS, KERNAL, and hardware addresses are absent from the table.
6. Confirm a no-change rebuild is stable.

### API Verification

1. Query system info into valid guarded buffers.
2. Reject or explicitly report invalid app indices.
3. Return empty-slot status without copying stale data.
4. Guarantee app-name termination or padding.
5. Verify end-address calculation, including zero size and 16-bit boundaries.
6. Verify VMM-unavailable behavior.
7. Verify MCT counting leaves MCT contents unchanged.
8. Re-run all existing API regressions.

### Runtime Verification

The user performs runtime checks in the supported local emulator or on
hardware; the `c64-testing` MCP and web emulators must not be used.

Load and run the same generated binary at:

- `$3800`: `UserProgStart`, the address the external-command path uses.
- `$5000`: mid-range page relocation.
- `$9000`: high-range page relocation.

There is deliberately no zero-delta control: CASM emits at
`CASM_DEFAULT_ORIGIN` (`$3400`), which is below `UserProgStart` and so can
never be a legal load address. Every case exercises relocation.

At each address verify:

1. Title and labels render correctly.
2. All three relocated page-dispatch entries work.
3. `DASH` appears at its actual load range.
4. Refresh does not corrupt the screen.
5. `Q` returns cleanly to the shell.
6. The VMM test passes when an REU is available.
7. The VMM page disables safely without an REU.
8. Repeated tests do not reduce available VMM pages.
9. Repeated launch/exit cycles remain stable.

## Atomic Work Packages

### WP1: API Contract Freeze

- Reconcile the proposed services with the current dispatcher and callers.
- Freeze service numbers, record layouts, statuses, register preservation,
  malformed-record behavior, and tests.
- Save a dedicated detailed implementation plan.
- Obtain explicit approval before source edits.

### WP2: System Information API

- Implement `DOS_GET_SYSTEM_INFO`.
- Add bounded tests.
- Document the public contract.
- Verify with and without VMM.

### WP3: Application Query API

- Implement `DOS_GET_APP_INFO`.
- Test occupied, empty, invalid, and VMM-unavailable cases.
- Verify app-table VMM access and caller-buffer boundaries.

### WP4: DASH Relocatable Skeleton

- Create the ordered multi-file application source.
- Add entry, event loop, exit, page dispatch, and minimal screen.
- Assemble with CASM and audit R6 output.
- Prove relocation at several addresses before adding complexity.

### WP5: Panel UI and Formatting

- Add frames, cursor positioning, color, and status bar.
- Add hexadecimal and decimal conversion.
- Add input-driven navigation and redraw.

### WP6: System Page

- Query the new system API.
- Render all fields.
- Add unavailable-state handling.

### WP7: Applications Page

- Enumerate all 16 slots.
- Render compact occupied rows.
- Format ranges, sizes, and flags.
- Highlight the running application.

### WP8: VMM Test Page

- Implement allocation, pattern transfer, comparison, and cleanup.
- Add explicit failure-stage reporting.
- Verify repeated runs do not leak pages.

### WP9: Integration and Relocation Audit

- Run the complete build and regression matrix.
- Inspect all R6 entries.
- Test at `$3800`, `$5000`, and `$9000`.
- Confirm `DASH` consumes no private OS addresses.

### WP10: Documentation and Completion Gate

- Document assembly, launch, controls, and expected behavior.
- Update tasks, Taskwarrior, changelog, knowledge, memory, and affected DOX
  records as required by actual changes.
- Present a manual walkthrough.
- Ask the user whether the work is complete before marking any task done.

## Expected Deliverables

- Stable system-information API.
- Stable application-enumeration API.
- API regression tests.
- Multi-file CASM source for `DASH`.
- CASM-generated native R6 `DASH` application.
- Trusted binary/relocation references where appropriate.
- Disk-image integration.
- Public documentation and manual walkthrough.
- Updated task and architectural records required by completed work.

## Approval Gate

The first implementation increment is WP1 only. It produces the dedicated API
contract plan with exact service numbers, record bytes, statuses, register and
flag behavior, scratch/clobber rules, and verification. No API or DASH source
may be edited until that plan is explicitly approved.

## Closeout (user-approved 2026-07-30)

All ten work packages are complete: WP1-WP3 (frozen `$5C`/`$5D` API contract
and implementations), WP4-WP5 (relocatable skeleton, panel UI/formatting),
WP6-WP8 (System, Applications, VMM Test pages), WP9 (integration/relocation
audit -- R6 ledger, private-address audit, production packaging, stale-
artifact gate; manifest provenance remains the ca65 `dash_ref` cross-check as
an explicit interim, user-approved rather than blocking on a native-CASM-on-
hardware run), and WP10 (documentation reconciliation and completion
walkthrough, see that plan's own closeout note). DASH ships as `dash.prg`
(`DASH V0.1.4`) on the production `image_d64`. See each WP's own plan file
for its individual completion note and evidence.
