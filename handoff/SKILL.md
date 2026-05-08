---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up. Use when the user asks for a handoff, session summary, continuation note, or context package for the next agent or next session.
---

# Handoff

Write a handoff document summarizing the current conversation so a fresh agent can continue the work.

## Workflow

1. Create the destination file with:

   ```sh
   mktemp -t handoff-XXXXXX.md
   ```

2. Read the new file before writing to it.
3. Write the handoff document to that exact path.
4. Tell the user the path.

## What To Include

- Current objective and the user's latest intent.
- Relevant decisions, constraints, and assumptions.
- Current repository, branch, workspace, or external artifact context.
- Work already completed, including important file paths, commit SHAs, PRs, issues, plans, or diffs by reference.
- Work in progress, blockers, risks, and the next concrete steps.
- Commands already run and their important outcomes when they matter for continuity.
- Suggested skills for the next session, if any.

## Avoid Duplication

Do not duplicate content already captured in other artifacts such as PRDs, plans, ADRs, issues, commits, diffs, or generated files. Reference them by path, URL, branch, commit, or issue identifier instead.

## Arguments

If the user passes arguments, treat them as the next session's focus and tailor the handoff document accordingly. Emphasize the state, artifacts, and next steps most relevant to that focus.
