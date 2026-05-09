// include/command64.inc
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Core Definitions

// --- KERNAL Jump Table Addresses ---
// Always reference the jump table ($FF00+), never raw ROM body addresses.
.label KernalChROUT    = $FFD2  // Output character to current channel
.label KernalGetIn       = $FFE4  // Raw keyboard input (bypasses screen editor/quote mode)
.label KernalChRIN     = $FFCF  // Input character from current channel (screen editor)
.label KernalCLALL     = $FFE7  // Close all I/O channels (was $E548, raw ROM addr, wrong)
.label KernalWarmStart = $FC68  // Warm start / BASIC restart vector

// --- PETSCII Control Characters ---
.label PetCr   = $0D  // Carriage return
.label PetLl   = $0A  // Line feed
.label PetVBar = $7C  // Vertical bar '|'
.label PetLeft = $9D  // Cursor left control code

// --- Zero Page: Pointer and Dispatch Scratch ($22–$2F, $F9–$FE) ---
// Standard C64 user zero-page scratch area is $FB–$FE; $F9–$FA also safe.
// However, $FB-$FE can be used by KERNAL tape/RS-232. Moving string pointers.
.label PrintPtrLo    = $22  // petPrintString: pointer low byte
.label PrintPtrHi    = $23  // petPrintString: pointer high byte
.label HandlerVecLo  = $FD  // shellDispatch: resolved handler address low byte
.label HandlerVecHi  = $FE  // shellDispatch: resolved handler address high byte
.label ParsePos      = $F9  // index into CommandBuffer past matched command name
.label CmpBase       = $FA  // cmdCompare: saved entry-base offset

// --- I/O Buffers ---
// Relocating CommandBuffer to $1500 to provide more headroom for the shell code.
.label CommandBuffer = $1500
.label CommandLen    = $1550

// --- User Program Space ---
// External commands are loaded here. 
// $2000 is well clear of the shell and buffers.
.label UserProgStart = $2000
.label UserProgEnd   = $3FFF // Allocated 8KB for most external tools

// --- VMM / REU (Page 2) ---
.label VmmSeg   = $0200
.label VmmOff   = $0201
.label ReuBank  = $0202
.label VmmMctBase = $0203 // Base of Memory Control Table in REU/Base RAM
.label VmmFreeHead = $0204 // Pointer to first free memory block
