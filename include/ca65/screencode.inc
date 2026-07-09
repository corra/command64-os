; include/ca65/screencode.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; ca65 equivalent of Kick Assembler's "screencode_mixed" / "petscii_mixed"
; .encoding toggle idiom, used to write text destined for screen memory
; (which uses C64 screen codes, not PETSCII byte values). Kick's
; screencode_mixed is documented as "the screencode representation of
; petscii_mixed" (brain/kickassembler/KickAssembler.md:729) — a built-in
; encoding, not project-custom.
;
; Usage, mirroring the Kick call sites 1:1
; (src/external/conway/conway.asm:711/715, src/external/pacman/pacman.asm):
;
;   screencode_mixed
;   statusText: .byte "space=pause  r=random  c=clear  q=quit"
;   statusTextEnd:
;   petscii_mixed
;
; Coverage: this table only maps the character set actually used in the
; codebase's existing screencode-toggled strings today (verified by
; grepping every "screencode_mixed" block in conway.asm and pacman.asm) —
; lowercase letters and the $20-$3F punctuation/digit range. Uppercase
; ASCII source characters are NOT mapped here (no current call site needs
; them) — ca65's .CHARMAP leaves unmapped characters untranslated, which
; would silently emit the wrong byte, so don't use uppercase letters inside
; a screencode_mixed block until this table is extended and verified
; against a real screen-memory readback.

.MACRO screencode_mixed
        .PUSHCHARMAP
        ; $20-$3F ("space" through "?": digits, most punctuation) map
        ; unchanged — verified against spike/ca65-conway/conway_grid.s's
        ; hand-derived bytes for " ", "=", etc.
        .REPEAT $20, I
                .CHARMAP $20 + I, $20 + I
        .ENDREPEAT
        ; lowercase 'a'-'z' ($61-$7A) map to screencodes $01-$1A — verified
        ; against the same hand-derived reference bytes (e.g. 's' -> $13).
        .REPEAT 26, I
                .CHARMAP $61 + I, $01 + I
        .ENDREPEAT
.ENDMACRO

.MACRO petscii_mixed
        .POPCHARMAP
.ENDMACRO
