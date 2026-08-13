---
feature: <phase-or-wp-slug>
created: YYYY-MM-DD
status: proposed
taskwarrior: <UUID, or TBD (created on approval)>
depends-on: <UUID of prerequisite WP/Phase, if any>
---

# Plan: <Phase/WP Name>

## Status

**Proposed, not yet approved.** Drafted YYYY-MM-DD for user review, per
this project's per-work-package-plan-approval requirement
(`.agents/workflows/phased-implementation-planning.md`). No implementation
is authorized until this plan is approved.

Parent plan (if this is a WP within a Phase): `brain/plans/<phase-plan>.md`.
Prerequisite: <prior WP(s)>, complete and user-approved.

## Objective

<What does this Phase/WP actually deliver? What does it NOT deliver —
what's explicitly excluded? If it adds no new production behavior (a
hardening/verification/documentation WP), say so directly.>

## Scoping Decisions (user-confirmed YYYY-MM-DD)

<Only needed when the plan has to make a judgment call the user hasn't
already settled. Ask before drafting; record the actual answers here,
numbered, and cite them by number elsewhere in the plan. Delete this
section if nothing needed asking.>

1. ...

## Scope

**Included:**
- ...

**Excluded:**
- ...

## <Technical sections as needed>

<ABI/storage/register contracts, design decisions, audit surfaces,
harness design, etc. — whatever this specific Phase/WP actually needs to
plan out in detail before implementation. Cut what doesn't apply; this
varies more than any other part of the template.>

## Atomic Increments

<Numbered, in dependency order. Each increment should be small enough to
implement and verify on its own before starting the next.>

1. ...
2. ...

## Expected Files

| File | Planned action |
| --- | --- |
| ... | Create / Modify |

## Stop Conditions

<When does this plan halt and require renewed direction rather than
pushing through? Always include: any harness/test fails unexpectedly; any
approved boundary/cap is exceeded; a no-change rebuild changes an
artifact; a genuinely new defect is discovered outside this plan's own
scope (default: disclose and defer as a separate follow-up, not an inline
fix — see the workflow doc's "Deviating from an approved plan" section).>

## Documentation, Task, and DOX Updates

<Which of Taskwarrior, `brain/task.md`, `wiki/tasks/*.md`,
`brain/KNOWLEDGE.md`, `CHANGELOG.md`, memory, and any user-facing docs
(`docs/*.md`, `wiki/*.md`) does this Phase/WP touch, and when (at
activation vs. at completion)?>

## Completion Gate

<The specific, checkable conditions that must all be true before this
Phase/WP can be marked complete. Always include: live evidence recorded
in a `brain/walkthroughs/` doc; trackers synchronized; explicit user
approval.>

## Progress

<Append-only running log, updated as implementation proceeds — not
rewritten after the fact. Each entry dated, describing what was actually
done and what was found, not just what was planned.>

- YYYY-MM-DD: ...
