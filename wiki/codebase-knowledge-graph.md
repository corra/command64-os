# Codebase Knowledge Graph (src/ + include/)

This page maps the structural and runtime relationships of the command64 OS
source tree. Scope is strictly [src/](../src/) and [include/](../include/) —
build tooling (`cmake/`, `tools/`), tests, and the wiki/brain/docs themselves
are out of scope. Diagrams were built by manually tracing `#import`/`.include`
directives and ca65 `.export`/`.import` symbol tables (the codebase-memory
MCP was unavailable for this pass); see individual `AGENTS.md` files linked
below for the authoritative contracts behind each subsystem.

## 1. Codebase Map

```mermaid
graph TD
    subgraph INC["include/"]
        incCmd["command64.inc<br/>Kick core defs (KERNAL vectors, ZP, DOS_* fn codes)"]
        incVmm["vmm.inc<br/>VMM spec — reference doc, not #import'd anywhere"]
        subgraph INCCA65["ca65/"]
            ca65Cmd["command64.inc<br/>hand-mirrored ca65 port"]
            ca65Vmm["vmm.inc<br/>hand-mirrored ca65 port"]
            ca65Macros["macros.inc<br/>petPrintChar port (unused)"]
            ca65Screen["screencode.inc<br/>screencode encoding helper"]
        end
    end

    subgraph SRC["src/"]
        cmdAsm["command64.asm<br/>segment layout + entry point"]
        subgraph CORE["command64/ — Core OS (KickAssembler)"]
            petsci["petsci.asm"]
            api["api.asm"]
            utils["utils.asm"]
            loader["loader.asm"]
            path["path.asm"]
            vmmasm["vmm.asm"]
            fileasm["file.asm"]
            apptable["apptable.asm"]
            shell["shell.asm"]
        end
        subgraph EXT["external/ — user-space apps, $2200-$9FFF"]
            casmApp["casm/ — 10 files (ca65)"]
            pacmanApp["pacman/ — 3 files + autotile.py (ca65)"]
            edlinApp["edlin/ — 4 files (ca65)"]
            conwayApp["conway/ — 2 files (ca65)"]
            debugApp["debug/ — 1 file, 3479 lines (ca65)"]
            compApp["comp/ — 1 file (ca65)"]
            formatApp["format/ — 1 file (ca65)"]
            labelApp["label/ — 1 file (ca65)"]
            dvorakApp["dvorak/ — 1 file (KickAssembler)"]
            viApp["vi/ — BUILD_VI only, no source yet"]
        end
    end

    cmdAsm -->|"#import"| incCmd
    cmdAsm -->|"#import"| CORE
    CORE -.->|".include (ca65 apps)"| INCCA65
    dvorakApp -->|"#import"| incCmd
```

## 2. Toolchain Split & Header Mirroring

Two assemblers coexist by directory contract ([src/external/AGENTS.md](../src/external/AGENTS.md)):
Kick Assembler builds the core OS (and `dvorak`), ca65/ld65 builds every other
external app. Each toolchain has its own header set, kept in sync by hand
rather than shared.

```mermaid
graph LR
    subgraph Kick["KickAssembler world"]
        k1["include/command64.inc"]
        k2["include/vmm.inc<br/>(spec only)"]
        kUsers["command64.asm, command64/*.asm, external/dvorak/dvorak.asm"]
    end
    subgraph Ca65["ca65 world"]
        c1["include/ca65/command64.inc"]
        c2["include/ca65/vmm.inc"]
        c3["include/ca65/macros.inc"]
        c4["include/ca65/screencode.inc"]
        cUsers["external/{casm,comp,conway,debug,edlin,format,label,pacman}"]
    end
    kUsers --> k1
    kUsers -.reference only.-> k2
    cUsers --> c1
    cUsers --> c2
    cUsers --> c3
    cUsers --> c4
    k1 -.hand-mirrored.-> c1
    k2 -.hand-mirrored.-> c2
```

## 3. Core OS Memory Segment Layout

`src/command64.asm` chains KickAssembler segments with `startAfter`, so
source-file order in `#import` determines final memory layout. `ApiStub` and
`VmmData` are pinned addresses that external apps and other core modules
hardcode; everything else floats. (Source: [command64.asm](../src/command64.asm) header comment.)

