// include/vmm.inc
// VMM (Virtual Memory Manager) API Specification
// Maps 1MB logical DOS space to C64 Ultimate REU

#ifndef VMM_INC
#define VMM_INC

// --- VMM Constants ---
.label VMM_SUCCESS      = $00
.label VMM_ERR_NOMEM    = $01
.label VMM_ERR_INVALID  = $02

// --- Register / ZP Interface ---
// The shell and other modules use these ZP locations to interact with the VMM.
// These are duplicated in command64.inc for convenience but are the canonical source.
.label VmmSeg   = $0200
.label VmmOff   = $0201
.label ReuBank  = $0202
.label VmmMctBase = $0203
.label VmmFreeHead = $0204

// --- REU Hardware Port ---
.label REU_CTRL_REG    = $D405 // REU Bank selection and control
.label REU_DATA_REG    = $D406 // REU Data port

// --- API Prototypes (Conceptual) ---
// VMM_INIT(pages)    -> A = return code
// VMM_READ_BYTE(seg, off) -> A = byte
// VMM_WRITE_BYTE(seg, off, val) -> A = return code

#endif
