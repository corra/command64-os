# Application Manager Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase A of the app table — a VMM-backed registry of loaded programs with LOAD/RUN/GO/APPS/PS/FREE integration, enforcing table membership before execution, at a fixed $2200 entry point.

**Architecture:** A new `apptable.asm` segment at $2000 (512 bytes) manages a VMM-allocated 4KB page containing a 16-slot app table (40 bytes/slot, 644 bytes total). UserProgStart shifts from $2000 to $2200. Shell commands call internal API labels (not service bus). Phase B/C extend the same entry points without changing the API surface.

**Tech Stack:** KickAssembler 5.25, 6502 assembly, C64 REU/VMM, GNU Make

---

## File Map

| File | Action | What changes |
|------|--------|-------------|
| `include/command64.inc` | Modify | Add APT_* constants, AptSegLo/Hi; shift UserProgStart to $2200 |
| `src/command64/apptable.asm` | **Create** | All app table logic: aptInit, aptProtectedCheck, aptSlotBase, aptNameMatch, aptFind, aptRegister, aptRemove, aptList, aptPrintHex8 |
| `src/command64.asm` | Modify | Add AppTable segment + import |
| `src/command64/shell.asm` | Modify | aptInit call at startup; modified cmdLoad/cmdRun; new cmdApps, cmdFree; new message strings |
| `src/external/debug/debug.asm` | Modify | Change `* = $2000` → `* = $2200` |
| `tests/src/*.asm` (all 6) | Modify | Change `* = $2000` → `* = $2200` |
| `brain/COMMANDS.md` | Modify | Add APPS, PS, FREE |
| `brain/KNOWLEDGE.md` | Modify | Document app table VMM allocation, protected ranges |
| `CHANGELOG.md` | Modify | All tasks |

## VMM & ZP Calling Conventions (read before implementing)

- `vmmReadByte` / `vmmWriteByte`: Input via `VmmSegLo/Hi` ($68/$69) + `VmmOffLo/Hi` ($6A/$6B). **Clobbers A, TempLo ($64), TempHi ($65), Y.** Preserves X, VmmSegLo/Hi, VmmOffLo/Hi.
- `vmmAlloc`: Input `VmmSegLo/Hi` = requested paragraphs; returns segment in `VmmSegLo/Hi`.
- `SrcHandle` ($6E) = name byte length passed to aptRegister/aptFind name mode.
- `DstHandle` ($6F) = scratch used by aptSlotBase (slot multiplication). Clobbered; set to 0 on return.
- `aptSlotBase`: Preserves X (uses DstHandle as countdown, not X).
- `aptPrintHex8`: Clobbers A, X. Preserves Y.

---

## Task 1: APT_* Constants + UserProgStart Shift

**Files:**
- Modify: `include/command64.inc`
- Modify: `src/external/debug/debug.asm`
- Modify: `tests/src/color.asm`, `tests/src/extcls.asm`, `tests/src/hello.asm`, `tests/src/vmmtest.asm`, `tests/src/filetest.asm`, `tests/src/apitest.asm`

- [ ] **Step 1: Add APT_* constants and AptSegLo/Hi to `include/command64.inc`**

In `include/command64.inc`, replace the existing `UserProgStart` block with the following (keep UserProgEnd unchanged):

```asm
// --- App Table: Phase A Constants ---
.label APT_MAX_SLOTS    = 16       // compile-time max entries
.label APT_ENTRY_SIZE   = 40       // bytes per entry
.label APT_HEADER_SIZE  = 4        // bytes for table header (MaxSlots, UsedSlots, reserved×2)
.label APT_OFF_FLAGS    = 0        // entry field: Flags
.label APT_OFF_NAME     = 1        // entry field: Name (16 bytes, PETSCII null-padded)
.label APT_OFF_ADDR     = 17       // entry field: LoadAddr lo/hi
.label APT_OFF_SIZE     = 19       // entry field: Size lo/hi (byte count)
.label APT_FLAG_USED    = $01      // Bit 0: slot in use
.label APT_FLAG_RUNNING = $02      // Bit 1: app currently executing
.label APT_FLAG_REU     = $04      // Bit 2: REU-backed image (Phase C)
.label APT_FLAG_STACK   = $08      // Bit 3: stack saved (Phase C)
// AptSegLo/Hi occupy first 2 bytes of cassette buffer free area ($03F2-$03FF)
.label AptSegLo         = $03F2    // persistent: APT VMM segment lo (0 = not yet allocated)
.label AptSegHi         = $03F3    // persistent: APT VMM segment hi

// --- User Program Space ---
// Shifted from $2000 to $2200 to make room for the AppTable segment ($2000-$21FF).
.label UserProgStart = $2200
.label UserProgEnd   = $9FFF
```

- [ ] **Step 2: Update debug.asm load address**

In `src/external/debug/debug.asm`, change the segment origin at line 1:

```asm
* = $2200 "Debug"
```

(was `* = $2000`)

- [ ] **Step 3: Update all test ASM files**

In each of the 6 files in `tests/src/`, change `* = $2000` to `* = $2200`. They all use the same pattern:

