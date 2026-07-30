# command64 OS DASH Utility Manual

**File Name:** `dash.prg` (packaged on disk as `dash`)
**Version:** `DASH V0.1.4`
**Origin:** Relocatable R6 binary, implicit base `$3400`
**Supported Hardware:** Any command64 OS machine. The System and Applications
pages work with or without a REU. The VMM Test page requires a REU to run;
without one it reports itself unavailable rather than failing.

## Overview

DASH is a three-page system dashboard: System information, a live
Applications registry, and a VMM/REU hardware self-test. It is assembled by
the *native* CASM assembler (see [CASM Utility Manual](casm-utility.md))
running on the C64 itself, not by any host tool, and ships as a relocatable
PRG that runs identically wherever the OS loads it.

- **F1** — System page
- **F3** — Applications page
- **F5** — VMM Test page
- **R** (or **r**) — redraw the current page
- **T** (or **t**) — run the VMM test (System/Applications pages ignore it;
  only the VMM Test page acts on it)
- **Q** (or **q**) — exit cleanly via `DOS_EXIT`

## Running DASH

### Default launch

```text
LOAD DASH
RUN
```

`LOAD` reads the PRG's own load-address header and registers DASH in the App
Table; `RUN` (or `GO` with no argument) starts it there. Because DASH's
output is R6-relocatable, this works at whatever address the OS's default
user-program placement currently resolves to.

### Explicit relocated launch

```text
LOAD DASH,9
GO 5000
```

`GO <address>` looks the loaded program up by address and relocates/runs it
there. DASH has been verified to run identically at `$3800`, `$5000`, and
`$9000` — every JSR/JMP high operand, `#>label` high byte, `.WORD` renderer
pointer, and absolute local-data reference the R6 relocation table covers is
patched for the new base, and the Applications page (F3) correctly reports
DASH's own row at whichever address it's actually running from.

## Building DASH from Source

DASH is **not** assembled by any host tool — it is assembled by CASM running
on the C64 (or in VICE), from seven ordered files, all of which must be
present on the assembling disk:

1. `dmain.s` — entry, event loop, dispatch trampoline (also pulls in the
   other six via `.INCLUDE`)
2. `dscr.s` — screen clear, layouts, frame, borders
3. `dfmt.s` — text formatting, printing
4. `dsys.s` — System page content
5. `dapp.s` — Applications page content
6. `dvmm.s` — VMM Test page content
7. `ddata.s` — shared data, screen-code strings, page routine table,
   variables (kept last so data follows all code)

Because `dmain.s` pulls the other six in itself via `.INCLUDE`, the CASM
command line only ever names the entry file:

```text
DRIVE 9
CASM DMAIN.S /O:DASH.PRG
COMP DASH.PRG DASH.REF
```

Everything needed lives on `command64_casm_utils.d64` (`casm.prg`,
`comp.prg`, the seven sources as SEQ files, and a ca65 cross-check reference
as `dash.ref`). Because the OS loads external commands from
`CurrentDevice`, switching to that drive first means no `9:` prefix is
needed on the command itself. **Native CASM assembly requires a REU** — the
resulting DASH runtime does not.

### Source, Candidate, and Shipping Artifact

DASH's build pipeline distinguishes three things, deliberately kept
separate:

- **Source** — the seven `.s` files above, the only thing anyone edits.
- **Candidate** — the PRG a real `CASM DMAIN.S /O:DASH.PRG` run on
  native CASM produces. Nothing on the host can reproduce this run.
- **Reviewed/shipping artifact** — `src/external/dash/dash.ref.hex`, a
  human-reviewed hex manifest transcribed from a candidate via
  `scripts/build_dash_manifest.py`, which `scripts/hex_manifest_to_bin.py`
  turns back into the actual `dash.prg` CMake packages at build time. Editing
  a source file without regenerating this manifest is caught, not silent:
  the manifest embeds a `source_sha256` line per file, and the build hard-fails
  if any of the seven sources' hashes no longer match.

