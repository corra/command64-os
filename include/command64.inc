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

// --- Zero Page: Pointer and Dispatch Scratch ($22–$2F) ---
// Moving all pointers out of $F5-$FE as that range is clobbered by KERNAL I/O.
.label PrintPtrLo    = $22  // petPrintString: pointer low byte
.label PrintPtrHi    = $23  // petPrintString: pointer high byte
.label NamePtrLo     = $24  // Loader: pointer to filename in buffer
.label NamePtrHi     = $25  // Loader: pointer to filename in buffer
.label TempLo        = $26  // Utility scratch low byte
.label TempHi        = $27  // Utility scratch high byte
.label HexValLo      = $28  // parseHex: result low byte
.label HexValHi      = $29  // parseHex: result high byte
.label ParsePos      = $2A  // index into CommandBuffer past matched command name
.label CmpBase       = $2B  // cmdCompare: saved entry-base offset
.label HandlerVecLo  = $2C  // shellDispatch: resolved handler address low byte
.label HandlerVecHi  = $2D  // shellDispatch: resolved handler address high byte

// --- I/O Buffers ---
// Relocating CommandBuffer to $1600 to provide more headroom for the shell code.
.label CommandBuffer = $1600
.label CommandLen    = $1650
.label SpecificLoad  = $1651 // 0=use file header, 1=use HexVal address

// --- User Program Space ---
// External commands are loaded here. 
// $2000 is well clear of the shell and buffers.
.label UserProgStart = $2000
.label UserProgEnd   = $3FFF // Allocated 8KB for most external tools

// --- VMM / REU ---
#import "vmm.inc"