```asm
* = $2200 "ProgramName"
```

- [ ] **Step 4: Build and verify**

```bash
make
```

Expected: build completes with no errors. The segment layout comment at the top of `src/command64.asm` is not yet updated (that's Task 2).

- [ ] **Step 5: Commit**

```bash
git add include/command64.inc src/external/debug/debug.asm tests/src/
git commit -m "feat: add APT_* constants and shift UserProgStart to \$2200 for AppTable"
```

---

## Task 2: Create `apptable.asm` Skeleton + Wire into Build

**Files:**
- Create: `src/command64/apptable.asm`
- Modify: `src/command64.asm`
- Modify: `src/command64/shell.asm` (startup only)

- [ ] **Step 1: Create `src/command64/apptable.asm`** with aptSlotBase, aptInit, aptProtectedCheck, and data stubs

```asm
// src/command64/apptable.asm
// KickAssembler v5.25 — App Table Phase A
// Manages a 16-slot loaded-program registry in one VMM-allocated 4KB page.
// Entry stride: APT_ENTRY_SIZE = 40 bytes. Header: 4 bytes at VMM offset 0.

.segment AppTable [start=$2000]

// -----------------------------------------------------------------------
// aptSlotBase — set VmmSeg/Off to the base of slot X's entry
// Input:  X = slot index 0..APT_MAX_SLOTS-1
// Output: VmmSegLo/Hi = AptSegLo/Hi; VmmOffLo/Hi = APT_HEADER_SIZE + X*APT_ENTRY_SIZE
// Clobbers: A, DstHandle (= 0 on return)
// Preserves: X
// -----------------------------------------------------------------------
aptSlotBase:
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    stx DstHandle           // countdown (DstHandle, not X — X is unchanged)
    lda #APT_HEADER_SIZE    // start offset = 4
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    lda DstHandle
    beq asbDone
asbLoop:
    clc
    lda VmmOffLo
    adc #APT_ENTRY_SIZE     // += 40 per slot
    sta VmmOffLo
    bcc asbNoCarry
    inc VmmOffHi
asbNoCarry:
    dec DstHandle
    bne asbLoop
asbDone:
    rts

// -----------------------------------------------------------------------
// aptInit — allocate one VMM page; write table header
// Call once from shell startup after env block alloc, inside the vmmInitialized block.
// Idempotent: returns immediately if AptSegLo/Hi already non-zero.
// -----------------------------------------------------------------------
aptInit:
    lda AptSegLo
    ora AptSegHi
    bne aiDone              // non-zero: already allocated
    lda #0
    sta VmmSegLo
    lda #1                  // 256 paragraphs = 4KB = 1 VMM page
    sta VmmSegHi
    jsr vmmAlloc
    lda VmmSegLo
    sta AptSegLo
    lda VmmSegHi
    sta AptSegHi
    // Write header at VMM offset 0: MaxSlots, UsedSlots=0, reserved×2
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda #APT_MAX_SLOTS      // offset 0: MaxSlots = 16
    jsr vmmWriteByte
    inc VmmOffLo
    lda #0
    jsr vmmWriteByte        // offset 1: UsedSlots = 0
    inc VmmOffLo
    jsr vmmWriteByte        // offset 2: reserved
    inc VmmOffLo
    jsr vmmWriteByte        // offset 3: reserved
aiDone:
    rts

// -----------------------------------------------------------------------
// aptProtectedCheck — reject load addresses in protected regions
// Protected: $0000-$21FF (OS + AppTable), $C000-$FFFF (VMM MCT, I/O, KERNAL)
// Input:  HexValLo/Hi = proposed load address
// Output: carry set = protected (reject), carry clear = OK
// Clobbers: A
// -----------------------------------------------------------------------
aptProtectedCheck:
    lda HexValHi
    cmp #$22                // addr < $2200?
    bcc apcProtected
    cmp #$C0                // addr >= $C000?
    bcs apcProtected
    clc
    rts
apcProtected:
    sec
    rts

// -----------------------------------------------------------------------
// Data area (remainder of tasks append stubs here)
// -----------------------------------------------------------------------
aptSearchMode:  .byte 0    // 0 = name search, 1 = address search
aptNameIndex:   .byte 0    // byte index used in aptNameMatch and aptRegister name copy
aptUsedSlots:   .byte 0    // saved UsedSlots count for aptList footer
```

- [ ] **Step 2: Wire `apptable.asm` into `src/command64.asm`**

In `src/command64.asm`, add `AppTable` to the `.file` segments list and import the file:

```asm
// src/command64.asm
// Segment layout:
//   Main          $0801  BASIC SYS launcher (BasicUpstart2)
//   Utils         $0C00  Hex parsing and string utilities
//   Api           $0D00  INT 21h Service Bus (Jump Table)
//   Loader        $0E00  KERNAL binary loader wrapper
//   Path          $0F00  Directory search and path logic
//   ApiStub       $1000  Stable OS Entry Point (Jump Table)
//   Petsci        $1040  PETSCII print routines
//   CommandTable  $1080  Fixed-width command dispatch table
//   CommandShell  $1180  Command loop, dispatcher, built-ins
//   Vmm           $1B80  Virtual Memory Manager (REU mapping)
//   File          $1D80  Handle-based File I/O
//   VmmData       $1F90  VMM temporary storage
//   AppTable      $2000  App table logic (UserProgStart shifts to $2200)

.file [name="command64.prg", segments="Main,ApiStub,Petsci,CommandTable,CommandShell,Api,Utils,Loader,Path,Vmm,File,VmmData,AppTable"]

.segmentdef Main [start=$0801]
.segmentdef VmmData [start=$1F90]

#import "../include/command64.inc"
#import "command64/petsci.asm"
#import "command64/api.asm"
#import "command64/utils.asm"
#import "command64/loader.asm"
#import "command64/path.asm"
#import "command64/vmm.asm"
#import "command64/file.asm"
#import "command64/apptable.asm"
#import "command64/shell.asm"

.segment Main
BasicUpstart2(start)
```

- [ ] **Step 3: Call `aptInit` from shell startup in `src/command64/shell.asm`**

In `shell.asm`, the `start:` routine has a block that runs only when `vmmInitialized` is set. Add `jsr aptInit` right after the double-null env initialization (after `jsr vmmWriteByte` for the second null):

```asm
    // Initialize with double null (empty environment)
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda #0
    jsr vmmWriteByte
    inc VmmOffLo
    lda #0
    jsr vmmWriteByte

    jsr aptInit             // allocate app table VMM page and write header

siSkipEnv:
```

- [ ] **Step 4: Build and verify**

```bash
make
```

Expected: build completes. The `AppTable` segment occupies $2000. AppTable code must fit within $0200 bytes (512 bytes). KickAssembler will error if it overflows into $2200.

- [ ] **Step 5: Commit**

```bash
git add src/command64/apptable.asm src/command64.asm src/command64/shell.asm
git commit -m "feat: add AppTable segment with aptInit and aptProtectedCheck"
```

---

## Task 3: `aptFind` + `aptNameMatch`

**Files:**
- Modify: `src/command64/apptable.asm` — append aptNameMatch and aptFind

- [ ] **Step 1: Append `aptNameMatch` to `apptable.asm`** (before the data area)

```asm
// -----------------------------------------------------------------------
// aptNameMatch — compare SrcHandle bytes from NamePtrLo/Hi against VMM name field
// Entry name starts at current VmmOffLo/Hi. Null-padded to 16 bytes.
// Input:  VmmSegLo/Hi and VmmOffLo/Hi set to name field start
//         SrcHandle = search name byte count
//         NamePtrLo/Hi = pointer to search name (NOT modified)
// Output: carry clear = full match; carry set = no match
// Clobbers: A, Y, DstHandle, VmmOffLo (advanced SrcHandle+1 bytes on any path)
// Preserves: X, NamePtrLo/Hi
// -----------------------------------------------------------------------
aptNameMatch:
    lda #0
    sta aptNameIndex        // byte index 0..SrcHandle-1
    lda SrcHandle
    sta DstHandle           // byte countdown
anmLoop:
    lda DstHandle
    beq anmCheckEnd
    jsr vmmReadByte         // A = entry name byte; Y clobbered
    ldy aptNameIndex        // reload index (Y clobbered by vmmReadByte)
    cmp (NamePtrLo), y      // compare against search name[aptNameIndex]
    bne anmMiss
    inc VmmOffLo            // advance VMM name position
    inc aptNameIndex        // advance search index
    dec DstHandle
    jmp anmLoop
anmCheckEnd:
    // All bytes matched; verify entry name is not longer (next byte must be $00)
    jsr vmmReadByte
    inc VmmOffLo
    cmp #0
    bne anmMiss             // entry name is longer → no match
    clc
    rts
anmMiss:
    sec
    rts
```

- [ ] **Step 2: Append `aptFind` to `apptable.asm`** (before the data area)

```asm
// -----------------------------------------------------------------------
// aptFind — scan app table for a matching name or address
// Input:  carry clear = name mode: NamePtrLo/Hi = name ptr, SrcHandle = name length
//         carry set   = address mode: HexValLo/Hi = load address to match
// Output: carry clear + X = slot index on found; carry set = not found
//         On found: HandlerVecLo/Hi = LoadAddr from the matched entry
// Clobbers: A, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// Preserves: SrcHandle, NamePtrLo/Hi, HexValLo/Hi
// -----------------------------------------------------------------------
aptFind:
    bcs afSetAddrMode
    lda #0                  // name mode
    .byte $2C               // BIT $xxxx — skip next lda #1
afSetAddrMode:
    lda #1                  // address mode
    sta aptSearchMode
    ldx #0                  // slot counter
afScanLoop:
    cpx #APT_MAX_SLOTS
    bcs afNotFound
    jsr aptSlotBase         // VmmSeg/Off = entry base; X preserved; DstHandle = 0
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_USED
    beq afNextSlot          // skip unused slots
    lda aptSearchMode
    bne afCheckAddr
    // --- Name search ---
    inc VmmOffLo            // advance to APT_OFF_NAME (base + 1)
    jsr aptNameMatch        // carry clear = match
    bcc afFound
    jmp afNextSlot
afCheckAddr:
    // --- Address search: advance to APT_OFF_ADDR (base + 17) ---
    clc
    lda VmmOffLo
    adc #APT_OFF_ADDR       // = 17
    sta VmmOffLo
    bcc afAddrRead
    inc VmmOffHi
afAddrRead:
    jsr vmmReadByte         // A = LoadAddr lo
    cmp HexValLo
    bne afNextSlot
    inc VmmOffLo
    jsr vmmReadByte         // A = LoadAddr hi
    cmp HexValHi
    bne afNextSlot
    // Address match — fall through to afFound
afFound:
    // Load HandlerVecLo/Hi from LoadAddr field (reset VmmOff to base + APT_OFF_ADDR)
    jsr aptSlotBase
    clc
    lda VmmOffLo
    adc #APT_OFF_ADDR
    sta VmmOffLo
    bcc afReadLo
    inc VmmOffHi
afReadLo:
    jsr vmmReadByte
    sta HandlerVecLo
    inc VmmOffLo
    jsr vmmReadByte
    sta HandlerVecHi
    clc
    rts
afNextSlot:
    inx
    jmp afScanLoop
afNotFound:
    sec
    rts
```

- [ ] **Step 3: Build and verify**

```bash
make
```

Expected: no errors. AppTable segment must still fit within $0200 bytes.

- [ ] **Step 4: Commit**

```bash
git add src/command64/apptable.asm
git commit -m "feat: add aptFind and aptNameMatch to apptable.asm"
```

---

## Task 4: `aptRegister`

**Files:**
- Modify: `src/command64/apptable.asm` — append aptRegister

- [ ] **Step 1: Append `aptRegister` to `apptable.asm`** (before the data area)

```asm
// -----------------------------------------------------------------------
// aptRegister — add or overwrite an app table entry
// If an entry with the same name already exists, it is overwritten (re-LOAD).
// Otherwise, the first free slot is used and UsedSlots is incremented.
// Input:  NamePtrLo/Hi = pointer to app name; SrcHandle = name byte length (1-16)
//         HexValLo/Hi = load address (intact after shellLoadPrg)
//         TempLo/Hi = end_addr+1 from KernalLOAD return (X/Y saved by caller)
// Output: carry clear on success; carry set if table full (no free slot found)
// Clobbers: A, X, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// Preserves: NamePtrLo/Hi, HexValLo/Hi
// -----------------------------------------------------------------------
aptRegister:
    // Save TempLo/Hi — clobbered by vmmWriteByte, needed for size computation at end
    lda TempHi
    pha
    lda TempLo
    pha
    // Search for existing entry with same name (overwrite on re-LOAD)
    clc                     // name mode
    jsr aptFind
    bcs arFindFree          // not found → find a free slot
    // Found: X = existing slot index; overwrite without bumping UsedSlots
    jmp arWriteEntry

arFindFree:
    ldx #0
arFreeLoop:
    cpx #APT_MAX_SLOTS
    bcs arFull
    jsr aptSlotBase
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_USED
    beq arGotFree
    inx
    jmp arFreeLoop

arGotFree:
    // Increment UsedSlots (VMM header offset 1)
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #1
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    jsr vmmReadByte         // A = current UsedSlots
    clc
    adc #1
    jsr vmmWriteByte        // write incremented value

arWriteEntry:
    jsr aptSlotBase         // VmmSeg/Off = entry base for slot X

    // --- Flags: set SLOT_USED ---
    lda #APT_FLAG_USED
    jsr vmmWriteByte
    inc VmmOffLo            // → APT_OFF_NAME (base + 1)

    // --- Name: copy SrcHandle bytes from NamePtrLo/Hi, null-pad to 16 bytes ---
    lda SrcHandle
    sta DstHandle           // byte countdown
    lda #0
    sta aptNameIndex        // source byte index
arNameLoop:
    lda DstHandle
    beq arNamePad
    ldy aptNameIndex
    lda (NamePtrLo), y      // read source name byte
    jsr vmmWriteByte
    inc VmmOffLo
    inc aptNameIndex
    dec DstHandle
    jmp arNameLoop
arNamePad:
    // Pad remaining bytes to fill 16-byte name field
    lda #16
    sec
    sbc SrcHandle           // remaining = 16 - name_length
    sta DstHandle
    beq arNameDone
arPadLoop:
    lda #0
    jsr vmmWriteByte
    inc VmmOffLo
    dec DstHandle
    bne arPadLoop
arNameDone:
    // VmmOffLo is now at base + 17 = APT_OFF_ADDR

    // --- LoadAddr lo/hi ---
    lda HexValLo
    jsr vmmWriteByte
    inc VmmOffLo
    lda HexValHi
    jsr vmmWriteByte
    inc VmmOffLo
    // VmmOffLo is now at base + 19 = APT_OFF_SIZE

    // --- Size = (end_addr+1) - LoadAddr ---
    // Restore TempLo/Hi (were pushed at top; clobbered by vmmWriteByte)
    pla
    sta TempLo              // end_addr+1 lo
    pla
    sta TempHi              // end_addr+1 hi
    lda TempLo
    sec
    sbc HexValLo
    pha                     // save size lo; TempLo/Hi about to be clobbered by vmmWriteByte
    lda TempHi
    sbc HexValHi            // size hi (carries borrow from previous sbc)
    tax                     // stash size hi in X (preserved by vmmWriteByte)
    pla                     // restore size lo
    jsr vmmWriteByte        // write size lo
    inc VmmOffLo
    txa
    jsr vmmWriteByte        // write size hi
    clc
    rts

arFull:
    pla                     // clean stack (TempLo)
    pla                     // clean stack (TempHi)
    sec
    rts
```

- [ ] **Step 2: Build and verify**

```bash
make
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/command64/apptable.asm
git commit -m "feat: add aptRegister to apptable.asm"
```

---

## Task 5: `aptRemove`

**Files:**
- Modify: `src/command64/apptable.asm` — append aptRemove

- [ ] **Step 1: Append `aptRemove` to `apptable.asm`** (before the data area)

```asm
// -----------------------------------------------------------------------
// aptRemove — clear a slot entry and decrement UsedSlots
// Phase A: does not touch REU backing store (no REU_BACKED entries yet).
// Input:  X = slot index (from aptFind)
// Output: carry clear always
// Clobbers: A, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// Preserves: X
// -----------------------------------------------------------------------
aptRemove:
    // Zero the Flags byte (clears SLOT_USED and all other flags)
    jsr aptSlotBase         // VmmSeg/Off = entry base
    lda #0
    jsr vmmWriteByte

    // Decrement UsedSlots (VMM header offset 1)
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #1
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    jsr vmmReadByte         // A = UsedSlots
    sec
    sbc #1
    jsr vmmWriteByte
    clc
    rts
```

- [ ] **Step 2: Build and verify**

```bash
make
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/command64/apptable.asm
git commit -m "feat: add aptRemove to apptable.asm"
```

---

## Task 6: `aptList` + `aptPrintHex8`

**Files:**
- Modify: `src/command64/apptable.asm` — append aptPrintHex8, aptList, and string literals

- [ ] **Step 1: Append `aptPrintHex8` and `aptList` to `apptable.asm`** (before the data area)

```asm
// -----------------------------------------------------------------------
// aptPrintHex8 — print A as two hex digits to screen
// Clobbers: A, X
// Preserves: Y
// -----------------------------------------------------------------------
aptPrintHex8:
    pha                     // save full byte
    lsr
    lsr
    lsr
    lsr                     // high nibble → A
    tax
    lda aptHexChars, x
    jsr KernalChROUT
    pla                     // restore full byte
    and #$0F                // low nibble
    tax
    lda aptHexChars, x
    jsr KernalChROUT
    rts

// -----------------------------------------------------------------------
// aptList — print all SLOT_USED entries to screen
// Output format (40-column):
//   name             addr  size
//   hello            2200   1a4
//   N app(s) loaded
// Input:  none
// Clobbers: A, X, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// -----------------------------------------------------------------------
aptList:
    // Read UsedSlots; print "no apps loaded" if zero
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #1
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    jsr vmmReadByte         // A = UsedSlots
    sta aptUsedSlots
    bne alHasApps
    lda #<aptNoAppsMsg
    ldy #>aptNoAppsMsg
    jsr petPrintString
    rts

alHasApps:
    lda #<aptListHeader
    ldy #>aptListHeader
    jsr petPrintString

    ldx #0                  // slot counter (preserved by vmmReadByte)
alScanLoop:
    cpx #APT_MAX_SLOTS
    bcs alFooter
    jsr aptSlotBase         // VmmOff = entry base; X preserved; DstHandle = 0
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_USED
    beq alNextSlot          // X is still the current slot index here
    stx DstHandle           // save slot index before aptPrintHex8 clobbers X
    // --- Print 16-char name field (null bytes print as space) ---
    inc VmmOffLo            // → APT_OFF_NAME (base + 1)
    lda #16
    sta aptNameIndex        // loop 16 times
alNameLoop:
    lda aptNameIndex
    beq alNameDone
    jsr vmmReadByte         // A = name byte; Y clobbered
    cmp #0
    beq alNamePad
    jsr KernalChROUT
    jmp alNameCont
alNamePad:
    lda #' '
    jsr KernalChROUT
alNameCont:
    inc VmmOffLo
    dec aptNameIndex
    jmp alNameLoop
alNameDone:
    // VmmOffLo = base + 17 = APT_OFF_ADDR
    lda #' '
    jsr KernalChROUT
    // --- Print LoadAddr: hi byte then lo byte (4 hex digits) ---
    jsr vmmReadByte         // A = LoadAddr lo
    pha
    inc VmmOffLo
    jsr vmmReadByte         // A = LoadAddr hi; X clobbered below
    jsr aptPrintHex8        // print hi (X clobbered)
    pla
    jsr aptPrintHex8        // print lo (X clobbered)
    lda #' '
    jsr KernalChROUT
    // --- Print Size: hi byte then lo byte ---
    inc VmmOffLo            // → APT_OFF_SIZE (base + 19)
    jsr vmmReadByte         // A = Size lo
    pha
    inc VmmOffLo
    jsr vmmReadByte         // A = Size hi
    jsr aptPrintHex8
    pla
    jsr aptPrintHex8
    lda #PetCr
    jsr KernalChROUT
    ldx DstHandle           // restore slot index

alNextSlot:
    inx
    jmp alScanLoop

alFooter:
    ldx aptUsedSlots
    ldy #0
    jsr printDecimal16
    lda #<aptAppsMsg
    ldy #>aptAppsMsg
    jsr petPrintString
    rts
```

- [ ] **Step 2: Add string literals and hex table to `apptable.asm` data area** (after the existing data stubs at the bottom)

Replace the end of `apptable.asm` (the data area) with:

```asm
// -----------------------------------------------------------------------
// Data area
// -----------------------------------------------------------------------
aptSearchMode:  .byte 0    // 0 = name search, 1 = address search
aptNameIndex:   .byte 0    // current byte index for name match/copy loops
aptUsedSlots:   .byte 0    // saved UsedSlots for aptList footer

aptHexChars:
    .text "0123456789abcdef"

aptListHeader:
    .text "name             addr  size"
    .byte PetCr, 0

aptNoAppsMsg:
    .text "no apps loaded"
    .byte PetCr, 0

aptAppsMsg:
    .text " app(s) loaded"
    .byte PetCr, 0
```

- [ ] **Step 3: Build and verify**

```bash
make
```

Expected: no errors. Verify `AppTable` fits in 512 bytes by checking KA's output or the map.

- [ ] **Step 4: Commit**

```bash
git add src/command64/apptable.asm
git commit -m "feat: add aptList and aptPrintHex8 to apptable.asm"
```

---

## Task 7: Modify `cmdLoad` in `shell.asm`

**Files:**
- Modify: `src/command64/shell.asm` — replace cmdLoad body; add new message strings

- [ ] **Step 1: Replace the `cmdLoad` handler** in `shell.asm`

Find the existing `cmdLoad:` label (around line 403) and replace the entire handler through `clError:` with:

```asm
// LOAD — load a .PRG from disk [address]
// Modified for Phase A: protected address check, table-full check, aptRegister.
cmdLoad:
    ldy ParsePos
    lda CommandBuffer, y
    beq clNoArgs

    sty TempLo              // save name start position
clScanName:
    lda CommandBuffer, y
    beq clDoneScan
    cmp #' '
    beq clDoneScan
    iny
    jmp clScanName
clDoneScan:
    sty TempHi              // save name end position

    tya
    sec
    sbc TempLo
    pha                     // push name length (restored at clDoLoad or error exits)

    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi

    ldy TempHi
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq clHeaderLoad

    jsr parseHex
    bcs clHeaderLoad
    lda #0                  // 0 = Relocated (uses HexVal)
    sta SpecificLoad
    jmp clCheckAddr
clHeaderLoad:
    lda #1                  // 1 = Absolute (uses file header)
    sta SpecificLoad

clCheckAddr:
    // Protected check only for relocated loads (we know the address)
    lda SpecificLoad
    bne clCheckFull
    jsr aptProtectedCheck
    bcs clProtected

clCheckFull:
    // Table-full check: skip if no REU (AptSegLo/Hi = 0)
    lda AptSegLo
    ora AptSegHi
    beq clDoLoad
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #1
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    jsr vmmReadByte         // A = UsedSlots
    cmp #APT_MAX_SLOTS
    bcs clTableFull

clDoLoad:
    pla                     // restore name length → A
    tax
    stx SrcHandle           // save for aptRegister
    lda NamePtrLo
    ldy NamePtrHi
    jsr findFile
    bcs clError
    stx SrcHandle           // findFile may update length in X; re-save
    lda NamePtrLo
    ldy NamePtrHi
    jsr shellLoadPrg        // X = end_addr+1 lo, Y = end_addr+1 hi on success
    bcs clError

    // Register in app table (skip if no REU)
    lda AptSegLo
    ora AptSegHi
    beq clDone
    // For header loads, LoadAddr is not in HexValLo/Hi — use UserProgStart as approximation
    lda SpecificLoad
    beq clGotAddr
    lda #<UserProgStart
    sta HexValLo
    lda #>UserProgStart
    sta HexValHi
clGotAddr:
    stx TempLo              // end_addr+1 lo (X/Y from KernalLOAD return)
    sty TempHi              // end_addr+1 hi
    jsr aptRegister         // carry clear on success; carry set = table full (already checked)

clDone:
    rts

clNoArgs:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts

clError:
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jsr petPrintString
    rts

clProtected:
    pla                     // clean name-length from stack
    lda #<aptProtectedMsg
    ldy #>aptProtectedMsg
    jsr petPrintString
    rts

clTableFull:
    pla                     // clean name-length from stack
    lda #<aptTableFullMsg
    ldy #>aptTableFullMsg
    jsr petPrintString
    rts
```

- [ ] **Step 2: Add new message strings** to the string literals section of `shell.asm` (after the existing `noDeviceMsg` at the bottom):

```asm
aptProtectedMsg:
    .text "protected address"
    .byte PetCr, 0

aptTableFullMsg:
    .text "app table full"
    .byte PetCr, 0

aptNotLoadedMsg:
    .text "not loaded"
    .byte PetCr, 0

aptNotFoundMsg:
    .text "not found"
    .byte PetCr, 0

aptRunningMsg:
    .text "app is running"
    .byte PetCr, 0
```

- [ ] **Step 3: Build and verify**

```bash
make
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add src/command64/shell.asm
git commit -m "feat: modify cmdLoad for protected check, table-full check, and aptRegister"
```

---

## Task 8: Modify `cmdRun` in `shell.asm`

**Files:**
- Modify: `src/command64/shell.asm` — replace cmdRun

- [ ] **Step 1: Replace the `cmdRun` handler** in `shell.asm`

Find the existing `cmdRun:` label (around line 476) and replace the entire handler through `crError:` with:

```asm
// RUN [name|addr] / GO [name|addr] — execute a registered app
// Phase A: looks up entry in app table; executes via JSR to LoadAddr.
// No arg: searches table for entry at UserProgStart.
// Hex arg: address search. Alpha arg: name search.
// Prints "not loaded" if not found in table.
cmdRun:
    ldy ParsePos
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq crDefault           // no argument: search for UserProgStart

    sty TempLo              // save arg start index
    jsr parseHex            // try to parse as hex address
    bcs crNameSearch        // not valid hex → treat as name

    // Hex address search
    sec                     // address mode
    jsr aptFind
    bcs crNotLoaded
    jmp crExecute           // HandlerVecLo/Hi set by aptFind

crNameSearch:
    ldy TempLo              // restore arg start (parseHex advanced Y)
crScanName:
    lda CommandBuffer, y
    beq crNameEnd
    cmp #' '
    beq crNameEnd
    iny
    jmp crScanName
crNameEnd:
    tya
    sec
    sbc TempLo              // name length
    sta SrcHandle
    beq crNotLoaded         // zero-length arg
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    clc                     // name mode
    jsr aptFind
    bcs crNotLoaded
    jmp crExecute           // HandlerVecLo/Hi set by aptFind

crDefault:
    lda #<UserProgStart
    sta HexValLo
    lda #>UserProgStart
    sta HexValHi
    sec                     // address mode
    jsr aptFind
    bcs crNotLoaded

crExecute:
    jsr crJump
    rts

crJump:
    jmp (HandlerVecLo)

crNotLoaded:
    lda #<aptNotLoadedMsg
    ldy #>aptNotLoadedMsg
    jsr petPrintString
    rts
```

- [ ] **Step 2: Build and verify**

```bash
make
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/command64/shell.asm
git commit -m "feat: modify cmdRun to require app table membership before execution"
```

---

## Task 9: Add `APPS` / `PS` Command

**Files:**
- Modify: `src/command64/shell.asm` — add table entries + handler; update HELP message

- [ ] **Step 1: Add `APPS` and `PS` entries to `tableCmd`** in `shell.asm`

Append after the `"path  "` entry (before `tableEnd:`):

```asm
    .text "apps  "
    .word cmdApps
    .text "ps    "
    .word cmdApps
```

- [ ] **Step 2: Add `cmdApps` handler** in `shell.asm` (in the command handlers section, e.g. after cmdPath):

```asm
// APPS / PS — list loaded apps from app table
cmdApps:
    jsr aptList
    rts
```

- [ ] **Step 3: Update HELP text** in `shell.asm` to add APPS/PS:

In `helpMsg`, add before the trailing `$0D, 0`:

```asm
    .text "APPS   - LIST LOADED APPS"
    .byte $0D
    .text "PS     - ALIAS FOR APPS"
    .byte $0D
    .text "FREE   - FREE APP [NAME]"
    .byte $0D
```

- [ ] **Step 4: Build and verify**

```bash
make
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add src/command64/shell.asm
git commit -m "feat: add APPS/PS command calling aptList"
```

---

## Task 10: Add `FREE` Command

**Files:**
- Modify: `src/command64/shell.asm` — add table entry + handler

- [ ] **Step 1: Add `FREE` entry to `tableCmd`** (append after APPS/PS entries, before `tableEnd:`):

```asm
    .text "free  "
    .word cmdFree
```

- [ ] **Step 2: Add `cmdFree` handler** in `shell.asm` (after cmdApps):

```asm
// FREE <name> — remove an app from the app table (does not zero RAM)
// Refuses if APP_RUNNING flag is set.
cmdFree:
    ldy ParsePos
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq cfNoArg
    sty TempLo              // name start
cfScanName:
    lda CommandBuffer, y
    beq cfEnd
    cmp #' '
    beq cfEnd
    iny
    jmp cfScanName
cfEnd:
    tya
    sec
    sbc TempLo              // name length
    sta SrcHandle
    beq cfNoArg
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    clc                     // name search mode
    jsr aptFind
    bcs cfNotFound
    // X = slot index; check APP_RUNNING before removing
    jsr aptSlotBase
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_RUNNING
    bne cfRunning
    jsr aptRemove           // X = slot index (aptSlotBase re-enters with X)
    rts
cfNoArg:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts
cfNotFound:
    lda #<aptNotFoundMsg
    ldy #>aptNotFoundMsg
    jsr petPrintString
    rts
cfRunning:
    lda #<aptRunningMsg
    ldy #>aptRunningMsg
    jsr petPrintString
    rts
```

Note: `aptSlotBase` is called in `cfRunning` path to read Flags. After `bne cfRunning`, X is still the slot index from `aptFind`. `aptRemove` internally calls `aptSlotBase` again with X.

- [ ] **Step 3: Build and verify**

```bash
make
```

Expected: no errors.

- [ ] **Step 4: Manual verification checklist** (VICE emulator):

Load the disk image and test:

```
LOAD hello          → "loading..." + registers hello at $2200
LOAD hello          → re-LOAD: overwrites same slot (UsedSlots stays 1)
APPS                → shows: "hello            2200   <size>" + "1 app(s) loaded"
RUN hello           → runs hello (prints "Hello from the C64 Disk!")
RUN 2200            → same result (address search)
FREE hello          → removes entry; APPS shows "no apps loaded"
RUN hello           → "not loaded"
LOAD protected 0100 → "protected address" (below $2200)
LOAD protected c000 → "protected address" ($C000 = VMM MCT)
```

- [ ] **Step 5: Commit**

```bash
git add src/command64/shell.asm
git commit -m "feat: add FREE command with APP_RUNNING guard"
```

---

## Task 11: Update Documentation

**Files:**
- Modify: `brain/COMMANDS.md`
- Modify: `brain/KNOWLEDGE.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add APPS, PS, FREE to `brain/COMMANDS.md`**

Add a new section or add rows to section 2 (High Priority):

```markdown
| `APPS` / `PS` | List loaded programs from app table | ✅ Done | High | C64 |
| `FREE` | Remove app from app table by name | ✅ Done | High | C64 |
```

Also update `RUN` / `G` description to note it now requires app table membership.

- [ ] **Step 2: Update `brain/KNOWLEDGE.md`**

In the "Architectural Decisions & Constraints" section, add:

```markdown
### App Table (Phase A)
- **Storage**: VMM-allocated 4KB page, segment saved in `AptSegLo/Hi` ($03F2-$03F3).
- **Layout**: 4-byte header (MaxSlots=16, UsedSlots, reserved×2) + 16 entries × 40 bytes = 644 bytes total.
- **Protected Ranges**: Loads rejected if address < $2200 or >= $C000.
- **UserProgStart**: Shifted from $2000 to $2200 to accommodate the AppTable segment.
- **Phase B/C**: aptRegister/aptFind API surface is unchanged; new flags and fields are reserved in each entry (offsets 21-39).
```

Also update the Current Status table:

```markdown
| Phase 6A: App Manager (Phase A) | ✅ Done |
```

- [ ] **Step 3: Update `CHANGELOG.md`** with a new entry at the top:

```markdown
## [0.2.XX] - 2026-05-13 — App Manager Phase A

### Added
- `apptable.asm`: VMM-backed 16-slot app registry (aptInit, aptFind, aptRegister, aptRemove, aptList).
- `APPS` / `PS` command: lists loaded programs with name, load address, size.
- `FREE` command: removes app from table; refuses if APP_RUNNING flag set.

### Changed
- `LOAD`: protected address check, table-full check, registers app after successful disk read.
- `RUN` / `GO`: requires app table membership; supports `RUN <name>` and `RUN <addr>`.
- `UserProgStart` shifted from $2000 to $2200; AppTable occupies $2000–$21FF.
- `debug.asm` and all test PRGs updated to $2200 load address.
```

- [ ] **Step 4: Build final image**

```bash
make
```

Expected: clean build.

- [ ] **Step 5: Commit**

```bash
git add brain/COMMANDS.md brain/KNOWLEDGE.md CHANGELOG.md
git commit -m "docs: update COMMANDS, KNOWLEDGE, CHANGELOG for App Manager Phase A"
```

---

## Post-Implementation Verification

After all tasks are committed, verify the full feature set in VICE with a loaded disk image:

1. `LOAD hello` → "loading..." → `APPS` shows hello at 2200
2. `LOAD hello` (again) → re-registers in same slot; `APPS` still shows 1 entry
3. `LOAD debug` → `APPS` shows 2 entries
4. `RUN hello` → executes hello program
5. `RUN 2200` → same result as `RUN hello`
6. `FREE hello` → `APPS` shows 1 entry (debug only)
7. `RUN hello` → "not loaded"
8. `FREE nosuch` → "not found"
9. `LOAD x 0100` → "protected address"
10. `LOAD x c000` → "protected address"
11. Load 16 programs → 17th `LOAD` → "app table full"
12. `PS` → same output as `APPS`
