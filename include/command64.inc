// include/command64.inc
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Core Definitions

// --- KERNAL Jump Table Addresses ---
// Always reference the jump table ($FF00+), never raw ROM body addresses.
.label KernalChROUT    = $FFD2  // Output character to current channel
.label KernalGetIn       = $FFE4  // Raw keyboard input (bypasses screen editor/quote mode)
.label KernalChRIN     = $FFCF  // Input character from current channel (screen editor)
.label KernalCLALL     = $FFE7  // Close all I/O channels (was $E548, raw ROM addr, wrong)
.label KernalWarmStart = $FC68  // Warm start / BASIC restart vector
.label KernalSETMSG    = $FF90  // Set KERNAL messages
.label KernalSETLFS    = $FFBA  // Set logical, first, and second addresses
.label KernalSETNAM    = $FFBD  // Set file name
.label KernalLOAD      = $FFD5  // Load or verify file
.label KernalOPEN      = $FFC0  // Open a logical file
.label KernalCLOSE     = $FFC3  // Close a logical file
.label KernalREADST    = $FFB7  // Read status byte

// --- PETSCII Control Characters ---
.label PetCr   = $0D  // Carriage return
.label PetLl   = $0A  // Line feed
.label PetVBar = $7C  // Vertical bar '|'
.label PetLeft = $9D  // Cursor left control code

// --- Zero Page: Pointer and Dispatch Scratch ($FB–$FE, $66–$6A) ---
// Using 100% safe area ($FB-$FE) and FAC1 workspace ($66-$6A).
// This avoids clobbering KERNAL I/O ($90-$FA) and BASIC pointers ($2B-$32).
.label PrintPtrLo    = $FB  // petPrintString: pointer low byte
.label PrintPtrHi    = $FC  // petPrintString: pointer high byte
.label NamePtrLo     = $FD  // Loader: pointer to filename in buffer
.label NamePtrHi     = $FE  // Loader: pointer to filename in buffer
.label TempLo        = $66  // Utility scratch low byte
.label TempHi        = $67  // Utility scratch high byte
.label HexValLo      = $68  // parseHex: result low byte
.label HexValHi      = $69  // parseHex: result high byte
.label ParsePos      = $6A  // index into CommandBuffer past matched command name
.label CmpBase       = $02  // cmdCompare: saved entry-base offset (user safe byte)
.label HandlerVecLo  = $03  // shellDispatch: resolved handler address low byte
.label HandlerVecHi  = $04  // shellDispatch: resolved handler address high byte

// --- I/O Buffers ---
// Relocating CommandBuffer to $1600 to provide more headroom for the shell code.
.label CommandBuffer = $1600
.label CommandLen    = $1650
.label SpecificLoad  = $1651 // 0=use file header, 1=use HexVal address

// --- User Program Space ---
// External commands are loaded here. 
// $2000 is the standard entry point for the pre-verified image.d64 programs.
.label UserProgStart = $2000
.label UserProgEnd   = $9FFF // Allocated all remaining BASIC RAM

// --- VMM / REU ---
#import "vmm.inc"
