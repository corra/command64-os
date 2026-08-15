; src/external/casm/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM shared constants and module ABI. This file declares no storage and
; emits no code. Phase 0A scaffold and Phase 0B CLI/file contracts were
; approved on 2026-07-16; changes to these foundational limits require a new
; approved planning increment.

.ifndef CASM_COMMON_INC
CASM_COMMON_INC = 1

; ---------------------------------------------------------------------------
; Application-private zero page: $70-$8F
;
; These fixed-address aliases are transient scratch shared by CASM modules.
; They do not allocate linker storage. Any later linker-defined zero-page
; symbol shared across object files must use .exportzp/.importzp.
; ---------------------------------------------------------------------------

; General pointers and values ($70-$77).
CasmPtr0Lo       = $70
CasmPtr0Hi       = $71
CasmPtr1Lo       = $72
CasmPtr1Hi       = $73
CasmValue0Lo     = $74
CasmValue0Hi     = $75
CasmValue1Lo     = $76
CasmValue1Hi     = $77

; I/O and VMM transfer scratch ($78-$7F).
CasmIoPtrLo      = $78
CasmIoPtrHi      = $79
CasmIoLenLo      = $7A
CasmIoLenHi      = $7B
CasmVmmSegHi     = $7C
CasmVmmBank      = $7D
CasmVmmOffLo     = $7E
CasmVmmOffHi     = $7F

; Parser and expression transient scratch ($80-$87), reserved until the
; corresponding approved phases define narrower aliases.
CasmParseScratch0 = $80
CasmParseScratch1 = $81
CasmParseScratch2 = $82
CasmParseScratch3 = $83

; Phase 2 CLI aliases. These values are transient within cli.s calls and must
; not be treated as persistent parser state across public routine boundaries.
CasmCliPos        = CasmParseScratch0
CasmCliTokenStart = CasmParseScratch1
CasmCliDestIndex  = CasmParseScratch2
CasmCliScratch    = CasmParseScratch3

; Phase 3 source and lexer aliases. These are transient within a documented
; source or lexer call and never hold persistent state across public routine
; boundaries or OS_API calls.
CasmSourceScratch0 = CasmParseScratch0
CasmSourceScratch1 = CasmParseScratch1
CasmLexerScratch0  = CasmParseScratch2
CasmLexerScratch1  = CasmParseScratch3

CasmExprScratch0  = $84
CasmExprScratch1  = $85
CasmExprScratch2  = $86
CasmExprScratch3  = $87

; WP15 diagnostic renderer aliases. Safe to overlay the expression scratch:
; the renderer runs only on the terminal fatal path, after all evaluation has
; stopped. Deliberately not the lexer scratch, which printDec16 clobbers.
CasmDiagWinStart = CasmExprScratch0
CasmDiagWinCount = CasmExprScratch1
CasmDiagCaretPos = CasmExprScratch2
CasmDiagWinFlags = CasmExprScratch3

; Resolved view of whichever echo buffer holds the diagnostic's line.
CasmDiagViewSel     = CasmPassScratch0
CasmDiagViewLen     = CasmPassScratch1
CasmDiagViewClipped = CasmPassScratch2

; CasmDiagWinFlags bits.
CASM_DIAG_CLIP_LEFT  = $01
CASM_DIAG_CLIP_RIGHT = $02

; Pass and emission transient scratch ($88-$8F), reserved until the
; corresponding approved phases define narrower aliases.
CasmPassScratch0 = $88
CasmPassScratch1 = $89
CasmPassScratch2 = $8A
CasmPassScratch3 = $8B
CasmEmitScratch0 = $8C
CasmEmitScratch1 = $8D
CasmEmitScratch2 = $8E
CasmEmitScratch3 = $8F

CASM_ZP_FIRST = $70
CASM_ZP_LAST  = $8F
CASM_ZP_SIZE  = CASM_ZP_LAST - CASM_ZP_FIRST + 1
.assert CASM_ZP_SIZE = 32, error, "CASM zero-page contract must span 32 bytes"

; ---------------------------------------------------------------------------
; Bounded resource registry contract
; ---------------------------------------------------------------------------

CASM_FILE_CAPACITY = 8
CASM_VMM_CAPACITY  = 8

CASM_RESOURCE_FREE  = 0
CASM_RESOURCE_OWNED = 1
CASM_INVALID_HANDLE = $FF

; File record: occupancy flag followed by Command 64 handle.
CASM_FILE_REC_FLAG   = 0
CASM_FILE_REC_HANDLE = 1
CASM_FILE_REC_SIZE   = 2

; VMM record: occupancy flag, the DOS_ALLOC_MEM identity returned in X
; (segment high byte) and Y (REU bank), and the granted 4KB-page count
; (1-16, WP24) needed to bounds-check windowed transfers against an
; allocation's actual capacity -- the OS provides no such check itself.
CASM_VMM_REC_FLAG  = 0
CASM_VMM_REC_SEGHI = 1
CASM_VMM_REC_BANK  = 2
CASM_VMM_REC_PAGES = 3
CASM_VMM_REC_SIZE  = 4

CASM_FILE_REGISTRY_BYTES = CASM_FILE_CAPACITY * CASM_FILE_REC_SIZE
CASM_VMM_REGISTRY_BYTES  = CASM_VMM_CAPACITY * CASM_VMM_REC_SIZE

.assert CASM_FILE_CAPACITY = 8, error, "CASM file registry contract changed"
.assert CASM_VMM_CAPACITY = 8, error, "CASM VMM registry contract changed"
.assert CASM_VMM_REC_SIZE = 4, error, "CASM VMM registry record size changed"

; Single-allocation addressing cap (Phase 0C.4, frozen by WP22): a fixed
; SegHi:Bank pair plus a 16-bit Off cursor can address at most 65536 bytes.
; vmm_store.s must reject any request that would need more than this before
; ever calling DOS_ALLOC_MEM.
CASM_VMM_ALLOC_MAX_BYTES = 65536

.assert CASM_VMM_ALLOC_MAX_BYTES = 65536, error, "CASM VMM single-allocation cap changed"

; DOS_ALLOC_MEM's granularity (WP24): CASM_VMM_REC_PAGES * CASM_VMM_PAGE_BYTES
; is an allocation's true granted capacity, which vmmWindowRead/Write bounds-
; check windowed transfers against.
CASM_VMM_PAGE_BYTES = 4096

.assert CASM_VMM_PAGE_BYTES = 4096, error, "CASM VMM page size changed"

; Fixed base-RAM staging buffer for vmmWindowRead/vmmWindowWrite/vmmReplay
; (WP24). Not CasmIoBuffer, which stays reserved for source input. Sized at
; WP24 generically for WP25's pattern-based fixtures, against no real Phase
; 6B record (not yet designed at the time). WP27 amends this to exactly the
; real Phase 6B symbol record size (CASM_SYMBOL_REC_SIZE, below) so one
; record fits one transfer -- reconciling the 37-byte record WP26 froze
; against this 32-byte cap found they conflicted; the user resolved it by
; padding the record to 64 bytes (a power of two, so record-index-to-offset
; arithmetic is a single shift) and growing this buffer to match. Must fit
; an 8-bit byte count so the transfer length can never itself overflow while
; being checked against this bound.
CASM_VMM_BUFFER_SIZE = 64

.assert CASM_VMM_BUFFER_SIZE <= 255, error, "CASM VMM staging buffer must fit an 8-bit byte count"

; ---------------------------------------------------------------------------
; Phase 2 bounded CLI and file-service contract
; ---------------------------------------------------------------------------

; CommandBuffer is an 80-byte OS-owned buffer. CASM copies filenames into
; private bounded buffers and never inserts terminators into CommandBuffer.
CASM_COMMAND_BUFFER_SIZE = 80
CASM_FILENAME_MAX        = 63
CASM_FILENAME_BUFFER_SIZE = CASM_FILENAME_MAX + 1
CASM_IO_BUFFER_SIZE      = $0100

.assert CASM_FILENAME_BUFFER_SIZE = 64, error, "CASM filename buffer changed"
.assert CASM_FILENAME_BUFFER_SIZE <= CASM_COMMAND_BUFFER_SIZE, error, "CASM filename buffer exceeds command buffer"
.assert CASM_IO_BUFFER_SIZE = 256, error, "CASM I/O buffer changed"

; Parsed option bits. CLI state stores one byte and rejects an option whose bit
; is already set. Option names are compared case-insensitively; filename bytes
; are copied unchanged.
CASM_PETSCII_SPACE = $20
CASM_PETSCII_NULL  = $00
CASM_PETSCII_TAB   = $09
CASM_PETSCII_LF    = $0A
CASM_PETSCII_CR    = $0D
CASM_PETSCII_QUOTE = $22
CASM_PETSCII_APOSTROPHE = $27  ; WP69: character-literal delimiter
CASM_PETSCII_HASH  = $23
CASM_PETSCII_PERCENT = $25
CASM_PETSCII_AMPERSAND = $26
CASM_PETSCII_LPAREN = $28
CASM_PETSCII_RPAREN = $29
CASM_PETSCII_ASTERISK = $2A  ; WP66: current-address symbol
CASM_PETSCII_PLUS  = $2B
CASM_PETSCII_COMMA = $2C
CASM_PETSCII_MINUS = $2D
CASM_PETSCII_DOT   = $2E
CASM_PETSCII_SLASH = $2F
CASM_PETSCII_DIGIT_0 = $30
CASM_PETSCII_DIGIT_9 = $39
CASM_PETSCII_COLON = $3A
CASM_PETSCII_SEMICOLON = $3B
CASM_PETSCII_LESS  = $3C
CASM_PETSCII_EQUALS = $3D  ; WP65: named-constant definition (identifier = expr)
CASM_PETSCII_GREATER = $3E
CASM_PETSCII_CARET = $5E
CASM_PETSCII_PIPE = $7C
CASM_PETSCII_TILDE = $7E
CASM_PETSCII_AT    = $40  ; WP53: CBM DOS's native open-for-write replace marker
CASM_PETSCII_UPPER_A = $41
CASM_PETSCII_UPPER_Z = $5A
CASM_PETSCII_UNDERSCORE = $5F
CASM_PETSCII_SHIFTED_A = $C1
CASM_PETSCII_SHIFTED_Z = $DA
CASM_PETSCII_G     = $47
CASM_PETSCII_L     = $4C
CASM_PETSCII_M     = $4D
CASM_PETSCII_O     = $4F
CASM_PETSCII_P     = $50
CASM_PETSCII_R     = $52
CASM_PETSCII_S     = $53
CASM_PETSCII_T     = $54

; Phase 9 WP44 quoted include operand grammar. Filename payload bytes preserve
; their original PETSCII spelling; quote is the delimiter and is therefore not
; part of either accepted printable range.
CASM_INCLUDE_FILENAME_MAX         = 63
CASM_INCLUDE_FILENAME_BUFFER_SIZE = CASM_INCLUDE_FILENAME_MAX + 1
CASM_INCLUDE_PRINT_LO_MIN          = $20
CASM_INCLUDE_PRINT_LO_MAX          = $7E
CASM_INCLUDE_PRINT_HI_MIN          = $A0
CASM_INCLUDE_PRINT_HI_MAX          = $FE

.assert CASM_INCLUDE_FILENAME_BUFFER_SIZE = 64, error, "CASM include filename buffer changed"
.assert CASM_PETSCII_QUOTE >= CASM_INCLUDE_PRINT_LO_MIN, error, "CASM include quote below printable range"
.assert CASM_PETSCII_QUOTE <= CASM_INCLUDE_PRINT_LO_MAX, error, "CASM include quote above printable range"

; Phase 9 WP45 physical file catalog contract. One 8KB VMM allocation (Phase
; 0C.19 freeze) holds the physical-file catalog; WP45 writes only the first
; CASM_INCLUDE_PHYS_CAPACITY * CASM_INCLUDE_PHYS_REC_SIZE bytes of it. The
; remainder is reserved, untouched space for WP47's include-event log --
; never a second allocation.
CASM_INCLUDE_META_BYTES = 8192

.assert CASM_INCLUDE_META_BYTES = 8192, error, "CASM include metadata allocation size changed"

