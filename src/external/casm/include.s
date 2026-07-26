; src/external/casm/include.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 9 WP45 physical file catalog and dynamic source loading. This
; module is deliberately standalone: it has no production call site anywhere
; in casm.s/parser.s/source.s's traversal path (WP44's parsed `.INCLUDE`
; statement still terminates through casmRunPass's own CASM_DIAG_NOT_IMPLEMENTED
; boundary, unchanged). Only the dedicated test_casm_catalog harness calls
; this module's public ABI directly. Frame push, traversal switching, and
; wiring this module into a live assembly are WP46's job.
;
; Owns one 8KB VMM allocation (Phase 0C.19 freeze): the first
; CASM_INCLUDE_PHYS_CAPACITY * CASM_INCLUDE_PHYS_REC_SIZE (4096) bytes hold a
; deduplicated physical-file catalog, transferred two 64-byte windows per
; record; the remaining 4096 bytes are reserved, untouched space for WP47's
; include-event log rather than a second allocation.
;
; Device resolution reuses the OS's own DOS_PARSE_PREFIX (parsePointerDevice,
; src/command64/utils.asm) directly rather than re-implementing prefix
; parsing: that routine already advances the caller's zero-page pointer past
; a recognized "<n>:" prefix in place, so once it returns, the same pointer
; already addresses the post-prefix filename -- no independent colon scan is
; needed or safe to duplicate (a naive scan could disagree with the OS's own
; strict "8:"/"9:"/"10:"/"11:" recognition on an edge case like "FOO:BAR",
; where the OS finds no prefix but a colon still appears in the payload,
; since colon is an accepted WP44 filename byte). When no prefix is present,
; the OS resolves to CurrentDevice, which is *not* what an included file
; should inherit -- the parent's own resolved device must be substituted in
; that case (Phase 0C.19: "an unprefixed child inherits its including
; physical file's resolved device").
;
; Catalog identity folds the stored name's case live at compare time
; (includeFoldByte) rather than storing a second folded copy: unshifted and
; shifted PETSCII letters compare equal, but only the original spelling is
; ever persisted, satisfying both halves of the Phase 0C.19 identity
; contract with one buffer. A linear scan (cheap early-outs: flag, device,
; name length, then folded bytes) is sufficient at the 32-record cap --
; unlike symbols.s's 512-entry table, no hash index is needed.
;
; A candidate record is always read into this module's own 128-byte
; CasmIncludeRecordStage before any field is inspected, and a lookup's
; search key is always captured into CasmIncludeKeyDevice/KeyName/KeyLen
; before any vmmWindowRead call: CasmVmmBuffer is one shared 64-byte staging
; buffer reused by every VMM consumer, and reading a second time before the
; first read's bytes are copied out would silently corrupt whichever value
; was still needed -- the same aliasing bug class that hit vmm_store.s three
; times (WP23-25) and hit WP44's own test harness (CasmPtr0/1 clobbered by
; the real directive classifier).

.include "command64.inc"
.include "common.inc"

.import vmmStoreAlloc
.import vmmWindowRead
.import vmmWindowWrite
.import CasmVmmBuffer
.import sourceAppendFile

.export includeCatalogInit
.export includeResolveDevice
.export includeCatalogFind
.export includeCatalogRead
.export includeCatalogLoad

.export CasmIncludeMetaSlot
.export CasmIncludeCatalogCount
.export CasmIncludeResolvedDevice
.export CasmIncludeRecordStage
.export CasmIncludeOpenName

.segment "BSS"

CasmIncludeMetaSlot:       .res 1
CasmIncludeCatalogCount:   .res 1

; includeResolveDevice's own transient/output state.
CasmIncludeParentDevice:   .res 1
CasmIncludeResolvedDevice: .res 1
CasmIncludeNamePtrLo:      .res 1
CasmIncludeNamePtrHi:      .res 1