**Current provenance (as of this writing):** the shipping manifest's bytes
come from the `dash_ref` ca65 cross-check build
(`build_dash_manifest.py --allow-host-bytes`), used as an explicit,
user-approved interim stand-in — not a native-CASM-on-hardware run. The
manifest's own `# provenance:` line states this plainly. A native-CASM
regeneration remains available as a future step if wanted, but is not a
blocker on any current work. The `dash_ref` cross-check is independent by
construction: ca65 and CASM share no code and derive relocation entries by
completely different means, so a defect in one cannot reproduce itself in
the other.

## System Page (F1)

Queries `DOS_GET_SYSTEM_INFO` (`$5C`) exactly once per redraw and renders,
from that public 24-byte record alone (never reading `CurrentDevice`,
`KernalVideoStd`, `AptSeg`, MCT, or VMM state directly): OS version, device,
video standard, user program range, protected range, VMM/REU status, page
size, page totals, used/free pages, and application counts.

Any field whose value depends on VMM/REU state is **capability-gated** on
`VmmFlags` bit 0 (VMM active) from the same record: when VMM is inactive,
those fields print `N/A` rather than a zero or stale value — a `0` on this
page always means "the OS reported zero," never "unavailable." `VmmFlags`
bit 1 (REU probed) similarly selects between `PROBED`/`UNPROBED` display
text.

## Applications Page (F3)

Queries `DOS_GET_APP_INFO` (`$5D`) once per slot, for all 16 public
application-table slots, and renders one row per **occupied** slot:

```text
NAME            RANGE     SIZE FLAGS
1234567890 3400-3FFF 0C00 UR--
```

- **NAME** — the application's full public name, up to 15 characters, never
  truncated (the display column is exactly the WP1 API's frozen name-field
  width).