; Physical-file record: 4 control bytes (flags/device/namelen/reserved), a
; 2-byte source-store start offset, a 2-byte byte length, a 64-byte
; null-terminated name slot (original spelling, prefix already removed), and
; 56 reserved bytes -- 128 bytes total, transferred as two fixed 64-byte
; vmmWindowRead/vmmWindowWrite windows (matching CASM_VMM_BUFFER_SIZE
; exactly, the same one-record-per-transfer precedent CASM_SYMBOL_REC_SIZE
; established). Identity comparison folds the stored name's case live at
; compare time rather than storing a second folded copy, so one buffer
; satisfies both the case-folded-identity and original-spelling-for-
; diagnostics halves of the Phase 0C.19 contract.
CASM_INCLUDE_PHYS_REC_FLAG      = 0
CASM_INCLUDE_PHYS_REC_DEVICE    = 1
CASM_INCLUDE_PHYS_REC_NAMELEN   = 2
CASM_INCLUDE_PHYS_REC_RESERVED0 = 3
CASM_INCLUDE_PHYS_REC_START_LO  = 4
CASM_INCLUDE_PHYS_REC_START_HI  = 5
CASM_INCLUDE_PHYS_REC_LENGTH_LO = 6
CASM_INCLUDE_PHYS_REC_LENGTH_HI = 7
CASM_INCLUDE_PHYS_REC_NAME      = 8    ; 64-byte fixed slot, null-terminated
CASM_INCLUDE_PHYS_REC_SIZE      = 128

CASM_INCLUDE_PHYS_CAPACITY = 32

