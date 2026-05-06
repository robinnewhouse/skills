---
phase: worktree
description: Use as QRSPI full-pipeline step 7 after approved plan/tasks to decide sequential vs parallel execution and optionally create git worktrees.
---

# QRSPI Worktree

Announce: "I'm using QRSPI Worktree to plan isolated task execution."

## Required inputs

- Approved `plan.md`
- Approved `tasks/task-NN.md`
- Full route in `config.md`

Skip this phase for quick fixes unless isolation is helpful.

## Steps

1. Read all task specs.
2. Build a dependency graph.
3. Decide execution mode:
   - sequential: chained dependencies or same files
   - parallel: independent tasks, separate files
   - hybrid: parallel groups with sequential gates
4. Run baseline tests if practical.
5. If using worktrees, create one worktree/branch per independent task or group.
6. Write `parallelization.md` with branch/worktree map and execution order.
7. Present plan for user approval.
8. On approval, mark it `status: approved`.
9. Tell the user the next phase is Implement, then return to the router before opening `phases/implement/README.md`.

## Safety

Do not create many worktrees for tiny or tightly coupled tasks. Prefer simplicity when parallelism does not clearly help.
