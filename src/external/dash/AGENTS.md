# Purpose

DASH is a CASM-assembled, relocatable, three-page system dashboard utility for Command 64 OS. It displays system specifications, application registry listings, and runs VMM page/DMA hardware tests when an REU is present.

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- **Origin**: Relocatable R6 binary targeting implicit `$3400` base.
- **Source Files**: Seven ordered files:
  1. `dmain.s` (entry, event loop, dispatch trampoline)
  2. `dscr.s` (screen clear, layouts, frame, borders)
  3. `dfmt.s` (text formatting, printing)
  4. `dsys.s` (System page content)
  5. `dapp.s` (Applications page content)
  6. `dvmm.s` (VMM Test page content)
  7. `ddata.s` (shared data, screen code strings, page routine table, variables)
- **Zero Page Allocation**: Private scratch registers in the `$70-$8F` range:
  - ZP `$70-$71`: `dispatchVector` (for indirect JMP)
  - ZP `$72`: `currentRow` index
  - ZP `$73-$74`: `screenDestPtr`
  - ZP `$75-$76`: `stringSrcPtr`
  - ZP `$77`: `currentCol` index
  - ZP `$78-$79`: formatting/division working value (`FORMATHEX16`, `FORMATDEC16`, `DIV10`); also used transiently as `SCREENPUTCHAR`'s color-pointer input before being copied to `$7B-$7C`
  - ZP `$7A`: `DIV10` remainder accumulator; also used transiently by `dsys.s`'s `PRINTDEC16` as a skip-count scratch, only after `FORMATDEC16`/`DIV10` have already returned
  - ZP `$7B-$7C`: `SCREENPUTCHAR`/`HIGHLIGHTTABS` color-cell pointer
  - ZP `$7D`: `SCREENPUTCHAR` character stash; `HIGHLIGHTTABS` chosen-color stash
  - ZP `$7E`: `SCREENPUTSTRING` clamped max-length; `HIGHLIGHTTABS` per-tab length
  - ZP `$7F`: `SCREENPUTSTRING` saved source-string index (needed because `SCREENPUTCHAR` clobbers Y)
- **OS API Jump Table**: Exclusively queries kernel services via `$1000` jump table.
- **Exit Procedure**: Terminates using `DOS_EXIT` (`A = $4C`, `JSR $1000`).

# Work Guidance