; The captured, case-folded search key for one includeCatalogFind call.
; Captured before any CasmVmmBuffer-aliasing call (see header).
CasmIncludeKeyDevice: .res 1
CasmIncludeKeyName:   .res CASM_INCLUDE_FILENAME_BUFFER_SIZE
CasmIncludeKeyLen:    .res 1

; One fully-assembled 128-byte physical record, staged here (never read
; directly out of the shared CasmVmmBuffer) so a candidate's fields stay
; stable across both transfer windows and across every comparison.
CasmIncludeRecordStage: .res CASM_INCLUDE_PHYS_REC_SIZE

; Transient "<device>:<name>" synthesis buffer for the real DOS_OPEN_FILE
; call, built fresh for every includeCatalogLoad miss. Never persisted into
; a catalog record.
CasmIncludeOpenName: .res CASM_INCLUDE_OPEN_NAME_BUFFER_SIZE

CasmIncludeScanIndex: .res 1
CasmIncludeFreeSlot:  .res 1

.segment "CODE"

; ---------------------------------------------------------------------------
; includeCatalogInit
; Allocate the 8KB metadata VMM store and reset the catalog to empty. Called
; once, analogous to symbolsInit/sourceInit.
;
; Inputs:    none
; Outputs:   C clear, A = CASM_DIAG_NONE; CasmIncludeMetaSlot holds the
;            granted registry slot, CasmIncludeCatalogCount = 0
;            C set, A = CASM_DIAG_VMM_ALLOC_FAILED or
;            CASM_DIAG_VMM_UNAVAILABLE (propagated from vmmStoreAlloc)
; Clobbers:  A, X, Y and vmmStoreAlloc's own volatile state
; ---------------------------------------------------------------------------
includeCatalogInit:
    ldx #<CASM_INCLUDE_META_BYTES
    ldy #>CASM_INCLUDE_META_BYTES
    jsr vmmStoreAlloc
    bcs iciFail
    stx CasmIncludeMetaSlot
    lda #0
    sta CasmIncludeCatalogCount
    lda #CASM_DIAG_NONE
    clc
    rts
iciFail:
    rts                          ; A/C already set by vmmStoreAlloc

; ---------------------------------------------------------------------------
; includeResolveDevice
; Resolve the device a child spelling should open on, and locate the
; filename bytes after any prefix. Reuses DOS_PARSE_PREFIX directly: that OS
; call already advances a zero-page pointer past a recognized "8:"/"9:"/
; "10:"/"11:" prefix in place, so this routine never re-implements prefix
; scanning. When no prefix is present, the parent's resolved device is
; substituted for the OS's own CurrentDevice-based default (Phase 0C.19:
; inheritance, not CurrentDevice).
;
; Inputs:    A = parent's resolved device (8-11); X/Y = pointer to the
;            child's original spelling (null-terminated; not mutated)
; Outputs:   A = resolved device (8-11); X/Y = pointer to the filename bytes
;            after any prefix (same underlying buffer, later offset;
;            unchanged pointer if no prefix was present)
; Preserves: the pointed-to string's bytes (DOS_PARSE_PREFIX never rewrites
;            the string itself, only the transient zero-page pointer copy)
; Clobbers:  A, X, Y, CasmPtr0Lo/Hi, processor flags
; ---------------------------------------------------------------------------
includeResolveDevice:
    sta CasmIncludeParentDevice
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldx #CasmPtr0Lo
    lda #DOS_PARSE_PREFIX
    jsr OS_API
    bcs irdHasPrefix             ; C=1: A already the resolved device
    lda CasmIncludeParentDevice  ; C=0: no prefix -- inherit the parent's device
irdHasPrefix:
    sta CasmIncludeResolvedDevice
    lda CasmPtr0Lo
    sta CasmIncludeNamePtrLo
    lda CasmPtr0Hi
    sta CasmIncludeNamePtrHi
    lda CasmIncludeResolvedDevice
    ldx CasmIncludeNamePtrLo
    ldy CasmIncludeNamePtrHi
    rts

