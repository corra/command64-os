# CASM Phase 9 WP43 Walkthrough

## Scope

WP43 records the Phase 9 include-processing architecture, freezes Phase 0C.19,
and creates the WP43-WP49 task hierarchy. It deliberately implements no
`.INCLUDE` grammar, source traversal, metadata, diagnostics, or fixtures.

## Recorded Contract

- Quoted-only 1-63-byte raw PETSCII include filenames, with no escapes.
- Explicit child device or inherited parent device; no search path.
- Immutable Pass 1 loading and filesystem-free Pass 2 event replay.
- 16 include levels, 32 physical files, and 128 include events.
- One 8KB VMM metadata store and a 65,535-byte distinct-source cap.
- Repeated expansion with deduplicated physical bytes.
- Active-frame cycle detection and physical-location plus include-site
  traceback diagnostics.

Parent plan:
`brain/plans/2026-07-25-casm-phase9-include-processing.md`.

Dedicated plan:
`brain/plans/2026-07-25-casm-phase9-wp43-prerequisite-reconciliation.md`.

## Task Verification

Taskwarrior contains:

- Parent `687ada7e-4175-41b4-93f3-9e8df85c1a5c`.
- Active WP43 `2826144e-b7c6-4372-8e1d-74cfff242d1a`.
- Sequentially blocked WP44-WP49 (`2682d04b`, `199b4da7`, `005a1819`,
  `579096d9`, `797bb460`, `a8c3dbf0`).

The parent depends on all seven work packages. WP44-WP49 each depend on their
immediate predecessor and remain separately gated.

## Baseline

WP43 is based on `main` at `b279365`. Phase 8 closed at `0.1.44` build 1157;
the subsequently merged LABEL/API work changed the shared ca65 include and
legitimately advanced CASM's content-hash counter to 1159 without changing its
stage. WP43's starting baseline is therefore `0.1.44` build 1159.

Branch hierarchy:

- Stage 9 parent: `feature/casm-stage9` at `b279365`.
- Active child: `feature/casm-phase9-wp43` at the same baseline, with this
  records-only working state.
- WP44 remains a separately gated future child and is not active.

## Automated Verification

Commands completed successfully:

```text
cmake --build build --target casm
cmake --build build --target casm
cmake --build build --target image_d64 test_image_d64 casm_overflow_test_d64
git diff --check
```

Results:

- Both consecutive CASM builds retained `BUILD_CASM` 1159.
- All three disk-image targets built successfully.
- `build/casm.prg` is 15,239 bytes.
- PRG load address bytes are `00 34` (`$3400`).
- Final six bytes are `00 34 79 06 52 36`: R6 base `$3400`, 1657 relocation
  entries, and `R6` magic.
- No production source, version stage, build counter, fixture, or MAIN-size
  change was made by WP43.

## DOX Closeout

`src/external/casm/AGENTS.md` records the approved Phase 9 planning contract and
explicitly says `.INCLUDE` is not operational until WP44-WP49 implement it. The
master plan now describes transient include handles and VMM-span frames rather
than retaining a live handle stack.

## Manual Confirmation

No runtime behavior changed, so WP43 requires no emulator execution. Confirm
that the parent and dedicated plans reflect the approved decisions and that
WP44 remains blocked pending its own detailed plan.

## Completion Gate

User approved completion. The version-only stage increment from `0.1.44` to
`0.1.45` advanced the content-hash build once to 1160. A no-change rebuild held
1160, all three disk images passed, and the artifact remained 15,239 bytes with
load address `$3400` and R6 footer `00 34 79 06 52 36`. WP43 is complete. WP44
was not activated.
