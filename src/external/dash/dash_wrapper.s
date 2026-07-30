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