; ---------------------------------------------------------------------------
; includeFoldByte (private)
; Fold a shifted PETSCII letter ($C1-$DA) down to its unshifted equivalent
; ($41-$5A) for comparison only; every other byte passes through unchanged.
; Deliberately distinct from symbols.s's case-*sensitive* identifier
; comparison -- filename identity is case-insensitive (Phase 0C.19).
;
; Inputs:    A = byte
; Outputs:   A = folded byte
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
includeFoldByte:
    cmp #CASM_PETSCII_SHIFTED_A
    bcc ifbDone
    cmp #CASM_PETSCII_SHIFTED_Z + 1
    bcs ifbDone
    sec
    sbc #(CASM_PETSCII_SHIFTED_A - CASM_PETSCII_UPPER_A)
ifbDone:
    rts

; ---------------------------------------------------------------------------
; includeCaptureKey (private)
; Capture the case-folded search key -- device and up to 63 name bytes --
; into CasmIncludeKeyDevice/KeyName/KeyLen, before any call that could
; disturb CasmPtr0Lo/Hi or CasmVmmBuffer. Original bytes are never mutated;
; only the private key copy is folded.
;
; Inputs:    A = device; X/Y = pointer to a null-terminated name
; Outputs:   CasmIncludeKeyDevice/KeyName/KeyLen populated
;            C clear on success; C set with A = CASM_DIAG_INVALID_INCLUDE_FILENAME
;            if the name is empty (nothing follows a device prefix)
; Clobbers:  A, X, Y, CasmPtr1Lo/Hi, processor flags
; ---------------------------------------------------------------------------
includeCaptureKey:
    sta CasmIncludeKeyDevice
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
ickLoop:
    lda (CasmPtr1Lo), y
    beq ickDone
    jsr includeFoldByte
    sta CasmIncludeKeyName, y
    iny
    cpy #CASM_INCLUDE_FILENAME_MAX
    bcc ickLoop
ickDone:
    sty CasmIncludeKeyLen
    lda #0
    sta CasmIncludeKeyName, y
    cpy #0
    beq ickEmpty
    clc
    rts
ickEmpty:
    lda #CASM_DIAG_INVALID_INCLUDE_FILENAME
    sec
    rts

; ---------------------------------------------------------------------------
; includeCatalogRead
; Read one 32-slot physical record (both 64-byte transfer windows) into
; CasmIncludeRecordStage.
;
; Inputs:    A = record index (0..CASM_INCLUDE_PHYS_CAPACITY-1)
; Outputs:   C clear on success; CasmIncludeRecordStage holds the full
;            128-byte record
;            C set, A = CASM_DIAG_VMM_TRANSFER_FAILED (propagated from
;            vmmWindowRead) on failure
; Clobbers:  A, X, Y, CasmVmmOffLo/Hi, CasmIoLenLo/Hi, CasmVmmBuffer and
;            vmmWindowRead's own volatile state
; ---------------------------------------------------------------------------
includeCatalogRead:
    ; 16-bit byte offset = index * CASM_INCLUDE_PHYS_REC_SIZE (128): a
    ; 7-bit left shift of the 8-bit index into a 16-bit accumulator.
    sta CasmVmmOffLo
    lda #0
    sta CasmVmmOffHi
    ldx #7
icrShift:
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    dex
    bne icrShift

    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmIncludeMetaSlot
    jsr vmmWindowRead
    bcs icrFail
    ldy #0
icrCopyA:
    lda CasmVmmBuffer, y
    sta CasmIncludeRecordStage, y
    iny
    cpy #CASM_VMM_BUFFER_SIZE
    bcc icrCopyA

    lda CasmVmmOffLo
    clc
    adc #CASM_VMM_BUFFER_SIZE
    sta CasmVmmOffLo
    lda CasmVmmOffHi
    adc #0
    sta CasmVmmOffHi
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmIncludeMetaSlot
    jsr vmmWindowRead
    bcs icrFail
    ldy #0
