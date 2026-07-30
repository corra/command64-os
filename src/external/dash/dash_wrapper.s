; dash_wrapper.s - ca65 reference-build wrapper.
;
; The seven DASH sources are written in the strict syntactic subset that BOTH
; ca65 and the native CASM assembler accept, so the same bytes on disk can be
; assembled either way and the outputs compared. That subset has no segment
; directives (CASM has no segment concept -- it emits one linear stream in
; command-line file order), so the single ".segment" this build needs lives
; here, in the ca65-only wrapper, and covers all seven includes at once.
;
; The include order below is authoritative and must match the CASM command
; line's source order exactly, or the two toolchains lay the program out
; differently and the byte comparison is meaningless.
.import __MAIN_START__
.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"
.include "dmain.s"
.include "dscr.s"
.include "dfmt.s"
.include "dsys.s"
.include "dapp.s"
.include "dvmm.s"
.include "ddata.s"
