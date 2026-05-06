---
phase: implement
description: Use as QRSPI implementation step after approved task specs; executes TDD per task, runs focused tests, and records review results.
---

# QRSPI Implement

Announce: "I'm using QRSPI Implement to execute tasks with TDD and review."

## Required inputs

- Approved task file(s)
- For quick tasks: approved `goals.md` and `research/summary.md`
- For full tasks: approved `goals.md`, `design.md`, `structure.md`, and optionally `parallelization.md`

## Iron rule

No production code without a failing test first, unless the user explicitly accepts a non-testable task such as docs-only work.

## Steps per task

1. Read the task spec and required artifacts.
2. Identify expected tests.
3. Write or update tests first.
4. Run tests and verify they fail for the intended reason.
5. Implement minimal production code.
6. Run focused tests until passing.
7. Run relevant typecheck/lint/build commands when practical.
8. Self-review for:
   - spec compliance
   - code quality/simplicity
   - silent failure paths
   - security risks
   - test coverage
9. Commit or summarize changes according to user preference.
10. Record review notes under `reviews/tasks/task-NN-review.md` when useful.
11. Next phase:
   - full route with multiple branches: Integrate
   - quick route or already merged work: Test

## Batch gate

After all tasks, present completed tasks, tests run, failures/risks, and ask before moving on.
