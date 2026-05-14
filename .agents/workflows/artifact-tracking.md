---
description: Track implementation plans, walkthroughs, and tasks in the project brain directory
---

# Artifact Tracking Workflow

This workflow ensures that every significant feature, bug fix, or architectural change is formally documented in the project's `brain/` directory. These records persist across sessions, agents, and repositories.

> **Important:** This workflow **supplements** the per-conversation Antigravity artifacts. Both locations are maintained — the project brain is the canonical, git-tracked copy.

## When to Run

- At the **start** of any feature, refactor, or multi-step bug fix (create the plan)
- At the **end** of any completed feature (create the walkthrough)
- At the **start and end** of every session (update `brain/task.md`)

## Steps

### Before Implementation

1. **Create a plan** at `brain/plans/<feature-slug>.md` using the template at `brain/plans/_TEMPLATE.md`. Include:
   - Goal and rationale
   - Files that will be modified or created
   - Key design decisions
   - Verification plan (tests, manual checks)

2. **Update `brain/task.md`** to add the new feature as `[/]` (in progress).

### After Implementation

3. **Create a walkthrough** at `brain/walkthroughs/<feature-slug>.md` using the template at `brain/walkthroughs/_TEMPLATE.md`. Include:
   - Summary of what was implemented
   - Table of files changed
   - Testing results (test count, what's covered)
   - Lessons learned or gotchas

4. **Update `brain/task.md`** to mark the feature as `[x]` (completed).

5. **Update `brain/MEMORY.md`** to reflect the new project state.

### Suspending Work (WIP Handoff)

When pausing work on an in-progress feature (end of session, switching machines, etc.):

1. **Update `brain/MEMORY.md`** with detailed progress within the feature:
   - Which sub-steps are done (e.g., "lexer and parser complete")
   - What is partially done and where you left off
   - What remains to be done
   - Any decisions made during implementation not yet in the plan

2. **Annotate the plan** at `brain/plans/<feature-slug>.md`:
   - Add a `## Progress` section at the bottom with the current state
   - Note any design changes discovered during implementation

3. **Ensure `brain/task.md`** still shows the feature as `[/]` (in progress).

4. **Commit with a `wip:` prefix** and include all brain artifacts alongside the code:

   ```
   wip(<scope>): <description of partial progress>
   ```

   Stage **both** the source changes and the brain artifacts together so the
   repository is self-describing at every commit.

5. **Resuming work:** When picking up a suspended feature, read `brain/MEMORY.md`
   and the plan's `## Progress` section *before* touching any code. Update
   `brain/MEMORY.md` to note the new session.

### Naming Convention

Use kebab-case slugs that match between plans and walkthroughs. 
Create new slugs as needed. Use judgement:

| Feature | Plan | Walkthrough |
|---------|------|-------------|


### Scope

Not every commit needs a plan and walkthrough. Use judgment:

| Change Type | Plan? | Walkthrough? | task.md? |
|-------------|-------|-------------|----------|
| New language feature | ✅ | ✅ | ✅ |
| Multi-step refactor | ✅ | ✅ | ✅ |
| Bug fix (multi-file) | ✅ | ✅ | ✅ |
| Code review (multi-finding) | ✅ | ✅ | ✅ |
| One-line bug fix | ❌ | ❌ | ❌ |
| Documentation update | ❌ | ❌ | ❌ |
| Dependency bumps | ❌ | ❌ | ❌ |

### Code Reviews

Code reviews produce their own artifact type stored in `brain/reviews/`:

1. **Conduct the review** → `brain/reviews/<date>_<slug>.md` with findings and scorecard
2. **Create a remediation plan** → `brain/plans/<date>_<slug>code-review-remediation.md`
3. **Implement fixes** → follow normal plan → implement → verify cycle
4. **Update the review artifact** with remediation status

## Quality Bar

- **Plans are written before code.** They are the "why" and "what" — not a post-hoc rationalization.
- **Walkthroughs are written after verification.** They are proof of work, not aspirational.
- **Retroactive records are clearly marked.** Use the `> [!NOTE] Retroactive record` banner.
