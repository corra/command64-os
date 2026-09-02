# Purpose

DASH (`0.2.0`) is a CASM-assembled, relocatable, three-page system dashboard utility for Command 64 OS. It displays system specifications, application registry listings, and runs VMM page/DMA hardware tests when an REU is present.

The seven sources were modernized across the **DASH Modernization** increment (2026-09-01, `feature/casm-phase14`, DASH-MOD WP1-6): every routine-internal label is a `@local`; every magic number is a named constant declared in `dmain.s`'s prologue; structural invariants are `.assert`-guarded (`dash_wrapper.s`); the event loop, key dispatch and page renderers are helper-backed with no inline duplication. No user-visible behaviour changed. Shipping size fell `4766 -> 4579` bytes. Per-WP detail: `brain/plans/2026-09-01-dash-mod-wp*.md` + walkthroughs.

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- **Origin**: Relocatable R6 binary targeting implicit `$3400` base.
- **Version**: `DASHVERSTR` in `ddata.s` is a hand-edited static screen-code string (`DASH v<x.y.z>`, printed on screen row 24 by `DRAWVERSIONBANNER`). It stays a literal string rather than computed digits — a static banner is immune to the `PRINTDEC16` spacing bug it partly exists to help diagnose. Bump it by hand when DASH changes.
- **Named constants**: The `$70-$8F` ZP equates and every other DASH magic number (page model, screen geometry, `SYS_OFF_*` / `APP_OFF_*` record maps, `VMMSTATE_*` / `VMMFAIL_*` enums, `DOS_*` API codes, `KEY_*`, `ROW_*`, `COL_*`) are named constants at the top of `dmain.s`, before any code (DASH-MOD WP3). A named-constant definition's RHS must be a bare literal — see the Dual-Assembler Subset note.
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
  - This map's contiguity, range, and non-overlapping two-byte pairs are `.assert`-guarded in `dash_wrapper.s` (DASH-MOD WP3, ca65-only — CASM has no comparison operator; the ca65↔CASM byte cross-check covers the CASM side). The `$70-$8F` equates and every other DASH magic number are named constants declared in `dmain.s`'s prologue before any code.
- **OS API Jump Table**: Exclusively queries kernel services via the `OS_API` (`$1000`) jump table.
- **Exit Procedure**: Terminates using `DOS_EXIT` (`A = $4C`, `JSR OS_API`).
- **Event loop / key dispatch** (`dmain.s`, DASH-MOD WP4): `POLLINPUT` reads `KERNAL_GETIN`, then — F1/F3/F5 (`$85`-`$87`, consecutive) select a page by `page = key - KEY_F1` (range-checked against `KEY_F1 + PAGECOUNT`), feeding a single select path; `T`/`R`/`Q` are matched after `AND #KEY_CASE_MASK` (`$DF`) folds the shifted/lowercase-charset variant onto the base code, so one compare each covers both PETSCII forms. `MARKREDRAW` (`NEEDREDRAW := 1`) is the shared redraw request. `T` (`TRYRUNVMMTEST`) is gated on `CURRPAGE = PAGE_VMM`.

# Work Guidance

