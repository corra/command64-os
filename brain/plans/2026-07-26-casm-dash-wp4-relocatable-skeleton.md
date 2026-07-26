---
feature: casm-dash-wp4-relocatable-skeleton
created: 2026-07-26
status: draft
---

# Plan: DASH WP4 - Relocatable Skeleton

## Objective

Create the smallest real multi-file DASH application assembled natively by
CASM. It must emit R6 output at the implicit `$3400` base, select three
placeholder pages, redraw on input, exit through `DOS_EXIT`, and run unchanged
at `$3400`, `$4000`, and `$5000`.

Parent: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`.
Prerequisites: approved completion of WP1-WP3 unless the user explicitly
approves reordering.

## Mandatory Activation Review

Re-read current CASM syntax, source limits, CLI parsing, R6 behavior, loader
relocation, external-app build contracts, command-buffer size, and image
packaging. Compare them to this plan.

Any material discrepancy affecting file count/names/order, command length,
CASM syntax, artifact provenance, relocation, ownership, memory, verification,
or downstream plans stops implementation. Record expected/observed behavior
and root cause, amend the plan, and obtain renewed approval.

## Known Discrepancies to Freeze

1. The descriptive seven-file command in the parent exceeds the shell's
   80-byte command buffer. Use short on-disk names, provisionally:

   ```text
   dmain.s dscr.s dfmt.s dsys.s dapp.s dvmm.s ddata.s
   ```

2. CASM supports at most eight ordered top-level sources and a 65,535-byte
   combined source stream; DASH uses seven.
3. `.INCLUDE`, string literals, and general equates are not available for this
   application. Strings require explicit numeric screen/PETSCII bytes and
   fixed API/hardware constants require documented numeric literals.
4. The 6502 has no indirect `JSR`. Use a reviewed stack-balanced trampoline
   ending in `JMP (vector)`.
5. Native CASM runs on the C64 and currently requires VMM/REU for assembly,
   although the resulting DASH runtime must work without REU.
6. No host `add_casm_app` helper exists. Freeze a truthful native-artifact
   path before production packaging.
7. `src/external/dash/` becomes a durable boundary and requires local DOX plus
   a parent Child DOX Index update.

## Expected Files

- `src/external/dash/AGENTS.md`
- `src/external/dash/BUILD_DASH`, only if the approved native build contract
  requires it
- `src/external/dash/dmain.s`
- `src/external/dash/dscr.s`
- `src/external/dash/dfmt.s`
- `src/external/dash/dsys.s`
- `src/external/dash/dapp.s`
- `src/external/dash/dvmm.s`
- `src/external/dash/ddata.s`
- `src/external/AGENTS.md`
- Packaging/manifest files only after artifact strategy approval

WP4 creates placeholders in later module files; WP5-WP8 own their functional
content.

## Source and Runtime Contract

- Omit `.ORG`; implicit relocatable origin remains `$3400`.
- Start with `CLD` and assume no input register/flag values.
- Persistent page/redraw state lives in application RAM.
- Use only `$70-$8F` for app-private zero page.
- Use OS ZP only according to frozen API contracts.
- Call fixed OS entry `$1000`; call `KernalGetIn` at `$FFE4`.
- Exit only with `A=$4C`, `JSR $1000`.
- No allocation or file ownership in WP4.

Page renderer ABI:

```text
Input: none
Output: placeholder body rendered; returns with RTS
Clobbers: A, X, Y, N/Z/C and documented DASH scratch
```

## Dispatch Trampoline

`pageRoutineTable` contains three relocatable `.WORD` entries. Dispatch:

1. Validate current page 0-2; reset invalid state to System.
2. Copy selected low/high bytes into a two-byte vector.
3. Push `dispatchReturn-1` high byte, then low byte.
4. Execute `JMP (dispatchVector)`.
5. Renderer `RTS` consumes the synthetic return.
6. `dispatchReturn: RTS` consumes the original caller return.

Static audit must prove net stack delta zero. No self-modifying code is needed.

## Event Loop

- Redraw initial System page.
- Poll GETIN once per iteration.
- F1/F3/F5 select System/Applications/VMM and set redraw.
- `R` sets redraw.
- `Q` calls `DOS_EXIT`.
- `T` and unknown keys do nothing in WP4.
- Redraw clears the pending flag before dispatch.

Function key values must be reconfirmed against the current C64/KERNAL
environment at activation.

## Relocation Showcase

Include and audit:

- Cross-file `JSR localRoutine` and `JMP eventLoop`.
- `LDX #<label` and `LDY #>label`.
- `.WORD` renderer and data pointers.
- Absolute indexed local table reads.
- Forward/backward branches.

Exclude fixed `$1000`, `$FFE4`, screen/color/hardware addresses, and fixed ZP
from relocation entries.

## Artifact Contract

Before source implementation, freeze:

- Exact native CASM command and byte count (`<=80`).
- Authoritative source order.
- Where native source SEQs are packaged for assembly.
- How the CASM-produced PRG is reviewed and promoted.
- How the reviewed checked-in hex manifest avoids stale shipping output.
- How CMake identifies the final PRG without claiming host assembly.

The selected v1 strategy is a reviewed hex manifest: native CASM produces the
candidate, the reviewed manifest records the approved bytes, and the existing
manifest converter generates the host-packaged PRG. WP4 must still freeze the
manifest path, review evidence, and stale-source protection.

If no truthful reproducible artifact strategy exists, stop WP4 and plan the
missing integration rather than using ca65/KickAssembler for DASH.

## Atomic Increments

1. Freeze short filenames, command, source order, DOX, and artifact path.
2. Implement one-file entry/GETIN/Q proof and run at `$3400`.
3. Split into seven ordered files with cross-file labels.
4. Add F1/F3/F5/R and direct placeholder selection.
5. Add the relocatable `.WORD` trampoline and prove stack balance.
6. Audit R6 header, table, footer, required entries, and exclusions.
7. Run the same binary at `$3400`, `$4000`, and `$5000`.
8. Apply only approved packaging/DOX/document records and present walkthrough.

## Verification

- Exact command fits 80 bytes including spaces/options/device prefixes.
- Seven sources remain under current source/symbol/token/relocation limits.
- No `.ORG` or unsupported syntax appears.
- Output header/footer base is `$3400`; magic is `52 36`.
- Every relocation offset targets an eligible program byte.
- Fixed targets produce no entries.
- No-change native assembly is byte-identical.
- Repeated page dispatch leaves stack stable.
- Same artifact works at all three addresses.
- DASH runs without REU after it has been assembled.
- Existing CASM relocation fixtures and OS loader behavior remain unchanged.

The user performs runtime checks in a supported local emulator or hardware;
do not use `c64-testing` or a web emulator.

## Stop Conditions

- Command exceeds 80 bytes or more than eight sources are needed.
- Required behavior needs `.INCLUDE`, strings, equates, or another unsupported
  construct.
- Artifact path misrepresents host output as native CASM output.
- Dispatch stack balance is unproven.
- Output becomes static or contains bad relocation entries.
- Runtime differs by load address.
- New ownership/build contracts exceed approved scope.

## Completion Gate

Present exact command, source order, binary/R6 audit, artifact provenance,
multi-address runtime results, stack proof, and DOX changes. Ask the user
whether WP4 is complete before WP5 activation or task closure.
