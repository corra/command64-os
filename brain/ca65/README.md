# cc65 toolchain reference

Reference docs for the cc65 suite this project depends on for ca65/ld65-built
external apps, mirroring `brain/kickassembler/KickAssembler.md`'s verbatim
transcription pattern.

- [`ca65.md`](ca65.md) — ca65 macro assembler reference manual.
- [`ld65.md`](ld65.md) — ld65 linker reference manual (config file
  `MEMORY`/`SEGMENTS`/`SYMBOLS`/`FEATURES` syntax).

## Other tools in the cc65 suite

The cc65 distribution ships more than just the assembler and linker. Not all
of it is relevant here, since this project is pure 6502 assembly with no C
compilation or graphics-conversion pipeline:

- **`od65`, `da65`, `sim65`** — potentially useful for debugging ca65/ld65
  output on this project (object-file dumper, disassembler, and 6502
  simulator, respectively). Not currently invoked anywhere in `cmake/` or
  `tools/`, but worth reaching for if a link or relocation issue needs
  inspecting outside VICE.
- **`cc65`, `cl65`, `grc65`, `sp65`, `chrcvt65`** — not relevant. These are
  the C compiler, compile-and-link driver, game-console runtime generator,
  sprite/bitmap converter, and character-set converter. This project has no
  C sources and no sprite/graphics conversion step.

Full upstream doc index: <https://cc65.github.io/doc/>.
