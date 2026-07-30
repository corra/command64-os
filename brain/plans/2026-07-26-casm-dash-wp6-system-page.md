---
feature: casm-dash-wp6-system-page
created: 2026-07-26
updated: 2026-07-30
status: complete
---

# Plan: DASH WP6 - System Page

## Objective

Query the approved system-information service once per System-page redraw and
render truthful OS, device, video, user-range, VMM, and application-count
fields without reading private OS memory.

Prerequisites: approved WP1/WP2 API and approved WP4/WP5 completion.

## Mandatory Activation Review

Re-read the final public record, statuses, clobbers, implementation docs,
current DASH buffers/layout, and no-REU behavior. Any material discrepancy in
record size/version, field validity, range/capacity meaning, display space,
or API preservation stops work, requires an amended plan, and requires renewed
approval.

## Expected Files

- `src/external/dash/dsys.s`
- `src/external/dash/ddata.s`
- `src/external/dash/dfmt.s`, only for approved extensions/fixes
- `src/external/dash/dscr.s`, only for approved page labels/layout
- DASH docs/DOX only when contracts change

## Record and Query Contract

- Allocate application RAM for the exact WP1 record size.
- Use the frozen public service number and pointer ABI.
- Query exactly once per redraw.
- Save returned status before any subsequent OS call.
- Validate structure version and returned size before reading fields.
- Ignore supported trailing fields from newer records.
- Capability-gate every optional value.
- Never directly read `CurrentDevice`, `KernalVideoStd`, `AptSeg`, MCT, or VMM
  private state.

Planned wrapper:

```text
querySystemInfo
  C clear: validated snapshot available
  C set: saved failure status; record not treated as current
```

`drawSystemPage` refreshes once, then renders from the validated buffer.

## Display Contract

Proposed fields, subject to final WP1 record:

1. OS version.
2. Current device.
3. PAL/NTSC/UNKNOWN.
4. User-program interval under frozen inclusive/exclusive notation.
5. Protected range description only if public ABI supports it honestly.
6. REU/VMM availability.
7. Capacity in pages, or `N/A` when not valid.
8. VMM page size.
9. Total, used, and free logical pages.
10. Applications used/capacity.

Prefer page counts rather than introducing 24/32-bit byte-capacity arithmetic.
Unknown or invalid values display `N/A`, never misleading zero.

## Validation and Failure Handling

- Unsupported version or too-short record: `SYSTEM INFO UNAVAILABLE`.
- API C set: clear/poison stale record and display bounded failure.
- Unknown video enum: `UNKNOWN` or `N/A` per frozen UI contract.
- Inconsistent counts: mark affected values unavailable; do not wrap.
- VMM unavailable: System page remains functional with optional values `N/A`.
- Any screen/format failure remains local and navigation continues.
- A failed refresh must not display previous data as current unless explicitly
  labeled stale; recommended policy is no stale display.

## Atomic Increments

1. Map exact WP1 record/service/status in source comments and storage.
2. Integrate query and success/failure marker only.
3. Render version, device, and video.
4. Render user/protected ranges.
5. Render VMM availability/capacity/page size.
6. Render total/used/free page counts.
7. Render application count/capacity.
8. Add short/newer/malformed/unavailable handling.
9. Audit relocation and run the full runtime matrix.

## Verification

- Service number matches both public includes.
- Destination pointer relocations are present and correct.
- Every field read is guarded by record size/version.
- Every optional field is capability-gated.
- Source contains no private OS addresses or REU registers.
- API target `$1000` remains fixed, not relocated.
- WP2 guarded-buffer/MCT tests pass unchanged.
- At all three load addresses, user confirms correct OS/device/video/range and
  application counts.
- With REU, values follow WP1 semantics; without REU, optional values show
  `N/A` and navigation/exit remain safe.
- `R` performs one fresh query and no continuous polling occurs.

## Stop Conditions

- Final ABI differs from inherited assumptions.
- Protected ranges or capacity cannot be represented truthfully.
- DASH needs a private OS address.
- Unavailable data would be shown as zero.
- API clobbers corrupt persistent page/UI state.
- Record size/version cannot be bounded.
- Relocation differs by address.

