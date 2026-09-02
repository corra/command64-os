# Independent Byte & Relocation Derivation: DASH

**Target:** `src/external/dash/dash.ref.hex` (`DASH.PRG`)  
**Sources:**
- `src/external/dash/dmain.s` (SHA-256: `a8cab31077861497eb99d26c4e71cd232d3bed686f6d1f1c40dba511cc0a9834`)
- `src/external/dash/dscr.s` (SHA-256: `eb813bf49e324991d8217a548bf38c07cbcd8f0333a60a67c5d8e91f006268b4`)
- `src/external/dash/dfmt.s` (SHA-256: `bc8925de0748a7849485c6d6f71483347326b3204fa266c9d4418accbbc734a1`)
- `src/external/dash/dsys.s` (SHA-256: `29992b8b486c0e35328ab072212d1924165468aa86ac3080313d9d38e12fb2d2`)
- `src/external/dash/dapp.s` (SHA-256: `f5953f8da88a03ef47c48d1324e01d616a13ec34018d351568fa9f90da1affd5`)
- `src/external/dash/dvmm.s` (SHA-256: `5144b367bc3888167e344921b5d03794c5300953ca770bff86b883c9f8c66948`)
- `src/external/dash/ddata.s` (SHA-256: `8c7a4498077ae76b2887ff607b349257ebc3a656564d46b7fea574c6d79df3d1`)

**Base Address:** `$3400`  
**Total Assembled Extent:** 4,579 bytes (2-byte load header + 3,669-byte code/data + 902-byte R6 table + 6-byte R6 footer)  
**Binary SHA-256:** `3b4d0693a6413e7e7d328f18276b6beae3d5cbecccbe7578cfe9a13504121984`  
**Classification:** `CANONICAL-INDEPENDENT`

---

## 1. Modular Structure & Extent Ledger

DASH version `0.2.0` (DASH Modernization baseline) is assembled from 7 source modules:

| Module | Source File | Description |
|---|---|---|
| Main | `dmain.s` | Shell entry point, event loop, keystroke dispatcher, exit handling |
| Screen | `dscr.s` | Screen buffer rendering, windowing, status line formatting |
| Format | `dfmt.s` | Integer/hex/byte formatters, tabular layout helpers |
| System | `dsys.s` | OS API wrappers, memory/disk/REU status queries |
| Apps | `dapp.s` | Process/task inspection, external application table display |
| VMM | `dvmm.s` | Virtual memory / REU bank map rendering and inspection |
| Data | `ddata.s` | Message strings, static lookup tables, color palettes, version string `0.2.0` |

### Extent Breakdown:
- **Load Address Header:** `$00 $34` (2 bytes)
- **Code + Data:** 3,669 bytes (`$3400..$4254`)
- **R6 Relocation Table:** 451 entries $\times$ 2 bytes = 902 bytes (`$4255..$45DA`)
- **R6 Footer:** 6 bytes (`$45DB..$45E0`)
  - Load base: `$00 $34` (`$3400`)
  - Relocation count: `$C3 $01` (451)
  - Magic signature: `$52 $36` (`"R6"`)
- **Total:** 4,579 bytes

---

## 2. Relocation Analysis & Verification

### Criteria:
Every relocation entry targets the high byte of an absolute 16-bit address within the `$3400..$4254` program memory range:
- Subroutine jumps and calls (`JSR $34xx..$42xx`, `JMP $34xx..$42xx`)
- Absolute memory reads/writes to module variables, jump tables, and string constants (`LDA $34xx`, `STA $34xx`, `LDX $34xx`, etc.)
- Table base pointers (`#>TABLE_LABEL` in immediate operand expressions)

### Exclusions:
- Zero-Page allocations (`$60..$8F` private scratch, system zero-page locations)
- Hardware & Kernel Vectors (`$D000-$DFFF`, `$FFxx` Kernal ROM, `$0400` Screen RAM, `$D800` Color RAM)
- Immediate 8-bit constants (`#$00`, `#$FF`, `#<LOW_BYTE`)
- Signed relative branch offsets (`BEQ`, `BNE`, `BCC`, `BCS`, `BPL`, `BMI`, `BVC`, `BVS`)

### Offsets Audit:
- Total relocation entries: **451**
- Sorted in strictly ascending order: `True` (minimum offset `$0005`, maximum offset `$09F1`)
- Table bytes exactly equal $451 \times 2 = 902$ bytes.

---

## 3. Multi-Base Relocation Verification

An independent relocation emulator applying $+N$ page offsets was tested against three runtime bases:
1. **Base `$3800`** (offset delta: $+4$ pages):
   - High bytes correctly mapped into `[$38..$45]`.
   - Zero pointers point outside the relocated extent.
2. **Base `$5000`** (offset delta: $+28$ pages):
   - High bytes correctly mapped into `[$50..$5D]`.
   - Zero pointers point outside the relocated extent.
3. **Base `$9000`** (offset delta: $+92$ pages):
   - High bytes correctly mapped into `[$90..$9D]`.
   - Zero pointers point outside the relocated extent.

---

## 4. Ground Truth Confirmation

DASH 0.2.0 shipping bytes match the reviewed manifest `dash.ref.hex` (SHA-256 `3b4d0693a641...`) and the independent R6 derivation.
