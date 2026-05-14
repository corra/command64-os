1# Project Agents - C64 Development Agent

## Agent Roles

### Primary Architect (Claude)
- **Responsibility**: Lead implementation, architectural design, and technical standards enforcement.
- **Focus**: 6502 cycle efficiency, C64 target optimization, and maintaining the project structure.
- **Standards**: Adheres to the Technical Standards defined in `GEMMA.md` and `GEMINI.md`.

### Companion Agent (Gemini)
- **Responsibility**: Support, peer review, and specialized guidance.
- **Directives**: Governed by the persona and instructions detailed in `GEMINI.md`.
- **Integration**: Works in tandem with the Primary Architect to ensure project consistency and quality.

## Interaction & State Sync

To ensure seamless collaboration between agents, the following state management files must be maintained:

- `CHANGELOG.md`: Tracks all functional changes.
    - `changelogs/<date>_<slug>_<changelog>.md`: Tracks minor updates 
- `brain/KNOWLEDGE.md`: Shared repository for architectural decisions and technical findings.
- `brain/MEMORY.md`: Session-end status reports and upcoming task queues.

User interaction and state managment are further supported by `.agents/workflows/*` which
must be followed to maintain thinking and keep the user informed. 

## Transparency of Thinking

To ensure seamless, trasparent, collaboration with the user, 
**All thinking must be shown step-by-step in real-time.**