```mermaid
flowchart TD
    A["$0801 Main<br/>BasicUpstart2 → SYS $1200"] --> B["$0820 Utils<br/>utils.asm — hex parsing"]
    B --> C["$0920 Api<br/>api.asm — apiHandler dispatcher body"]
    C --> D["$09C0 Loader<br/>loader.asm — shellLoadPrg (KERNAL LOAD wrapper)"]
    D --> E["$0A60 Path<br/>path.asm — findFile, device prefix parsing"]
    E --> F["$0B00 Vmm<br/>vmm.asm — REU paging"]
    F --> G["$0D00 File<br/>file.asm — handle table + KERNAL I/O"]
    G --> H["$1000 ApiStub — FIXED<br/>api.asm — JMP apiHandler, external apps JSR here"]
    H --> I["Petsci<br/>petsci.asm"]
    I --> J["CommandTable<br/>shell.asm — 22 builtin command entries"]
    J --> K["CommandShell<br/>shell.asm — mainLoop, dispatch, builtins"]
    K --> L["$1FA0 VmmData — FIXED<br/>FileScratch, vmmInitialized, SysDate* scratch"]
    L --> M["$2000 AppTable<br/>apptable.asm — 16-slot loaded-program registry"]
    M --> N["ShellExt<br/>reserved growth"]
```

## 4. Core OS Runtime Call Graph

Two entry paths converge on the same subsystem modules: the interactive
shell loop (built-in commands) and the `OS_API` service bus that external
apps call via `JSR $1000` (documented in [wiki/api-reference.md](api-reference.md)).

```mermaid
flowchart LR
    boot["BasicUpstart2<br/>SYS $1200"] --> start["shell.asm: start"]
    start --> mainLoop["mainLoop"]
    mainLoop --> shellReadLine --> shellDispatch
    shellDispatch -->|"linear scan, stride 8"| tableCmd["CommandTable (22 entries)"]

    tableCmd --> cmdLoad & cmdRun & cmdDir & cmdCopy & cmdDel & cmdRen & cmdApps & cmdOther["cmdExit, cmdCls, cmdEcho,<br/>cmdVer, cmdHelp, cmdType, cmdMore,<br/>cmdDrive, cmdSet, cmdVol, cmdPath,<br/>cmdFree, cmdFlush, cmdDate, cmdTime"]

    cmdLoad --> shellLoadPrg["loader.asm: shellLoadPrg"]
    cmdRun --> shellLoadPrg
    cmdDir --> findFile["path.asm: findFile"]
    cmdCopy --> fileOpsShell["file.asm: fileOpen/Read/Write/Close"]
    cmdDel & cmdRen --> fileOpsShell
    cmdApps --> aptOps["apptable.asm: aptSlotBase + registry walk"]

    extApp["External app<br/>(any src/external/* program)"] -->|"JSR $1000, A = fn#"| apiStub["ApiStub: jmp apiHandler"]
    apiStub --> apiHandler["api.asm: apiHandler<br/>INT 21h-style dispatcher"]

    apiHandler --> ahPrintChar & ahPrintStr & ahOpen & ahClose & ahRead & ahWrite & ahDelete & ahRename & ahAllocMem & ahFreeMem & ahExit & ahParsePrefix & ahSendCommand & ahVmmRead & ahVmmWrite

    ahPrintChar & ahPrintStr --> petsciMod["petsci.asm: KernalChROUT / petPrintString"]
    ahOpen & ahClose & ahRead & ahWrite & ahDelete & ahRename --> fileMod["file.asm: handle table + KERNAL I/O"]
    ahAllocMem & ahFreeMem & ahVmmRead & ahVmmWrite --> vmmMod["vmm.asm: vmmAlloc / vmmFree / vmmReadBlock / vmmWriteBlock (REU DMA)"]
    ahParsePrefix & ahSendCommand --> pathMod["path.asm: parsePointerDevice / dosSendCommand"]
    ahExit --> mainLoop
```

## 5. External Application Skeleton

Every ca65 external app (all of `src/external/` except `dvorak`) follows the
same three-header pattern, then talks to the core OS exclusively through the
`OS_API` jump table — apps never touch core OS zero page or internals
directly ([src/external/AGENTS.md](../src/external/AGENTS.md)).

```mermaid
flowchart TD
    entry["App entry .s<br/>.define VERSION_MAJOR/MINOR/STAGE"]
    cmdinc["include/ca65/command64.inc<br/>DOS_* fn codes, KERNAL vectors, shared ZP"]
    commoninc["&lt;app&gt;/common.inc<br/>app-private ZP $70-$8F, local constants"]
    buildinc["build_&lt;app&gt;.inc<br/>generated by CMake — BUILD_NUMBER"]
    osapi["Command64 OS_API<br/>JSR $1000, A = function #"]

    entry --> cmdinc
    entry --> commoninc
    entry --> buildinc
    entry -->|"file/mem/print/exit services"| osapi
```

## 6. External Application Inventory

