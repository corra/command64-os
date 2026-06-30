// src/external/conway/conway.asm
// Conway's Game of Life for Command 64 OS
//
// Rules (B3/S23):
//   Live cell with <2 or >3 live neighbours dies.
//   Live cell with 2 or 3 live neighbours survives.
//   Dead cell with exactly 3 live neighbours is born.
//
// Grid: 40x25 toroidal (edges wrap). 1 byte/cell (0=dead, 1=alive).
// Buffers: double-buffered at fixed page-aligned addresses $3000/$3400.
//          Page-alignment lets multi-page iteration use INC zpHi without
//          an explicit page-boundary check in the inner loops.
//
// Display: Direct writes to screen RAM ($0400). Live cell = solid block
//          ($A0, reverse-space). Dead cell = space ($20). Green on black.
//
// Controls (PETSCII, standard keyboard mode):
//   SPACE        pause / resume
//   R            re-randomize grid
//   C            clear grid (all dead)
//   Q / RUN-STOP quit (return to shell)

#import "../../../include/command64.inc"

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_conway.inc"

.encoding "petscii_mixed"

// ---------------------------------------------------------------------------
// Grid dimensions
// ---------------------------------------------------------------------------
.const GRID_W    = 40           // columns  — matches the C64 text-screen width
.const GRID_H    = 25           // rows     — matches the C64 text-screen height
.const GRID_SIZE = 1000         // GRID_W * GRID_H

// ---------------------------------------------------------------------------
// Hardware addresses
// ---------------------------------------------------------------------------
.const VIC_BORD  = $D020        // VIC-II border colour register
.const VIC_BGND  = $D021        // VIC-II background colour register
.const SCREEN    = $0400        // text screen RAM (1000 bytes, page-aligned)
.const COLORRAM  = $D800        // colour RAM (1000 bytes, page-aligned)
.const JIFFY_CLK = $A2          // KERNAL jiffy counter lo (increments ~60 Hz)

// ---------------------------------------------------------------------------
// Buffer base addresses (page-aligned; low byte is always $00)
//   grid0: $3000-$33E7  (1000 cells; remainder of page is harmless padding)
//   grid1: $3400-$37E7  (same layout, second buffer)
// Code fits comfortably below $3000 (~600 bytes from $2000).
// ---------------------------------------------------------------------------
.const GRID0_LO  = $00
.const GRID0_HI  = $30
.const GRID1_LO  = $00
.const GRID1_HI  = $34

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------
.const CHAR_LIVE = $A0          // PETSCII reversed-space = solid block
.const CHAR_DEAD = $20          // PETSCII space  (background shows through)
.const CLR_LIVE  = 5            // VIC-II colour 5 = green

// ---------------------------------------------------------------------------
// Timing: jiffy ticks to skip between generations.
// 3 ticks ≈ 50 ms → ~20 generations/sec; tune to taste.
// ---------------------------------------------------------------------------
.const GEN_DELAY = 3

// ---------------------------------------------------------------------------
// Zero-page scratch ($70-$7D — documented safe area for external programs)
// ---------------------------------------------------------------------------
.label zpPrevLo = $70           // \
.label zpPrevHi = $71           //  |  row pointers into the current buffer:
.label zpCurrLo = $72           //  |  prev/curr/next for neighbour reads
.label zpCurrHi = $73           //  |
.label zpNextLo = $74           //  |
.label zpNextHi = $75           // /
.label zpDstLo  = $76           // destination row pointer into inactive buffer
.label zpDstHi  = $77
.label zpRow    = $78           // row loop index (0..GRID_H-1)
.label zpCol    = $79           // column loop index (0..GRID_W-1)
.label zpCount  = $7A           // Moore-neighbourhood live-neighbour count
.label zpLfsr   = $7B           // Galois LFSR state byte (pseudo-RNG seed)
.label zpPaused = $7C           // 0 = running;  $FF = paused
.label zpBufSel = $7D           // 0 = grid0 is active;  1 = grid1 is active

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
* = $2000 "ConwayEntry"

