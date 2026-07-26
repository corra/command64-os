; tests/src/casm_catalog/casm_catalog.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 9 WP45 physical file catalog and dynamic source
; loading fixture harness. Links include.s plus every module
; sourceAppendFile transitively needs (fileio.s, source.s, state.s,
; resources.s, vmm_store.s) but deliberately not cli.s, lexer.s, parser.s,
; opcodes.s, emit.s, expr.s, symbols.s, reloc.s, diagnostics.s, or casm.s:
; this harness drives include.s's public ABI directly against real fixture
; files, never a real assembly. Mirrors casm_pass1.s/casm_passcheck.s's own
; precedent exactly: since source.s's sourceLoad references cli.s's
; CasmSourceNames/CasmSourceCount/cliSourceSlotLo/Hi and ld65 links whole
; object files, this harness declares its own single-slot stand-in copies of
; those three globals rather than pulling in cli.s's whole CLI-parsing
; dependency chain.
;
; Fixtures (cmake/GenerateCasmTestFixtures.cmake, packaged on
; casm_overflow_test_d64 under bare lowercase disk names): casmcat3.seq
; (8 bytes) seeds the source store as the one top-level file via sourceLoad,
; establishing CasmSourceVmmSlot/CasmSourceLoadedLenLo-Hi = 8 before any
; catalog test runs. casmcat1.seq (10 bytes), casmcat2.seq (15 bytes), and
; casmcat4.seq/casmcat5.seq (20/12 bytes) are used only as included-file
; targets through includeCatalogLoad, never as the top-level seed -- keeping
; the combined source store's running length arithmetic (used to prove
; dedup causes no phantom append) simple and distinct from the catalog's own
; record count.
;
; Catalog-capacity boundary cases pre-populate synthetic records directly
; via includeCatalogWrite (bypassing real file I/O) rather than requiring
; 28 more real distinct fixture files -- only the record actually being
; tested (the 32nd, real) needs to exist on disk.
;
; Device-inheritance cases test includeResolveDevice in isolation (no real
; file open), since the test environment mounts only one physical/emulated
; device: a resolved device other than the one actually mounted cannot be
; exercised through a real DOS_OPEN_FILE call without a second drive.
;
; Every real-load case reads the actual CurrentDevice ($039E) at startup into
; TestDevice rather than assuming a fixed device number: casm_overflow_test.d64
; (which carries the casmcat* fixtures) is not itself bootable, so it is
; typically attached as a second drive (e.g. device 9) while the bootable
; test.d64 stays on device 8 -- CurrentDevice reflects whichever device the
; running PRG actually loaded from. An earlier debug round of this harness
; hardcoded CASM_DEVICE_MIN (8) and got CASM_DIAG_INPUT_OPEN_FAILED on every
; real load in exactly that two-drive setup, confirming the fixtures were
; never on device 8 to begin with.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_catalog.inc"

.import __MAIN_START__
.import resourcesInit
.import fileIoInit
.import sourceInit
.import sourceLoad
.import includeCatalogInit
.import includeResolveDevice
.import includeCatalogFind
.import includeCatalogRead
.import includeCatalogLoad
.import CasmIncludeMetaSlot
.import CasmIncludeCatalogCount
.import CasmIncludeRecordStage
.import CasmIncludeResolvedDevice
.import vmmWindowWrite
.import CasmVmmBuffer

