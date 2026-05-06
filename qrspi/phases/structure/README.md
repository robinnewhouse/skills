---
phase: structure
description: Use as QRSPI full-pipeline step 5 after approved design.md to map vertical slices to files, interfaces, and component boundaries.
---

# QRSPI Structure

Announce: "I'm using QRSPI Structure to map the design to files and interfaces."

## Required inputs

- Approved `goals.md`
- Approved `research/summary.md`
- Approved `design.md`

## Steps

1. Read the approved artifacts.
2. Map each vertical slice to exact files/modules/components.
3. Mark each file as create/modify/delete.
4. Define interfaces and contracts without implementing them.
5. Identify dependencies between slices/components.
6. Write `structure.md`.
7. Present for approval.
8. On approval, mark it `status: approved`.
9. Tell the user the next phase is Plan, then return to the router before opening `phases/plan/README.md`.

## `structure.md` should include

- File/component map by vertical slice
- Interface/function/class signatures where useful
- Data model changes
- Test file locations
- Dependency graph
- Migration or compatibility notes
- Risks and assumptions