start:
    // Seed the LFSR from volatile hardware so each run differs.
    // OR #1 ensures the LFSR is never stuck at the all-zero invalid state.
    lda $D012                   // VIC-II raster counter (changes each scan line)
    eor JIFFY_CLK
    eor $0314                   // IRQ vector low byte (environment-dependent)
    ora #1
    sta zpLfsr

    lda #0
    sta zpPaused
    sta zpBufSel

    // Black border and background
    sta VIC_BORD
    sta VIC_BGND

    // Flood-fill colour RAM with green so live cells appear green.
    // Three full 256-byte pages in a single X-indexed loop, then the
    // remaining 232-byte tail (1000 - 3*256 = 232).
    lda #CLR_LIVE
    ldx #0
fillColorPages:
    sta COLORRAM,     x         // $D800-$D8FF
    sta COLORRAM+256, x         // $D900-$D9FF
    sta COLORRAM+512, x         // $DA00-$DAFF
    inx
    bne fillColorPages
    ldy #0
fillColorTail:
    sta COLORRAM+768, y         // $DB00-$DBE7
    iny
    cpy #232
    bne fillColorTail

    jsr randomizeGrid
    jsr drawGrid

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------
mainLoop:
    jsr handleKeys

    lda zpPaused
    bne mainLoop                // spin (handleKeys still polled above)

    jsr waitDelay
    jsr computeNext
    jsr swapBufs
    jsr drawGrid
    jmp mainLoop

// ---------------------------------------------------------------------------
// handleKeys  — non-blocking keyboard poll; act on recognised keys.
// KernalGetIn returns 0 when no key is pressed.
// All PETSCII values below are the codes returned by KernalGetIn in the
// default (unshifted/uppercase) keyboard mode; explicit hex used to avoid
// encoding surprises from the petscii_mixed directive.
// ---------------------------------------------------------------------------
handleKeys:
    jsr KernalGetIn
    beq hkNone

    cmp #$51                    // Q  (PETSCII $51 = uppercase Q)
    beq hkQuit
    cmp #3                      // RUN/STOP  ($03)
    beq hkQuit
    cmp #$20                    // SPACE
    beq hkPause
    cmp #$52                    // R  (PETSCII $52)
    beq hkRandom
    cmp #$43                    // C  (PETSCII $43)
    beq hkClear
hkNone:
    rts

hkQuit:
    // Restore a clean screen, then exit to the shell.
    //
    // Stack at this point (top → bottom):
    //   [mainLoop return addr hi]  ← pushed by mainLoop's "jsr handleKeys"
    //   [mainLoop return addr lo]
    //   [shell return addr hi]     ← pushed by the loader calling $2000
    //   [shell return addr lo]
    //
    // A plain RTS would return into mainLoop (wrong).
    // Discard the mainLoop frame first, then RTS reaches the shell.
    lda #0
    sta VIC_BORD
    sta VIC_BGND
    jsr clearScreen
    pla                         // discard mainLoop return addr lo
    pla                         // discard mainLoop return addr hi
    rts                         // now returns to the shell

hkPause:
    lda zpPaused
    eor #$FF                    // toggle between 0 (running) and $FF (paused)
    sta zpPaused
    rts

hkRandom:
    jsr randomizeGrid
    jsr drawGrid
    rts

hkClear:
    jsr clearGrid
    jsr drawGrid
    rts

// ---------------------------------------------------------------------------
// waitDelay  — busy-wait for GEN_DELAY jiffy-clock increments.
// Polls $A2 (jiffy lo).  One increment = 1/60 s (NTSC) or 1/50 s (PAL).
// The outer counter runs down from GEN_DELAY to zero; for each count it
// waits until $A2 actually changes before decrementing again.
// ---------------------------------------------------------------------------
waitDelay:
    lda #GEN_DELAY
wdOuter:
    pha
    lda JIFFY_CLK               // snapshot current tick
wdPoll:
    cmp JIFFY_CLK               // wait until the counter advances
    beq wdPoll
    pla
    sec
    sbc #1
    bne wdOuter
    rts

// ---------------------------------------------------------------------------
// swapBufs  — toggle zpBufSel; roles of grid0 and grid1 exchange.
// ---------------------------------------------------------------------------
swapBufs:
    lda zpBufSel
    eor #1
    sta zpBufSel
    rts

// ---------------------------------------------------------------------------
// randomizeGrid  — fill the active buffer with ~25% live cells.
//
// Uses an 8-bit Galois LFSR (period 255, poly x^8+x^6+x^5+x^4+1).
// A cell is set alive when (LFSR_output & $0A) == 0, i.e. when bits 1 and 3
// are both zero (probability 1/4 for a uniform LFSR).
//
// Iterates 3 full 256-byte pages then a 232-byte tail (total 1000 bytes).
// The X register counts pages; Y iterates within each page.
// ---------------------------------------------------------------------------
randomizeGrid:
    jsr getCurrBase             // A=lo, X=hi of active buffer
    sta zpCurrLo
    stx zpCurrHi

    ldx #0                      // page counter: 0, 1, 2 (3 full pages)
    ldy #0
