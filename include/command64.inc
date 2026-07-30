// include/command64.inc
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Core Definitions

// --- KERNAL Jump Table Addresses ---
// Always reference the jump table ($FF00+), never raw ROM body addresses.
.label KernalChROUT    = $FFD2  // Output character to current channel
.label KernalGetIn     = $FFE4  // Raw keyboard input (bypasses screen editor/quote mode)
.label KernalChRIN     = $FFCF  // Input character from current channel (screen editor)
.label KernalCLALL     = $FFE7  // Close all I/O channels (was $E548, raw ROM addr, wrong)
.label KernalWarmStart = $E37B  // BASIC warm start (assumes ZP intact — NOT safe after shell)
.label KernalColdStart = $E394  // BASIC cold start (full re-init of interpreter state)
.label KernalSETMSG    = $FF90  // Set KERNAL messages
.label KernalSETLFS    = $FFBA  // Set logical, first, and second addresses
.label KernalSETNAM    = $FFBD  // Set file name
.label KernalLOAD      = $FFD5  // Load or verify file
.label KernalSAVE      = $FFD8  // Save memory range to file
.label KernalOPEN      = $FFC0  // Open a logical file
.label KernalCLOSE     = $FFC3  // Close a logical file
.label KernalREADST    = $FFB7  // Read status byte
.label KernalStatus    = $90    // KERNAL I/O status byte
.label KernalCHKIN     = $FFC6  // Set input channel
.label KernalCHKOUT    = $FFC9  // Set output channel
.label KernalCLRCHN    = $FFCC  // Clear I/O channels
.label KernalLISTEN    = $FFB1  // Send LISTEN on the serial bus (ATN handshake only)
.label KernalUNLSN     = $FFAE  // Send UNLISTEN (releases the bus, no data phase)

// --- API Function Constants (DOS Standard Hex Codes) ---
.label DOS_PRINT_CHAR  = $02  // Print character (PETSCII)
.label DOS_PRINT_STR   = $09  // Print string (Null-terminated)
.label DOS_OPEN_FILE   = $3D  // Open file
.label DOS_CLOSE_FILE  = $3E  // Close file
.label DOS_READ_FILE   = $3F  // Read from file
.label DOS_WRITE_FILE  = $40  // Write to file
.label DOS_DELETE_FILE = $41  // Delete file (UNLINK)
.label DOS_RENAME_FILE = $56  // Rename file
.label DOS_ALLOC_MEM   = $48  // Allocate memory (VMM)
.label DOS_FREE_MEM    = $49  // Free memory (VMM)
.label DOS_EXIT        = $4C  // Terminate program (Return to Shell)
.label DOS_PARSE_PREFIX = $57  // Parse target device prefix from ZP pointer
.label DOS_SEND_COMMAND = $58  // Send raw command-channel string, read drive response
.label DOS_VMM_READ    = $59  // Block-read bytes from a DOS_ALLOC_MEM'd REU segment
.label DOS_VMM_WRITE   = $5A  // Block-write bytes to a DOS_ALLOC_MEM'd REU segment
.label DOS_RELEASE_L15 = $5B  // Close LFN 15 and clear the OS command-channel cache
.label DOS_GET_SYSTEM_INFO = $5C // Gather system status and memory metrics
.label DOS_GET_APP_INFO    = $5D // Query loaded application table entry

// --- API Status & Error Codes ---
.label DOS_ERR_OK            = $00 // Success
.label DOS_ERR_INVALID_INDEX = $01 // Invalid slot index (>= 16)
.label DOS_ERR_SLOT_EMPTY     = $02 // Requested app slot is unallocated
.label DOS_ERR_UNAVAILABLE  = $03 // Feature or subsystem uninitialized
.label DOS_ERR_INVALID_ARG   = $04 // Null or invalid argument pointer

