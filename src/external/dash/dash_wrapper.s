; dash_wrapper.s - ca65 reference-build wrapper.
;
; The seven DASH sources are written in the strict syntactic subset that BOTH
; ca65 and the native CASM assembler accept, so the same bytes on disk can be
; assembled either way and the outputs compared. That subset has no segment
; directives (CASM has no segment concept -- it emits one linear stream in
; command-line file order), so the single ".segment" this build needs lives
; here, in the ca65-only wrapper.
;
; dmain.s is now the single entry point for both toolchains: it pulls in the
; other six sources itself via native CASM's .INCLUDE (operational since CASM
; WP47), in the authoritative order. This wrapper just includes dmain.s and
; lets its own .INCLUDE chain (upper-cased operands, resolved ca65-side via
; an extra -I directory of uppercase symlinks -- see CMakeLists.txt) do the
; rest, so the source order is specified in exactly one place instead of
; being hand-synced between this file and the CASM command line.
.import __MAIN_START__
.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"
.include "dmain.s"

; --- DASH-MOD WP3: STRUCTURAL INVARIANTS (ca65-only) ---
;
; CASM's expression grammar has no equality/comparison operator (only
; + - | ^ & << >> * /), so it cannot express these. They live here, in
; the ca65-only wrapper, and are checked on every dash_ref build. The
; CASM side is covered transitively: CASM's DASH.PRG is byte-compared
; against this ca65 build, so any constant that diverged would surface
; as a byte mismatch. A real CASM comparison operator is a separately
; planned future item; if it lands, these can move into dmain.s.
;
; .assert emits no bytes. A false condition aborts the link with `error`.

; ZP scratch map ($70-$8F) is contiguous with no gaps and no overlapping
; two-byte pairs -- the packing DASH's AGENTS.md documents by hand.
.assert CURRENTROW    = DISPATCHVECTOR + 2, error, "ZP: CURRENTROW"
.assert SCREENDESTPTR = CURRENTROW    + 1, error, "ZP: SCREENDESTPTR"
.assert STRINGSRCPTR  = SCREENDESTPTR + 2, error, "ZP: STRINGSRCPTR"
.assert CURRENTCOL    = STRINGSRCPTR  + 2, error, "ZP: CURRENTCOL"
.assert FMTWORK       = CURRENTCOL    + 1, error, "ZP: FMTWORK"
.assert DIV10REM      = FMTWORK       + 2, error, "ZP: DIV10REM"
.assert COLORPTR      = DIV10REM      + 1, error, "ZP: COLORPTR"
.assert CHARSTASH     = COLORPTR      + 2, error, "ZP: CHARSTASH"
.assert MAXLEN        = CHARSTASH     + 1, error, "ZP: MAXLEN"
.assert SRCIDX        = MAXLEN        + 1, error, "ZP: SRCIDX"
.assert DISPATCHVECTOR >= $70, error, "ZP: below scratch range"
.assert SRCIDX        <= $8F, error, "ZP: above scratch range"

; Page model.
.assert PAGECOUNT = 3, error, "PAGECOUNT != 3"
.assert (PAGEROUTINETABLE_END - PAGEROUTINETABLE) / 2 = PAGECOUNT, error, "PAGEROUTINETABLE size != PAGECOUNT"
.assert PAGE_SYS = 0, error, "PAGE_SYS"
.assert PAGE_VMM = PAGECOUNT - 1, error, "PAGE_VMM"

; DOS service-bus call codes sit in the $40-$5F OS API band.
.assert DOS_ALLOC_MEM    >= $40, error, "DOS_ALLOC_MEM band"
.assert DOS_GET_APP_INFO <= $5F, error, "DOS_GET_APP_INFO band"
