---
phase: design
description: Use as QRSPI full-pipeline step 4 after approved goals and research to choose architecture, vertical slices, phases, and test strategy.
---

# QRSPI Design

Announce: "I'm using QRSPI Design to compare approaches and define the architecture."

## Required inputs

- Approved `goals.md`
- Approved `research/summary.md`

If quick route is selected, skip this phase and use Plan.

## Steps

1. Read goals and research.
2. Propose 2-3 viable approaches with tradeoffs.
3. Recommend one approach and ask the user to converge.
4. Define vertical slices, not horizontal layers.
5. Define phases if the work is large. Phase 1 should prove the end-to-end path.
6. Define test strategy.
7. Write `design.md`.
8. Present for approval.
9. On approval, mark it `status: approved`.
10. Tell the user the next phase is Structure, then return to the router before opening `phases/structure/README.md`.

## `design.md` should include

- Context and chosen approach
- Alternatives considered
- Architecture overview
- Vertical slices
- Phase boundaries and replan gates
- Data/control flow, ideally with Mermaid when useful
- Test strategy
- Risks and unresolved decisions