- **UPPERCASE ONLY (load-bearing)**: Every byte of these files — mnemonics, labels, hex digits, **and comment text** — must be uppercase ASCII. `cc1541 -w` writes host bytes to the SEQ verbatim with no translation, and ASCII lowercase `a`-`z` (`$61`-`$7A`) are *not* letters in PETSCII; CASM rejects them with `CASM_DIAG_INVALID_SOURCE_BYTE`. ASCII uppercase `A`-`Z` (`$41`-`$5A`) coincides exactly with the PETSCII letter range, so an all-uppercase host file needs no conversion step. `banner.s` follows the same rule and is the proven precedent. This is safe for identifiers only because no two differ solely by case — check that before renaming anything.
- **Differential Guidance (transitioned from dual-assembler in Byte-Oracle WP5)**: The primary and authoritative assembler for DASH is native CASM. `dash_ref` (ca65) is no longer built by `ALL`, required at configure time, or a hard dependency of `command64_casm_utils_d64` — build it on demand with `cmake --build build --target dash_ref`. **But** DASH's 3,669 code/data bytes are *not* independently byte-derived (see `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md`): they are reviewed native observation, and the `dash_ref` differential is their **standing independent corroboration**. So while DASH source stays in the shared syntax subset below, the **release process runs `dash_ref` and compares it to `dash.prg`** — treat a mismatch as a release blocker, not an optional nicety. Only when a future DASH feature deliberately adopts CASM-native syntax that ca65 rejects does `dash_ref` cease to build without being a defect — and that WP must record the loss of this corroboration and add a fresh native `COMP` in its place. Concretely, for differential compatibility:
  - **No segment directives.** CASM has no segment concept — it emits one linear stream in command-line file order. The single `.segment` ca65 needs lives in `dash_wrapper.s`, the ca65-only wrapper.
  - **Audited string literals only.** CASM supports raw-PETSCII strings in
    `.BYTE` lists. Use them only for runs proven byte-identical under ca65's
    active C64 charmap: digits, `.`, `-`, `/`, `$`, space, `?` are proven
    safe (`DASHVERSTR`, `APPRANGEBADSTR`, the `SYSL_*`/`VMML_*` label
    fragments). Screen-code **letters** remain explicit bytes because ca65
    remaps source letters and would break native/host identity.
  - **Equates must precede every use, and there are no mid-code equates.** ca65 cannot select zero-page addressing for a forward-referenced equate, and a mid-code `=` splits a `@local` scope differently under each assembler (see below). Every DASH constant lives in the `dmain.s` prologue before any code (the "Named constants" contract) — keep it that way.
  - **No character literals.** ca65's character mapping does not preserve the raw keyboard-byte values native CASM assigns to uppercase literals (`'T'` becomes `$D4`, not `$54`). Keep keyboard and screen-code operands as explicit hex bytes or named constants (`KEY_T = $54`, `SCREENCODE_VBAR = $5D`).
  - **`@local` labels are shared (CASM Phase 14 WP87-90); anonymous `:+`/`:-` are NOT.** A `@name` label is a cheap local scoped to the nearest preceding non-`@` label in **both** assemblers — ca65's native cheap-local feature and CASM's own `@local`. **Every** routine-internal loop/skip/done target in DASH is a `@local` (DASH-MOD WP2 migrated all seven files); only routine entry points, cross-file symbols, and `ddata.s`'s labels stay global. Use `@LOOP`/`@DONE`/`@FAIL`-style names for any new internal target. Two constraints keep the two assemblers in agreement:
    - **No `=` equate may sit between a label and its `@locals`.** ca65 ends a cheap-local scope at *any* non-`@` symbol including an `=` equate; CASM ends it only at a `NAME:` label. DASH already declares every equate at the top of `dmain.s` before code (see "Equates must precede every use"), so within the executable sections the two rules coincide — but a new mid-code equate would silently split the scope differently under each assembler.
    - **Never reuse one `@name` within a single CASM scope.** CASM rejects a redefined `@local` in the same scope (`DUPLICATE LOCAL LABEL IN SCOPE`); ca65, whose scope may have been split by an `=`, might not. Keep each `@name` unique between one `NAME:` label and the next.
    Anonymous ca65 labels (`:`, `:+`, `:-`) have no CASM equivalent yet (deferred past Phase 14) — do not use them.
  - **Accumulator shifts must be written `asl a`.** CASM maps a no-operand shift to `MODE_IMPLIED` and has *no* implied-to-accumulator fallback (`opcodesFindOpcode`), so a bare `asl` is a hard `CASM_DIAG_INVALID_ADDR_MODE`. ca65 accepts both spellings; only `asl a` works in both.
  - **Expressions are bounded**: parenthesised arithmetic and the Phase 12 operators are available at *instruction-operand* use sites where both assemblers produce identical values (proven in DASH-MOD WP3: `#(2 * SCREEN_COLS)`, `#>COLOR_RAM`, `SYMBOL + OFFSET + 1`). But a **named-constant definition's RHS must be a bare literal** — native CASM's `NAME = ...` parser rejects an operator there (`SYS_VMMFLAG_ACTIVE = 1<<0` → `EXPECTED NEWLINE`; write flag masks as `1`/`2`/`4`/`8`). ZP pointer high bytes use `SYMBOL+1`.
  - **`.ASSERT` is shared, in the ca65 action-keyword form only.** ca65's `.assert` *requires* an action keyword: `.ASSERT cond, ERROR[, "MSG"]` (also `WARNING`/`LDERROR`/`LDWARNING`). Native CASM accepts that exact spelling (DASH-MOD WP1) and evaluates the assertion at pass time, fatal on a false result, for every keyword. CASM's own keyword-less legacy forms (`.ASSERT cond`, `.ASSERT cond, "MSG"`) are **not** ca65-compatible — never use them here. Assertions emit no bytes. **But equality/range invariants (`a = b`, `a >= b`) can only be expressed under ca65** — CASM's expression grammar has no comparison operator (only `+ - | ^ & << >> * /`), so a CASM `.ASSERT` is nonzero-truthiness only. DASH's structural invariants (`PAGECOUNT = 3`, the `$70-$8F` ZP map, the API `$40-$5F` band, the `PAGEROUTINETABLE` size) therefore live in `dash_wrapper.s`, the ca65-only wrapper, as `.assert cond, error, "msg"`; the ca65↔CASM byte cross-check covers the CASM side (DASH-MOD WP3).
  - **`.RES count[, value]` is shared; `.FILL` is not.** CASM's Phase 13 `.RES` (WP84 adopted it for `ddata.s`'s `FMTBUF`/`SYSINFOBUF`/`APPBUF`/`BORDERROW`/`VMMBUFFER`) has a byte-identical ca65 counterpart (`.res count[, fillval]`), independently verified to emit the literal fill bytes — not just reserve BSS space — in a non-BSS segment. CASM's `.FILL` has **no ca65 equivalent at all** (`.fill` is not a recognized ca65 directive); express any required-value fill as `.RES count, value` instead, never `.FILL`, or the ca65 cross-check breaks outright.