icrCopyB:
    lda CasmVmmBuffer, y
    sta CasmIncludeRecordStage + CASM_VMM_BUFFER_SIZE, y
    iny
    cpy #CASM_VMM_BUFFER_SIZE
    bcc icrCopyB
    clc
    rts
icrFail:
    rts                          ; A/C already set by vmmWindowRead

; ---------------------------------------------------------------------------
; includeCatalogWrite (private)
; Write CasmIncludeRecordStage's full 128 bytes out to one record slot (both
; transfer windows).
;
; Inputs:    A = record index (0..CASM_INCLUDE_PHYS_CAPACITY-1);
;            CasmIncludeRecordStage holds the record to write
; Outputs:   C clear on success
;            C set, A = CASM_DIAG_VMM_TRANSFER_FAILED (propagated from
;            vmmWindowWrite) on failure
; Clobbers:  A, X, Y, CasmVmmOffLo/Hi, CasmIoLenLo/Hi, CasmVmmBuffer and
;            vmmWindowWrite's own volatile state
; ---------------------------------------------------------------------------
includeCatalogWrite:
    sta CasmVmmOffLo
    lda #0
    sta CasmVmmOffHi
    ldx #7
icwShift:
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    dex
    bne icwShift

    ldy #0
icwStageA:
    lda CasmIncludeRecordStage, y
    sta CasmVmmBuffer, y
    iny
    cpy #CASM_VMM_BUFFER_SIZE
    bcc icwStageA
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmIncludeMetaSlot
    jsr vmmWindowWrite
    bcs icwFail

    lda CasmVmmOffLo
    clc
    adc #CASM_VMM_BUFFER_SIZE
    sta CasmVmmOffLo
    lda CasmVmmOffHi
    adc #0
    sta CasmVmmOffHi
    ldy #0
icwStageB:
    lda CasmIncludeRecordStage + CASM_VMM_BUFFER_SIZE, y
    sta CasmVmmBuffer, y
    iny
    cpy #CASM_VMM_BUFFER_SIZE
    bcc icwStageB
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmIncludeMetaSlot
    jsr vmmWindowWrite
    bcs icwFail
    clc
    rts
icwFail:
    rts                          ; A/C already set by vmmWindowWrite

; ---------------------------------------------------------------------------
; includeCatalogFind
; Linearly scan the populated physical records for one matching the already
; captured search key (CasmIncludeKeyDevice/KeyName/KeyLen -- see
; includeCaptureKey). Cheap early-outs (device, then name length) avoid
; reading a second transfer window or comparing bytes for an obvious
; mismatch.
;
; Inputs:    CasmIncludeKeyDevice/KeyName/KeyLen already captured;
;            CasmIncludeCatalogCount populated records exist at indices
;            0..CasmIncludeCatalogCount-1
; Outputs:   C clear with X = the matching record index on a hit
;            C set, A = CASM_DIAG_NONE (not-found, not a failure) on a miss
;            C set, A = CASM_DIAG_VMM_TRANSFER_FAILED if a record read fails
; Clobbers:  A, X, Y, CasmIncludeRecordStage, CasmIncludeScanIndex and
;            includeCatalogRead's own clobbers
; ---------------------------------------------------------------------------
includeCatalogFind:
    lda #0
    sta CasmIncludeScanIndex
icfLoop:
    lda CasmIncludeScanIndex
    cmp CasmIncludeCatalogCount
    bcs icfMiss
    jsr includeCatalogRead
    bcs icfReadFail

    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    cmp CasmIncludeKeyDevice
    bne icfNext
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAMELEN
    cmp CasmIncludeKeyLen
    bne icfNext

    ; Same device and name length: compare folded bytes.
    ldy #0
icfCompare:
    cpy CasmIncludeKeyLen
    beq icfHit                  ; every byte matched
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME, y
    jsr includeFoldByte
    cmp CasmIncludeKeyName, y
    bne icfNext
    iny
    jmp icfCompare

