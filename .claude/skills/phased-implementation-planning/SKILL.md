---
name: phased-implementation-planning
description: Use when starting a new Phase or Work Package (CASM, DASH, DEBUG, or any other numbered multi-WP effort), when asked to plan the next phase/WP, or when about to implement something phase/WP-shaped without an approved plan yet on file. Triggers on: new phase, new work package, WP##, next phase, plan the next increment, start implementing <feature> phase, completion gate, walkthrough.
---

# Phased Implementation Planning

Full contract: `.agents/workflows/phased-implementation-planning.md`. This
skill is the at-conversation-time reminder; read the workflow doc for the
complete rationale and worked examples.

## The rule

**No implementation begins until a detailed plan for that specific Phase
or Work Package exists in `brain/plans/`, is recorded, and is explicitly
approved by the user.** Don't start writing code (or asm) for a new WP
because the shape of it seems obvious — draft the plan first, even if it
feels like ceremony. This project has a real history of rework when that
step got skipped.

**No Phase or Work Package is marked complete until** a completion-gate
walkthrough exists in `brain/walkthroughs/` with live evidence, and the
user has explicitly approved closing it.

## Checklist when starting a new Phase/WP

1. Copy `brain/plans/_TEMPLATE_PHASE_WP.md` to
   `brain/plans/YYYY-MM-DD-<feature-slug>.md`.
2. If any judgment call isn't already settled by the user (scope, fix-vs-
   defer, how much verification is enough), **ask first** — record the
   answers as a dated `Scoping Decisions` section before drafting the rest.
3. Fill in Objective, Scope, the technical sections this specific WP
   actually needs, Atomic Increments, Expected Files, Stop Conditions,
   Documentation/Task/DOX Updates, and Completion Gate. Keep `Atomic
   Increments`, `Stop Conditions`, and `Completion Gate` even when
   everything else is thin — those three are load-bearing.
4. Present the drafted plan and get explicit approval before writing any
   implementation.
5. Update the plan's own `Progress` log as you go — append, don't rewrite.

## Checklist when closing a Phase/WP

1. Write `brain/walkthroughs/YYYY-MM-DD-<feature-slug>.md` (same slug as
   the plan) — live evidence only, not intentions.
2. If this WP closes a whole Phase, do a **consolidated** live
   re-verification first (re-run everything together, fresh — not just
   citing each WP's own individual pass). See the workflow doc's
   "Multi-WP phases" section for why this matters.
3. Synchronize Taskwarrior, `brain/task.md`, `wiki/tasks/*.md`,
   `brain/KNOWLEDGE.md` (closing note on the existing phase section),
   `CHANGELOG.md`, and memory.
4. Ask for explicit approval. Do not self-declare completion.

## If a defect is found mid-plan

Default is disclose-and-defer (a separate, separately-approved follow-up),
per the plan's own Stop Conditions. Only fix inline if the user explicitly
directs it in the moment — and record that deviation and its reasoning in
the plan/walkthrough, don't let it slide by silently.