## Completion Gate

Present exact field mapping, private-address audit, API regression evidence,
and REU/no-REU multi-address walkthrough. Ask whether WP6 is complete before
WP7 activation.

## Implementation Note (2026-07-30)

Implemented, not yet gated complete -- see wiki/tasks/dash-wp6.md for the
sub-task list and outstanding items (native-CASM manifest regeneration and
the live REU/no-REU multi-address walkthrough both still need the user).

Also folded in, per explicit 2026-07-30 user decision: the kernel-side fix
for [[project-dash-version-literal-deferred]] (Task Warrior #41, now closed)
and the WP1 amendment bumping `StructVersion` to `$02` / reinterpreting
offset 22 as `OsPatch` (see
`brain/plans/2026-07-26-casm-dash-wp1-api-contract-freeze.md` section 7).

## Completion Note (2026-07-30)

Approved complete by the user, with known inconsistencies explicitly
deferred rather than blocking closure -- see below.

**Real bug found and fixed during live verification**: `FORMATDEC16`
(`dfmt.s`, WP5 code) called `JSR DIV10` while X still held the digit
write-index; `DIV10` is documented as clobbering X (its own 16-iteration
shift counter) and always returns with X=0, so every digit was written to
`FMTBUF+0` regardless of position, and the multi-digit loop terminated after
one digit. This produced exactly the "digit then padding" / "only the last
digit of a multi-digit number" symptoms reported against the System page.
Fixed by stacking X across the `DIV10` call. This was caught only by testing
the native-CASM-built `DASH.PRG` on real/emulated hardware and comparing
against expectations byte-by-byte with the user -- static review, a Python
simulation, and disassembly of the byte-identical `dash_ref.prg` all missed
it, because none of those exercise real runtime register-clobber behavior.
Confirms the WP5 gap flagged at its own completion note (formatter test
vectors were verified by static inspection there, not on hardware).

Also added `DASHVERSTR` (ddata.s) -- a static `"DASH V0.1.3"` banner on the
previously-unused screen row 24, matching other external apps' version-label
convention (e.g. `casm.s`'s `"CASM V<major>.<minor>.<stage>.<build>"`). DASH
cannot use those apps' `.define`/generated-`build_<name>.inc` mechanism since
the dual-assembler subset has no equates; this is a hand-bumped literal
instead. It's a real, permanent banner now, not a throwaway debug line.

**Known inconsistencies, explicitly deferred (not WP6's to fix -- DASH is
reporting exactly what `$5C` returns; these are kernel apptable.asm/vmm.asm
behaviors)**, logged as Task Warrior #42 (project `casm-dash`):

- `VmmTotalPages`/`VmmPageSize` are hardcoded to a 16MB-REU assumption
  (4096 pages x 4096 bytes), not computed from the actual attached REU.
  `VmmFlags` bit 1 ("REU probed") is defined in the WP1 contract but never
  set by `ahGetSystemInfo`. Correct only by coincidence for a 16MB REU.
- `DOS_EXIT` does not clear `APT_FLAG_USED`/`APT_FLAG_RUNNING` or free the
  exiting program's VMM allocations; only the manual `FREE` shell command
  reclaims app-table slots, and even that left `APPLICATIONS` unchanged in a
  user-verified repro (VMM pages partially reclaimed, app count did not
  move) -- possibly a bug in `aptRemoveAll` itself, not just a missing
  automatic-cleanup feature.

These require kernel (not DASH-side) changes and are deferred to a future
point-fix WP rather than folded into WP6.

**Not independently re-verified in this closing pass**: the full
`$3800`/`$5000`/`$9000` load-address matrix from this plan's original
Completion Gate. The user's live testing in this session loaded DASH at
`$3800` via COMMAND64's own `load`/`run` shell commands (device 9) and
confirmed correct System-page rendering there, including after the
`FORMATDEC16` fix; the other two addresses were not separately exercised in
this pass.
