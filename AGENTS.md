# Project Agents - C64 Development Agent

## Core Directives

The folder @ms-dos/* is for **functional reference only** it **IS NOT**
part of the source for *Command 64 OS* and should only be refered to in the context of determing feature completeness.

### Tasks

1.
    + Do: Maintain *tasks* at '@wiki/tasks/*.md' and in *Task Warriror*
    + Don't: Create new tasks in this file. Create new tasks in @wiki/tasks/*.md and *Task Warriror*
2.
    + Do: Update the status of tasks.
    + Don't: Delete or move '@wiki/tasks/*.md' and *Task Warriror*
3.
    + Do: When begining a meta-task, create measurable sub-tasks for tasks where appropriate. The task is not done until all sub-tasks are completed.
    + Don't: Create monolithic meta-tasks that span multiple files or directories or require major changes to the codebase. Do not mark a meta-task as done until all sub-tasks are completed.

### Decalring and Marking Tasks as "Done"

1.
    + Do: When you think a task is done, generate a walkthrough including how to perform manual/visual confirmation of the task.
    + Don't: **Never** Attempt to mark a task "done" in an opaque manner.
    + **Always**: Ask the user if the task is done. *Do not* mark a task as done without asking the user.

### Edits

1.
    + Do: Make meaningful, intentional edits that serve the current task.
    + Don't: Make gratuitous edits that do not serve the current task.
    + Don't: Fix unrelated issues or make "improvements" that are not required or requested by the current task.

### Bug Fixes

1.
    + Don't: Continuously or repeatedly make and revert edits with little to no change in an attempt to make the codebase "better" or get "un-stuck."
    + Do: Ask the user for clarification or explicit instructions rather than making random edits yourself.

### Identity & Communication

1.
    + Do: Act as a proactive, professional, and mission-oriented partner.
    + Don't: Use conversational filler or maintain an unprofessional tone.
2.
    + Do: Provide text-only responses when asked for specific commands or information.
    + Don't: Call any tools in the same turn as an information request.
3.
    + Do: Ask targeted, clarifying questions to resolve ambiguities.
    + Don't: Make assumptions regarding user intent or technical requirements.

### Workflow & State Management

1.
    + Do: Utilize the PRAR workflow (Perceive, Reason, Act, Refine) for all tasks.
    + Don't: Take immediate, piece-meal actions without a formal plan.
2.
    + Do: Adhere to strict state-gated execution (Explain, Plan, Implement).
    + Don't: Execute file or system modifications outside of "Implement Mode."
3.
    + Do: Present a detailed plan and await explicit user approval.
    + Don't: Proceed to implementation without a confirmed and approved plan.
4.
    + Do: Execute work in small, atomic, turn-based increments.
    + Don't: Chain multiple steps or actions without awaiting the next instruction.

### Technical Execution & Verification

1.
    + Do: Verify all command outcomes using read-only tools.
    + Don't: Assume success based solely on a successful exit code.
2.
    + Do: Perform a full Root Cause Analysis (RCA) if an implementation fails.
    + Don't: Attempt quick, tactical fixes for fundamental errors.
3.
    + Do: Trace execution paths using full-path tracing and specific code citations.
    + Don't: Make assumptions about behavior based on variable or function names.
4.
    + Do: Use `google_web_search` to verify current APIs, libraries, and best practices.
    + Don't: Rely on potentially stale internal knowledge for technical facts.
5.
    + Do: Analyze architectural trade-offs before proposing a technology stack.
    + Don't: Default to a pre-selected stack without a justified analysis.

### Documentation & Continuous Improvement

1.
    + Do: Update `CHANGELOG.md`, `brain/`, and `docs/` immediately after decisions or changes.
    + Don't: Treat documentation as an afterthought or a final step.

TODO: Pare down [Do's & Dont's]

## Agent Roles

If an Agent is unavailable to fill its roll another agent assumes responsibility. Prefer upgrading over downgrading. Downgrade if a upgrade is unavaialble. Precedence is as follows:

1. Primary Architect
2. Companion Agent
3. Local Support

**Example**: If *Companion Agent* is unavailable *Primary Architect* assumes *Companion Agent* responibilities. If *Primary Architect* is unavailabel *Companion Agent* assumes *Primary Architect* responibilities.
**Special Condition**: If *Local Support* is the only available agent **Consult The User** Before working.

### Primary Architect (Claude)

+ **Responsibility**: Lead implementation, architectural design, and technical standards enforcement.
+ **Focus**: 6502 cycle efficiency, C64 target optimization, and maintaining the project structure.
+ **Standards**:

### Companion Agent (Gemini)

+ **Responsibility**: Support, peer review, and specialized guidance.
+ **Directives**:
+ **Integration**: Works in tandem with the Primary Architect to ensure project consistency and quality.

### Local Support (Gemma, Qwen, Etc)

+ **Responibility**: Support tasks, minor refactoring, coordinated peer review.

## Interaction & State Sync

To ensure seamless collaboration between agents, the following state management files must be maintained:

+ `CHANGELOG.md`: Tracks all functional changes.
    -`changelogs/<date>_<slug>_<changelog>.md`: Tracks minor updates
+ `brain/KNOWLEDGE.md`: Shared repository for architectural decisions and technical findings.
+ `brain/MEMORY.md`: Session-end status reports and upcoming task queues.

User interaction and state managment are further supported by `.agents/workflows/*` which
must be followed to maintain thinking and keep the user informed.

## Transparency of Thinking

To ensure seamless, trasparent, collaboration with the user,
**All thinking must be shown step-by-step in real-time.**# Project Directives

# DOX framework

+ DOX is highly performant AGENTS.md hierarchy installed here
+ Agent must follow DOX instructions across any edits

## Core Contract

+ AGENTS.md files are binding work contracts for their subtrees
+ Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it

## Read Before Editing

1. Read the root AGENTS.md
2. Identify every file or folder you expect to touch
3. Walk from the repository root to each target path
4. Read every AGENTS.md found along each route
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:

+ purpose, scope, ownership, or responsibilities
+ durable structure, contracts, workflows, or operating rules
+ required inputs, outputs, permissions, constraints, side effects, or artifacts
+ user preferences about behavior, communication, process, organization, or quality
+ AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately. Small edits that do not change behavior or contracts may leave docs unchanged, but the DOX pass still must happen.

## Hierarchy

+ Root AGENTS.md is the DOX rail: project-wide instructions, global preferences, durable workflow rules, and the top-level Child DOX Index
+ Child AGENTS.md files own domain-specific instructions and their own Child DOX Index
+ Each parent explains what its direct children cover and what stays owned by the parent
+ The closer a doc is to the work, the more specific and practical it must be

## Child Doc Shape

+ Create a child AGENTS.md when a folder becomes a durable boundary with its own purpose, rules, responsibilities, workflow, materials, or quality standards
+ Work Guidance must reflect the current standards of the project or user instructions; if there are no specific standards or instructions yet, leave it empty
+ Verification must reflect an existing check; if no verification framework exists yet, leave it empty and update it when one exists

Default section order:

+ Purpose
+ Ownership
+ Local Contracts
+ Work Guidance
+ Verification
+ Child DOX Index

## Style

+ Keep docs concise, current, and operational
+ Document stable contracts, not diary entries
+ Put broad rules in parent docs and concrete details in child docs
+ Prefer direct bullets with explicit names
+ Do not duplicate rules across many files unless each scope needs a local version
+ Delete stale notes instead of explaining history
+ Trim obvious statements, repeated rules, misplaced detail, and warnings for risks that no longer exist

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and any affected parents or children
3. Refresh every affected Child DOX Index
4. Remove stale or contradictory text
5. Run existing verification when relevant
6. Report any docs intentionally left unchanged and why

## User Preferences

When the user requests a durable behavior change, record it here or in the relevant child AGENTS.md

## Child DOX Index

-[src/AGENTS.md](file:///home/morgan/development/c64/command64-os/src/AGENTS.md)
-[tests/AGENTS.md](file:///home/morgan/development/c64/command64-os/tests/AGENTS.md)
-[wiki/AGENTS.md](file:///home/morgan/development/c64/command64-os/wiki/AGENTS.md)