- **Source Order Is Authoritative, Specified Once**: `dmain.s` pulls in the other six sources itself via `.INCLUDE "DSCR.S"` / `.INCLUDE "DFMT.S"` / ... / `.INCLUDE "DDATA.S"` (native CASM's include facility, operational since CASM WP47), and `dash_wrapper.s` (the ca65-only wrapper) does nothing but `.include "dmain.s"` — its own `.INCLUDE` chain then does the rest for both toolchains. `ddata.s` stays last so data follows all code. Because both toolchains now read the order from the same six lines instead of it being hand-duplicated between a CASM command line and `dash_wrapper.s`'s own include list, the two can no longer silently drift out of sync.
  - **Case mismatch is expected and handled by the build, not the source**: the `.INCLUDE` operands are uppercase (`"DSCR.S"`), matching the uppercase PETSCII directory entries `cc1541 -f` writes on the packaged disk (same byte-matching mechanism the old multi-file CLI already relied on). ca65 resolves `.include` operands as literal filesystem paths on this case-sensitive host, where the real files are lowercase (`dscr.s`). `CMakeLists.txt` generates uppercase symlinks into `${CMAKE_BINARY_DIR}/dash_ref_includes/` at configure time and passes that directory to the `dash_ref` ca65 build via `add_ca65_app`'s `EXTRA_INCLUDE_DIRS`, so the identical operand spelling resolves for both toolchains without renaming any checked-in file.
- **Dispatch Trampoline**: `DISPATCHPAGE` validates `CURRPAGE` against `PAGECOUNT`, indexes `PAGEROUTINETABLE` by `CURRPAGE * PAGE_ROUTINE_ENTRY_SIZE` (the `ASL A`), stashes the target routine's high/low bytes through `DISPATCHVECTOR` (`$70/$71`), pushes `@RETURNMINUSONE` onto the stack, and executes `JMP (DISPATCHVECTOR)`; the renderer's `RTS` lands on `@RETURN`.
- **Renderer helpers** (DASH-MOD WP5): `dscr.s` `COPYFRAMEROW` (dest row in A, source pointer in X/Y, via `COMPUTEROWADDR`) draws each of `DRAWFRAME`'s 7 full-width template rows — one call each, no inline loops. `dsys.s` `DSYSLABEL` (row in A, label pointer in X/Y) is the shared "cursor to `COL_CONTENT,row` then print" opener every System-page row renderer uses. `dapp.s` `DAPPPRINTFLAGS` loops over the `APPFLAGMASKS` / `APPFLAGCHARS` tables (`ddata.s`) instead of four inline cells. The old unbounded `PRINTAT` routine was **removed** (dead). `dvmm.s` was surveyed but not refactored — its capability-gated string-selection ladders were left explicit; a `DVMMLABEL` helper + enum→string tables are a noted future item (see the WP5 walkthrough).

# Artifact Provenance

DASH ships from a **reviewed hex manifest** (`dash.ref.hex`), transcribed to a PRG at build time by `scripts/hex_manifest_to_bin.py` — a script with no 6502 knowledge and no assembler.

- The manifest records canonical bytes produced by **native CASM running on the C64** and backed by an independent byte and relocation derivation (`brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md`). It is regenerated only by a deliberate human act (`scripts/build_dash_manifest.py`), never as a build step, so editing a source can never silently change what ships.
- The ca65 `dash_ref` target is an **optional differential cross-check only** and must never be the source of manifest bytes. `build_dash_manifest.py` strictly refuses host builds as manifest input.
- The cross-check is non-circular: ca65 and CASM share no code and derive relocation entries by completely different means — `tools/reloc.py` diffs two links one page apart, while CASM classifies each operand as relocatable during emission. A defect in one cannot reproduce itself in the other.
- **Stale-artifact protection (WP9)**: `dash.ref.hex` embeds one `# source_sha256: <name>=<hash>` line per source file, written by `build_dash_manifest.py`. The `dash` CMake target always passes `--source-dir` to `hex_manifest_to_bin.py`, which recomputes each file's hash and hard-fails the build on any mismatch, missing file, or a manifest with no recorded hashes at all — editing a source without regenerating the manifest is a build failure, not a silent stale ship.
- **Current provenance** (DASH `0.2.0`, DASH-MOD WP6, 2026-09-01; WP4 independent canonical record):
  `dash.ref.hex`'s shipping bytes come from native CASM `0.5.2` build
  `1404` under VICE 3.10 with a 16MB REU, assembled from the seven SEQ
  sources on `command64_casm_utils.d64` (`CASM DMAIN.S /O:DW6.PRG`).
  `COMP DW6.PRG DASH.REF` on the C64 -> `FILES COMPARE OK`; the extracted
  `DW6.PRG` matches the independent canonical derivation and ca65 differential
  byte-for-byte: **4579 bytes, sha256
  `3b4d0693a6413e7e7d328f18276b6beae3d5cbecccbe7578cfe9a13504121984`**,
  451 relocation entries. `dash` ships on `image_d64` (production only, never
  `test.d64`) from these reviewed native bytes.

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

Note: the CMake `command64_casm_utils_d64` target now also packages the
built `dash.prg`, so `CASM DMAIN.S /O:DASH.PRG` on a freshly-built utils
disk fails with `OUTPUT WRITE FAILED` (`fileCreateOutput` has no replace
mode). For a byte-check run, assemble to a scratch name (`/O:DW.PRG`) and
`COMP DW.PRG DASH.REF`.

Native CASM requires an REU for assembly; the resulting DASH runtime does not.

# Verification

- Output header/footer base is `$3400`; footer magic is `52 36` (`R6`).
- `COMP DASH.PRG DASH.REF` matches byte-for-byte on the C64, and re-running CASM with no source change reproduces identical bytes.
- Relocation entries cover only eligible program bytes: `.WORD` renderer pointers, absolute label operands, and `#>label` high bytes. Fixed targets produce **no** entries — `$1000`, `$FFE4`, screen/colour RAM (`$0400`-`$07FF`, `$D800`-`$DBFF`), and ZP `$70`-`$8F`. `#<label` low bytes are correctly excluded (`applyExtraction` clears `RELOCATABLE` for `<`).
- Repeated page dispatch leaves the stack balanced: `DISPATCHPAGE` pushes 2 bytes (`@RETURNMINUSONE`), the renderer's `RTS` consumes them landing on `@RETURN`, whose `RTS` consumes the original caller return. Net delta zero.
- The same artifact runs identically at `$3800`, `$5000`, and `$9000`, without an REU — spot-checked live via `LOAD DASH <hex>` / `RUN <hex>` and the Applications page's `dash <hex>-....` load-range readout.
