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

; VMM record: occupancy flag followed by the DOS_ALLOC_MEM identity returned
; in X (segment high byte) and Y (REU bank).
CASM_VMM_REC_FLAG  = 0
CASM_VMM_REC_SEGHI = 1
CASM_VMM_REC_BANK  = 2
CASM_VMM_REC_SIZE  = 3

CASM_FILE_REGISTRY_BYTES = CASM_FILE_CAPACITY * CASM_FILE_REC_SIZE
CASM_VMM_REGISTRY_BYTES  = CASM_VMM_CAPACITY * CASM_VMM_REC_SIZE

.assert CASM_FILE_CAPACITY = 8, error, "CASM file registry contract changed"
.assert CASM_VMM_CAPACITY = 8, error, "CASM VMM registry contract changed"

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
CASM_PETSCII_HASH  = $23
CASM_PETSCII_PERCENT = $25
CASM_PETSCII_LPAREN = $28
CASM_PETSCII_RPAREN = $29
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
CASM_PETSCII_GREATER = $3E
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

CASM_OPT_OUTPUT = %00000001
CASM_OPT_STATIC = %00000010
CASM_OPT_MAP    = %00000100
CASM_OPT_LIST   = %00001000
CASM_OPT_ALL    = CASM_OPT_OUTPUT | CASM_OPT_STATIC | CASM_OPT_MAP | CASM_OPT_LIST

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
CASM_TOKEN_COUNT      = $10

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

.assert CASM_SOURCE_LINE_PAYLOAD_MAX = 255, error, "CASM source line payload changed"
.assert CASM_SOURCE_STATE_COUNT = CASM_SOURCE_STATE_ERROR + 1, error, "CASM source state range changed"
.assert CASM_SOURCE_API_COUNT = CASM_SOURCE_API_LINE + 1, error, "CASM source API range changed"
.assert CASM_SOURCE_LINE_COUNT = CASM_SOURCE_LINE_EOF + 1, error, "CASM source line state range changed"
.assert CASM_LEXER_STATE_COUNT = CASM_LEXER_STATE_ERROR + 1, error, "CASM lexer state range changed"
.assert CASM_TOKEN_TEXT_BUFFER_SIZE = 32, error, "CASM token text buffer changed"
.assert CASM_TOKEN_COUNT = CASM_TOKEN_GREATER + 1, error, "CASM token type range changed"
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
CASM_DIAG_UNKNOWN        = $FF

.assert CASM_DIAG_PHASE2_LAST = $13, error, "CASM Phase 2 diagnostic range changed"
.assert CASM_DIAG_SOURCE_REWIND_FAILED = CASM_DIAG_PHASE2_LAST + 1, error, "CASM Phase 3 diagnostics must remain contiguous"
.assert CASM_DIAG_PHASE3_LAST = $1B, error, "CASM Phase 3 diagnostic range changed"

; Registration/release routines return carry clear on success. On failure,
; carry is set and A contains one of the CASM_DIAG_* identifiers above.

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

.endif