- **UPPERCASE ONLY (load-bearing)**: Every byte of these files — mnemonics, labels, hex digits, **and comment text** — must be uppercase ASCII. `cc1541 -w` writes host bytes to the SEQ verbatim with no translation, and ASCII lowercase `a`-`z` (`$61`-`$7A`) are *not* letters in PETSCII; CASM rejects them with `CASM_DIAG_INVALID_SOURCE_BYTE`. ASCII uppercase `A`-`Z` (`$41`-`$5A`) coincides exactly with the PETSCII letter range, so an all-uppercase host file needs no conversion step. `banner.s` follows the same rule and is the proven precedent. This is safe for identifiers only because no two differ solely by case — check that before renaming anything.
- **Dual-Assembler Subset (load-bearing)**: The seven sources are written in the strict syntactic subset that **both** ca65 and native CASM accept, so the identical bytes on disk can be assembled either way and the outputs compared. Anything outside that subset breaks the cross-check, not just one build. Concretely:
  - **No segment directives.** CASM has no segment concept — it emits one linear stream in command-line file order. The single `.segment` ca65 needs lives in `dash_wrapper.s`, the ca65-only wrapper.
  - **Audited string literals only.** CASM WP74 supports raw-PETSCII strings in
    `.BYTE` lists. Use them only for runs proven byte-identical under ca65's
    active C64 charmap; digits and punctuation in `DASHVERSTR` are the initial
    safe adoption. Screen-code letters remain explicit bytes because ca65
    remaps source letters and would break native/host identity.
  - **Equates must precede every use.** Both assemblers accept named constants, but ca65 cannot select zero-page addressing for a forward-referenced equate. Declare shared equates at the top of `dmain.s`, before executable code.
  - **No character literals.** ca65's character mapping does not preserve the raw keyboard-byte values native CASM assigns to uppercase literals (`'T'` becomes `$D4`, not `$54`). Keep keyboard and screen-code operands as explicit hex bytes.
  - **`@local` labels are shared (CASM Phase 14 WP87-90); anonymous `:+`/`:-` are NOT.** A `@name` label is a cheap local scoped to the nearest preceding non-`@` label in **both** assemblers — ca65's native cheap-local feature and CASM's own `@local` (WP89). Use them for routine-internal loop/skip/done targets that are never branched to from outside their own routine (`dfmt.s`'s `FORMATDEC16`/`PETTOSCREEN`/`DIV10` adopted `@LOOP`/`@DONE`/`@SKIP` in WP91). Two constraints keep the two assemblers in agreement:
    - **No `=` equate may sit between a label and its `@locals`.** ca65 ends a cheap-local scope at *any* non-`@` symbol including an `=` equate; CASM ends it only at a `NAME:` label. DASH already declares every equate at the top of `dmain.s` before code (see "Equates must precede every use"), so within the executable sections the two rules coincide — but a new mid-code equate would silently split the scope differently under each assembler.
    - **Never reuse one `@name` within a single CASM scope.** CASM rejects a redefined `@local` in the same scope (`DUPLICATE LOCAL LABEL IN SCOPE`); ca65, whose scope may have been split by an `=`, might not. Keep each `@name` unique between one `NAME:` label and the next.
    Anonymous ca65 labels (`:`, `:+`, `:-`) have no CASM equivalent yet (deferred past Phase 14) — do not use them.
  - **Accumulator shifts must be written `asl a`.** CASM maps a no-operand shift to `MODE_IMPLIED` and has *no* implied-to-accumulator fallback (`opcodesFindOpcode`), so a bare `asl` is a hard `CASM_DIAG_INVALID_ADDR_MODE`. ca65 accepts both spellings; only `asl a` works in both.
  - **Expressions are bounded**: parenthesised arithmetic and the Phase 12 operators are available, but use them only where both assemblers produce identical values. ZP pointer high bytes use `SYMBOL+1`.
  - **`.RES count[, value]` is shared; `.FILL` is not.** CASM's Phase 13 `.RES` (WP84 adopted it for `ddata.s`'s `FMTBUF`/`SYSINFOBUF`/`APPBUF`/`BORDERROW`/`VMMBUFFER`) has a byte-identical ca65 counterpart (`.res count[, fillval]`), independently verified to emit the literal fill bytes — not just reserve BSS space — in a non-BSS segment. CASM's `.FILL` has **no ca65 equivalent at all** (`.fill` is not a recognized ca65 directive); express any required-value fill as `.RES count, value` instead, never `.FILL`, or the ca65 cross-check breaks outright.
