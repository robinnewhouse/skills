---
name: qrspi
description: Use when the user wants a structured QRSPI-style development process. Top-level guide that routes to internal phase docs with progressive disclosure.
---

# QRSPI Pipeline

Use this skill to run a structured QRSPI development process. Verify artifacts, ask for approval between phases, and do not silently skip steps.

## Progressive phase docs

This is the only top-level QRSPI skill. The phase instructions live under `phases/` and should be loaded only when needed:

- Goals: `phases/goals/README.md`
- Questions: `phases/questions/README.md`
- Research: `phases/research/README.md`
- Design: `phases/design/README.md`
- Structure: `phases/structure/README.md`
- Plan: `phases/plan/README.md`
- Worktree: `phases/worktree/README.md`
- Implement: `phases/implement/README.md`
- Integrate: `phases/integrate/README.md`
- Test: `phases/test/README.md`
- Replan: `phases/replan/README.md`

Do not preload every phase doc. First use this router to determine the next phase, then read only that phase's `README.md` and follow it. If the selected phase redirects to another phase because prerequisites are missing, return to this router and open the needed phase doc.

## Start

Say: "I'm using the QRSPI pipeline."

## Artifact directory

Create or reuse a project-local artifact directory:

```text
docs/qrspi/YYYY-MM-DD-{short-slug}/
```

Keep all QRSPI artifacts for a run under that directory.

## Pipeline routes

### Full pipeline

Use for features, architectural changes, greenfield work, or changes touching several components:

1. Goals -> `goals.md`, `config.md`
2. Questions -> `questions.md`
3. Research -> `research/summary.md` and optional `research/q*.md`
4. Design -> `design.md`
5. Structure -> `structure.md`
6. Plan -> `plan.md` and `tasks/task-NN.md`
7. Worktree -> optional `parallelization.md` and worktree/branch plan
8. Implement -> code, tests, task commits/reviews
9. Integrate -> merge/integration review/CI gate
10. Test -> acceptance testing and PR readiness
11. Replan -> only between phases when more phases remain

### Quick fix route

Use for targeted bugs or small 1-3 file changes:

1. Goals
2. Questions
3. Research
4. Plan
5. Implement
6. Test

Skip Design, Structure, Worktree, and Integrate unless the work grows.

## Routing rules

- If no artifact directory exists: open `phases/goals/README.md`.
- If `goals.md` is approved but no `questions.md`: open `phases/questions/README.md`.
- If `questions.md` is approved but no `research/summary.md`: open `phases/research/README.md`.
- If full route and no approved `design.md`: open `phases/design/README.md`.
- If full route and no approved `structure.md`: open `phases/structure/README.md`.
- If no approved `plan.md` or task files: open `phases/plan/README.md`.
- If full route and tasks need isolated execution planning: open `phases/worktree/README.md`.
- If task specs exist and implementation is pending: open `phases/implement/README.md`.
- If full route tasks are implemented but not merged/reviewed: open `phases/integrate/README.md`.
- If implementation/integration is done: open `phases/test/README.md`.
- If acceptance passed and more phases remain: open `phases/replan/README.md`.

## Approval convention

Each artifact should start with YAML frontmatter:

```yaml
---
status: draft
created: YYYY-MM-DD
---
```

Only change `status: approved` after explicit user approval. If the user rejects an artifact, save feedback in `feedback/{phase}-round-NN.md` and regenerate or edit in response.

## Operating principles

- Keep artifacts reviewable and concise.
- Prefer fresh subagents for phase synthesis/review when useful.
- Ask the user before moving to the next phase.
- For implementation, use TDD: failing test first, then minimal code, then passing tests.
- Run the most relevant local tests before claiming a phase is complete.
- Preserve alignment between goals, research, design, structure, plan, implementation, and tests.