.export CasmSourceNames  ; this harness's own copy -- NOT linking cli.s, see header
.export CasmSourceCount  ; this harness's own copy -- always set to 1
.export cliSourceSlotLo  ; this harness's own single-entry copy, see BSS section
.export cliSourceSlotHi  ; this harness's own single-entry copy, see BSS section
.export CasmOutputName   ; fileio.s's outputAbort references this by name
.export diagPrintFatal   ; stub -- see routine below; not linking diagnostics.s

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    ; Capture the real CurrentDevice once, before anything else runs, as the
    ; device every real-load test case targets -- see the file header. Never
    ; hardcode a device number: casm_overflow_test.d64 (which carries the
    ; casmcat* fixtures) is not bootable and is typically a second drive,
    ; not device 8.
    lda CurrentDevice
    sta TestDevice
    jsr resourcesInit
    jsr fileIoInit
    jsr sourceInit
    lda #0
    sta FailCount

    ; Seed the combined source store with the one top-level file (never
    ; reused as an include target below).
    ldx #<seedName
    ldy #>seedName
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
seedCopyLoop:
    lda (CasmPtr1Lo), y
    sta CasmSourceNames, y
    beq seedCopyDone
    iny
    jmp seedCopyLoop
seedCopyDone:
    lda #1
    sta CasmSourceCount
    jsr sourceLoad
    bcc seedOk
    jmp seedFailed
seedOk:
    jsr includeCatalogInit
    bcc initOk
    jmp seedFailed

initOk:
    jsr catinit1
    jsr reportCase
    jsr catload1
    jsr reportCase
    jsr catload2
    jsr reportCase
    jsr cathit1
    jsr reportCase
    jsr catload3
    jsr reportCase
    jsr catfold1
    jsr reportCase
    jsr catresolve1
    jsr reportCase
    jsr catresolve2
    jsr reportCase
    jsr catopenfail1
    jsr reportCase
    jsr catempty1
    jsr reportCase
    jsr catfull1
    jsr reportCase
    jsr catoverflow1
    jsr reportCase

    lda #$0D
    jsr KernalChROUT

    lda FailCount
    beq allPass
    lda #<failMsg
    ldy #>failMsg
    jmp printResult
allPass:
    lda #<passMsg
    ldy #>passMsg
printResult:
    tax
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

seedFailed:
    lda #<seedFailMsg
    ldy #>seedFailMsg
    tax
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount.
; ---------------------------------------------------------------------------
reportCase:
    bcs rcFail
    lda #$2E
    jsr KernalChROUT
    rts
rcFail:
    inc FailCount
    lda #$46
    jsr KernalChROUT
    rts

; ---------------------------------------------------------------------------
; catinit1: includeCatalogInit already ran in start; just confirm the
; catalog starts empty.
; ---------------------------------------------------------------------------
; Every check below uses its own local "sec/rts" fail tail immediately after
; its routine's own success path (matching casm_pass1.s's own convention),
; rather than a single shared distant fail label -- keeps every branch a few
; bytes long and immune to the 6502's +/-127-byte range limit regardless of
; how many checks a routine accumulates.
catinit1:
    lda CasmIncludeCatalogCount
    bne ci1Fail
    clc
    rts
ci1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catload1: first real load (miss) of casmcat1.seq (10 bytes). Expect a new
; record 0: device TestDevice, namelen 8 ("CASMCAT1"), start = 8 (the seed's
; own length), length = 10. CasmIncludeCatalogCount becomes 1.
; ---------------------------------------------------------------------------
catload1:
    lda TestDevice               ; parent device: the real device this PRG ran from
    ldx #<cat1Name
    ldy #>cat1Name
    jsr includeCatalogLoad
    bcs cl1Fail
    cpx #0
    bne cl1Fail
    lda CasmIncludeCatalogCount
    cmp #1
    bne cl1Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    cmp TestDevice
    bne cl1Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAMELEN
    cmp #8
    bne cl1Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    cmp #8
    bne cl1Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    bne cl1Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_LO
    cmp #10
    bne cl1Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_HI
    bne cl1Fail
    clc
    rts