rgCell:
    jsr lfsrStep
    and #$0A                    // alive iff bits 1 & 3 both clear (~25% chance)
    beq rgAlive
    lda #0
    jmp rgStore
rgAlive:
    lda #1
rgStore:
    sta (zpCurrLo), y
    iny
    bne rgCell                  // inner Y loop: 0..255 (one full page)

    inc zpCurrHi                // advance grid pointer to next page
    inx
    cpx #3
    bne rgCell                  // pages 0, 1, 2 done; fall through at page 3

    // Final partial page: 232 cells
    ldy #0
rgTail:
    jsr lfsrStep
    and #$0A
    beq rgTailAlive
    lda #0
    jmp rgTailStore
rgTailAlive:
    lda #1
rgTailStore:
    sta (zpCurrLo), y
    iny
    cpy #232
    bne rgTail
    rts

// ---------------------------------------------------------------------------
// clearGrid  — set every cell in the active buffer to dead (0).
// ---------------------------------------------------------------------------
clearGrid:
    jsr getCurrBase
    sta zpCurrLo
    stx zpCurrHi

    lda #0
    ldx #0
    ldy #0
cgPage:
    sta (zpCurrLo), y
    iny
    bne cgPage
    inc zpCurrHi
    inx
    cpx #3
    bne cgPage
    ldy #0
cgTail:
    sta (zpCurrLo), y
    iny
    cpy #232
    bne cgTail
    rts

// ---------------------------------------------------------------------------
// clearScreen  — fill screen RAM ($0400) with space characters.
// Same page-by-page strategy used throughout: three full pages + 232-byte tail.
// ---------------------------------------------------------------------------
clearScreen:
    lda #<SCREEN
    sta zpDstLo
    lda #>SCREEN
    sta zpDstHi

    lda #CHAR_DEAD
    ldx #0
    ldy #0
csPage:
    sta (zpDstLo), y
    iny
    bne csPage
    inc zpDstHi
    inx
    cpx #3
    bne csPage
    ldy #0
csTail:
    sta (zpDstLo), y
    iny
    cpy #232
    bne csTail
    rts

// ---------------------------------------------------------------------------
// drawGrid  — copy active buffer to screen RAM, converting 0/1 → PETSCII.
//
// cellCharTbl maps: 0 → CHAR_DEAD ($20), 1 → CHAR_LIVE ($A0).
// X is clobbered inside the inner loop by 'tax', so the outer page counter
// lives in memory (dgPageCnt).  Y wraps naturally to 0 after 256 iterations,
// making it ready for the next page without an explicit reset.
// ---------------------------------------------------------------------------
drawGrid:
    jsr getCurrBase
    sta zpCurrLo
    stx zpCurrHi

    lda #<SCREEN
    sta zpDstLo
    lda #>SCREEN
    sta zpDstHi

    lda #0
    sta dgPageCnt
    ldy #0
dgPage:
    lda (zpCurrLo), y
    tax
    lda cellCharTbl, x          // 0/1 → CHAR_DEAD/CHAR_LIVE
    sta (zpDstLo), y
    iny
    bne dgPage                  // Y 0→255 then wraps: one full page done

    inc zpCurrHi                // advance grid pointer one page
    inc zpDstHi                 // advance screen pointer one page
    inc dgPageCnt
    lda dgPageCnt
    cmp #3
    bne dgPage                  // Y is 0 after wrap; safe to restart inner loop

    // Final 232-cell tail (1000 - 3*256 = 232)
    ldy #0
dgTail:
    lda (zpCurrLo), y
    tax
    lda cellCharTbl, x
    sta (zpDstLo), y
    iny
    cpy #232
    bne dgTail
    rts

dgPageCnt: .byte 0

