---
phase: integrate
description: Use as QRSPI full-pipeline integration step after implemented tasks to merge branches, run integration/security review, and check CI/tests.
---

# QRSPI Integrate

Announce: "I'm using QRSPI Integrate to merge work and verify cross-task behavior."

## Required inputs

- Implemented task branches/worktrees or completed task changes
- Task review notes if present
- Approved `design.md`, `structure.md`, and `parallelization.md` when available

Skip for quick route unless there are multiple independently implemented pieces.

## Steps

1. Confirm all current-phase tasks are complete.
2. Merge task branches/worktrees into the feature branch, or verify already-merged changes.
3. Resolve conflicts only with user awareness when non-trivial.
4. Run integration review:
   - do components work together?
   - do interfaces match structure/design?
   - are security boundaries preserved?
5. Run relevant test suite/CI command locally when possible.
6. If failures occur, write fix tasks under `fixes/integration-round-NN/` or `fixes/ci-round-NN/` and route back to Implement.
7. Present integration status for approval.
8. On approval, proceed to Test.

## Rule

Do not directly sneak in production fixes during integration. Turn them into explicit fix tasks unless they are trivial conflict-resolution edits approved by the user.
