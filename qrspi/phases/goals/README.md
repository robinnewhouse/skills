---
phase: goals
description: Use as QRSPI step 1 to capture intent, constraints, acceptance criteria, and choose full vs quick route; produces goals.md and config.md.
---

# QRSPI Goals

Announce: "I'm using QRSPI Goals to capture intent, constraints, and acceptance criteria."

## Purpose

Turn the user's request into an approved, testable goals artifact and choose the route: `full` or `quick`.

## Steps

1. Create or select `docs/qrspi/YYYY-MM-DD-{slug}/`.
2. Ask enough questions to capture:
   - purpose and user value
   - in-scope and out-of-scope work
   - constraints and risks
   - observable acceptance criteria
   - likely test/verification commands
3. Recommend `quick` or `full` route:
   - `quick`: targeted bug/small 1-3 file change
   - `full`: feature, architecture, multi-component, or uncertain design
4. Write `config.md` with route and settings.
5. Write `goals.md` with concrete acceptance criteria.
6. Present both artifacts and ask for approval.
7. Only after explicit approval, mark `goals.md` as `status: approved`.
8. Tell the user the next phase is Questions, then return to the router before opening `phases/questions/README.md`.

## Artifact requirements

`config.md` should include:

```yaml
---
created: YYYY-MM-DD
pipeline: quick|full
route:
  - goals
  - questions
  - research
  # ...
review_depth: quick|deep
review_mode: single|loop
---
```

`goals.md` should include:

- Problem / intent
- Users or stakeholders
- Scope
- Non-goals
- Constraints
- Risks / unknowns
- Acceptance criteria with measurable pass/fail language
- Suggested verification commands

## Quality bar

Reject vague criteria like "works well" or "feels fast". Replace them with observable behavior.
