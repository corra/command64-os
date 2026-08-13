---
description: Require a detailed, approved plan for every Phase and Work Package before implementation begins, and a walkthrough with explicit sign-off before it's marked complete
---

# Phased Implementation Planning Workflow

This project organizes large efforts (CASM, DASH, DEBUG's REU work, etc.)
into numbered **Phases**, each broken into **Work Packages** (WP56, WP60,
WP63, ...). This workflow is the contract for how a Phase or Work Package
moves from "next thing to do" to "done" — it is not optional ceremony; it
is how this project has actually operated across every closed phase to
date (CASM Phases 1-11, DEBUG's REU work, DASH's WP1-10), and every
skipped step here has previously cost real rework.

## When to use

- Starting a new Phase (the first Work Package in it).
- Starting a new Work Package within an already-active Phase.
- Any effort large enough that "just start coding" would leave no record
  of what was decided, why, or what "done" means — if in doubt, err
  toward writing the plan.

Small, self-contained fixes (a one-line bug fix, a doc typo) don't need
this — use judgment, but the numbered Phase/WP structure itself always
does.

## The rule

**No implementation begins until a detailed plan for that specific Phase
or Work Package exists in `brain/plans/`, has been recorded, and has been
explicitly approved by the user.** Write each phase's detailed sub-plan
and record it *before* implementing that phase — not a rough outline, the
real thing: a plan a stranger could pick up and execute without
re-deriving your own reasoning.

**No Phase or Work Package is marked complete until:**

1. A completion-gate walkthrough exists in `brain/walkthroughs/`
   recording what was actually verified (live evidence, not claims).
2. The user has given explicit approval to close it — never self-declare
   completion. A plan being "done" in your own judgment is not the same
   as the user approving it.

## Plan structure

Use `brain/plans/_TEMPLATE_PHASE_WP.md` as the starting skeleton for any
Phase or Work Package plan. It captures the structure that's proven out
across every WP plan referenced in this workflow — some sections won't
apply to every WP (a documentation-only WP has no ABI/register contract
to declare); drop what's inapplicable rather than filling it with
boilerplate, but don't drop `Atomic Increments`, `Stop Conditions`, or
`Completion Gate` — those three are load-bearing for every plan regardless
of size.

Filename convention: `brain/plans/YYYY-MM-DD-<feature-slug>.md`, e.g.
`brain/plans/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`.

## Scoping decisions need to be explicit, not assumed

When a plan has to make a judgment call the user hasn't already settled
(build scope, whether to fix vs. defer a found defect, how much live
verification is "enough"), **ask before drafting**, record the answers as
a dated `Scoping Decisions` section, and cite them by number in the rest
of the plan. Don't silently assume a default and mention it only in
passing — WP63's plan is a good model (four scoping questions asked and
recorded before a line of the plan itself was written).

## Deviating from an approved plan

A plan's Stop Conditions exist for a reason: if live work uncovers a
genuine defect outside a plan's stated scope, the plan's own default is
**disclose and defer** — stop, record the finding, and treat fixing it as
a separately scoped, separately approved follow-up. Only fix inline if the
user explicitly directs it in the moment (see WP63: a real dangling-vector
defect was found during verification, and the user explicitly overrode
the disclose-and-defer default to have it fixed within the same WP — that
deviation, and the reasoning, is recorded in the plan and walkthrough, not
silently absorbed).

## Completion gate

The walkthrough (`brain/walkthroughs/YYYY-MM-DD-<feature-slug>.md`,
matching the plan's own filename) is where live evidence lives: what was
actually run, what the actual output was, what was found and disclosed,
what's still open. It is not a summary of intentions — every claim in it
should be something you actually observed (a screen showing `PASS`, a
`diff` showing byte-identical output, a build log showing zero errors),
not something you expect to be true. See
`brain/walkthroughs/2026-08-08-casm-phase10-wp55-verification-walkthrough-completion-gate.md`
and
`brain/walkthroughs/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`
as worked examples — including how each documents disclosed findings that
didn't block completion, and (WP63) a mid-course defect and fix.

Before asking for completion approval, synchronize every tracker the plan
touches: Taskwarrior, `brain/task.md`, the relevant `wiki/tasks/*.md`,
`brain/KNOWLEDGE.md` (a closing note on the *existing* phase section, not
a new one, once the phase has an existing section), `CHANGELOG.md`, and
memory (a durable project-type memory superseding any stale in-progress
snapshot — see [[project-casm-phase11-complete]] for the pattern, including
a `reference`-type memory for any genuinely reusable technical finding).

## Multi-WP phases

A Phase closes only when its own closing Work Package (mirroring WP49/
WP55/WP63's own precedent) does a **consolidated** live re-verification —
not just citing each WP's own individual verification, but actually
re-running everything together in one continuous session. This is
deliberate: WP63 found a real defect specifically *because* it was the
first session to run every harness back-to-back without a reset between
them — individual per-WP verification had never exercised that
interaction. Don't skip the consolidated pass on the assumption that
"each piece already passed on its own."