- **RANGE** — `LLLL-EEEE`, the inclusive load-to-end address range (end is
  the API's own normalized end field, not locally recomputed).
- **SIZE** — 4 hex digits.
- **FLAGS** — four characters, one per bit, in order:
  - **U** — slot in use (`APT_FLAG_USED`).
  - **R** — currently running (`APT_FLAG_RUNNING`). **Known limitation**:
    no loader code path sets this bit today and `DOS_EXIT` doesn't clear it,
    so this column is truthfully `-` for every application right now
    (tracked as Task Warrior #42, a kernel-side gap, not a DASH defect).
    DASH renders the raw bit as-is and never infers running state any other
    way (e.g. by name comparison) — there is deliberately no row highlight
    for a case that has no truthful instance to highlight.
  - **V** — REU-backed image (`APT_FLAG_REU`).
  - **S** — stack saved (`APT_FLAG_STACK`).

Empty slots are skipped silently — not shown as errors. A query failure on a
valid slot index stops enumeration with `APP QUERY ERROR` rather than
displaying partial or stale data; a completely empty table displays `NO
APPLICATIONS`. All 16 possible rows fit the page's content area by
construction; no scrolling or paging is needed.

## VMM Test Page (F5)

A safe, repeatable REU self-test, triggered by **T**. Nothing runs
automatically — the page starts `Ready` (or `Unavailable` without a REU) and
only allocates memory when you press T.

**States:**

| State | Meaning |
| --- | --- |
| Unavailable | No REU present; T does nothing |
| Ready | REU present, no allocation currently owned |
| Running | Test in progress |
| Passed | All three patterns matched and the page was freed |
| Failed | A write/read/compare mismatch occurred; failure stage and offset are shown |
| Cleanup failed | The page couldn't be freed after a test; **retesting is disabled** — restart or reset DASH before trying again |

**What the test does:** allocates one 4KB REU page, then for each of three
patterns (`$00/$FF` alternating by byte parity, `$55/$AA` alternating by
byte parity, and an incrementing pattern by absolute offset mod 256), writes
all 4096 bytes in sixteen 256-byte blocks, reads them back, and compares
every byte before moving to the next pattern. On any mismatch, the page
records the failing stage (allocation/write/read/compare/free/internal), the
16-bit offset, and the expected/actual bytes, then attempts cleanup.

**Cleanup is unconditional**: whenever an allocation succeeds, DASH attempts
exactly one `DOS_FREE_MEM` on every exit path — success or failure, first
pattern or third. `Passed` is only ever shown once every pattern *and* the
free both succeeded. If the free itself fails, the page enters `Cleanup
failed`, which permanently disables further T presses for this run (no
second allocation is ever attempted on top of one that couldn't be freed) —
restart DASH or reset the machine to try again.

Without a REU, T is a no-op: no allocation, no transfer, and page navigation
and Q remain safe.

## Memory and API Contract

DASH exclusively queries the OS through the public jump table (`JSR $1000`)
— `DOS_GET_SYSTEM_INFO` (`$5C`), `DOS_GET_APP_INFO` (`$5D`),
`DOS_ALLOC_MEM`/`DOS_FREE_MEM`/`DOS_VMM_READ`/`DOS_VMM_WRITE`
(`$48`/`$49`/`$59`/`$5A`), `DOS_PRINT_STR`, `GETIN` (`$FFE4`), and
`DOS_EXIT` (`$4C`). It never reads or writes:

- `$C000`-`$CFFF` (private MCT/VMM workspace) — the only mention of this
  range anywhere in DASH's source is a documentation comment, never an
  operand.
- The app table, VMM segment, or any private OS offset directly.
- REU hardware registers (`$DF00`-`$DF0A`).
- Any kernel body entry point other than `$1000` and `$FFE4`.

Zero-page usage is exactly `$66`-`$6C` (shared OS API parameter registers)
and `$70`-`$8F` (DASH's own private 32-byte range — see
[src/external/dash/AGENTS.md](../src/external/dash/AGENTS.md) for the exact
per-byte allocation). DASH never touches OS or another application's private
zero page.

## R6 Relocation

DASH ships as native CASM's default relocatable output: a 2-byte PRG load
header (`$3400`), program bytes, a relocation table of 2-byte little-endian
offsets, and a 6-byte footer (base, count, then the ASCII magic `R6`). Every
entry in the table is a genuine high-byte address reference that must move
with the load page — local `JSR`/`JMP` targets, `#>label` high bytes,
renderer `.WORD` pointers, and absolute references to DASH's own data.
Fixed targets never appear as entries: `$1000`, `$FFE4`, screen/color RAM,
and DASH's own ZP range are all excluded by construction.

As audited against the current `dash_ref` cross-check build: load header
`$3400`, program length 3828 bytes, 465 relocation entries (930 bytes),
footer base `$3400`/count `465`/magic `R6`, total file size 4766 bytes
(SHA-256 `3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`).
Every offset is bounded, unique, and complete against this build. Behavior
has been verified identical at `$3800`, `$5000`, and `$9000`.

## Known Limitations and Troubleshooting

| Symptom | Cause / stage | Notes |
| --- | --- | --- |
| Applications page never shows `R` (running) for anything | Kernel gap, not a DASH bug | `APT_FLAG_RUNNING` is never set by any loader path today (Task Warrior #42) |
| System page VMM-dependent fields show `N/A` | Expected when VMM is inactive | Capability-gated on `VmmFlags` bit 0; never displayed as a false zero |
| VMM page shows `Unavailable`, T does nothing | No REU attached | Expected, safe no-op — not a failure state |
| VMM page shows `Failed` | A write/read/compare mismatch during the 3-pattern test | Check the reported stage/offset/expected/actual; a REU hardware or transfer problem is the most likely cause |
| VMM page shows `Cleanup failed`, T no longer responds | `DOS_FREE_MEM` failed after a test | By design — restart DASH or reset the machine before testing again; a second allocation is never attempted on top of an unfreed one |
| `FREE`-ing DASH from the shell doesn't fully reclaim its slot | Kernel gap, not a DASH bug | `DOS_EXIT`/`aptRemoveAll` don't reliably clear `APT_FLAG_USED`/`APT_FLAG_RUNNING` or free VMM allocations (Task Warrior #42) |
| VMM page total/size figures look wrong for your actual REU size | Kernel gap, not a DASH bug | The OS currently reports a hardcoded 16MB-REU assumption rather than a probed size (Task Warrior #42) |

## Source

[src/external/dash/](../src/external/dash/) — see
[src/external/dash/AGENTS.md](../src/external/dash/AGENTS.md) for the local
contracts (zero-page allocation, dual-assembler source subset, artifact
provenance workflow) and
[api-reference.md](api-reference.md) for the OS services DASH calls into.