cl1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catload2: second real load (miss) of casmcat2.seq (15 bytes). Expect a new
; record 1: start = 18 (8 + 10), length = 15. CasmIncludeCatalogCount
; becomes 2.
; ---------------------------------------------------------------------------
catload2:
    lda TestDevice
    ldx #<cat2Name
    ldy #>cat2Name
    jsr includeCatalogLoad
    bcs cl2Fail
    cpx #1
    bne cl2Fail
    lda CasmIncludeCatalogCount
    cmp #2
    bne cl2Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    cmp #18
    bne cl2Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    bne cl2Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_LO
    cmp #15
    bne cl2Fail
    clc
    rts
cl2Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; cathit1: repeated load of casmcat1.seq (identical spelling). Expect a
; cache hit: same record index 0, CasmIncludeCatalogCount unchanged at 2
; (no new record, and -- proved indirectly by catload3 below -- no second
; append to the source store).
; ---------------------------------------------------------------------------
cathit1:
    lda TestDevice
    ldx #<cat1Name
    ldy #>cat1Name
    jsr includeCatalogLoad
    bcs ch1Fail
    cpx #0
    bne ch1Fail
    lda CasmIncludeCatalogCount
    cmp #2
    bne ch1Fail
    clc
    rts
ch1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catload3: third real load (miss) of casmcat4.seq (20 bytes), immediately
; after cathit1. Expect start = 33 (8 + 10 + 15) -- if cathit1 had wrongly
; re-appended casmcat1's 10 bytes, this would instead observe start = 43.
; ---------------------------------------------------------------------------
catload3:
    lda TestDevice
    ldx #<cat4Name
    ldy #>cat4Name
    jsr includeCatalogLoad
    bcs cl3Fail
    cpx #2
    bne cl3Fail
    lda CasmIncludeCatalogCount
    cmp #3
    bne cl3Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    cmp #33
    bne cl3Fail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    bne cl3Fail
    clc
    rts
cl3Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catfold1: load a shifted-PETSCII ("casmcat1", lowercase ca65 source ->
; shifted bytes via the charmap) spelling of the same logical name. Expect a
; cache hit against record 0 -- proves case-folded identity comparison, and
; implicitly proves no real open was attempted against the (nonexistent)
; shifted-byte disk name, since a real open there would fail.
; ---------------------------------------------------------------------------
catfold1:
    lda TestDevice
    ldx #<cat1NameFolded
    ldy #>cat1NameFolded
    jsr includeCatalogLoad
    bcs cfd1Fail
    cpx #0
    bne cfd1Fail
    lda CasmIncludeCatalogCount
    cmp #3
    bne cfd1Fail
    clc
    rts
cfd1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catresolve1: includeResolveDevice in isolation. A fake parent device
; deliberately different from TestDevice (the real CurrentDevice), child
; spelling has no prefix -> must inherit the *parent's* device, not
; CurrentDevice. Choosing a fake parent equal to the real CurrentDevice
; would make this test unable to distinguish correct inheritance from a
; coincidental CurrentDevice-fallback match, so it is picked to always
; differ.
; ---------------------------------------------------------------------------
catresolve1:
    lda TestDevice
    cmp #11
    bne cr1UseEleven
    lda #8
    sta cr1FakeParent
    jmp cr1Go
cr1UseEleven:
    lda #11
    sta cr1FakeParent
cr1Go:
    lda cr1FakeParent
    ldx #<cat1Name
    ldy #>cat1Name
    jsr includeResolveDevice
    cmp cr1FakeParent
    bne cr1Fail
    clc
    rts
cr1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catresolve2: includeResolveDevice in isolation. Parent device 9, child
; spelling carries an explicit "11:" prefix -> the prefix must win over both
; the parent device and CurrentDevice.
; ---------------------------------------------------------------------------
catresolve2:
    lda #9
    ldx #<cat11PrefixName
    ldy #>cat11PrefixName
    jsr includeResolveDevice
    cmp #11
    bne cr2Fail
    clc
    rts
