// include/command64.inc
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Core Definitions

// --- KERNAL Jump Table Addresses ---
// Always reference the jump table ($FF00+), never raw ROM body addresses.
.label KernalChROUT    = $FFD2  // Output character to current channel
.label KernalGetIn       = $FFE4  // Raw keyboard input (bypasses screen editor/quote mode)
.label KernalChRIN     = $FFCF  // Input character from current channel (screen editor)
.label KernalCLALL     = $FFE7  // Close all I/O channels (was $E548, raw ROM addr, wrong)
.label KernalWarmStart = $E37B  // BASIC warm start vector (was $FC68, incorrect)
.label KernalSETMSG    = $FF90  // Set KERNAL messages
.label KernalSETLFS    = $FFBA  // Set logical, first, and second addresses
.label KernalSETNAM    = $FFBD  // Set file name
.label KernalLOAD      = $FFD5  // Load or verify file
.label KernalOPEN      = $FFC0  // Open a logical file
.label KernalCLOSE     = $FFC3  // Close a logical file
.label KernalREADST    = $FFB7  // Read status byte
.label KernalCHKIN     = $FFC6  // Set input channel
.label KernalCHKOUT    = $FFC9  // Set output channel
.label KernalCLRCHN    = $FFCC  // Clear I/O channels

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
.label FileScratch   = $1F92 // Filename scratch in VmmData: vmmInitialized($1F90), vmmTempByte($1F91), fileScratch($1F92)

// --- User Program Space ---
// External commands are loaded here. 
// $2000 is the standard entry point for the pre-verified image.d64 programs.
.label UserProgStart = $2000
.label UserProgEnd   = $9FFF // Allocated all remaining BASIC RAM

// --- VMM / REU ---
#import "vmm.inc"
