# ca65/ld65 relocation spike (conway)

Exploratory, throwaway spike — evaluating whether cc65's `ca65`/`ld65`
toolchain gives an easier relocation story than Kick Assembler's current
`add_external_app` approach (`cmake/KickAssembler.cmake`), which reassembles
each app from source twice (once per target address) and diffs the two
outputs (`tools/reloc.py`) to build a runtime patch table.

Not a migration in progress — no commitment to carry this forward. See
`brain/` / project chat history for the interview that scoped this.

## What this proves

1. **Assemble once, relink at different addresses.** `conway_main.s` and
   `conway_grid.s` assemble to `.o` files that don't encode a load address.
   `conway_2c00.cfg` and `conway_2d00.cfg` are linker configs differing only
   in where the `MAIN` memory area starts ($2C00 vs $2D00, matching this
   OS's `UserProgStart` / `UserProgStart+$100` convention). Relinking the
   same two `.o` files against either config produces a correctly working
   binary — confirmed by `cmp -l` on the two outputs: every differing byte
   is exactly a page-shift (high byte off by 1) at absolute-address
   references the linker relocated; nothing else changes.
2. **Cross-object symbol resolution.** `conway_main.s` calls into
   `conway_grid.s` (`randomizeGrid`, `drawGrid`, `drawStatusLine`,
   `computeNext`, `clearGrid`, `clearScreen`) via `.import`/`.export`. ld65
   resolves these across object files automatically — Kick has no
   equivalent concept since everything lives in one assembled unit.

## How the CBM load-address header works here

The 2-byte header (what a C64 loader reads to know where to place the
following bytes) is emitted from a linker-defined symbol, not hardcoded in
source:

```asm
.segment "HEADER"
    .word __MAIN_START__      ; ld65 exports this because MAIN has define=yes
```

This is why relinking against a different `.cfg` is enough — the header
patches itself.

## Layout

- `common.inc` — shared constants/zero-page equates (plain `.include`, no
  import/export needed — mirrors a shared C header).
- `conway_main.s` — entry point, main loop, key handling. Must be listed
  **before** `conway_grid.s` on the `ld65` command line: ld65 concatenates a
  segment's contributions in object-file order, and `start:` needs to land
  at the very first byte of `MAIN` so `JSR UserProgStart` (the shell's app
  dispatch convention) lands on it.
- `conway_grid.s` — grid buffer/randomize/draw logic + data tables.
- `conway_2c00.cfg` / `conway_2d00.cfg` — the two linker configs.

## Build wiring

`cmake/Ca65.cmake` (`add_ca65_spike_app`) assembles this once, links it
**twice** (against `conway_2c00.cfg` and `conway_2d00.cfg`), then runs
`tools/reloc.py` — the same diff tool Kick's `add_external_app` uses — on
the two link outputs. That produces `conwayca.prg` with a real high-byte
patch table and `'R','6'` footer, exactly like the Kick-built `conway.prg`,
so the shell's `aptRelocate` (`src/command64/loader.asm`) can correctly
patch it if it gets loaded away from `$2C00`. It's `Ca65_FOUND`-gated
(mirrors `Oscar64.cmake` — absence of cc65 must not break the real build)
and is only added to `TEST_IMAGE_PRG_TARGETS`, never `IMAGE_PRG_TARGETS` —
it does not ship on the release disk. Output filename on disk is
`conwayca` (deliberately distinct from the real `conway` target) so both
can coexist on `test.d64` and be exercised independently in VICE.

## Why relocation isn't optional here

Earlier revisions of this spike shipped a single, non-relocatable link
(no footer/patch table). That turned out to be actively unsafe on this
OS: `cmdLoad` (`src/command64/shell.asm`) always ignores a `.prg`'s own
embedded load-address header and auto-allocates a free page instead
(`aptFindFreeRegion` in `src/command64/apptable.asm`) when no explicit
address is given. If `conway` (Kick-built, relocatable) was already
resident at `$2C00` and `conwayca` (non-relocatable) got auto-allocated to
the next free page, `conwayca`'s hardcoded-at-link-time absolute
`JSR`/`JMP` targets still pointed at `$2C00` — the first internal jump
would land inside whatever was actually there, producing a crash on `RUN`,
not on `LOAD`. Running every spike app through the same diff-and-patch
pipeline Kick already relies on closes that gap, and it turned out to
need zero new relocator code: ld65's output diffs exactly like Kick's
(see "What this proves" above), so `tools/reloc.py` works on it unmodified.

## What's deliberately NOT covered

- This reuses Kick's existing relocation *tooling* (`reloc.py`'s diff
  algorithm, `aptRelocate`'s patch-time logic) rather than building
  anything new. The spike's contribution is proving ld65's output is
  diffable the same way Kick's is — not a new relocation mechanism.