cr2Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catopenfail1: load a distinct, real device, but a filename with no
; matching disk file. Expect a propagated open-failure diagnostic and no
; catalog growth.
; ---------------------------------------------------------------------------
catopenfail1:
    lda CasmIncludeCatalogCount
    sta catSavedCount
    lda TestDevice
    ldx #<catMissingName
    ldy #>catMissingName
    jsr includeCatalogLoad
    bcc cof1Fail                 ; must fail
    cmp #CASM_DIAG_INPUT_OPEN_FAILED
    bne cof1Fail
    lda CasmIncludeCatalogCount
    cmp catSavedCount
    bne cof1Fail
    clc
    rts
cof1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catempty1: load a spelling that resolves to an empty post-prefix name
; ("8:" alone). Expect CASM_DIAG_INVALID_INCLUDE_FILENAME and no catalog
; growth.
; ---------------------------------------------------------------------------
catempty1:
    lda CasmIncludeCatalogCount
    sta catSavedCount
    lda TestDevice
    ldx #<catEmptyName
    ldy #>catEmptyName
    jsr includeCatalogLoad
    bcc ce1Fail                  ; must fail
    cmp #CASM_DIAG_INVALID_INCLUDE_FILENAME
    bne ce1Fail
    lda CasmIncludeCatalogCount
    cmp catSavedCount
    bne ce1Fail
    clc
    rts
ce1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catfull1: pre-populate 28 synthetic distinct records directly (bypassing
; real file I/O), bringing the catalog from 3 to 31 populated records, then
; perform one more REAL load (casmcat5.seq, 12 bytes) as the 32nd (capacity
; boundary) record. Expect success, index 31, count 32.
; ---------------------------------------------------------------------------
catfull1:
    lda #3
    sta catFillIndex
cfLoop:
    lda catFillIndex
    cmp #31
    bcs cfLoopDone
    jsr catBuildSyntheticRecord
    lda catFillIndex
    jsr catWriteSyntheticRecord
    bcs cf1Fail
    inc catFillIndex
    inc CasmIncludeCatalogCount
    jmp cfLoop
cfLoopDone:
    lda CasmIncludeCatalogCount
    cmp #31
    bne cf1Fail

    lda TestDevice
    ldx #<cat5Name
    ldy #>cat5Name
    jsr includeCatalogLoad
    bcs cf1Fail
    cpx #31
    bne cf1Fail
    lda CasmIncludeCatalogCount
    cmp #32
    bne cf1Fail
    clc
    rts
cf1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catoverflow1: with the catalog now full (32/32), one more distinct miss
; (a nonexistent filename, since it must fail before any real open is
; attempted) must report CASM_DIAG_INCLUDE_CATALOG_FULL and leave the count
; unchanged.
; ---------------------------------------------------------------------------
catoverflow1:
    lda TestDevice
    ldx #<catMissingName
    ldy #>catMissingName
    jsr includeCatalogLoad
    bcc co1Fail                  ; must fail
    cmp #CASM_DIAG_INCLUDE_CATALOG_FULL
    bne co1Fail
    lda CasmIncludeCatalogCount
    cmp #32
    bne co1Fail
    clc
    rts
co1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; catBuildSyntheticRecord (private)
; Fill CasmIncludeRecordStage with a distinct, owned, minimal-but-valid
; synthetic record keyed by catFillIndex alone (device TestDevice; a one-byte name
; equal to catFillIndex + 'A', guaranteed distinct across indices 3..30 and
; never colliding with any real "CASMCAT*" name).
; ---------------------------------------------------------------------------
catBuildSyntheticRecord:
    lda #CASM_RESOURCE_OWNED
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_FLAG
    lda TestDevice
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    lda #1
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAMELEN
    lda #0
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_RESERVED0
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    lda #1
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_LO
    lda #0
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_HI
    lda catFillIndex
    clc
    adc #$41
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME
    lda #0
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME + 1
    ldy #CASM_INCLUDE_PHYS_REC_NAME + 2