- **Source Order Is Authoritative, Specified Once**: `dmain.s` pulls in the other six sources itself via `.INCLUDE "DSCR.S"` / `.INCLUDE "DFMT.S"` / ... / `.INCLUDE "DDATA.S"` (native CASM's include facility, operational since CASM WP47), and `dash_wrapper.s` (the ca65-only wrapper) does nothing but `.include "dmain.s"` — its own `.INCLUDE` chain then does the rest for both toolchains. `ddata.s` stays last so data follows all code. Because both toolchains now read the order from the same six lines instead of it being hand-duplicated between a CASM command line and `dash_wrapper.s`'s own include list, the two can no longer silently drift out of sync.
  - **Case mismatch is expected and handled by the build, not the source**: the `.INCLUDE` operands are uppercase (`"DSCR.S"`), matching the uppercase PETSCII directory entries `cc1541 -f` writes on the packaged disk (same byte-matching mechanism the old multi-file CLI already relied on). ca65 resolves `.include` operands as literal filesystem paths on this case-sensitive host, where the real files are lowercase (`dscr.s`). `CMakeLists.txt` generates uppercase symlinks into `${CMAKE_BINARY_DIR}/dash_ref_includes/` at configure time and passes that directory to the `dash_ref` ca65 build via `add_ca65_app`'s `EXTRA_INCLUDE_DIRS`, so the identical operand spelling resolves for both toolchains without renaming any checked-in file.
- **Dispatch Trampoline**: High/low bytes of the target page routine are stashed through `DISPATCHVECTOR` (`$70/$71`). The return address is set by pushing `dispatchReturnMinusOne` onto the stack before executing `JMP (DISPATCHVECTOR)`.

# Artifact Provenance

DASH ships from a **reviewed hex manifest** (`dash.ref.hex`), transcribed to a PRG at build time by `scripts/hex_manifest_to_bin.py` — a script with no 6502 knowledge and no assembler.

- The manifest records bytes produced by **native CASM running on the C64**. It is regenerated only by a deliberate human act (`scripts/build_dash_manifest.py`), never as a build step, so editing a source can never silently change what ships.
- The ca65 `dash_ref` target is an **independent cross-check only** and must never be the source of manifest bytes. `build_dash_manifest.py` refuses its output unless `--allow-host-bytes` is passed explicitly.
- The cross-check is non-circular: ca65 and CASM share no code and derive relocation entries by completely different means — `tools/reloc.py` diffs two links one page apart, while CASM classifies each operand as relocatable during emission. A defect in one cannot reproduce itself in the other.
- **Stale-artifact protection (WP9)**: `dash.ref.hex` embeds one `# source_sha256: <name>=<hash>` line per source file, written by `build_dash_manifest.py`. The `dash` CMake target always passes `--source-dir` to `hex_manifest_to_bin.py`, which recomputes each file's hash and hard-fails the build on any mismatch, missing file, or a manifest with no recorded hashes at all — editing a source without regenerating the manifest is a build failure, not a silent stale ship.
- **Current provenance**: `dash.ref.hex`'s shipping bytes come from native CASM
  `0.2.8` build `1322` running under VICE 3.10 with a 16MB REU on a dedicated
  CASM-only test disk, `dash_casm_test.d64` (2026-08-20) — following the same
  dedicated-d64-per-app methodology BANNER's own migration established
  (`brain/plans/2026-08-20-banner-casm-native-migration.md`). This run
  carried a further Phase 12 syntax pass beyond WP71's named-constant-only
  adoption (WP68 shift/arithmetic expressions, WP74 string literals for the
  audited range). Host `--cross-check build/dash_ref.prg` confirmed all
  4,766 bytes match the independent ca65 reference, and match the prior
  shipping manifest byte-for-byte — the syntax pass changed nothing
  observable. No `--allow-host-bytes` override was used. `dash` ships on
  `image_d64` (production only, never `test.d64`) from these reviewed
  native bytes.

# Native Assembly Workflow

Everything needed lives on `command64_casm_utils.d64` (casm.prg, comp.prg, the seven sources as SEQ, and the ca65 reference as `dash.ref`). Because the OS loads external commands from `CurrentDevice`, switching to that drive means no command needs a `9:` prefix.

```text
DRIVE 9
CASM DMAIN.S /O:DASH.PRG
COMP DASH.PRG DASH.REF
```

`dmain.s`'s own `.INCLUDE` chain pulls in the other six sources (see Source
Order Is Authoritative above), so the command line only ever names the entry
file — the old seven-file line (`CASM DMAIN.S DSCR.S DFMT.S DSYS.S DAPP.S
DVMM.S DDATA.S /O:DASH.PRG`, 67 of the shell's 80-byte `CommandBuffer`) is no
longer needed, freeing that headroom for future growth.

Native CASM requires an REU for assembly; the resulting DASH runtime does not.

# Verification

- Output header/footer base is `$3400`; footer magic is `52 36` (`R6`).
- `COMP DASH.PRG DASH.REF` matches byte-for-byte on the C64, and re-running CASM with no source change reproduces identical bytes.
- Relocation entries cover only eligible program bytes: `.WORD` renderer pointers, absolute label operands, and `#>label` high bytes. Fixed targets produce **no** entries — `$1000`, `$FFE4`, screen/colour RAM (`$0400`-`$07FF`, `$D800`-`$DBFF`), and ZP `$70`-`$8F`. `#<label` low bytes are correctly excluded (`applyExtraction` clears `RELOCATABLE` for `<`).
- Repeated page dispatch leaves the stack balanced: `dispatchPage` pushes 2 bytes, the renderer's `RTS` consumes them landing on `dispatchReturn`, whose `RTS` consumes the original caller return. Net delta zero.
- The same artifact runs identically at `$3800`, `$5000`, and `$9000`, without an REU.