icfHit:
    ldx CasmIncludeScanIndex
    clc
    rts

icfNext:
    inc CasmIncludeScanIndex
    jmp icfLoop

icfMiss:
    lda #CASM_DIAG_NONE
    sec
    rts
icfReadFail:
    rts                          ; A/C already set by includeCatalogRead

; ---------------------------------------------------------------------------
; includeSynthesizeOpenName (private)
; Build the explicit "<device>:<name>" string DOS_OPEN_FILE must see so an
; inherited device (which may differ from CurrentDevice, something
; DOS_OPEN_FILE cannot be told directly) is honored regardless of whether
; the child's own spelling carried a prefix. Always synthesizes, even when
; the resolved device happens to already match what DOS_OPEN_FILE would
; default to -- simpler and unconditionally correct, at the cost of a
; trivial handful of extra bytes copied.
;
; Inputs:    CasmIncludeResolvedDevice; CasmIncludeNamePtrLo/Hi = pointer to
;            the post-prefix name (null-terminated)
; Outputs:   CasmIncludeOpenName holds the synthesized, null-terminated
;            string; X/Y = its pointer
; Clobbers:  A, X, Y, processor flags
; ---------------------------------------------------------------------------
includeSynthesizeOpenName:
    lda CasmIncludeResolvedDevice
    sec
    sbc #CASM_DEVICE_MIN
    tax
    lda includeDeviceStrLo, x
    sta CasmPtr1Lo
    lda includeDeviceStrHi, x
    sta CasmPtr1Hi
    ldy #0
isonCopyDevice:
    lda (CasmPtr1Lo), y
    beq isonDeviceDone
    sta CasmIncludeOpenName, y
    iny
    jmp isonCopyDevice
