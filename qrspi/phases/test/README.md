---
phase: test
description: Use as QRSPI acceptance step after implementation/integration to verify goals, add acceptance tests when needed, and prepare PR summary.
---

# QRSPI Test

Announce: "I'm using QRSPI Test to verify the work against the original goals."

## Required inputs

- Approved `goals.md`
- Implemented code
- Full route: approved `design.md` or integration result when available
- Quick route: approved `research/summary.md`

## Steps

1. Re-read acceptance criteria in `goals.md`.
2. Map each criterion to verification:
   - existing tests
   - new acceptance/integration/E2E tests
   - manual verification
3. Add missing tests if appropriate, without changing production code.
4. Run full relevant test suite and focused commands.
5. If failures indicate production fixes, write fix tasks and route back:
   - quick route: Implement -> Test
   - full route: Implement -> Integrate -> Test
6. Present pass/fail matrix by acceptance criterion.
7. Ask user whether to accept, add tests, dispatch fixes, or stop.
8. If accepted, prepare PR/merge summary.
9. If more phases remain, use Replan; otherwise finish.

## Output

Prefer a concise final verification report with commands run and results.