csrZeroLoop:
    cpy #CASM_INCLUDE_PHYS_REC_SIZE
    bcs csrZeroDone
    lda #0
    sta CasmIncludeRecordStage, y
    iny
    jmp csrZeroLoop
csrZeroDone:
    rts

; ---------------------------------------------------------------------------
; catWriteSyntheticRecord (private)
; Write CasmIncludeRecordStage to the slot computed the same way
; includeCatalogRead/Write do (index * 128), duplicated here deliberately:
; this harness has no access to include.s's private includeCatalogWrite,
; only its exported ABI. Uses vmm_store.s's vmmWindowWrite directly against
; CasmIncludeMetaSlot.
;
; Inputs:  A = record index
; Outputs: C clear on success; C set, A = CASM_DIAG_VMM_TRANSFER_FAILED on
;          failure
; ---------------------------------------------------------------------------
catWriteSyntheticRecord:
    sta CasmVmmOffLo
    lda #0
    sta CasmVmmOffHi
    ldx #7
cwsShift:
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    dex
    bne cwsShift

    ldy #0
cwsStageA:
    lda CasmIncludeRecordStage, y
    sta CasmVmmBuffer, y
    iny
    cpy #CASM_VMM_BUFFER_SIZE
    bcc cwsStageA
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmIncludeMetaSlot
    jsr vmmWindowWrite
    bcs cwsFail

    lda CasmVmmOffLo
    clc
    adc #CASM_VMM_BUFFER_SIZE
    sta CasmVmmOffLo
    lda CasmVmmOffHi
    adc #0
    sta CasmVmmOffHi
    ldy #0
cwsStageB:
    lda CasmIncludeRecordStage + CASM_VMM_BUFFER_SIZE, y
    sta CasmVmmBuffer, y
    iny
    cpy #CASM_VMM_BUFFER_SIZE
    bcc cwsStageB
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmIncludeMetaSlot
    jsr vmmWindowWrite
    bcs cwsFail
    clc
    rts
cwsFail:
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal (stub)
; resources.s's exitSuccess/exitFatal reference this; this harness never
; calls either (every failure path here just sets carry and returns to the
; caller), so a trivial stub satisfies the link without pulling in the real
; diagnostics.s and transitively lexer.s/source.s's lexer-facing half --
; matches casm_vmm.s/casm_symbols.s's own precedent exactly.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

.segment "RODATA"

seedName:        .byte "CASMCAT3", 0
cat1Name:        .byte "CASMCAT1", 0
cat2Name:        .byte "CASMCAT2", 0
cat4Name:        .byte "CASMCAT4", 0
cat5Name:        .byte "CASMCAT5", 0
cat1NameFolded:  .byte "casmcat1", 0
cat11PrefixName: .byte "11:CASMCAT1", 0
catMissingName:  .byte "CASMCATMISSING", 0
catEmptyName:    .byte "8:", 0

passMsg: .byte "CASM CATALOG: PASS", $0D, 0
failMsg: .byte "CASM CATALOG: FAIL", $0D, 0
seedFailMsg: .byte "CASM CATALOG: SEED LOAD FAILED", $0D, 0

.segment "BSS"

FailCount:      .res 1
catSavedCount:  .res 1
catFillIndex:   .res 1
TestDevice:     .res 1  ; the real device this PRG ran from (CurrentDevice,
                        ; captured once at start) -- see file header
cr1FakeParent:  .res 1

; This harness's own single-entry stand-in for cli.s's WP34 multi-file
; arrays -- see header. Only slot 0 is ever populated; CasmSourceCount is
; always 1.
CasmSourceNames: .res CASM_FILENAME_BUFFER_SIZE
CasmSourceCount: .res 1
CasmOutputName:  .res CASM_FILENAME_BUFFER_SIZE

.segment "RODATA"

cliSourceSlotLo: .byte <(CasmSourceNames + 0)
cliSourceSlotHi: .byte >(CasmSourceNames + 0)