// --- System Information Record Constants ---
.label SYS_INFO_SIZE         = 24  // Byte size of DOS_GET_SYSTEM_INFO structure
.label SYS_INFO_OFF_VER      = 0   // StructVersion (1 byte)
.label SYS_INFO_OFF_SIZE     = 1   // StructSize (1 byte = 24)
.label SYS_INFO_OFF_OS_MAJ   = 2   // OsMajor (1 byte)
.label SYS_INFO_OFF_OS_MIN   = 3   // OsMinor (1 byte)
.label SYS_INFO_OFF_OS_STG   = 4   // OsStage (1 byte)
.label SYS_INFO_OFF_DEV      = 5   // CurrentDevice (1 byte)
.label SYS_INFO_OFF_VIDEO    = 6   // VideoStandard (1 byte: 0=NTSC, 1=PAL)
.label SYS_INFO_OFF_PROG_LO  = 7   // UserProgStart low byte
.label SYS_INFO_OFF_PROG_HI  = 8   // UserProgStart high byte
.label SYS_INFO_OFF_END_LO   = 9   // UserProgEnd low byte ($FF)
.label SYS_INFO_OFF_END_HI   = 10  // UserProgEnd high byte ($BF)
.label SYS_INFO_OFF_VMM_FLG  = 11  // VmmFlags (1 byte: bit 0=active, bit 1=probed)
.label SYS_INFO_OFF_PGSZ_LO  = 12  // VmmPageSize low byte ($00)
.label SYS_INFO_OFF_PGSZ_HI  = 13  // VmmPageSize high byte ($10 = 4096)
.label SYS_INFO_OFF_TOT_LO   = 14  // VmmTotalPages low byte ($00)
.label SYS_INFO_OFF_TOT_HI   = 15  // VmmTotalPages high byte ($10 = 4096)
.label SYS_INFO_OFF_ALC_LO   = 16  // VmmAllocPages low byte
.label SYS_INFO_OFF_ALC_HI   = 17  // VmmAllocPages high byte
.label SYS_INFO_OFF_FRE_LO   = 18  // VmmFreePages low byte
.label SYS_INFO_OFF_FRE_HI   = 19  // VmmFreePages high byte
.label SYS_INFO_OFF_MAX_SLOT = 20  // AppMaxSlots (1 byte = 16)
.label SYS_INFO_OFF_USD_SLOT = 21  // AppUsedSlots (1 byte)
.label SYS_INFO_OFF_RES0     = 22  // Reserved (1 byte)
.label SYS_INFO_OFF_RES1     = 23  // Reserved (1 byte)

// --- Application Information Record Constants ---
.label APP_INFO_SIZE         = 24  // Byte size of DOS_GET_APP_INFO structure
.label APP_INFO_OFF_VER      = 0   // StructVersion (1 byte)
.label APP_INFO_OFF_SIZE     = 1   // StructSize (1 byte = 24)
.label APP_INFO_OFF_SLOT     = 2   // SlotIndex (1 byte: 0..15)
.label APP_INFO_OFF_FLAGS    = 3   // Flags (1 byte: bit 0=used, 1=running, 2=reu, 3=stack)
.label APP_INFO_OFF_LOAD_LO  = 4   // LoadAddr low byte
.label APP_INFO_OFF_LOAD_HI  = 5   // LoadAddr high byte
.label APP_INFO_OFF_SIZE_LO  = 6   // Size low byte
.label APP_INFO_OFF_SIZE_HI  = 7   // Size high byte
.label APP_INFO_OFF_NAME_LEN = 8   // NameLen (1 byte: 0..15)
.label APP_INFO_OFF_NAME_DATA= 9   // NameData (15 bytes PETSCII, null-padded)

// --- PETSCII Control Characters ---
.label PetCr   = $0D  // Carriage return
.label PetLl   = $0A  // Line feed
.label PetDel  = $14  // DEL (INST/DEL key unshifted) — destructive backspace
.label PetVBar = $7C  // Vertical bar '|'
.label PetLeft = $9D  // Cursor left control code

// --- Zero Page: Pointer and Dispatch Scratch ---
// Using 100% safe area ($FB-$FE, $02) and non-critical FAC1 workspace ($61-$67).
// This avoids clobbering KERNAL I/O ($90-$FA) and BASIC pointers ($2B-$32).
.label PrintPtrLo    = $FB  // petPrintString: pointer low byte
.label PrintPtrHi    = $FC  // petPrintString: pointer high byte
.label NamePtrLo     = $FD  // Loader: pointer to filename in buffer
.label NamePtrHi     = $FE  // Loader: pointer to filename in buffer
.label CmpBase       = $02  // cmdCompare: saved entry-base offset (user safe byte)

.label HandlerVecLo  = $61  // shellDispatch: resolved handler address low byte
.label HandlerVecHi  = $62  // shellDispatch: resolved handler address high byte
.label ParsePos      = $63  // index into CommandBuffer past matched command name
.label TempLo        = $64  // Utility scratch low byte
.label TempHi        = $65  // Utility scratch high byte
.label HexValLo      = $66  // parseHex: result low byte
.label HexValHi      = $67  // parseHex: result high byte