| App | Toolchain | Files | Multi-module? | Notes |
|---|---|---|---|---|
| `casm` | ca65/ld65 | 10 | Yes — layered (§7) | Native 6502 assembler; VMM-backed source/symbol storage |
| `pacman` | ca65/ld65 | 3 + `autotile.py` | Yes (§8) | Maze table generated by `autotile.py`, checked into `pacman_game.s` |
| `edlin` | ca65/ld65 | 4 | Yes (§8) | Port of MS-DOS EDLIN line editor |
| `conway` | ca65/ld65 | 2 | Yes (§8) | Game of Life demo |
| `debug` | ca65/ld65 | 1 (3479 lines) | No — monolithic | Interactive memory editor/monitor; no `common.inc` |
| `comp` | ca65/ld65 | 1 | No | Raw byte-stream file comparison |
| `format` | ca65/ld65 | 1 | No | Drives 1541 `N:` command via `DOS_SEND_COMMAND` |
| `label` | ca65/ld65 | 1 | No | Disk volume-label writer |
| `dvorak` | KickAssembler | 1 | No | Port of a BASIC type-in listing; only non-ca65 external app |
| `vi` | — | 0 | — | `BUILD_VI` placeholder only; no source implemented yet |

## 7. CASM — Internal Module Graph

CASM ([src/external/casm/AGENTS.md](../src/external/casm/AGENTS.md)) is the
only external app with a layered architecture, reconstructed here from its
`.export`/`.import` symbol tables. `state.s` is pure BSS storage (63 bytes,
no imports) sitting at the bottom; `casm.s` is the orchestrator at the top.

```mermaid
flowchart TD
    casm["casm.s — entry / orchestrator"]
    resources["resources.s — handle+VMM registry, exitSuccess/exitFatal"]
    cli["cli.s — /O /S /M /L option parsing"]
    fileio["fileio.s — bounded 256B transfer buffer, stream API"]
    source["source.s — byte/line source cursor"]
    lexer["lexer.s — tokenizer + one-token lookahead"]
    parser["parser.s — statement parser (Pass 1/2 reparse)"]
    opcodes["opcodes.s — opcode table + addressing-mode matcher"]
    diagnostics["diagnostics.s — structured diagnostic printing"]
    emit["emit.s — Pass 2 instruction/directive emission"]
    state["state.s — 63-byte source/lexer/token BSS record (leaf)"]

    casm --> resources
    casm --> cli
    casm --> fileio
    casm --> source
    casm --> diagnostics
    casm --> lexer
    casm --> parser
    casm --> opcodes
    casm --> emit

    emit --> parser
    emit --> opcodes
    emit --> fileio
    emit --> lexer

    fileio --> resources
    fileio --> cli

    lexer --> state
    lexer --> source

    parser --> lexer
    parser --> state

    opcodes --> parser

    resources --> diagnostics

    source --> state
    source --> fileio

    diagnostics --> state
```

## 8. Pacman / Edlin / Conway — Internal Module Graphs

The remaining multi-file apps use a flat two-to-three module split (no
layering like CASM).

```mermaid
flowchart TD
    subgraph Pacman["pacman/"]
        pmain["pacman_main.s — game loop, entry"]
        pgame["pacman_game.s — maze render/collision (mazeWalls table)"]
        pai["pacman_ai.s — ghost AI, scatter/frightened modes"]
        pmain --> pgame
        pmain --> pai
        pai -->|"getWallCell"| pgame
    end

    subgraph Edlin["edlin/"]
        emain["edlin.s — command loop, EditBuf, line input"]
        ecmds["cmds.s — L/P/D/I/E/Q/W command handlers"]
        ebuf["buffer.s — windowed line buffer, gap (hole) management"]
        emain --> ebuf
        emain --> ecmds
        ecmds --> ebuf
        ecmds -->|"EditBuf, ownLineInput, Filename ptrs"| emain
    end

    subgraph Conway["conway/"]
        cmain["conway_main.s — sim loop, entry"]
        cgrid["conway_grid.s — grid state, rules, rendering"]
        cmain --> cgrid
    end
```

## Caveats & Method Notes

- `include/vmm.inc` (Kick side) is a specification document only — grepping
  the tree shows no `#import` of it anywhere; `vmm.asm` references it only in
  a comment. Its ca65 mirror `include/ca65/vmm.inc` is actually included by
  ca65 apps.
- `build_os.inc` and every `build_<app>.inc` are CMake-generated at build
  time (from the persistent `BUILD_<APPNAME>` counter files) and are not
  present in `src/` — they're referenced but don't exist as checked-in
  source.
- `src/external/vi/` contains only a `BUILD_VI` counter file; there is no
  source to graph yet.
- Diagrams reflect static `#import`/`.include`/`.export`/`.import` structure
  and direct `JSR`/`jmp` targets found by inspection, not a compiled linker
  map — cross-check against the linker output if precision at the byte level
  is required.