; Command 64 supported device numbers (matches CurrentDevice's own range and
; DOS_PARSE_PREFIX's recognized "8:"/"9:"/"10:"/"11:" prefixes).
CASM_DEVICE_MIN = 8
CASM_DEVICE_MAX = 11

.assert CASM_DEVICE_MAX - CASM_DEVICE_MIN + 1 = 4, error, "CASM device range changed"

; Phase 9 WP46 nested-include frame stack contract (Phase 0C.19: "16 include
; levels beyond a depth-zero top-level root"). Depth 0 means no nested frame
; is active (traversing a top-level root exactly as before Phase 9); depths
; 1..CASM_INCLUDE_MAX_DEPTH index the frame-stack arrays (source.s).
CASM_INCLUDE_MAX_DEPTH = 16

.assert CASM_INCLUDE_MAX_DEPTH = 16, error, "CASM include max nesting depth changed"

.assert CASM_INCLUDE_PHYS_REC_DEVICE = CASM_INCLUDE_PHYS_REC_FLAG + 1, error, "CASM include physical record device offset changed"
.assert CASM_INCLUDE_PHYS_REC_NAMELEN = CASM_INCLUDE_PHYS_REC_DEVICE + 1, error, "CASM include physical record namelen offset changed"
.assert CASM_INCLUDE_PHYS_REC_RESERVED0 = CASM_INCLUDE_PHYS_REC_NAMELEN + 1, error, "CASM include physical record reserved offset changed"
.assert CASM_INCLUDE_PHYS_REC_START_LO = CASM_INCLUDE_PHYS_REC_RESERVED0 + 1, error, "CASM include physical record start offset changed"
.assert CASM_INCLUDE_PHYS_REC_START_HI = CASM_INCLUDE_PHYS_REC_START_LO + 1, error, "CASM include physical record start offsets changed"
.assert CASM_INCLUDE_PHYS_REC_LENGTH_LO = CASM_INCLUDE_PHYS_REC_START_HI + 1, error, "CASM include physical record length offset changed"
.assert CASM_INCLUDE_PHYS_REC_LENGTH_HI = CASM_INCLUDE_PHYS_REC_LENGTH_LO + 1, error, "CASM include physical record length offsets changed"
.assert CASM_INCLUDE_PHYS_REC_NAME = CASM_INCLUDE_PHYS_REC_LENGTH_HI + 1, error, "CASM include physical record name offset changed"
.assert CASM_INCLUDE_PHYS_REC_SIZE = 128, error, "CASM include physical record size changed"
.assert CASM_INCLUDE_PHYS_REC_SIZE = CASM_VMM_BUFFER_SIZE * 2, error, "CASM include physical record must fit two VMM transfers exactly"
.assert CASM_INCLUDE_PHYS_REC_NAME + CASM_INCLUDE_FILENAME_BUFFER_SIZE <= CASM_INCLUDE_PHYS_REC_SIZE, error, "CASM include physical record name does not fit"
.assert CASM_INCLUDE_PHYS_CAPACITY * CASM_INCLUDE_PHYS_REC_SIZE <= CASM_INCLUDE_META_BYTES, error, "CASM include physical catalog exceeds metadata allocation"

; Phase 9 WP47 include-event log contract. Occupies the second half of the
; same 8KB metadata allocation the physical catalog already owns -- the space
; WP45's own header comment reserved for exactly this, never a second
; allocation. Pass 1 appends one event per `.INCLUDE` *occurrence* (a repeated
; include of an already-cataloged file still records its own event: Phase
; 0C.19 mandates expansion every time, with only the physical bytes
; deduplicated); Pass 2 consumes them in order with zero source-filesystem
; I/O.
;
; 16 bytes per record, so a whole event transfers in ONE 64-byte
; vmmWindowRead/vmmWindowWrite window -- unlike the 128-byte physical record's
; two-window read/write pair. The record deliberately stores no start/length
; span: Pass 2 always re-reads the child's span fresh from the (immutable
; since Pass 1) catalog, so a span duplicated here could only ever disagree
; with the record that actually governs traversal.
;
; Parent identity is a (kind, id) pair rather than a bare index because the
; two possible parents live in different namespaces: a top-level root is
; identified by CasmSourceFileId (0..CASM_SOURCE_COUNT_MAX-1) and is NOT a
; catalog entry at all (WP45/WP46 deliberately never cataloged top-level
; files -- unifying them is WP48's job), while a nested parent is identified
; by its catalog index (0..CASM_INCLUDE_PHYS_CAPACITY-1). Without the kind
; tag, root 3 and catalog record 3 would compare equal during replay.
CASM_INCLUDE_EVENT_PARENT_KIND    = 0
CASM_INCLUDE_EVENT_PARENT_ID      = 1
CASM_INCLUDE_EVENT_PARENT_LINE_LO = 2
CASM_INCLUDE_EVENT_PARENT_LINE_HI = 3
CASM_INCLUDE_EVENT_PARENT_COLUMN  = 4
CASM_INCLUDE_EVENT_CHILD_INDEX    = 5
CASM_INCLUDE_EVENT_SIZE           = 16

CASM_INCLUDE_EVENT_PARENT_KIND_ROOT  = 0
CASM_INCLUDE_EVENT_PARENT_KIND_FRAME = 1

; Phase 0C.19 freeze: "Maximum include occurrences/events is 128."
CASM_INCLUDE_EVENT_CAPACITY = 128

; Byte offset of the event log within the metadata allocation. Anchored to
; the catalog's own full reserved extent (not a bare literal) so growing
; CASM_INCLUDE_PHYS_CAPACITY can never silently overlap the two regions.
CASM_INCLUDE_EVENT_BASE = CASM_INCLUDE_PHYS_CAPACITY * CASM_INCLUDE_PHYS_REC_SIZE

.assert CASM_INCLUDE_EVENT_PARENT_ID = CASM_INCLUDE_EVENT_PARENT_KIND + 1, error, "CASM include event parent id offset changed"
.assert CASM_INCLUDE_EVENT_PARENT_LINE_LO = CASM_INCLUDE_EVENT_PARENT_ID + 1, error, "CASM include event parent line offset changed"
.assert CASM_INCLUDE_EVENT_PARENT_LINE_HI = CASM_INCLUDE_EVENT_PARENT_LINE_LO + 1, error, "CASM include event parent line offsets changed"
.assert CASM_INCLUDE_EVENT_PARENT_COLUMN = CASM_INCLUDE_EVENT_PARENT_LINE_HI + 1, error, "CASM include event parent column offset changed"
.assert CASM_INCLUDE_EVENT_CHILD_INDEX = CASM_INCLUDE_EVENT_PARENT_COLUMN + 1, error, "CASM include event child index offset changed"
.assert CASM_INCLUDE_EVENT_SIZE = 16, error, "CASM include event record size changed"
.assert CASM_INCLUDE_EVENT_SIZE <= CASM_VMM_BUFFER_SIZE, error, "CASM include event record must fit one VMM transfer"
.assert CASM_INCLUDE_EVENT_CAPACITY = 128, error, "CASM include event capacity changed"
.assert CASM_INCLUDE_EVENT_PARENT_KIND_FRAME = CASM_INCLUDE_EVENT_PARENT_KIND_ROOT + 1, error, "CASM include event parent kinds must remain contiguous"
; The event log must start at or after the catalog's end and fit entirely
; within the one 8KB metadata allocation.
.assert CASM_INCLUDE_EVENT_BASE >= CASM_INCLUDE_PHYS_CAPACITY * CASM_INCLUDE_PHYS_REC_SIZE, error, "CASM include event log overlaps the physical catalog"
.assert CASM_INCLUDE_EVENT_BASE + (CASM_INCLUDE_EVENT_CAPACITY * CASM_INCLUDE_EVENT_SIZE) <= CASM_INCLUDE_META_BYTES, error, "CASM include event log exceeds metadata allocation"

; Transient synthesis buffer for an explicit "<n>:name" string handed to
; fileOpenInput/DOS_OPEN_FILE when the resolved device is not what
; DOS_OPEN_FILE would default to on its own (an inherited parent device that
; differs from CurrentDevice, which DOS_OPEN_FILE cannot be told directly --
; it only ever honors an explicit prefix in the string or else CurrentDevice).
; Sized independently of CASM_INCLUDE_FILENAME_BUFFER_SIZE (device digits +
; colon can add bytes the original spelling didn't have) and never persisted
; into a catalog record.
CASM_INCLUDE_OPEN_NAME_BUFFER_SIZE = 68

.assert CASM_INCLUDE_OPEN_NAME_BUFFER_SIZE >= CASM_INCLUDE_FILENAME_BUFFER_SIZE + 4, error, "CASM include open-name synthesis buffer too small"

CASM_OPT_OUTPUT = %00000001
CASM_OPT_STATIC = %00000010
CASM_OPT_MAP    = %00000100
CASM_OPT_LIST   = %00001000
CASM_OPT_ALL    = CASM_OPT_OUTPUT | CASM_OPT_STATIC | CASM_OPT_MAP | CASM_OPT_LIST

; WP38 (Phase 0C.14/15): the page-aligned origin a relocatable assembly (no
; .ORG, no /S) starts at. Matches CASM's own add_ca65_app base link and
; every external app's base-linked relocation page, per the Phase 0C.14
; freeze.
CASM_DEFAULT_ORIGIN = $3400

; WP40 (Phase 0C.14/17): the relocation table's frozen capacity, per the
; user's confirmed Phase 0C.14 decision -- 4096 16-bit little-endian
; offsets, 8192 bytes total, one VMM allocation.
CASM_RELOC_MAX = 4096
CASM_RELOC_TABLE_BYTES = CASM_RELOC_MAX * 2
.assert CASM_RELOC_TABLE_BYTES = 8192, error, "CASM relocation table byte size changed"
.assert CASM_RELOC_TABLE_BYTES <= CASM_VMM_ALLOC_MAX_BYTES, error, "CASM relocation table exceeds one VMM allocation"

; WP41 (Phase 0C.14/18): the R6 footer's ASCII magic, matching
; tools/reloc.py's MAGIC = b"R6" exactly. Explicit bytes, not a ca65
; character literal, since this is raw binary file-format data that must
; not depend on this file's charmap.
CASM_R6_MAGIC_0 = $52  ; 'R'
CASM_R6_MAGIC_1 = $36  ; '6'

; Stable parser results. Public CLI routines return carry clear with
; CASM_PARSE_OK or carry set with a CASM_DIAG_* value; these identifiers are
; available for internal dispatch and static fixtures.
CASM_PARSE_OK = $00

; Command 64 DOS_OPEN_FILE access modes and the future assembler output type.
CASM_FILE_MODE_READ  = 0
CASM_FILE_MODE_WRITE = 1
CASM_OUTPUT_FILE_TYPE = CASM_PETSCII_P

CASM_INVALID_SLOT = $FF

; Managed local file state. A handle becomes OPEN only after it has been
; registered centrally. CLOSE_FAILED remains owned so cleanup can retry it.
CASM_FILE_STATE_CLOSED       = $00
CASM_FILE_STATE_OPEN         = $01
CASM_FILE_STATE_CLOSE_FAILED = $02

; Input-stream result stored separately from carry so normalized EOF is not
; confused with an OS error. The Phase 2 wrapper treats carry-set/zero-count
; read-past-EOF compatibility as CASM_STREAM_EOF.
CASM_STREAM_CLOSED = $00
CASM_STREAM_READY  = $01
CASM_STREAM_DATA   = $02
CASM_STREAM_EOF    = $03
CASM_STREAM_ERROR  = $04

; Output lifecycle values are reserved for the Phase 4 production consumer.
; Phase 2 defines the ABI but does not create placeholder output files.
CASM_OUTPUT_NOT_CREATED = $00
CASM_OUTPUT_CREATED     = $01
CASM_OUTPUT_INVALID     = $00
CASM_OUTPUT_VALID       = $01

; WP53: the PRG's permanent, one-way commit state for this run. Set only by
; outputCommit on a successful close, after emit/relocation finalization has
; both succeeded. outputAbort consults this before ever deleting the output
; file -- see outputAbort's own amended comment (fileio.s).
CASM_OUTPUT_NOT_COMMITTED = $00
CASM_OUTPUT_COMMITTED     = $01

; ---------------------------------------------------------------------------
; Phase 3 source and lexer contract
; ---------------------------------------------------------------------------

CASM_SOURCE_FILE_ID_INITIAL  = $00
CASM_SOURCE_OFFSET_INITIAL   = $0000
CASM_SOURCE_LINE_INITIAL     = $0001
CASM_SOURCE_COLUMN_INITIAL   = $01
CASM_SOURCE_LINE_MAX         = $FFFF
CASM_SOURCE_COLUMN_MAX       = $FF
CASM_SOURCE_OFFSET_MAX       = $FFFF
CASM_SOURCE_LINE_PAYLOAD_MAX = $FF

; Successful source results are deliberately nonzero so zeroed state cannot
; masquerade as a consumed source result.
CASM_SOURCE_BYTE    = $01
CASM_SOURCE_NEWLINE = $02
CASM_SOURCE_EOF     = $03

CASM_SOURCE_STATE_CLOSED = $00
CASM_SOURCE_STATE_READY  = $01
CASM_SOURCE_STATE_EOF    = $02
CASM_SOURCE_STATE_ERROR  = $03
CASM_SOURCE_STATE_COUNT  = $04

CASM_SOURCE_API_NONE  = $00
CASM_SOURCE_API_BYTE  = $01
CASM_SOURCE_API_LINE  = $02
CASM_SOURCE_API_COUNT = $03

CASM_SOURCE_LINE_IDLE     = $00
CASM_SOURCE_LINE_BUILDING = $01
CASM_SOURCE_LINE_READY    = $02
CASM_SOURCE_LINE_EOF      = $03
CASM_SOURCE_LINE_COUNT    = $04

; Lexer states. WP3 reserved the CasmLexerState byte in state.s and left its
; values for WP7. INIT is the pre-lexerInit value; READY produces tokens; EOF
; latches a repeat-stable EOF token; ERROR records a failure.
CASM_LEXER_STATE_INIT  = $00
CASM_LEXER_STATE_READY = $01
CASM_LEXER_STATE_EOF   = $02
CASM_LEXER_STATE_ERROR = $03
CASM_LEXER_STATE_COUNT = $04

CASM_TOKEN_TEXT_MAX         = 31
CASM_TOKEN_TEXT_BUFFER_SIZE = CASM_TOKEN_TEXT_MAX + 1

CASM_TOKEN_EOF        = $00
CASM_TOKEN_NEWLINE    = $01
CASM_TOKEN_IDENTIFIER = $02
CASM_TOKEN_MNEMONIC   = $03
CASM_TOKEN_DIRECTIVE  = $04
CASM_TOKEN_REGISTER   = $05
CASM_TOKEN_NUMBER     = $06
CASM_TOKEN_COMMA      = $07
CASM_TOKEN_COLON      = $08
CASM_TOKEN_HASH       = $09
CASM_TOKEN_LPAREN     = $0A
CASM_TOKEN_RPAREN     = $0B
CASM_TOKEN_PLUS       = $0C
CASM_TOKEN_MINUS      = $0D
CASM_TOKEN_LESS       = $0E
CASM_TOKEN_GREATER    = $0F
CASM_TOKEN_EQUALS     = $10  ; WP65: '=' -- named-constant definition (identifier = expr)
CASM_TOKEN_STAR       = $11  ; WP66: '*' -- current-address symbol (leaf/primary position only)
CASM_TOKEN_SLASH      = $12  ; WP68: '/'
CASM_TOKEN_AMPERSAND  = $13  ; WP68: '&'
CASM_TOKEN_CARET      = $14  ; WP68: '^'
CASM_TOKEN_PIPE       = $15  ; WP68: '|'
CASM_TOKEN_TILDE      = $16  ; WP68: '~'
CASM_TOKEN_SHL        = $17  ; WP68: '<<'
CASM_TOKEN_SHR        = $18  ; WP68: '>>'
CASM_TOKEN_CHAR       = $19  ; WP69: 'x' -- character literal (immediate/.BYTE only)
CASM_TOKEN_COUNT      = $1A

; WP68 expression precedence values, lowest to highest. Binary operators are
; left-associative, so an RHS recurses at its operator's precedence + 1.
CASM_EXPR_PREC_ADD     = 1
CASM_EXPR_PREC_OR      = 2
CASM_EXPR_PREC_XOR     = 3
CASM_EXPR_PREC_AND     = 4
CASM_EXPR_PREC_SHIFT   = 5
CASM_EXPR_PREC_MULDIV  = 6
CASM_EXPR_PREC_UNARY   = 7
CASM_EXPR_PREC_LOWEST  = CASM_EXPR_PREC_ADD

.assert CASM_EXPR_PREC_OR = CASM_EXPR_PREC_ADD + 1, error, "CASM expression precedence changed"
.assert CASM_EXPR_PREC_XOR = CASM_EXPR_PREC_OR + 1, error, "CASM expression precedence changed"
.assert CASM_EXPR_PREC_AND = CASM_EXPR_PREC_XOR + 1, error, "CASM expression precedence changed"
.assert CASM_EXPR_PREC_SHIFT = CASM_EXPR_PREC_AND + 1, error, "CASM expression precedence changed"
.assert CASM_EXPR_PREC_MULDIV = CASM_EXPR_PREC_SHIFT + 1, error, "CASM expression precedence changed"
.assert CASM_EXPR_PREC_UNARY = CASM_EXPR_PREC_MULDIV + 1, error, "CASM expression precedence changed"

; Subtypes are interpreted only together with their token type.
CASM_SUBTYPE_NONE = $00

CASM_MNEMONIC_FIRST = $00
CASM_MNEMONIC_LAST  = $37
CASM_MNEMONIC_COUNT = 56

CASM_DIRECTIVE_UNKNOWN = $00
CASM_DIRECTIVE_ORG     = $01
CASM_DIRECTIVE_BYTE    = $02
CASM_DIRECTIVE_WORD    = $03
CASM_DIRECTIVE_INCLUDE = $04
CASM_DIRECTIVE_STATIC  = $05
CASM_DIRECTIVE_RELOC   = $06
CASM_DIRECTIVE_COUNT   = $07

CASM_REGISTER_A     = $00
CASM_REGISTER_X     = $01
CASM_REGISTER_Y     = $02
CASM_REGISTER_COUNT = $03

CASM_NUMBER_DECIMAL = $00
CASM_NUMBER_HEX     = $01
CASM_NUMBER_BINARY  = $02
CASM_NUMBER_COUNT   = $03

; Contiguous persistent token record. CasmTokenText begins at offset 7 and
; occupies the final 32 bytes of the 39-byte record.
CASM_TOKEN_REC_TYPE    = 0
CASM_TOKEN_REC_SUBTYPE = 1
CASM_TOKEN_REC_LENGTH  = 2
CASM_TOKEN_REC_FILE_ID = 3
CASM_TOKEN_REC_LINE_LO = 4
CASM_TOKEN_REC_LINE_HI = 5
CASM_TOKEN_REC_COLUMN  = 6
CASM_TOKEN_REC_TEXT    = 7
CASM_TOKEN_REC_SIZE    = CASM_TOKEN_REC_TEXT + CASM_TOKEN_TEXT_BUFFER_SIZE

; Phase 9 WP48: CASM_TOKEN_REC_FILE_ID (and every field it is copied into
; verbatim -- CasmSourceResultFileId, CasmLookaheadFileId, CasmStmtLocFileId,
; CasmDiagLocFileId) is bit-packed rather than a raw top-level index, so a
; byte's true provenance survives being fetched from inside a nested
; `.INCLUDE` frame. This is a semantic amendment to an already-stable-ABI
; byte, not a size change -- CASM_TOKEN_REC_SIZE stays 39 (user-approved:
; the alternative was growing the frozen token record for the first time
; since WP44 froze it there).
;
; Bit 7 clear: bits 0-6 are CasmSourceFileId (0..CASM_SOURCE_COUNT_MAX-1), a
; top-level root's own index -- the field's original, sole meaning before
; Phase 9.
; Bit 7 set: bits 0-6 are a physical catalog index
; (0..CASM_INCLUDE_PHYS_CAPACITY-1), identifying which included file the
; byte actually came from. Mirrors CASM_INCLUDE_EVENT_PARENT_KIND_ROOT/FRAME
; (WP47)'s own root-vs-frame split, applied here to per-byte provenance
; instead of an include event.
;
; Both namespaces fit in 7 bits with room to spare (CASM_SOURCE_COUNT_MAX is
; 8, CASM_INCLUDE_PHYS_CAPACITY is 32), so one flag bit is sufficient and no
; id ever collides with the flag bit itself.
CASM_DIAG_FILEID_FRAME_FLAG = $80
CASM_DIAG_FILEID_ID_MASK    = $7F

.assert CASM_DIAG_FILEID_FRAME_FLAG = $80, error, "CASM FILE_ID frame flag bit changed"
.assert CASM_DIAG_FILEID_ID_MASK = $7F, error, "CASM FILE_ID id mask changed"
.assert (CASM_DIAG_FILEID_FRAME_FLAG & CASM_DIAG_FILEID_ID_MASK) = 0, error, "CASM FILE_ID flag and id mask must not overlap"
.assert (CASM_DIAG_FILEID_FRAME_FLAG | CASM_DIAG_FILEID_ID_MASK) = $FF, error, "CASM FILE_ID flag and id mask must cover the whole byte"
.assert CASM_SOURCE_COUNT_MAX <= CASM_DIAG_FILEID_ID_MASK + 1, error, "CASM top-level file count no longer fits the FILE_ID id bits"
.assert CASM_INCLUDE_PHYS_CAPACITY <= CASM_DIAG_FILEID_ID_MASK + 1, error, "CASM include catalog capacity no longer fits the FILE_ID id bits"

.assert CASM_SOURCE_LINE_PAYLOAD_MAX = 255, error, "CASM source line payload changed"
.assert CASM_SOURCE_STATE_COUNT = CASM_SOURCE_STATE_ERROR + 1, error, "CASM source state range changed"
.assert CASM_SOURCE_API_COUNT = CASM_SOURCE_API_LINE + 1, error, "CASM source API range changed"
.assert CASM_SOURCE_LINE_COUNT = CASM_SOURCE_LINE_EOF + 1, error, "CASM source line state range changed"
.assert CASM_LEXER_STATE_COUNT = CASM_LEXER_STATE_ERROR + 1, error, "CASM lexer state range changed"
.assert CASM_TOKEN_TEXT_BUFFER_SIZE = 32, error, "CASM token text buffer changed"
.assert CASM_TOKEN_EQUALS = CASM_TOKEN_GREATER + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_STAR = CASM_TOKEN_EQUALS + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_SLASH = CASM_TOKEN_STAR + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_AMPERSAND = CASM_TOKEN_SLASH + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_CARET = CASM_TOKEN_AMPERSAND + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_PIPE = CASM_TOKEN_CARET + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_TILDE = CASM_TOKEN_PIPE + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_SHL = CASM_TOKEN_TILDE + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_SHR = CASM_TOKEN_SHL + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_CHAR = CASM_TOKEN_SHR + 1, error, "CASM token type range changed"
.assert CASM_TOKEN_COUNT = CASM_TOKEN_CHAR + 1, error, "CASM token type range changed"
.assert CASM_MNEMONIC_COUNT = CASM_MNEMONIC_LAST - CASM_MNEMONIC_FIRST + 1, error, "CASM mnemonic subtype range changed"
.assert CASM_MNEMONIC_COUNT = 56, error, "CASM mnemonic count changed"
.assert CASM_DIRECTIVE_COUNT = CASM_DIRECTIVE_RELOC + 1, error, "CASM directive subtype range changed"
.assert CASM_REGISTER_COUNT = CASM_REGISTER_Y + 1, error, "CASM register subtype range changed"
.assert CASM_NUMBER_COUNT = CASM_NUMBER_BINARY + 1, error, "CASM number subtype range changed"
.assert CASM_TOKEN_REC_SUBTYPE = CASM_TOKEN_REC_TYPE + 1, error, "CASM token subtype offset changed"
.assert CASM_TOKEN_REC_LENGTH = CASM_TOKEN_REC_SUBTYPE + 1, error, "CASM token length offset changed"
.assert CASM_TOKEN_REC_FILE_ID = CASM_TOKEN_REC_LENGTH + 1, error, "CASM token file offset changed"
.assert CASM_TOKEN_REC_LINE_LO = CASM_TOKEN_REC_FILE_ID + 1, error, "CASM token line-low offset changed"
.assert CASM_TOKEN_REC_LINE_HI = CASM_TOKEN_REC_LINE_LO + 1, error, "CASM token line-high offset changed"
.assert CASM_TOKEN_REC_COLUMN = CASM_TOKEN_REC_LINE_HI + 1, error, "CASM token column offset changed"
.assert CASM_TOKEN_REC_TEXT = CASM_TOKEN_REC_COLUMN + 1, error, "CASM token text offset changed"
.assert CASM_TOKEN_REC_SIZE = 39, error, "CASM token record size changed"
.assert CasmSourceScratch0 = $80, error, "CASM source scratch zero-page changed"
.assert CasmSourceScratch1 = $81, error, "CASM source scratch zero-page changed"
.assert CasmLexerScratch0 = $82, error, "CASM lexer scratch zero-page changed"
.assert CasmLexerScratch1 = $83, error, "CASM lexer scratch zero-page changed"
.assert CasmExprScratch0 = $84, error, "CASM expression scratch boundary changed"
.assert CasmPassScratch0 = $88, error, "CASM pass scratch boundary changed"
.assert CASM_IO_BUFFER_SIZE = 256, error, "CASM Phase 3 requires one 256-byte I/O buffer"

; ---------------------------------------------------------------------------
; Stable diagnostic identifiers
; ---------------------------------------------------------------------------

CASM_DIAG_NONE           = $00
CASM_DIAG_INIT_FAILED    = $01
CASM_DIAG_REGISTRY_FULL  = $02
CASM_DIAG_CLEANUP_FAILED = $03
CASM_DIAG_SOURCE_REQUIRED = $04
CASM_DIAG_EXTRA_SOURCE    = $05
CASM_DIAG_MALFORMED_OUTPUT_OPTION = $06
CASM_DIAG_DUPLICATE_OPTION = $07
CASM_DIAG_UNKNOWN_OPTION   = $08
CASM_DIAG_FILENAME_TOO_LONG = $09
CASM_DIAG_NOT_IMPLEMENTED  = $0A
CASM_DIAG_INPUT_OPEN_FAILED = $0B
CASM_DIAG_INPUT_READ_FAILED = $0C
CASM_DIAG_INPUT_CLOSE_FAILED = $0D
CASM_DIAG_OUTPUT_CREATE_FAILED = $0E
CASM_DIAG_OUTPUT_WRITE_FAILED = $0F
CASM_DIAG_OUTPUT_CLOSE_FAILED = $10
CASM_DIAG_OUTPUT_DELETE_FAILED = $11
CASM_DIAG_OUTPUT_SHORT_WRITE = $12
CASM_DIAG_STREAM_STATE_FAILED = $13
CASM_DIAG_PHASE2_LAST = CASM_DIAG_STREAM_STATE_FAILED
CASM_DIAG_SOURCE_REWIND_FAILED = $14
CASM_DIAG_SOURCE_OFFSET_OVERFLOW = $15
CASM_DIAG_SOURCE_LOCATION_OVERFLOW = $16
CASM_DIAG_SOURCE_LINE_TOO_LONG = $17
CASM_DIAG_TOKEN_TOO_LONG = $18
CASM_DIAG_INVALID_SOURCE_BYTE = $19
CASM_DIAG_MALFORMED_NUMBER = $1A
CASM_DIAG_LEXER_STATE_FAILED = $1B
CASM_DIAG_PHASE3_LAST = CASM_DIAG_LEXER_STATE_FAILED
CASM_DIAG_SYNTAX_ERROR = $1C
CASM_DIAG_EXPECTED_NEWLINE = $1D
CASM_DIAG_OPERAND_OUT_OF_RANGE = $1E
CASM_DIAG_INVALID_ADDR_MODE = $1F
CASM_DIAG_DUPLICATE_ORG = $20
CASM_DIAG_ORG_REQUIRED = $21
CASM_DIAG_ADDRESS_OVERFLOW = $22
CASM_DIAG_BRANCH_OUT_OF_RANGE = $23
CASM_DIAG_PHASE4_LAST = CASM_DIAG_BRANCH_OUT_OF_RANGE
; Phase 5 reservations. WP17 declares stable values only; diagnostics.s does
; not print or raise these until the package that implements each failure path.
CASM_DIAG_EXPR_MALFORMED = $24
CASM_DIAG_EXPR_UNSUPPORTED = $25
CASM_DIAG_EXPR_OVERFLOW = $26
CASM_DIAG_RESOLVER_FAILED = $27
CASM_DIAG_PHASE5_LAST = CASM_DIAG_RESOLVER_FAILED

; CASM Phase 6A (VMM storage foundation) reservations. WP23 raises the first
; three; the fourth is reserved for WP24's windowed transfer wrappers.
CASM_DIAG_VMM_UNAVAILABLE     = $28  ; VMM_ERR_INVALID: no REU / not initialized
CASM_DIAG_VMM_ALLOC_FAILED    = $29  ; VMM_ERR_NOMEM, or a rejected zero-size request
CASM_DIAG_VMM_FREE_FAILED     = $2A  ; DOS_FREE_MEM rejected the stored handle
CASM_DIAG_VMM_TRANSFER_FAILED = $2B  ; reserved for WP24; not raised by WP23
CASM_DIAG_PHASE6A_LAST = CASM_DIAG_VMM_TRANSFER_FAILED

; CASM Phase 6B (symbol table and two-pass assembly) reservations, per the
; Phase 5/WP17 precedent: the full block is declared here even though WP27
; raises/prints only the first and third; CASM_DIAG_UNDEFINED_SYMBOL and
; CASM_DIAG_PASS_MISMATCH stay reserved and unprintable until WP28 and WP30
; implement their raise paths.
CASM_DIAG_DUPLICATE_SYMBOL  = $2C  ; symbolsInsert: exact case-sensitive name already DEFINED
CASM_DIAG_UNDEFINED_SYMBOL  = $2D  ; reserved for WP28
CASM_DIAG_SYMBOL_TABLE_FULL = $2E  ; symbolsInsert: CasmSymbolCount already at CASM_SYMBOL_MAX
CASM_DIAG_PASS_MISMATCH     = $2F  ; reserved for WP30
CASM_DIAG_PHASE6B_LAST = CASM_DIAG_PASS_MISMATCH

; CASM Phase 8 WP40: relocation table capacity.
CASM_DIAG_RELOC_TABLE_FULL = $30  ; relocRecord: entry count already at CASM_RELOC_MAX
CASM_DIAG_PHASE8_LAST = CASM_DIAG_RELOC_TABLE_FULL
; CASM Phase 9 WP44 quoted include operand grammar.
CASM_DIAG_INCLUDE_FILENAME_EXPECTED = $31
CASM_DIAG_INVALID_INCLUDE_FILENAME  = $32
CASM_DIAG_INCLUDE_FILENAME_TOO_LONG = $33
CASM_DIAG_PHASE9_WP44_LAST = CASM_DIAG_INCLUDE_FILENAME_TOO_LONG
; CASM Phase 9 WP45 physical file catalog and dynamic source loading.
; Metadata allocation and record-transfer failures deliberately reuse
; vmmStoreAlloc's/vmmWindowRead's/vmmWindowWrite's own existing
; CASM_DIAG_VMM_ALLOC_FAILED/CASM_DIAG_VMM_UNAVAILABLE/
; CASM_DIAG_VMM_TRANSFER_FAILED by direct propagation -- tracing every call
; site found no failure mode those don't already describe correctly, so no
; new diagnostic was reserved for them (the same "reserved but unreachable"
; finding WP23 made for CASM_DIAG_VMM_ALLOC_TOO_LARGE). Only the physical
; catalog's own 32-slot capacity check is genuinely new, matching the
; CASM_DIAG_SYMBOL_TABLE_FULL/CASM_DIAG_REGISTRY_FULL precedent.
CASM_DIAG_INCLUDE_CATALOG_FULL = $34
CASM_DIAG_PHASE9_WP45_LAST = CASM_DIAG_INCLUDE_CATALOG_FULL
; CASM Phase 9 WP46 frame stack, nested traversal, and cycle detection.
CASM_DIAG_INCLUDE_DEPTH_EXCEEDED = $35
CASM_DIAG_INCLUDE_CYCLE_DETECTED = $36
CASM_DIAG_PHASE9_WP46_LAST = CASM_DIAG_INCLUDE_CYCLE_DETECTED
; CASM Phase 9 WP47 ordered include graph and Pass 2 replay. The event log's
; own 128-occurrence capacity check is genuinely new (same
; CASM_DIAG_SYMBOL_TABLE_FULL/CASM_DIAG_INCLUDE_CATALOG_FULL precedent).
; CASM_DIAG_INCLUDE_REPLAY_MISMATCH covers every Pass 2 correspondence
; failure -- a disagreeing parent/child identity or include-site location, an
; `.INCLUDE` with no recorded event behind it, and unconsumed events left at
; Pass 2's own EOF. Like CASM_DIAG_PASS_MISMATCH (WP30), it is a defensive
; internal-consistency diagnostic, not believed reachable through any
; legitimate source under the current grammar. Metadata transfer failures keep
; propagating CASM_DIAG_VMM_TRANSFER_FAILED, exactly as WP45 established.
CASM_DIAG_INCLUDE_EVENT_LOG_FULL  = $37
CASM_DIAG_INCLUDE_REPLAY_MISMATCH = $38
CASM_DIAG_PHASE9_WP47_LAST = CASM_DIAG_INCLUDE_REPLAY_MISMATCH

; CASM Phase 10 WP51 listing capture: metadata/byte-mirror capacity and
; source/listing capture transaction-discipline failures.
; CASM_DIAG_LISTING_NAME_COLLISION is declared and rendered here (per WP50's
; ABI freeze reserving it first in the Phase 10 range) but WP53 -- not WP51
; -- is the only package that can raise it; no WP51 code path reaches it.
CASM_DIAG_LISTING_NAME_COLLISION  = $39
CASM_DIAG_LISTING_RECORDS_FULL    = $3A  ; listingCommitLine: metadata store already at CASM_LISTING_META_MAX
CASM_DIAG_LISTING_BYTES_FULL      = $3B  ; listingMirrorByte: byte mirror already CASM_LISTING_BYTE_MAX
CASM_DIAG_LISTING_REPLAY_MISMATCH = $3C  ; listing/source capture transaction discipline violated
CASM_DIAG_PHASE10_WP51_LAST = CASM_DIAG_LISTING_REPLAY_MISMATCH
; Reserved for WP53's listing-file I/O; declared for contiguity only -- not
; yet raised, and not yet covered by diagnostics.s's message table.
CASM_DIAG_LISTING_CREATE_FAILED = $3D
CASM_DIAG_LISTING_WRITE_FAILED  = $3E
CASM_DIAG_LISTING_CLOSE_FAILED  = $3F
CASM_DIAG_LISTING_DELETE_FAILED = $40
CASM_DIAG_LISTING_SHORT_WRITE   = $41
CASM_DIAG_PHASE10_WP53_LAST = CASM_DIAG_LISTING_SHORT_WRITE
CASM_DIAG_SYMBOL_MAP_INVALID = $42  ; mapPrint: corrupt symbol record (locationless)
CASM_DIAG_PHASE10_WP52_LAST = CASM_DIAG_SYMBOL_MAP_INVALID
; WP64 reserved $43-$45 across Phase 12 for EXPR_CIRCULAR/EXPR_DIV_ZERO/
; EXPR_RELOC_UNSUPPORTED (brain/KNOWLEDGE.md, Phase 12 WP64 section); WP65
; was the only WP that raised one of the three ($43) at the time. $44
; stays declared-but-unraised until WP68 implements division; WP67
; activates $45 (a relocatable value reaching a paren-combine that can't
; collapse to one symbol + static addend, WP64's own representability
; rule -- see expr.s's evalExpr).
CASM_DIAG_EXPR_CIRCULAR = $43  ; resolutionSweep: named constant's definition is directly or transitively self-referential
CASM_DIAG_PHASE12_WP65_LAST = CASM_DIAG_EXPR_CIRCULAR
CASM_DIAG_EXPR_DIV_ZERO = $44  ; WP68: division by a static zero (not yet raised anywhere)
CASM_DIAG_EXPR_RELOC_UNSUPPORTED = $45  ; WP67: a relocatable operand reached a combine that isn't representable as one symbol + static addend
; WP67: parenthesized sub-expression nesting exceeded CASM_EXPR_PAREN_MAX_DEPTH.
CASM_DIAG_EXPR_PAREN_TOO_DEEP = $46
CASM_DIAG_PHASE12_WP67_LAST = CASM_DIAG_EXPR_PAREN_TOO_DEEP
; WP69: character literal ('x') -- no closing quote found immediately after
; the one content byte (also covers an empty '' literal, not special-cased).
CASM_DIAG_CHAR_UNTERMINATED = $47
; WP69: character literal's content byte outside the existing printable-
; PETSCII range (CASM_INCLUDE_PRINT_LO/HI_MIN/MAX, same bounds .INCLUDE
; filenames already enforce).
CASM_DIAG_CHAR_INVALID_BYTE = $48
CASM_DIAG_PHASE12_WP69_LAST = CASM_DIAG_CHAR_INVALID_BYTE
CASM_DIAG_UNKNOWN        = $FF

.assert CASM_DIAG_PHASE2_LAST = $13, error, "CASM Phase 2 diagnostic range changed"
.assert CASM_DIAG_SOURCE_REWIND_FAILED = CASM_DIAG_PHASE2_LAST + 1, error, "CASM Phase 3 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE3_LAST = $1B, error, "CASM Phase 3 diagnostic range changed"
.assert CASM_DIAG_SYNTAX_ERROR = CASM_DIAG_PHASE3_LAST + 1, error, "CASM Phase 4 diagnostics must remain contiguous"
.assert CASM_DIAG_INVALID_ADDR_MODE = CASM_DIAG_OPERAND_OUT_OF_RANGE + 1, error, "CASM Phase 4 diagnostics must remain contiguous"
.assert CASM_DIAG_BRANCH_OUT_OF_RANGE = CASM_DIAG_DUPLICATE_ORG + 3, error, "CASM Phase 4 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE4_LAST = $23, error, "CASM Phase 4 diagnostic range changed"
.assert CASM_DIAG_EXPR_MALFORMED = CASM_DIAG_PHASE4_LAST + 1, error, "CASM Phase 5 diagnostics must follow Phase 4"
.assert CASM_DIAG_EXPR_UNSUPPORTED = CASM_DIAG_EXPR_MALFORMED + 1, error, "CASM Phase 5 diagnostics must remain contiguous"
.assert CASM_DIAG_EXPR_OVERFLOW = CASM_DIAG_EXPR_UNSUPPORTED + 1, error, "CASM Phase 5 diagnostics must remain contiguous"
.assert CASM_DIAG_RESOLVER_FAILED = CASM_DIAG_EXPR_OVERFLOW + 1, error, "CASM Phase 5 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE5_LAST = $27, error, "CASM Phase 5 diagnostic range changed"
.assert CASM_DIAG_VMM_UNAVAILABLE = CASM_DIAG_PHASE5_LAST + 1, error, "CASM Phase 6A diagnostics must follow Phase 5"
.assert CASM_DIAG_VMM_ALLOC_FAILED = CASM_DIAG_VMM_UNAVAILABLE + 1, error, "CASM Phase 6A diagnostics must remain contiguous"
.assert CASM_DIAG_VMM_FREE_FAILED = CASM_DIAG_VMM_ALLOC_FAILED + 1, error, "CASM Phase 6A diagnostics must remain contiguous"
.assert CASM_DIAG_VMM_TRANSFER_FAILED = CASM_DIAG_VMM_FREE_FAILED + 1, error, "CASM Phase 6A diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE6A_LAST = $2B, error, "CASM Phase 6A diagnostic range changed"
.assert CASM_DIAG_DUPLICATE_SYMBOL = CASM_DIAG_PHASE6A_LAST + 1, error, "CASM Phase 6B diagnostics must follow Phase 6A"
.assert CASM_DIAG_UNDEFINED_SYMBOL = CASM_DIAG_DUPLICATE_SYMBOL + 1, error, "CASM Phase 6B diagnostics must remain contiguous"
.assert CASM_DIAG_SYMBOL_TABLE_FULL = CASM_DIAG_UNDEFINED_SYMBOL + 1, error, "CASM Phase 6B diagnostics must remain contiguous"
.assert CASM_DIAG_PASS_MISMATCH = CASM_DIAG_SYMBOL_TABLE_FULL + 1, error, "CASM Phase 6B diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE6B_LAST = $2F, error, "CASM Phase 6B diagnostic range changed"
.assert CASM_DIAG_RELOC_TABLE_FULL = CASM_DIAG_PHASE6B_LAST + 1, error, "CASM Phase 8 diagnostics must follow Phase 6B"
.assert CASM_DIAG_PHASE8_LAST = $30, error, "CASM Phase 8 diagnostic range changed"
.assert CASM_DIAG_INCLUDE_FILENAME_EXPECTED = CASM_DIAG_PHASE8_LAST + 1, error, "CASM Phase 9 diagnostics must follow Phase 8"
.assert CASM_DIAG_INVALID_INCLUDE_FILENAME = CASM_DIAG_INCLUDE_FILENAME_EXPECTED + 1, error, "CASM WP44 diagnostics must remain contiguous"
.assert CASM_DIAG_INCLUDE_FILENAME_TOO_LONG = CASM_DIAG_INVALID_INCLUDE_FILENAME + 1, error, "CASM WP44 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE9_WP44_LAST = $33, error, "CASM WP44 diagnostic range changed"
.assert CASM_DIAG_INCLUDE_CATALOG_FULL = CASM_DIAG_PHASE9_WP44_LAST + 1, error, "CASM Phase 9 WP45 diagnostics must follow WP44"
.assert CASM_DIAG_PHASE9_WP45_LAST = $34, error, "CASM WP45 diagnostic range changed"
.assert CASM_DIAG_INCLUDE_DEPTH_EXCEEDED = CASM_DIAG_PHASE9_WP45_LAST + 1, error, "CASM Phase 9 WP46 diagnostics must follow WP45"
.assert CASM_DIAG_INCLUDE_CYCLE_DETECTED = CASM_DIAG_INCLUDE_DEPTH_EXCEEDED + 1, error, "CASM WP46 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE9_WP46_LAST = $36, error, "CASM WP46 diagnostic range changed"
.assert CASM_DIAG_INCLUDE_EVENT_LOG_FULL = CASM_DIAG_PHASE9_WP46_LAST + 1, error, "CASM Phase 9 WP47 diagnostics must follow WP46"
.assert CASM_DIAG_INCLUDE_REPLAY_MISMATCH = CASM_DIAG_INCLUDE_EVENT_LOG_FULL + 1, error, "CASM WP47 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE9_WP47_LAST = $38, error, "CASM WP47 diagnostic range changed"
.assert CASM_DIAG_LISTING_NAME_COLLISION = CASM_DIAG_PHASE9_WP47_LAST + 1, error, "CASM Phase 10 diagnostics must follow Phase 9"
.assert CASM_DIAG_LISTING_RECORDS_FULL = CASM_DIAG_LISTING_NAME_COLLISION + 1, error, "CASM WP51 diagnostics must remain contiguous"
.assert CASM_DIAG_LISTING_BYTES_FULL = CASM_DIAG_LISTING_RECORDS_FULL + 1, error, "CASM WP51 diagnostics must remain contiguous"
.assert CASM_DIAG_LISTING_REPLAY_MISMATCH = CASM_DIAG_LISTING_BYTES_FULL + 1, error, "CASM WP51 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE10_WP51_LAST = $3C, error, "CASM WP51 diagnostic range changed"
.assert CASM_DIAG_LISTING_CREATE_FAILED = CASM_DIAG_PHASE10_WP51_LAST + 1, error, "CASM WP53 diagnostics must follow WP51"
.assert CASM_DIAG_LISTING_WRITE_FAILED = CASM_DIAG_LISTING_CREATE_FAILED + 1, error, "CASM WP53 diagnostics must remain contiguous"
.assert CASM_DIAG_LISTING_CLOSE_FAILED = CASM_DIAG_LISTING_WRITE_FAILED + 1, error, "CASM WP53 diagnostics must remain contiguous"
.assert CASM_DIAG_LISTING_DELETE_FAILED = CASM_DIAG_LISTING_CLOSE_FAILED + 1, error, "CASM WP53 diagnostics must remain contiguous"
.assert CASM_DIAG_LISTING_SHORT_WRITE = CASM_DIAG_LISTING_DELETE_FAILED + 1, error, "CASM WP53 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE10_WP53_LAST = $41, error, "CASM WP53 diagnostic range changed"
.assert CASM_DIAG_SYMBOL_MAP_INVALID = CASM_DIAG_PHASE10_WP53_LAST + 1, error, "CASM WP52 diagnostics must follow WP53's reserved range"
.assert CASM_DIAG_PHASE10_WP52_LAST = $42, error, "CASM WP52 diagnostic range changed"
.assert CASM_DIAG_EXPR_CIRCULAR = CASM_DIAG_PHASE10_WP52_LAST + 1, error, "CASM Phase 12 diagnostics must follow Phase 10"
.assert CASM_DIAG_PHASE12_WP65_LAST = $43, error, "CASM WP65 diagnostic range changed"
.assert CASM_DIAG_EXPR_DIV_ZERO = CASM_DIAG_PHASE12_WP65_LAST + 1, error, "CASM Phase 12 diagnostics must remain contiguous"
.assert CASM_DIAG_EXPR_RELOC_UNSUPPORTED = CASM_DIAG_EXPR_DIV_ZERO + 1, error, "CASM Phase 12 diagnostics must remain contiguous"
.assert CASM_DIAG_EXPR_PAREN_TOO_DEEP = CASM_DIAG_EXPR_RELOC_UNSUPPORTED + 1, error, "CASM Phase 12 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE12_WP67_LAST = $46, error, "CASM WP67 diagnostic range changed"
.assert CASM_DIAG_CHAR_UNTERMINATED = CASM_DIAG_PHASE12_WP67_LAST + 1, error, "CASM Phase 12 diagnostics must remain contiguous"
.assert CASM_DIAG_CHAR_INVALID_BYTE = CASM_DIAG_CHAR_UNTERMINATED + 1, error, "CASM Phase 12 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE12_WP69_LAST = $48, error, "CASM WP69 diagnostic range changed"

; ---------------------------------------------------------------------------
; Phase 4 statement parser contract
; ---------------------------------------------------------------------------

; CasmParserStmt record layout. A fixed-size BSS record populated by
; parserParseStatement (parser.s) for the downstream addressing-mode matcher
; and emission engine.
;
; CASM_PARSER_STMT_FLAGS (WP28) carries CASM_PARSER_STMT_FORCE_ABS, derived
; from the Phase 5 expression result's CASM_EXPR_FLAG_SYMBOL_DERIVED bit
; (not CASM_EXPR_FLAG_FORCE_ABS) -- any operand derived from a symbol
; reference forces absolute width, whether or not that symbol resolved.
; Deriving it from FORCE_ABS alone (only set when unresolved) would let a
; resolved backward reference with a small address disagree in size with an
; unresolved forward reference to the same label between Pass 1 and Pass 2 --
; exactly the failure mode the master plan's high-risk section warns about.
CASM_PARSER_STMT_TYPE        = 0
CASM_PARSER_STMT_SUBTYPE     = 1
CASM_PARSER_STMT_OPKIND      = 2
CASM_PARSER_STMT_VAL_LO      = 3
CASM_PARSER_STMT_VAL_HI      = 4
CASM_PARSER_STMT_REG_SUBTYPE = 5
CASM_PARSER_STMT_FLAGS       = 6
CASM_PARSER_STMT_SIZE        = 7

CASM_PARSER_STMT_FORCE_ABS = %00000001

; WP39: CASM_PARSER_STMT_RELOCATABLE, derived at the same parser.s site as
; FORCE_ABS (parserParseExpressionValue), from the expression result's
; CASM_EXPR_FLAG_RELOCATABLE bit -- unconditionally alongside SYMBOL_DERIVED,
; not gated on RESOLVED, for the identical Pass 1/Pass 2 agreement reason
; FORCE_ABS already documents above.
CASM_PARSER_STMT_RELOCATABLE = %00000010

; Operand category recorded in CasmParserStmt.OpKind.
CASM_OPKIND_IMPLIED          = 0
CASM_OPKIND_ACCUMULATOR      = 1
CASM_OPKIND_IMMEDIATE        = 2
CASM_OPKIND_ABSOLUTE         = 3  ; Covers ZP, Absolute
CASM_OPKIND_ABSOLUTE_X       = 4  ; ZP,X / Abs,X
CASM_OPKIND_ABSOLUTE_Y       = 5  ; ZP,Y / Abs,Y
CASM_OPKIND_INDIRECT         = 6
CASM_OPKIND_INDEXED_INDIRECT = 7  ; (ZP,X)
CASM_OPKIND_INDIRECT_INDEXED = 8  ; (ZP),Y
CASM_OPKIND_COUNT            = 9

.assert CASM_PARSER_STMT_SIZE = 7, error, "CASM parser statement record size changed"
.assert (CASM_PARSER_STMT_FORCE_ABS & (CASM_PARSER_STMT_FORCE_ABS - 1)) = 0, error, "force-absolute flag must be one bit"
.assert (CASM_PARSER_STMT_RELOCATABLE & (CASM_PARSER_STMT_RELOCATABLE - 1)) = 0, error, "relocatable flag must be one bit"
.assert CASM_OPKIND_COUNT = CASM_OPKIND_INDIRECT_INDEXED + 1, error, "CASM operand kind range changed"

; ---------------------------------------------------------------------------
; Phase 4 opcode table and addressing-mode matcher contract (WP12)
; ---------------------------------------------------------------------------

; Concrete 6502 addressing modes. The bit position of each mode is also the
; canonical packing order of a mnemonic's opcode run in opcodes.s, so these
; values are stable ABI: opcodeMaskLo/Hi bits and opcodeBytes ordering both
; depend on them.
CASM_MODE_IMPLIED          = 0
CASM_MODE_ACCUMULATOR      = 1
CASM_MODE_IMMEDIATE        = 2
CASM_MODE_ZEROPAGE         = 3
CASM_MODE_ZEROPAGE_X       = 4
CASM_MODE_ZEROPAGE_Y       = 5
CASM_MODE_ABSOLUTE         = 6
CASM_MODE_ABSOLUTE_X       = 7
CASM_MODE_ABSOLUTE_Y       = 8
CASM_MODE_INDIRECT         = 9
CASM_MODE_INDEXED_INDIRECT = 10
CASM_MODE_INDIRECT_INDEXED = 11
CASM_MODE_RELATIVE         = 12
CASM_MODE_COUNT            = 13

; CasmInsn encoding record populated by opcodesFindOpcode (opcodes.s) and
; consumed by the WP13 emission engine.
CASM_INSN_OPCODE = 0   ; selected opcode byte
CASM_INSN_MODE   = 1   ; resolved CASM_MODE_*
CASM_INSN_LENGTH = 2   ; 1..3 total instruction bytes
CASM_INSN_SIZE   = 3

.assert CASM_MODE_COUNT = CASM_MODE_RELATIVE + 1, error, "CASM addressing mode range changed"
.assert CASM_INSN_SIZE = 3, error, "CASM instruction encoding record size changed"

; ---------------------------------------------------------------------------
; Phase 4 emission engine contract (WP13)
; ---------------------------------------------------------------------------

; Bounded output staging buffer used by emit.s. This is distinct from the
; single 256-byte CasmIoBuffer (which stays reserved for input): input and
; output are both live during the single emit pass, so output cannot reuse it.
CASM_EMIT_BUFFER_SIZE = 64

.assert CASM_EMIT_BUFFER_SIZE = 64, error, "CASM emit buffer size changed"

; Registration/release routines return carry clear on success. On failure,
; carry is set and A contains one of the CASM_DIAG_* identifiers above.

; ---------------------------------------------------------------------------
; WP15 diagnostic source context contract
; ---------------------------------------------------------------------------

; A source-position diagnostic prints the offending line with a caret under the
; failing column. The lexer drives the source in BYTE mode, so CasmIoBuffer
; holds a 256-byte block window rather than a line window and cannot be used to
; recover the line: a refill may already have overwritten the line start. The
; source layer therefore echoes each consumed line into CasmDiagLineBuf.
;
; The echo is a separate buffer from CasmIoBuffer by necessity, not choice.
; Both are live simultaneously during traversal.
CASM_DIAG_LINE_BUF_SIZE = $0100
CASM_DIAG_LINE_MAX      = $FF

; The screen is 40 columns. A source line may be 255 bytes, so the rendered
; line is a sliding window positioned to keep the failing column visible.
; INDENT leaves room for a clipping marker on each side within 40 columns.
CASM_DIAG_WINDOW_WIDTH = 38
CASM_DIAG_INDENT       = 2

; Bytes outside the safe printable PETSCII ranges are substituted before they
; reach the screen. This is required for correctness, not cosmetics: an
; INVALID SOURCE BYTE diagnostic fires precisely because the byte is unusual,
; and echoing a raw $93 (clear screen) or $12 (reverse on) would corrupt or
; erase the message being printed. $00-$1F and $80-$9F are PETSCII control
; ranges; everything else renders as some visible glyph.
CASM_DIAG_PRINT_LO_MIN = $20
CASM_DIAG_PRINT_LO_MAX = $7F
CASM_DIAG_PRINT_HI_MIN = $A0
CASM_DIAG_SUBST_CHAR   = $2E    ; '.'

; Line-echo capture gate. LINE-mode callers already hold the line in
; CasmIoBuffer and do not pay the per-byte echo cost.
CASM_DIAG_CAPTURE_OFF = $00
CASM_DIAG_CAPTURE_ON  = $01

; Two echo buffers are retained, not one. The parser consumes a statement's
; terminating newline before the emission engine runs, so by the time an emit
; diagnostic raises, the current buffer already holds the *following* line.
; Keeping the previous line lets those diagnostics still show their source.
; The buffers are swapped by flipping this selector, never copied.
CASM_DIAG_SEL_A = $00
CASM_DIAG_SEL_B = $01

; Line numbers are 1-based, so zero is a natural "no previous line" marker
; that can never match a real diagnostic location.
CASM_DIAG_LINE_NONE = $0000

; CasmDiagLocValid tri-state. BYTE additionally reports the offending byte's
; hex value, which a plain VALID location does not carry. A separate state
; rather than a separate flag byte, because $00 is itself a legal source byte
; and cannot double as "no byte recorded".
CASM_DIAG_LOC_INVALID = $00
CASM_DIAG_LOC_VALID   = $01
CASM_DIAG_LOC_BYTE    = $02

.assert CASM_DIAG_LINE_BUF_SIZE = 256, error, "CASM diagnostic line buffer changed"
.assert CASM_DIAG_LINE_MAX = 255, error, "CASM diagnostic line payload changed"
.assert CASM_DIAG_WINDOW_WIDTH + CASM_DIAG_INDENT <= 40, error, "CASM diagnostic window exceeds the 40-column screen"
.assert CASM_DIAG_LINE_BUF_SIZE = CASM_IO_BUFFER_SIZE, error, "CASM diagnostic line buffer must match the source line bound"

; ---------------------------------------------------------------------------
; Phase 5 expression result ABI
; ---------------------------------------------------------------------------

CASM_EXPR_VAL_LO        = 0
CASM_EXPR_VAL_HI        = 1
CASM_EXPR_FLAGS         = 2
CASM_EXPR_EXTRACTION    = 3
CASM_EXPR_SYMBOL_ID_LO  = 4
CASM_EXPR_SYMBOL_ID_HI  = 5
CASM_EXPR_ADDEND_SIGN   = 6
CASM_EXPR_ADDEND_MAG_LO = 7
CASM_EXPR_ADDEND_MAG_HI = 8
CASM_EXPR_REC_SIZE      = 9

CASM_EXPR_FLAG_RESOLVED       = %00000001
CASM_EXPR_FLAG_SYMBOL_DERIVED = %00000010
CASM_EXPR_FLAG_RELOCATABLE    = %00000100
CASM_EXPR_FLAG_FORCE_ABS      = %00001000
CASM_EXPR_FLAG_MASK           = %00001111

CASM_EXTRACTION_FULL  = 0
CASM_EXTRACTION_LO    = 1
CASM_EXTRACTION_HI    = 2
CASM_EXTRACTION_COUNT = 3

CASM_ADDEND_SIGN_POSITIVE = 0
CASM_ADDEND_SIGN_NEGATIVE = 1
CASM_ADDEND_SIGN_COUNT    = 2

; Resolver callback output view. exprEvaluate passes its address in X/Y while
; the current token is IDENTIFIER; the callback fills it before returning C
; clear. Value bytes are meaningful only when RESOLVED is set.
CASM_RESOLVE_FLAGS     = 0
CASM_RESOLVE_ID_LO     = 1
CASM_RESOLVE_ID_HI     = 2
CASM_RESOLVE_VAL_LO    = 3
CASM_RESOLVE_VAL_HI    = 4
; WP65: the matched symbol's own CASM_SYMBOL_REC_FLAGS byte (DEFINED/
; CONSTANT/RESOLVED/LABEL_DERIVED), distinct from CASM_RESOLVE_FLAGS above
; (which carries the CASM_EXPR_FLAG_* resolution-outcome bits, not the
; symbol's own kind). Meaningful only when CASM_RESOLVE_FLAGS' RESOLVED bit
; is set; zero on a not-found outcome. Lets a caller (expr.s) distinguish a
; constant from a label without a second lookup.
CASM_RESOLVE_SYM_FLAGS = 5
CASM_RESOLVE_SIZE      = 6
CASM_RESOLVE_FLAG_MASK = CASM_EXPR_FLAG_RESOLVED | CASM_EXPR_FLAG_RELOCATABLE

.assert CASM_EXPR_VAL_HI = CASM_EXPR_VAL_LO + 1, error, "CASM expression value offsets changed"
.assert CASM_EXPR_FLAGS = CASM_EXPR_VAL_HI + 1, error, "CASM expression flags offset changed"
.assert CASM_EXPR_EXTRACTION = CASM_EXPR_FLAGS + 1, error, "CASM expression extraction offset changed"
.assert CASM_EXPR_SYMBOL_ID_LO = CASM_EXPR_EXTRACTION + 1, error, "CASM expression symbol offset changed"
.assert CASM_EXPR_SYMBOL_ID_HI = CASM_EXPR_SYMBOL_ID_LO + 1, error, "CASM expression symbol offsets changed"
.assert CASM_EXPR_ADDEND_SIGN = CASM_EXPR_SYMBOL_ID_HI + 1, error, "CASM expression addend offset changed"
.assert CASM_EXPR_ADDEND_MAG_LO = CASM_EXPR_ADDEND_SIGN + 1, error, "CASM expression addend magnitude offset changed"
.assert CASM_EXPR_ADDEND_MAG_HI = CASM_EXPR_ADDEND_MAG_LO + 1, error, "CASM expression addend magnitude offsets changed"
.assert CASM_EXPR_REC_SIZE = CASM_EXPR_ADDEND_MAG_HI + 1, error, "CASM expression record size changed"

.assert (CASM_EXPR_FLAG_RESOLVED & (CASM_EXPR_FLAG_RESOLVED - 1)) = 0, error, "resolved flag must be one bit"
.assert (CASM_EXPR_FLAG_SYMBOL_DERIVED & (CASM_EXPR_FLAG_SYMBOL_DERIVED - 1)) = 0, error, "symbol-derived flag must be one bit"
.assert (CASM_EXPR_FLAG_RELOCATABLE & (CASM_EXPR_FLAG_RELOCATABLE - 1)) = 0, error, "relocatable flag must be one bit"
.assert (CASM_EXPR_FLAG_FORCE_ABS & (CASM_EXPR_FLAG_FORCE_ABS - 1)) = 0, error, "force-absolute flag must be one bit"
.assert (CASM_EXPR_FLAG_RESOLVED | CASM_EXPR_FLAG_SYMBOL_DERIVED | CASM_EXPR_FLAG_RELOCATABLE | CASM_EXPR_FLAG_FORCE_ABS) = CASM_EXPR_FLAG_MASK, error, "CASM expression flag mask changed"
.assert CASM_EXTRACTION_COUNT = CASM_EXTRACTION_HI + 1, error, "CASM extraction range changed"
.assert CASM_ADDEND_SIGN_COUNT = CASM_ADDEND_SIGN_NEGATIVE + 1, error, "CASM addend sign range changed"
.assert CASM_RESOLVE_ID_LO = CASM_RESOLVE_FLAGS + 1, error, "CASM resolver identity offset changed"
.assert CASM_RESOLVE_ID_HI = CASM_RESOLVE_ID_LO + 1, error, "CASM resolver identity offsets changed"
.assert CASM_RESOLVE_VAL_LO = CASM_RESOLVE_ID_HI + 1, error, "CASM resolver value offset changed"
.assert CASM_RESOLVE_VAL_HI = CASM_RESOLVE_VAL_LO + 1, error, "CASM resolver value offsets changed"
.assert CASM_RESOLVE_SYM_FLAGS = CASM_RESOLVE_VAL_HI + 1, error, "CASM resolver symbol-flags offset changed"
.assert CASM_RESOLVE_SIZE = CASM_RESOLVE_SYM_FLAGS + 1, error, "CASM resolver output size changed"
.assert CASM_RESOLVE_FLAG_MASK = %00000101, error, "CASM resolver flag mask changed"

; ---------------------------------------------------------------------------
; Phase 6B symbol table contract (WP27), amending WP26's Phase 0C.5 freeze
; ---------------------------------------------------------------------------

; VMM-backed symbol record. Meaningful fields keep the exact offsets WP26
; froze; WP27 pads the record from 37 to 64 bytes (a power of two) so it
; fits CASM_VMM_BUFFER_SIZE exactly in one transfer and so record-index-to-
; VMM-offset arithmetic is a single 16-bit left-shift-by-6 rather than a
; multiply by 37. Bytes 37-63 are reserved padding, zero-filled on every
; write.
CASM_SYMBOL_REC_NAMELEN = 0    ; 1 byte, 1..31
CASM_SYMBOL_REC_NAME    = 1    ; 31-byte fixed slot
CASM_SYMBOL_REC_VAL_LO  = 32
CASM_SYMBOL_REC_VAL_HI  = 33
CASM_SYMBOL_REC_FLAGS   = 34   ; bit 0 = DEFINED; bit 1 = CONSTANT; bit 2 = RESOLVED; bit 3 = LABEL_DERIVED; remaining bits reserved
CASM_SYMBOL_REC_NEXT_LO = 35   ; collision-chain record index; $FFFF = end of chain
CASM_SYMBOL_REC_NEXT_HI = 36
CASM_SYMBOL_REC_SIZE    = 64

CASM_SYMBOL_FLAG_DEFINED       = %00000001
CASM_SYMBOL_FLAG_CONSTANT      = %00000010
CASM_SYMBOL_FLAG_RESOLVED      = %00000100
; Meaningful only for a resolved CONSTANT: set when its defining reference
; chain bottoms out at a label (directly or through other constants), never
; for a bare-numeric constant. Mode-independent (a structural fact about the
; definition, not about the current assembly run) -- expr.s combines this
; with CasmExprRelocatableModeIn the same way it already does for a label,
; rather than blindly applying the mode flag to every resolved identifier
; the way today's label-only code does. See WP65's Increment 8.
CASM_SYMBOL_FLAG_LABEL_DERIVED = %00001000

; ---------------------------------------------------------------------------
; Phase 12 WP65 symbol record extension (deferred-constant reference bookmark)
; ---------------------------------------------------------------------------
;
; A constant defined as `identifier = expr` where expr's operand is itself
; an IDENTIFIER (not a bare NUMBER) may forward-reference a symbol not yet
; inserted (another constant defined later, or a label whose address isn't
; final until Pass 1 completes). Rather than copy the referenced name (up to
; 31 bytes, too large for the remaining padding) or re-scan the whole source,
; the record stores a compact bookmark to the RHS identifier token's own
; source position: the resolution sweep (Pass1->Pass2 seam) re-reads just
; those few bytes to recover the name and look it up, by which point every
; label and constant name is already present in the table. A symbol with
; CASM_SYMBOL_FLAG_CONSTANT set and CASM_SYMBOL_FLAG_RESOLVED clear carries a
; valid REF_* bookmark; once resolved, VAL_LO/HI holds the final value and
; the REF_* fields are no longer consulted. See
; `brain/plans/2026-08-13-casm-phase12-wp65-named-constants.md`.
CASM_SYMBOL_REC_REF_VMM_LO    = 37  ; RHS identifier token's VMM source offset, low byte
CASM_SYMBOL_REC_REF_VMM_HI    = 38  ; RHS identifier token's VMM source offset, high byte
CASM_SYMBOL_REC_REF_LEN       = 39  ; RHS identifier length, 1..31
CASM_SYMBOL_REC_REF_ADDEND_LO = 40  ; static addend magnitude, low byte
CASM_SYMBOL_REC_REF_ADDEND_HI = 41  ; static addend magnitude, high byte
CASM_SYMBOL_REC_REF_SIGN      = 42  ; 0 = '+' addend, 1 = '-' addend
CASM_SYMBOL_REC_REF_EXTRACT   = 43  ; CASM_EXTRACTION_FULL/LO/HI, applied to the resolved value

; Bounded capacity: 512 records x 64 bytes = 32768 bytes, one vmmStoreAlloc
; call, well under CASM_VMM_ALLOC_MAX_BYTES. 128 hash buckets (a power of
; two, masked with $7F -- no division needed).
CASM_SYMBOL_MAX          = 512
CASM_SYMBOL_BUCKET_COUNT = 128
CASM_SYMBOL_BUCKET_MASK  = $7F
CASM_SYMBOL_CHAIN_END    = $FFFF

; WP65: deepest constant-reference chain (a = b = c = ...) the Pass1->Pass2
; resolution sweep (casm.s's casmResolveConstants) will walk before treating
; it as CASM_DIAG_EXPR_CIRCULAR -- a bounded backstop, same precedent as
; CASM_INCLUDE_MAX_DEPTH, chosen because the sweep's cycle-detection bitmap
; alone catches a true cycle at any depth, but the chain-array it also
; builds (to unwind addends from the resolved base back out to the start)
; needs a fixed capacity.
CASM_CONST_CHAIN_MAX = 32

; WP67: deepest parenthesized-sub-expression nesting exprEvaluate's
; evalExpr will recurse before treating it as CASM_DIAG_EXPR_PAREN_TOO_DEEP.
; Each nesting level costs one JSR plus a save/restore of the full 9-byte
; CasmExprResultRecord (CasmExprParenSaveStack, expr.s) against the 6502's
; small hardware stack, shared with every other nested call in the whole
; assembler (parser/lexer/source/VMM) -- bounded explicitly rather than
; trusting caller-supplied nesting to stay small, same precedent as
; CASM_CONST_CHAIN_MAX/CASM_INCLUDE_MAX_DEPTH.
CASM_EXPR_PAREN_MAX_DEPTH = 8

.assert CASM_SYMBOL_REC_NAME = CASM_SYMBOL_REC_NAMELEN + 1, error, "CASM symbol record name offset changed"
.assert CASM_SYMBOL_REC_VAL_LO = CASM_SYMBOL_REC_NAME + 31, error, "CASM symbol record value offset changed"
.assert CASM_SYMBOL_REC_VAL_HI = CASM_SYMBOL_REC_VAL_LO + 1, error, "CASM symbol record value offsets changed"
.assert CASM_SYMBOL_REC_FLAGS = CASM_SYMBOL_REC_VAL_HI + 1, error, "CASM symbol record flags offset changed"
.assert CASM_SYMBOL_REC_NEXT_LO = CASM_SYMBOL_REC_FLAGS + 1, error, "CASM symbol record next offset changed"
.assert CASM_SYMBOL_REC_NEXT_HI = CASM_SYMBOL_REC_NEXT_LO + 1, error, "CASM symbol record next offsets changed"
.assert CASM_SYMBOL_REC_REF_VMM_LO = CASM_SYMBOL_REC_NEXT_HI + 1, error, "CASM symbol record ref-VMM offset changed"
.assert CASM_SYMBOL_REC_REF_VMM_HI = CASM_SYMBOL_REC_REF_VMM_LO + 1, error, "CASM symbol record ref-VMM offsets changed"
.assert CASM_SYMBOL_REC_REF_LEN = CASM_SYMBOL_REC_REF_VMM_HI + 1, error, "CASM symbol record ref-len offset changed"
.assert CASM_SYMBOL_REC_REF_ADDEND_LO = CASM_SYMBOL_REC_REF_LEN + 1, error, "CASM symbol record ref-addend offset changed"
.assert CASM_SYMBOL_REC_REF_ADDEND_HI = CASM_SYMBOL_REC_REF_ADDEND_LO + 1, error, "CASM symbol record ref-addend offsets changed"
.assert CASM_SYMBOL_REC_REF_SIGN = CASM_SYMBOL_REC_REF_ADDEND_HI + 1, error, "CASM symbol record ref-sign offset changed"
.assert CASM_SYMBOL_REC_REF_EXTRACT = CASM_SYMBOL_REC_REF_SIGN + 1, error, "CASM symbol record ref-extract offset changed"
.assert CASM_SYMBOL_REC_REF_EXTRACT < CASM_SYMBOL_REC_SIZE, error, "CASM symbol record ref bookmark overflows record"
.assert CASM_SYMBOL_REC_SIZE = 64, error, "CASM symbol record size changed"
.assert CASM_SYMBOL_REC_SIZE = CASM_VMM_BUFFER_SIZE, error, "CASM symbol record must fit one VMM transfer exactly"
.assert CASM_SYMBOL_BUCKET_COUNT = CASM_SYMBOL_BUCKET_MASK + 1, error, "CASM symbol bucket count/mask mismatch"
.assert CASM_SYMBOL_MAX * CASM_SYMBOL_REC_SIZE <= CASM_VMM_ALLOC_MAX_BYTES, error, "CASM symbol table exceeds one VMM allocation"

; ---------------------------------------------------------------------------
; Phase 6B two-pass contract (WP28)
; ---------------------------------------------------------------------------

; Single pass-mode flag, gated at exactly one point (the top of emitRawByte,
; emit.s). MEASURE never writes output bytes; EMIT behaves as every prior
; phase's single-pass emission always has.
CASM_PASS_MODE_MEASURE = $00
CASM_PASS_MODE_EMIT    = $01

; ---------------------------------------------------------------------------
; Phase 7 WP33 VMM-backed source load contract
; ---------------------------------------------------------------------------

; True single vmmStoreAlloc request ceiling (Phase 0C.10/0C.11): 65536 cannot
; be represented in a 16-bit X/Y byte count -- it wraps to $0000,
; indistinguishable from an explicit zero-size rejection. sourceLoad requests
; exactly this many bytes; the allocation internally rounds up to a full
; 16-page/65536-byte grant, matching every other VMM consumer's rounding.
CASM_SOURCE_VMM_MAX_BYTES = 65535

.assert CASM_SOURCE_VMM_MAX_BYTES = 65535, error, "CASM source VMM allocation cap changed"

; ---------------------------------------------------------------------------
; Phase 7 WP34 multi-file CLI contract
; ---------------------------------------------------------------------------

; Maximum ordered top-level source filenames CASM accepts on one command
; line (Phase 0C.10/0C.12), matching this codebase's existing bounded-
; capacity convention (CASM_FILE_CAPACITY = CASM_VMM_CAPACITY = 8).
CASM_SOURCE_COUNT_MAX = 8

.assert CASM_SOURCE_COUNT_MAX = 8, error, "CASM source count cap changed"

; ---------------------------------------------------------------------------
; Phase and cleanup state
; ---------------------------------------------------------------------------

CASM_PHASE_SCAFFOLD = $01
CASM_PHASE_CLI_FILE = $02
CASM_PHASE_SOURCE_LEXER = $03

CASM_CLEANUP_IDLE   = $00
CASM_CLEANUP_ACTIVE = $01

; Phase 1 initial ld65 MAIN envelope. CMake consumes the hexadecimal string
; "1000"; this numeric mirror supports later size assertions and docs.
CASM_PHASE1_MAIN_SIZE = $1000
.assert CASM_PHASE1_MAIN_SIZE = $1000, error, "CASM MAIN envelope changed"

; ---------------------------------------------------------------------------
; Phase 10 WP51: listing metadata record and byte-mirror capture
; ---------------------------------------------------------------------------

; One fixed 16-byte metadata record per captured physical source line,
; WP50-frozen offsets (parent plan's "Metadata ABI"; WP50 plan's "Metadata
; ABI" section). 4,096 records x 16 bytes = 65,536 bytes = exactly one
; CASM_VMM_ALLOC_MAX_BYTES allocation.
CASM_LISTING_META_FILEID       = 0   ; 1 byte: packed physical file identity
CASM_LISTING_META_FLAGS        = 1   ; 1 byte: bit 0 = FINAL_UNTERMINATED, rest reserved zero
CASM_LISTING_META_LINE_LO      = 2
CASM_LISTING_META_LINE_HI      = 3   ; one-based physical line number
CASM_LISTING_META_OFF_LO       = 4
CASM_LISTING_META_OFF_HI       = 5   ; absolute source VMM offset, first payload byte
CASM_LISTING_META_LEN          = 6   ; source payload length, 0-255
CASM_LISTING_META_RESERVED0    = 7   ; zero-filled
CASM_LISTING_META_PC_LO        = 8
CASM_LISTING_META_PC_HI        = 9   ; starting PC before the line's dispatch
CASM_LISTING_META_BYTEOFF_LO   = 10
CASM_LISTING_META_BYTEOFF_HI   = 11  ; first mirrored byte-mirror offset for the line
CASM_LISTING_META_BYTECOUNT_LO = 12
CASM_LISTING_META_BYTECOUNT_HI = 13  ; emitted-byte count attributed to the line
CASM_LISTING_META_RESERVED1    = 14  ; 2 bytes, zero-filled
CASM_LISTING_META_REC_SIZE     = 16

CASM_LISTING_META_FLAG_FINAL_UNTERMINATED = %00000001

; Bounded capacity: 4,096 physical-line occurrences, one vmmStoreAlloc call.
CASM_LISTING_META_MAX = 4096

; Dedicated byte-mirror flush stage. Deliberately distinct from the shared
; CasmVmmBuffer (symbols.s/source.s/reloc.s/include.s all stage through that
; buffer already; a second concurrent user would silently corrupt whichever
; transfer is in flight), but sized to match it exactly so one flush is
; exactly one VMM window transfer.
CASM_LISTING_STAGE_SIZE = 64

; Completed-line sidecar flags (WP50's "Completed-Line Sidecar" freeze),
; owned by source.s and read by listing.s after sourceTakeCompletedLine.
; Bits 3-6 stay reserved/always-zero in every value sourceTakeCompletedLine
; returns to a caller. Bit 7 (CASM_SOURCE_CAPTURE_ENABLED, below) shares this
; same byte purely as source.s's own private persistent enable/disable
; storage -- WP50 authorized exactly 11 new source BSS bytes, with none held
; back for an enable flag, so sourceSetLineCapture packs it into this
; existing byte's otherwise-reserved space instead of adding a 12th byte.
; sourceTakeCompletedLine always masks bit 7 out of its returned value, so
; no caller outside source.s ever observes it; the documented "bits 3-7
; reserved, always zero" contract holds from every caller's perspective.
CASM_SOURCE_COMPLETED_FLAG_VALID              = %00000001
CASM_SOURCE_COMPLETED_FLAG_SYNTHETIC_ONLY     = %00000010
CASM_SOURCE_COMPLETED_FLAG_FINAL_UNTERMINATED = %00000100
CASM_SOURCE_CAPTURE_ENABLED                   = %10000000

.assert CASM_LISTING_META_FLAGS = CASM_LISTING_META_FILEID + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_LINE_LO = CASM_LISTING_META_FLAGS + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_LINE_HI = CASM_LISTING_META_LINE_LO + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_OFF_LO = CASM_LISTING_META_LINE_HI + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_OFF_HI = CASM_LISTING_META_OFF_LO + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_LEN = CASM_LISTING_META_OFF_HI + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_RESERVED0 = CASM_LISTING_META_LEN + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_PC_LO = CASM_LISTING_META_RESERVED0 + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_PC_HI = CASM_LISTING_META_PC_LO + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_BYTEOFF_LO = CASM_LISTING_META_PC_HI + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_BYTEOFF_HI = CASM_LISTING_META_BYTEOFF_LO + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_BYTECOUNT_LO = CASM_LISTING_META_BYTEOFF_HI + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_BYTECOUNT_HI = CASM_LISTING_META_BYTECOUNT_LO + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_RESERVED1 = CASM_LISTING_META_BYTECOUNT_HI + 1, error, "CASM listing metadata offset changed"
.assert CASM_LISTING_META_REC_SIZE = 16, error, "CASM listing metadata record size changed"
.assert CASM_LISTING_META_REC_SIZE = CASM_LISTING_META_RESERVED1 + 2, error, "CASM listing metadata record size mismatch"
.assert CASM_LISTING_META_MAX * CASM_LISTING_META_REC_SIZE = CASM_VMM_ALLOC_MAX_BYTES, error, "CASM listing metadata store must be exactly one VMM allocation"
.assert CASM_LISTING_STAGE_SIZE = CASM_VMM_BUFFER_SIZE, error, "CASM listing byte-mirror stage must match one VMM transfer"

; listing.s capture lifecycle state (WP51).
CASM_LISTING_STATE_NONE     = $00  ; listingStateInit only; no VMM acquired
CASM_LISTING_STATE_ENABLED  = $01  ; listingCaptureInit succeeded; capturing
CASM_LISTING_STATE_COMPLETE = $02  ; listingCaptureFinalize succeeded

; WP53 increment 4: the `.LST` file's own I/O lifecycle -- deliberately
; distinct from CASM_LISTING_STATE_* above (WP51's in-memory capture
; transaction state; unrelated concept, same "listing" word). Reuses
; CASM_FILE_STATE_* (fileio.s) for open/closed/close-failed exactly as PRG
; output already does; these four are the parts PRG output does not need.
CASM_LISTFILE_NOT_OPENED = $00
CASM_LISTFILE_OPENED     = $01
CASM_LISTFILE_INVALID    = $00
CASM_LISTFILE_VALID      = $01
CASM_LISTFILE_NOT_COMMITTED    = $00
CASM_LISTFILE_COMMITTED        = $01
CASM_LISTFILE_DELETE_NOT_PENDING = $00
CASM_LISTFILE_DELETE_PENDING     = $01

; CasmListingName (cli.s) is bounded by CASM_FILENAME_BUFFER_SIZE (64,
; CASM_FILENAME_MAX + 1). The real DOS_OPEN_FILE name embeds "@0:" (3 bytes)
; immediately after any device-prefix colon, or prepended if none exists, so
; the open-name buffer needs room for the longest possible CasmListingName
; plus those 3 bytes plus its own terminating null: 63 + 3 + 1 = 67. $44 (68)
; is the next round value at or above that.
CASM_LISTING_OPEN_NAME_SIZE = $44
.assert CASM_LISTING_OPEN_NAME_SIZE >= CASM_FILENAME_MAX + 3 + 1, error, "CASM listing open-name buffer too small for CasmListingName plus the embedded @0: marker"

; WP53 increment 5: listingResolveFilename's output buffer. An included
; header's longest possible form is a 2-digit device ("10"/"11") + colon +
; the longest catalog name (CASM_INCLUDE_FILENAME_MAX) + null: 2 + 1 + 63 +
; 1 = 67. A top-level header's longest form is CASM_FILENAME_BUFFER_SIZE
; (64). $44 (68) covers both with the same round value CASM_LISTING_OPEN_
; NAME_SIZE already uses.
CASM_LISTING_RESOLVED_NAME_SIZE = $44
.assert CASM_LISTING_RESOLVED_NAME_SIZE >= 2 + 1 + CASM_INCLUDE_FILENAME_MAX + 1, error, "CASM listing resolved-name buffer too small for an included header"
.assert CASM_LISTING_RESOLVED_NAME_SIZE >= CASM_FILENAME_BUFFER_SIZE, error, "CASM listing resolved-name buffer too small for a top-level header"

; WP53 increment 6: frozen row/column layout (parent plan's "Listing
; Content" -- File Headers/Detail Rows/Continuations sections). Every row
; is exactly CASM_LISTING_ROW_WIDTH bytes of content plus one trailing
; PETSCII CR; the CR is never counted in any column width below.
CASM_LISTING_ROW_WIDTH        = 40
CASM_LISTING_ROW_SIZE         = 41  ; CASM_LISTING_ROW_WIDTH + 1 (CR)

; File header: "FILE HH: " occupies columns 1-9 on the first row of a
; transition (blank on continuation rows); up to this many filename bytes
; follow in columns 10-40 on every header row, first or continuation.
CASM_LISTING_HEADER_PREFIX_WIDTH = 9
CASM_LISTING_HEADER_CHUNK_SIZE   = 31
.assert CASM_LISTING_HEADER_PREFIX_WIDTH + CASM_LISTING_HEADER_CHUNK_SIZE = CASM_LISTING_ROW_WIDTH, error, "CASM listing header prefix+chunk must fill the row exactly"

; Detail row: columns 1-8 (identity+colon+5-digit line+space), blank on a
; byte-continuation or source-continuation row.
CASM_LISTING_ROW_HEAD_WIDTH   = 8
; Columns 9-13 (space+4-digit hex PC), blank on a source-continuation row.
CASM_LISTING_ROW_ADDR_WIDTH   = 5
; Columns 14-25 (space+"HH HH HH HH"), blank on a source-continuation row.
CASM_LISTING_ROW_BYTES_WIDTH  = 12
CASM_LISTING_ROW_BYTES_MAX    = 4   ; emitted bytes shown per row
; Column 26 (space), always present before the source column.
CASM_LISTING_ROW_GAP_WIDTH    = 1
; Columns 27-40: up to this many exact source bytes, blank on a
; byte-continuation row.
CASM_LISTING_ROW_SOURCE_MAX   = 14
.assert CASM_LISTING_ROW_HEAD_WIDTH + CASM_LISTING_ROW_ADDR_WIDTH + CASM_LISTING_ROW_BYTES_WIDTH + CASM_LISTING_ROW_GAP_WIDTH + CASM_LISTING_ROW_SOURCE_MAX = CASM_LISTING_ROW_WIDTH, error, "CASM listing detail row columns must fill the row exactly"

.endif
