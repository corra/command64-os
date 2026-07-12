; include/ca65/command64.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; MS-DOS 4.0 to C64 Port Core Definitions
;
; ca65 port of include/command64.inc — equate-for-equate mirror, kept in
; sync by hand alongside the Kick original.
;
; Deliberate deltas from the Kick source (see
; brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md, Phase 2):
;   - The Kick file's "#import build_config.inc" / "UserProgEnd = $CFFF"
;     block is intentionally NOT ported here. That mechanism exists to pull
;     the per-target load address into scope for Kick; ld65 apps get their
;     load address from the .cfg file's MEMORY block instead, so the
;     equivalent is redundant and would need a matching generated .inc that
;     doesn't exist yet.
;   - OS_API below is a new named constant. Every Kick app dispatches to
;     the OS via a hardcoded "jsr $1000" at each call site (verified: no
;     named constant exists anywhere in the Kick include/ or src/ trees).
;     Naming it here is a deliberate small improvement, not a mirror.

; --- KERNAL Jump Table Addresses ---
; Always reference the jump table ($FF00+), never raw ROM body addresses.
KernalChROUT    = $FFD2 ; Output character to current channel
KernalGetIn     = $FFE4 ; Raw keyboard input (bypasses screen editor/quote mode)
KernalChRIN     = $FFCF ; Input character from current channel (screen editor)
KernalCLALL     = $FFE7 ; Close all I/O channels (was $E548, raw ROM addr, wrong)
KernalWarmStart = $E37B ; BASIC warm start (assumes ZP intact — NOT safe after shell)
KernalColdStart = $E394 ; BASIC cold start (full re-init of interpreter state)
KernalSETMSG    = $FF90 ; Set KERNAL messages
KernalSETLFS    = $FFBA ; Set logical, first, and second addresses
KernalSETNAM    = $FFBD ; Set file name
KernalLOAD      = $FFD5 ; Load or verify file
KernalSAVE      = $FFD8 ; Save memory range to file
KernalOPEN      = $FFC0 ; Open a logical file
KernalCLOSE     = $FFC3 ; Close a logical file
KernalREADST    = $FFB7 ; Read status byte
KernalStatus    = $90   ; KERNAL I/O status byte
KernalCHKIN     = $FFC6 ; Set input channel
KernalCHKOUT    = $FFC9 ; Set output channel
KernalCLRCHN    = $FFCC ; Clear I/O channels
KernalLISTEN    = $FFB1 ; Send LISTEN on the serial bus (ATN handshake only)
KernalUNLSN     = $FFAE ; Send UNLISTEN (releases the bus, no data phase)

; --- OS DOS-dispatch entry point ---
; Not present as a named constant in the Kick source (see file header) —
; every Kick app hardcodes "jsr $1000". Use "jsr OS_API" instead.
OS_API = $1000

; --- API Function Constants (DOS Standard Hex Codes) ---
DOS_PRINT_CHAR   = $02 ; Print character (PETSCII)
DOS_PRINT_STR    = $09 ; Print string (Null-terminated)
DOS_OPEN_FILE    = $3D ; Open file
DOS_CLOSE_FILE   = $3E ; Close file
DOS_READ_FILE    = $3F ; Read from file
DOS_WRITE_FILE   = $40 ; Write to file
DOS_DELETE_FILE  = $41 ; Delete file (UNLINK)
DOS_RENAME_FILE  = $56 ; Rename file
DOS_ALLOC_MEM    = $48 ; Allocate memory (VMM)
DOS_FREE_MEM     = $49 ; Free memory (VMM)
DOS_EXIT         = $4C ; Terminate program (Return to Shell)
DOS_PARSE_PREFIX = $57 ; Parse target device prefix from ZP pointer
DOS_SEND_COMMAND = $58 ; Send raw command-channel string, read drive response
DOS_VMM_READ     = $59 ; Block-read bytes from a DOS_ALLOC_MEM'd REU segment
DOS_VMM_WRITE    = $5A ; Block-write bytes to a DOS_ALLOC_MEM'd REU segment

; --- PETSCII Control Characters ---
PetCr   = $0D ; Carriage return
PetLl   = $0A ; Line feed
PetDel  = $14 ; DEL (INST/DEL key unshifted) — destructive backspace
PetVBar = $7C ; Vertical bar '|'
PetLeft = $9D ; Cursor left control code

; --- Zero Page: Pointer and Dispatch Scratch ---
; Using 100% safe area ($FB-$FE, $02) and non-critical FAC1 workspace ($61-$67).
; This avoids clobbering KERNAL I/O ($90-$FA) and BASIC pointers ($2B-$32).
PrintPtrLo = $FB ; petPrintString: pointer low byte
PrintPtrHi = $FC ; petPrintString: pointer high byte
NamePtrLo  = $FD ; Loader: pointer to filename in buffer
NamePtrHi  = $FE ; Loader: pointer to filename in buffer
CmpBase    = $02 ; cmdCompare: saved entry-base offset (user safe byte)

HandlerVecLo = $61 ; shellDispatch: resolved handler address low byte
HandlerVecHi = $62 ; shellDispatch: resolved handler address high byte
ParsePos     = $63 ; index into CommandBuffer past matched command name
TempLo       = $64 ; Utility scratch low byte
TempHi       = $65 ; Utility scratch high byte
HexValLo     = $66 ; parseHex: result low byte
HexValHi     = $67 ; parseHex: result high byte

