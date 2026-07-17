; src/external/casm/state.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Bounded persistent state shared by the Phase 3 source and lexer modules.
; This translation unit owns storage only: it emits no executable code, calls
; no OS service, and performs no initialization. WP4 and WP7 import and
; initialize their respective subrecords before exposing public APIs.

.include "common.inc"

.export CasmSourceApiMode
.export CasmSourceState
.export CasmSourceFileId
.export CasmSourceBlockLenLo
.export CasmSourceBlockLenHi
.export CasmSourceBlockIndexLo
.export CasmSourceBlockIndexHi
.export CasmSourceOffsetLo
.export CasmSourceOffsetHi
.export CasmSourceLineLo
.export CasmSourceLineHi
.export CasmSourceColumn
.export CasmSourcePendingCr
.export CasmSourceResultByte
.export CasmSourceLineLength
.export CasmSourceLineState
.export CasmLexerState
.export CasmLookaheadValid
.export CasmLookaheadResult
.export CasmLookaheadByte
.export CasmLookaheadFileId
.export CasmLookaheadLineLo
.export CasmLookaheadLineHi
.export CasmLookaheadColumn
.export CasmTokenRecord
.export CasmTokenText

.segment "BSS"

CasmPhase3StateStart:
CasmSourceStateStart:
CasmSourceApiMode:      .res 1
CasmSourceState:        .res 1
CasmSourceFileId:       .res 1
CasmSourceBlockLenLo:   .res 1
CasmSourceBlockLenHi:   .res 1
CasmSourceBlockIndexLo: .res 1
CasmSourceBlockIndexHi: .res 1
CasmSourceOffsetLo:     .res 1
CasmSourceOffsetHi:     .res 1
CasmSourceLineLo:       .res 1
CasmSourceLineHi:       .res 1
CasmSourceColumn:       .res 1
CasmSourcePendingCr:    .res 1
CasmSourceResultByte:   .res 1
CasmSourceLineLength:   .res 1
CasmSourceLineState:    .res 1
CasmSourceStateEnd:

.assert CasmSourceStateEnd - CasmSourceStateStart = 16, error, "CASM source state must be exactly 16 bytes"

CasmLexerStateStart:
CasmLexerState:      .res 1
CasmLookaheadValid:  .res 1
CasmLookaheadResult: .res 1
CasmLookaheadByte:   .res 1
CasmLookaheadFileId: .res 1
CasmLookaheadLineLo: .res 1
CasmLookaheadLineHi: .res 1
CasmLookaheadColumn: .res 1
CasmTokenRecord:
    .res CASM_TOKEN_REC_TEXT
CasmTokenText:
    .res CASM_TOKEN_TEXT_BUFFER_SIZE
CasmTokenRecordEnd:
CasmLexerStateEnd:
CasmPhase3StateEnd:

.assert CasmTokenText - CasmTokenRecord = CASM_TOKEN_REC_TEXT, error, "CASM token text offset does not match shared ABI"
.assert CasmTokenRecordEnd - CasmTokenRecord = CASM_TOKEN_REC_SIZE, error, "CASM token record must be exactly 39 bytes"
.assert CasmLexerStateEnd - CasmLexerStateStart = 47, error, "CASM lexer state must be exactly 47 bytes"
.assert CasmPhase3StateEnd - CasmPhase3StateStart = 63, error, "CASM Phase 3 state must be exactly 63 bytes"