// ---------------------------------------------------------------------------
// computeNext  — evaluate one full generation of Conway's rules.
//
// Outer loop: rows 0..24 (zpRow).
// Inner loop: columns 0..39 (zpCol).
//
// For each cell (zpRow, zpCol):
//   1. Identify three column indices: left = (col-1) mod 40,
//      centre = col, right = (col+1) mod 40.
//   2. Sum cells at those columns across the previous, current, and next
//      rows (toroidal row wrap).  Centre column excludes current-row cell.
//      Total = 8-cell Moore neighbourhood count → zpCount.
//   3. Apply B3/S23 rules; write result to the same (row, col) in the
//      inactive buffer.
//
// Row pointers (zpPrev/Curr/Next) are rebuilt once per row via
// setThreeRowPtrs; destination pointer (zpDst) via setDstRowPtr.
// ---------------------------------------------------------------------------
computeNext:
    lda #0
    sta zpRow

cnRowLoop:
    jsr setThreeRowPtrs         // zpPrev/Curr/Next ← active-buffer row addrs
    jsr setDstRowPtr            // zpDst ← inactive-buffer row addr

    lda #0
    sta zpCol

cnColLoop:
    // --- Left column index (toroidal: col 0 wraps to col 39) ---
    lda zpCol
    bne cnNotFirstCol
    lda #GRID_W - 1
    jmp cnGotLeft
cnNotFirstCol:
    sec
    sbc #1
cnGotLeft:
    tay

    // --- Sum left column: prev[lc] + curr[lc] + next[lc] ---
    lda #0
    sta zpCount

    lda (zpPrevLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpCurrLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpNextLo), y
    clc
    adc zpCount
    sta zpCount

    // --- Centre column: prev[col] + next[col] (own cell excluded) ---
    ldy zpCol

    lda (zpPrevLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpNextLo), y
    clc
    adc zpCount
    sta zpCount

    // --- Right column index (toroidal: col 39 wraps to col 0) ---
    lda zpCol
    cmp #GRID_W - 1
    bne cnNotLastCol
    lda #0
    jmp cnGotRight
cnNotLastCol:
    clc
    adc #1
cnGotRight:
    tay

    // --- Sum right column: prev[rc] + curr[rc] + next[rc] ---
    lda (zpPrevLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpCurrLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpNextLo), y
    clc
    adc zpCount
    sta zpCount

    // --- Apply Conway B3/S23 rules ---
    ldy zpCol
    lda (zpCurrLo), y           // current cell state (0 or 1)
    beq cnDead

cnAlive:
    // Survive with 2 or 3 neighbours; die otherwise.
    lda zpCount
    cmp #2
    beq cnSurvive
    cmp #3
    beq cnSurvive
    jmp cnKill

cnDead:
    // Born with exactly 3 neighbours.
    lda zpCount
    cmp #3
    beq cnBorn
    jmp cnKill

cnSurvive:
cnBorn:
    lda #1
    ldy zpCol
    sta (zpDstLo), y
    jmp cnNext

cnKill:
    lda #0
    ldy zpCol
    sta (zpDstLo), y

cnNext:
    inc zpCol
    lda zpCol
    cmp #GRID_W
    beq cnColDone               // equal: all 40 columns done
    jmp cnColLoop               // not equal: next column
cnColDone:

    inc zpRow
    lda zpRow
    cmp #GRID_H
    beq cnAllDone               // equal: all 25 rows done
    jmp cnRowLoop
cnAllDone:
    rts

// ---------------------------------------------------------------------------
// setThreeRowPtrs  — set zpPrev/Curr/Next Lo/Hi to the start addresses of
// rows (zpRow-1, zpRow, zpRow+1) in the ACTIVE buffer, wrapping toroidally.
//
// Row N starts at: bufferBase + rowOffLo[N] + (rowOffHi[N] << 8).
// 16-bit addition: clc/adc lo, then adc hi naturally picks up the carry.
//
// Buffer base is stored in stpBLo/stpBHi for the three pointer calculations.
// Clobbers: A, X, Y.
// ---------------------------------------------------------------------------
setThreeRowPtrs:
    jsr getCurrBase             // A = buffer_lo, X = buffer_hi
    sta stpBLo
    stx stpBHi

    // Current row
    ldy zpRow
    clc
    lda stpBLo
    adc rowOffLo, y
    sta zpCurrLo
    lda stpBHi
    adc rowOffHi, y             // carry from lo addition propagates here
    sta zpCurrHi

    // Previous row (zpRow == 0 wraps to GRID_H-1)
    lda zpRow
    beq stpPrevWrap
    sec
    sbc #1
    jmp stpPrevGot
stpPrevWrap:
    lda #GRID_H - 1