; App-private zero page: $70-$8F is conventionally available for external
; app use, but nothing currently enforces non-collision between apps (both
; spike/ca65-conway/common.inc and spike/ca65-label/common.inc independently
; claim $70 today). Coordinate manually until a shared policy lands in
; src/external/AGENTS.md.

; --- I/O Buffers ---
; Relocating CommandBuffer to $033C (Cassette Buffer).
; This is 192 bytes of safe workspace if tape is not used.
; It avoids colliding with code segments at $1600.
; Workspace layout ($033C-$03FB):
;   $033C-$038B: CommandBuffer (80 bytes)
;   $038C:       CommandLen (1 byte)
;   $038D:       SpecificLoad (1 byte)
;   $038E-$039D: HandleTable (8 entries * 2 bytes = 16 bytes)
;                Entry: Byte 0 = Status (0=Free, 1=Open), Byte 1 = C64 LFN
CommandBuffer = $033C
CommandLen    = $038C
SpecificLoad  = $038D ; 0=use HexVal (Relocated), 1=use file header (Absolute)
HandleTable   = $038E
CurrentDevice = $039E ; Active C64 device (8, 9, 10, 11)
EnvSegmentLo  = $039F
EnvSegmentHi  = $03A0
EnvBank       = $03A1
MAX_HANDLES   = 8
SourceBuf     = $03A2 ; 40 bytes
DestBuf       = $03CA ; 40 bytes
FileScratch   = $1FA2 ; Filename scratch in VmmData: vmmInitialized($1FA0), vmmTempByte($1FA1), fileScratch($1FA2-$1FFB), SysDate*($1FFC-$1FFF)
SysDateYear     = $1FFC ; Offset from 1980 (e.g. 46 = 2026), range 0-255
SysDateMonth    = $1FFD ; Month index, range 1-12
SysDateDay      = $1FFE ; Day of month, range 1-31
SysDateLastHour = $1FFF ; Last-seen 24-hour decimal value (0-23); lazy midnight rollover detection

; --- CIA #1 TOD Clock Registers ---
CIA1_CRA    = $DC0E ; Control Register A: bit 7 = TOD input freq (0=60Hz/NTSC, 1=50Hz/PAL)
CIA1_CRB    = $DC0F ; Control Register B: bit 7 = TOD alarm/clock select (0=clock)
CIA1_TOD_HR    = $DC0B ; TOD Hours (BCD, bit 7 = PM); reading latches TOD registers
CIA1_TOD_MIN   = $DC0A ; TOD Minutes (BCD)
CIA1_TOD_SEC   = $DC09 ; TOD Seconds (BCD)
CIA1_TOD_10THS = $DC08 ; TOD Tenths of a second (BCD); reading unlatches, writing restarts clock
KernalVideoStd = $02A6 ; KERNAL video standard flag: 0 = NTSC, 1 = PAL

; --- App Table: Phase A Constants ---
APT_MAX_SLOTS    = 16   ; compile-time max entries
APT_ENTRY_SIZE   = 40   ; bytes per entry
APT_HEADER_SIZE  = 4    ; bytes for table header (MaxSlots, UsedSlots, reserved x2)
APT_OFF_FLAGS    = 0    ; entry field: Flags
APT_OFF_NAME     = 1    ; entry field: Name (16 bytes, PETSCII null-padded)
APT_OFF_ADDR     = 17   ; entry field: LoadAddr lo/hi
APT_OFF_SIZE     = 19   ; entry field: Size lo/hi (byte count)
APT_FLAG_USED    = $01  ; Bit 0: slot in use
APT_FLAG_RUNNING = $02  ; Bit 1: app currently executing
APT_FLAG_REU     = $04  ; Bit 2: REU-backed image (Phase C)
APT_FLAG_STACK   = $08  ; Bit 3: stack saved (Phase C)
; AptSegLo/Hi occupy first 2 bytes of cassette buffer free area ($03F2-$03FF)
AptSegLo = $03F2 ; persistent: APT VMM segment lo (0 = not yet allocated)
AptSegHi = $03F3 ; persistent: APT VMM segment hi

; Overlap-check scratch (aptRegister, aptCheckRange) — fills the remaining
; cassette buffer workspace bytes through $03FB.
AptTempLoadLo = $03F4 ; scanned slot's CurrLoadAddr lo
AptTempLoadHi = $03F5 ; scanned slot's CurrLoadAddr hi
AptTempSizeLo = $03F6 ; scanned slot's CurrSize lo
AptTempSizeHi = $03F7 ; scanned slot's CurrSize hi
AptTempEndLo  = $03F8 ; scanned slot's CurrEndAddr lo (CurrLoadAddr+CurrSize)
AptTempEndHi  = $03F9 ; scanned slot's CurrEndAddr hi
AptCandEndLo  = $03FA ; aptCheckRange: candidate end addr lo (HexVal+size)
AptCandEndHi  = $03FB ; aptCheckRange: candidate end addr hi

; --- VMM / REU ---
.include "vmm.inc"
