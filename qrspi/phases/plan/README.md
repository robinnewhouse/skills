---
phase: plan
description: Use as QRSPI step 6 to create plan.md and self-contained task specs after approved prerequisites; supports full and quick routes.
---

# QRSPI Plan

Announce: "I'm using QRSPI Plan to create self-contained task specs."

## Required inputs

Read `config.md` to determine route.

Full route requires approved:
- `goals.md`
- `research/summary.md`
- `design.md`
- `structure.md`

Quick route requires approved:
- `goals.md`
- `research/summary.md`

## Steps

1. Verify required artifacts are approved.
2. Produce `plan.md` with phases, task order, dependencies, and verification strategy.
3. Produce `tasks/task-NN.md` files.
4. Every task must be self-contained and include:
   - purpose
   - exact files to touch
   - implementation notes
   - test expectations
   - dependencies
   - estimated size/risk
   - `pipeline: quick|full` in frontmatter
5. Present `plan.md` and task list for approval.
6. On approval, mark `plan.md` and task files `status: approved`.
7. Next phase:
   - full route with multiple/parallel tasks: Worktree
   - quick route or simple sequential task: Implement

## Avoid

No TBDs, placeholders, or "same as previous task". Each implementation agent should be able to work from only its task file plus named artifacts.