// --- I/O Buffers ---
// Relocating CommandBuffer to $033C (Cassette Buffer). 
// This is 192 bytes of safe workspace if tape is not used.
// It avoids colliding with code segments at $1600.
// Workspace layout ($033C-$03FB):
//   $033C-$038B: CommandBuffer (80 bytes)
//   $038C:       CommandLen (1 byte)
//   $038D:       SpecificLoad (1 byte)
//   $038E-$039D: HandleTable (8 entries * 2 bytes = 16 bytes)
//                Entry: Byte 0 = Status (0=Free, 1=Open), Byte 1 = C64 LFN
.label CommandBuffer = $033C
.label CommandLen    = $038C
.label SpecificLoad  = $038D // 0=use HexVal (Relocated), 1=use file header (Absolute)
.label HandleTable   = $038E
.label CurrentDevice = $039E // Active C64 device (8, 9, 10, 11)
.label EnvSegmentLo  = $039F
.label EnvSegmentHi  = $03A0
.label EnvBank       = $03A1
.label MAX_HANDLES   = 8
.label SourceBuf     = $03A2 // 40 bytes
.label DestBuf       = $03CA // 40 bytes
.label FileScratch   = $1FA2 // Filename scratch in VmmData: vmmInitialized($1FA0), vmmTempByte($1FA1), fileScratch($1FA2-$1FFB), SysDate*($1FFC-$1FFF)
.label SysDateYear     = $1FFC // Offset from 1980 (e.g. 46 = 2026), range 0-255
.label SysDateMonth    = $1FFD // Month index, range 1-12
.label SysDateDay      = $1FFE // Day of month, range 1-31
.label SysDateLastHour = $1FFF // Last-seen 24-hour decimal value (0-23); lazy midnight rollover detection

// --- CIA #1 TOD Clock Registers ---
.label CIA1_CRA  = $DC0E // Control Register A: bit 7 = TOD input freq (0=60Hz/NTSC, 1=50Hz/PAL)
.label CIA1_CRB  = $DC0F // Control Register B: bit 7 = TOD alarm/clock select (0=clock)
.label CIA1_TOD_HR    = $DC0B // TOD Hours (BCD, bit 7 = PM); reading latches TOD registers
.label CIA1_TOD_MIN   = $DC0A // TOD Minutes (BCD)
.label CIA1_TOD_SEC   = $DC09 // TOD Seconds (BCD)
.label CIA1_TOD_10THS = $DC08 // TOD Tenths of a second (BCD); reading unlatches, writing restarts clock
.label KernalVideoStd = $02A6 // KERNAL video standard flag: 0 = NTSC, 1 = PAL

// --- App Table: Phase A Constants ---
.label APT_MAX_SLOTS    = 16       // compile-time max entries
.label APT_ENTRY_SIZE   = 40       // bytes per entry
.label APT_HEADER_SIZE  = 4        // bytes for table header (MaxSlots, UsedSlots, reserved×2)
.label APT_OFF_FLAGS    = 0        // entry field: Flags
.label APT_OFF_NAME     = 1        // entry field: Name (16 bytes, PETSCII null-padded)
.label APT_OFF_ADDR     = 17       // entry field: LoadAddr lo/hi
.label APT_OFF_SIZE     = 19       // entry field: Size lo/hi (byte count)
.label APT_FLAG_USED    = $01      // Bit 0: slot in use
.label APT_FLAG_RUNNING = $02      // Bit 1: app currently executing
.label APT_FLAG_REU     = $04      // Bit 2: REU-backed image (Phase C)
.label APT_FLAG_STACK   = $08      // Bit 3: stack saved (Phase C)
// AptSegLo/Hi occupy first 2 bytes of cassette buffer free area ($03F2-$03FF)
.label AptSegLo         = $03F2    // persistent: APT VMM segment lo (0 = not yet allocated)
.label AptSegHi         = $03F3    // persistent: APT VMM segment hi

// Overlap-check scratch (aptRegister, aptCheckRange) — fills the remaining
// cassette buffer workspace bytes through $03FB.
.label AptTempLoadLo    = $03F4    // scanned slot's CurrLoadAddr lo
.label AptTempLoadHi    = $03F5    // scanned slot's CurrLoadAddr hi
.label AptTempSizeLo    = $03F6    // scanned slot's CurrSize lo
.label AptTempSizeHi    = $03F7    // scanned slot's CurrSize hi
.label AptTempEndLo     = $03F8    // scanned slot's CurrEndAddr lo (CurrLoadAddr+CurrSize)
.label AptTempEndHi     = $03F9    // scanned slot's CurrEndAddr hi
.label AptCandEndLo     = $03FA    // aptCheckRange: candidate end addr lo (HexVal+size)
.label AptCandEndHi     = $03FB    // aptCheckRange: candidate end addr hi

// --- User Program Space ---
// External commands are loaded here. 
#import "build_config.inc"
.label UserProgEnd   = $CFFF // Allocated all remaining RAM (BASIC ROM banked out)

// --- VMM / REU ---
#import "vmm.inc"
