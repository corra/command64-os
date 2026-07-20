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
.export CasmDiagLineBufA
.export CasmDiagLineBufB
.export CasmDiagLineSel
.export CasmDiagLineLen
.export CasmDiagLineClipped
.export CasmDiagLineNoLo
.export CasmDiagLineNoHi
.export CasmDiagPrevLen
.export CasmDiagPrevClipped
.export CasmDiagPrevNoLo
.export CasmDiagPrevNoHi
.export CasmDiagCapture
.export CasmDiagLocValid
.export CasmDiagLocLineLo
.export CasmDiagLocLineHi
.export CasmDiagLocColumn
.export CasmDiagLocByte
.export CasmStmtLocLineLo
.export CasmStmtLocLineHi
.export CasmStmtLocColumn

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

; ---------------------------------------------------------------------------
; WP15 diagnostic source context state
;
; Deliberately outside the CasmPhase3State span above, whose exact-size
; asserts are a documented contract. This is diagnostic state, not source or
; lexer state: no traversal or tokenization decision may read it.
;
; The echo buffers record source lines as they are consumed, because BYTE-mode
; traversal leaves no other record of them (see the WP15 contract in
; common.inc).
;
; Two buffers are kept. The parser consumes a statement's terminating newline
; before the emission engine runs, so an emit diagnostic raises when the
; current buffer already holds the following line; without the previous line,
; every emit diagnostic would lose its caret. CasmDiagLineSel says which buffer
; is current, and a newline swaps roles by flipping it rather than copying 256
; bytes.
;
; The Clipped flags latch when a line exceeds its buffer, so the renderer
; reports truncation rather than showing a silently short line.
; ---------------------------------------------------------------------------
CasmDiagStateStart:
CasmDiagLineBufA:
    .res CASM_DIAG_LINE_BUF_SIZE
CasmDiagLineBufB:
    .res CASM_DIAG_LINE_BUF_SIZE
CasmDiagLineSel:     .res 1
CasmDiagLineLen:     .res 1
CasmDiagLineClipped: .res 1
CasmDiagCapture:     .res 1

; Line number each buffer holds. The renderer matches the diagnostic's own line
; against these and suppresses the text and caret when neither matches. Without
; that guard a diagnostic would print a caret into whatever line happened to be
; buffered, confidently pointing at the wrong source.
CasmDiagLineNoLo: .res 1
CasmDiagLineNoHi: .res 1

; The previous line: its length, truncation flag, and number. It lives in
; whichever buffer CasmDiagLineSel does not currently select.
CasmDiagPrevLen:     .res 1
CasmDiagPrevClipped: .res 1
CasmDiagPrevNoLo:    .res 1
CasmDiagPrevNoHi:    .res 1

; Location attached to a source-position diagnostic. CasmDiagLocValid gates
; every consumer: an unset location must never attach to an unrelated
; diagnostic, and must never trigger the terminal line-tail drain.
CasmDiagLocValid:  .res 1
CasmDiagLocLineLo: .res 1
CasmDiagLocLineHi: .res 1
CasmDiagLocColumn: .res 1
CasmDiagLocByte:   .res 1

; Statement-start location, stamped by parserParseStatement. The emission
; engine raises diagnostics after the statement's tokens are consumed, so the
; token record no longer points at the statement. Kept separate rather than
; grown into CasmParserStmt, whose 6-byte size is an asserted shared ABI.
CasmStmtLocLineLo: .res 1
CasmStmtLocLineHi: .res 1
CasmStmtLocColumn: .res 1
CasmDiagStateEnd:

.assert CasmDiagLineBufB - CasmDiagLineBufA = CASM_DIAG_LINE_BUF_SIZE, error, "CASM diagnostic line buffer A size changed"
.assert CasmDiagLineSel - CasmDiagLineBufB = CASM_DIAG_LINE_BUF_SIZE, error, "CASM diagnostic line buffer B size changed"
.assert CasmDiagStateEnd - CasmDiagStateStart = 530, error, "CASM diagnostic state must be exactly 530 bytes"

.assert CasmTokenText - CasmTokenRecord = CASM_TOKEN_REC_TEXT, error, "CASM token text offset does not match shared ABI"
.assert CasmTokenRecordEnd - CasmTokenRecord = CASM_TOKEN_REC_SIZE, error, "CASM token record must be exactly 39 bytes"
.assert CasmLexerStateEnd - CasmLexerStateStart = 47, error, "CASM lexer state must be exactly 47 bytes"
.assert CasmPhase3StateEnd - CasmPhase3StateStart = 63, error, "CASM Phase 3 state must be exactly 63 bytes"