isonDeviceDone:
    lda #CASM_PETSCII_COLON
    sta CasmIncludeOpenName, y
    iny

    lda CasmIncludeNamePtrLo
    sta CasmPtr1Lo
    lda CasmIncludeNamePtrHi
    sta CasmPtr1Hi
    ; Indirect-indexed addressing (needed to read through CasmPtr1Lo/Hi) only
    ; supports Y, so Y becomes the source index (restarting at 0) and X takes
    ; over as the destination index (continuing from the device+colon
    ; prefix's own length, already in Y from isonDeviceDone above) --
    ; CasmIncludeOpenName's direct-indexed writes accept either register.
    tya
    tax
    ldy #0
isonCopyName:
    lda (CasmPtr1Lo), y
    sta CasmIncludeOpenName, x
    beq isonNameDone
    iny
    inx
    cpx #CASM_INCLUDE_OPEN_NAME_BUFFER_SIZE - 1
    bcc isonCopyName
    lda #0
    sta CasmIncludeOpenName, x
isonNameDone:
    ldx #<CasmIncludeOpenName
    ldy #>CasmIncludeOpenName
    rts

; ---------------------------------------------------------------------------
; includeCatalogLoad
; Resolve, canonicalize, and deduplicate one child include target. On a
; catalog hit, performs no file I/O and no source append (Phase 0C.19:
; repeated includes share one immutable physical byte copy). On a miss,
; transiently opens/reads/closes the child (via sourceAppendFile, which
; appends its bytes to the existing source store without disturbing any
; live traversal read cursor), then writes a new physical record.
;
; A failure at any step leaves whatever was already registered (a transient
; file handle mid-open, any VMM work already committed by sourceAppendFile)
; for the central resource owner's generic cleanup sweep -- no manual unwind
; is performed here, matching every other CASM init-path failure.
;
; Inputs:    A = parent's resolved device; X/Y = pointer to the child's
;            original spelling (e.g. CasmIncludeFilename, WP44)
; Outputs:   C clear with X = the record index (new or existing) on success
;            C set, A = CASM_DIAG_* on failure:
;              CASM_DIAG_INVALID_INCLUDE_FILENAME (empty post-prefix name),
;              CASM_DIAG_INCLUDE_CATALOG_FULL (32 distinct files already
;                cataloged), or a propagated open/read/close/cap/transfer
;                diagnostic
; Clobbers:  A, X, Y and every routine above's own clobbers
; ---------------------------------------------------------------------------
includeCatalogLoad:
    jsr includeResolveDevice
    jsr includeCaptureKey
    bcs iclFailNear

    jsr includeCatalogFind
    bcc iclHitNear
    ; C set: either a genuine miss (proceed to load) or a propagated read
    ; failure. Both leave A meaningful only in the failure case; a genuine
    ; miss carries no diagnostic, so only continue past a real one.
    cmp #CASM_DIAG_NONE
    bne iclFailNear

    lda CasmIncludeCatalogCount
    cmp #CASM_INCLUDE_PHYS_CAPACITY
    bcc iclHaveSlot
    lda #CASM_DIAG_INCLUDE_CATALOG_FULL
    sec
    rts
iclHaveSlot:
    sta CasmIncludeFreeSlot
    jmp iclContinue

; Trampolines: iclFail/iclHit are out of direct branch range from the checks
; above.
iclFailNear:
    jmp iclFail
iclHitNear:
    jmp iclHit

iclContinue:
    jsr includeSynthesizeOpenName
    jsr sourceAppendFile
    bcs iclFail

    ; Build the new record: flags, device, namelen, reserved, start/length
    ; (from sourceAppendFile's CasmValue0/1), then the original (unfolded)
    ; post-prefix name, then zero-filled padding.
    lda #CASM_RESOURCE_OWNED
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_FLAG
    lda CasmIncludeResolvedDevice
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    lda CasmIncludeKeyLen
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAMELEN
    lda #0
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_RESERVED0
    lda CasmValue0Lo
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    lda CasmValue0Hi
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    lda CasmValue1Lo
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_LO
    lda CasmValue1Hi
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_HI

    ; Copy exactly CasmIncludeKeyLen bytes (already bounded to <=63 by
    ; includeCaptureKey) rather than re-scanning to a null terminator a
    ; second time -- avoids ever writing past the 64-byte NAME slot even in
    ; principle.
    lda CasmIncludeNamePtrLo
    sta CasmPtr1Lo
    lda CasmIncludeNamePtrHi
    sta CasmPtr1Hi
    ldy #0
iclCopyName:
    cpy CasmIncludeKeyLen
    beq iclNameDone
    lda (CasmPtr1Lo), y
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME, y
    iny
    jmp iclCopyName
iclNameDone:
    lda #0
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME, y
    ; Zero-fill from just past the terminator through the end of the
    ; 128-byte record.
    tya
    clc
    adc #CASM_INCLUDE_PHYS_REC_NAME + 1
    tay
    lda #0
iclZeroLoop:
    cpy #CASM_INCLUDE_PHYS_REC_SIZE
    bcs iclZeroDone
    sta CasmIncludeRecordStage, y
    iny
    jmp iclZeroLoop
iclZeroDone:

    lda CasmIncludeFreeSlot
    jsr includeCatalogWrite
    bcs iclFail

    inc CasmIncludeCatalogCount
    ldx CasmIncludeFreeSlot
    clc
    rts

iclHit:
    ; X already holds the matching record index from includeCatalogFind.
    clc
    rts
iclFail:
    rts                          ; A/C already set by the failing call

.segment "RODATA"

; Device-digit-string lookup, indexed by (device - CASM_DEVICE_MIN).
includeDeviceStrLo:
    .byte <includeDeviceStr8, <includeDeviceStr9, <includeDeviceStr10, <includeDeviceStr11
includeDeviceStrHi:
    .byte >includeDeviceStr8, >includeDeviceStr9, >includeDeviceStr10, >includeDeviceStr11
includeDeviceStr8:
    .byte "8", 0
includeDeviceStr9:
    .byte "9", 0
includeDeviceStr10:
    .byte "10", 0
includeDeviceStr11:
    .byte "11", 0
