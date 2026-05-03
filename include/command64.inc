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
.label PetCr = $0D  // Carriage return
.label PetLl = $0A  // Line feed

// --- Zero Page: Pointer and Dispatch Scratch ($F9–$FE) ---
// Standard C64 user zero-page scratch area is $FB–$FE; $F9–$FA also safe.
.label PrintPtrLo    = $FB  // petPrintString: pointer low byte
.label PrintPtrHi    = $FC  // petPrintString: pointer high byte
.label HandlerVecLo  = $FD  // shellDispatch: resolved handler address low byte
.label HandlerVecHi  = $FE  // shellDispatch: resolved handler address high byte
.label ParsePos      = $F9  // index into CommandBuffer past matched command name
.label CmpBase       = $FA  // cmdCompare: saved entry-base offset (entry start in tableCmd)

// --- I/O Buffers ---
// $0300–$033B is the C64 KERNAL/BASIC indirect vector table — DO NOT USE.
// CommandBuffer sits at $1400, safely after all code segments (~$1330 end).
// Layout: 79 data bytes ($1400–$144E), null terminator at $144F, length at $1450.
.label CommandBuffer = $1400
.label CommandLen    = $1450

// --- VMM / REU (Page 2) ---
.label VmmSeg   = $0200
.label VmmOff   = $0201
.label ReuBank  = $0202
.label VmmMctBase = $0203 // Base of Memory Control Table in REU/Base RAM
.label VmmFreeHead = $0204 // Pointer to first free memory block