stpPrevGot:
    tay
    clc
    lda stpBLo
    adc rowOffLo, y
    sta zpPrevLo
    lda stpBHi
    adc rowOffHi, y
    sta zpPrevHi

    // Next row (zpRow == GRID_H-1 wraps to 0)
    lda zpRow
    clc
    adc #1
    cmp #GRID_H
    bne stpNextOk
    lda #0
stpNextOk:
    tay
    clc
    lda stpBLo
    adc rowOffLo, y
    sta zpNextLo
    lda stpBHi
    adc rowOffHi, y
    sta zpNextHi

    rts

stpBLo: .byte 0                 // scratch: active-buffer base low byte
stpBHi: .byte 0                 // scratch: active-buffer base high byte

// ---------------------------------------------------------------------------
// setDstRowPtr  — set zpDstLo/Hi to the start of zpRow in the INACTIVE buffer.
// Clobbers: A, X, Y.
// ---------------------------------------------------------------------------
setDstRowPtr:
    jsr getNextBase             // A = buffer_lo, X = buffer_hi
    ldy zpRow
    clc
    adc rowOffLo, y
    sta zpDstLo
    txa
    adc rowOffHi, y             // carry from lo propagates automatically
    sta zpDstHi
    rts

// ---------------------------------------------------------------------------
// getCurrBase  — return base address of the active buffer.
// Returns: A = lo byte, X = hi byte.
// ---------------------------------------------------------------------------
getCurrBase:
    lda zpBufSel
    bne gcbGrid1
    lda #GRID0_LO
    ldx #GRID0_HI
    rts
gcbGrid1:
    lda #GRID1_LO
    ldx #GRID1_HI
    rts

// ---------------------------------------------------------------------------
// getNextBase  — return base address of the inactive (destination) buffer.
// Returns: A = lo byte, X = hi byte.
// ---------------------------------------------------------------------------
getNextBase:
    lda zpBufSel
    beq gnbGrid1
    lda #GRID0_LO
    ldx #GRID0_HI
    rts
gnbGrid1:
    lda #GRID1_LO
    ldx #GRID1_HI
    rts

// ---------------------------------------------------------------------------
// lfsrStep  — advance the 8-bit Galois LFSR; leaves new state in A and zpLfsr.
//
// Right-shift form: shift right one; if old bit 0 was 1, XOR with $B8.
// Feedback mask $B8 = 10111000b implements x^8+x^6+x^5+x^4+1 (maximal-length;
// period 255, visits every nonzero byte exactly once per cycle).
// ---------------------------------------------------------------------------
lfsrStep:
    lda zpLfsr
    lsr                         // shift right; old bit 0 → carry flag
    bcc lfsrNFB
    eor #$B8                    // apply feedback taps
lfsrNFB:
    sta zpLfsr
    rts

// ---------------------------------------------------------------------------
// Read-only data tables
// ---------------------------------------------------------------------------

// Character conversion: cell value → PETSCII display character
cellCharTbl:
    .byte CHAR_DEAD             // 0 (dead)  → $20 space
    .byte CHAR_LIVE             // 1 (alive) → $A0 solid block

// Row N starts at byte offset N*40 within the buffer.
// Split into lo/hi for fast 16-bit address computation.
// Precomputed to avoid runtime multiply; indexed by row number (0-24).
//
// Row  0: offset   0 = $0000    Row  7: offset 280 = $0118
// Row 12: offset 480 = $01E0    Row 13: offset 520 = $0208
// Row 19: offset 760 = $02F8    Row 20: offset 800 = $0320
// Row 24: offset 960 = $03C0

rowOffLo:
    .byte $00,$28,$50,$78,$A0,$C8,$F0   // rows  0-6
    .byte $18,$40,$68,$90,$B8,$E0       // rows  7-12
    .byte $08,$30,$58,$80,$A8,$D0,$F8   // rows 13-19
    .byte $20,$48,$70,$98,$C0           // rows 20-24

rowOffHi:
    .byte $00,$00,$00,$00,$00,$00,$00   // rows  0-6   (offsets 0-240)
    .byte $01,$01,$01,$01,$01,$01       // rows  7-12  (offsets 280-480)
    .byte $02,$02,$02,$02,$02,$02,$02   // rows 13-19  (offsets 520-760)
    .byte $03,$03,$03,$03,$03           // rows 20-24  (offsets 800-960)
