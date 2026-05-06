---
phase: replan
description: Use between QRSPI phases after acceptance testing when more phases remain; updates remaining tasks or loops back to design/structure for major changes.
---

# QRSPI Replan

Announce: "I'm using QRSPI Replan to update the remaining plan based on phase learnings."

## Required inputs

- Completed phase changes
- Test/integration/review results
- Approved `plan.md`
- Remaining task specs
- Approved `design.md` for full route

## Steps

1. Summarize lessons from the completed phase.
2. Identify needed changes to remaining work.
3. Classify each change:
   - Minor: task wording, estimates, task split/merge within existing design, dependency ordering
   - Major: new files/paths, interface changes, technology choices, architecture, phase boundaries, vertical slices
4. Present proposed changes and classifications to the user.
5. If approved minor changes: update `plan.md` and `tasks/*.md`, then ask for re-approval.
6. If approved major changes: loop back to the earliest affected phase:
   - file/path/interface changes -> Structure
   - architecture/technology/slice/phase changes -> Design
7. Save feedback under `feedback/replan-phase-NN-round-MM.md` when useful.
8. After re-approval, continue to Worktree or Implement for the next phase.

## Rule

Do not classify a major design or structure change as minor just to avoid re-approval.
