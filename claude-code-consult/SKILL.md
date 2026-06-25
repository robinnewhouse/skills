---
name: claude-code-consult
description: Consult Claude Code from the CLI as a persistent second reviewer,
  approver, or question-answering partner. Use when the user asks to "ask
  Claude", "ask Claude Code first", keep a Claude session id, get Claude's
  approval for QRSPI or similar phases, compare another model's judgment before
  asking the user, or maintain a back-and-forth Claude consultation during
  implementation.
---

# Claude Code Consult

Use Claude Code as an advisory peer with persistent context. The core pattern is: create or resume one CLI session, save the session id, ask focused questions, iterate on evidence until consensus is reached, and record decisions that affect the work.

## Start A Session

Prefer a named, explicit session id instead of relying on `--continue`; it makes later resumes deterministic.

```sh
CLAUDE_SESSION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
claude -p --session-id "$CLAUDE_SESSION_ID" --permission-mode acceptEdits \
  "You are consulting on this task. Read the prompt below, identify risks, and answer concisely.

Task:
..."
```

Record the session id somewhere durable for the task, for example:

```text
/tmp/claude-code-session/YYYY-MM-DD-task-slug/claude-session.md
```

At minimum, save:

- session id
- working directory
- reason Claude was consulted
- key approvals or disagreements

## Resume The Same Conversation

Reuse the same session id for follow-up questions so Claude retains task context.

```sh
claude -p --resume "$CLAUDE_SESSION_ID" --permission-mode acceptEdits \
  "Follow-up: review this new evidence and say whether it changes your prior recommendation.

Evidence:
..."
```

If the command cannot resume by id, retry with:

```sh
claude -p -r "$CLAUDE_SESSION_ID" --permission-mode acceptEdits "..."
```

## Before Asking The User

When the user says to ask Claude first, consult Claude before sending the user any non-trivial question.

Ask Claude:

- whether the answer can be inferred from the repo, logs, docs, or existing artifacts
- what command or inspection would remove the uncertainty
- whether the user question is still necessary

Only ask the user when Claude and your own inspection agree that local discovery would be risky, impossible, or too costly. If asking the user is still necessary, mention that Claude was consulted first and summarize why the question remains.

## QRSPI Approval Pattern

When Claude is authorized to approve QRSPI phases, provide the artifact path and ask for an explicit verdict.

```sh
claude -p --resume "$CLAUDE_SESSION_ID" --permission-mode acceptEdits \
  "QRSPI approval request.

Phase: Research
Artifact: docs/qrspi/.../research/summary.md

Please review for completeness, factual gaps, and whether implementation can proceed.
Reply with exactly one verdict line:
ACCEPTED
or
REVISE: <specific required changes>"
```

Treat `ACCEPTED` as approval only if the user has explicitly authorized Claude to approve that phase or workflow. Otherwise, use Claude's response as advisory and ask the user for final approval.

## Implementation Review Pattern

For bug fixes or PR readiness, ask Claude to review the concrete evidence, not just the intended fix.

Include:

- issue summary and expected behavior
- root-cause hypothesis
- relevant diff or file paths
- exact tests run and results
- reproduction or verification data

Ask for:

- whether the fix addresses the root cause
- whether any symptom remains unexplained
- missing tests or edge cases
- a short PR-ready statement of the issue

## Handling Disagreement

If Claude disagrees with your plan or finds a gap:

1. Inspect the evidence yourself.
2. Fix the issue or run the missing check when practical.
3. Resume the same Claude session with the new evidence.
4. Ask Claude whether the new evidence resolves the concern.
5. Continue this loop until you and Claude reach consensus, or until the remaining disagreement is clearly about product preference, unavailable evidence, or an explicit risk tradeoff.
6. If consensus cannot be reached, tell the user the competing views, what evidence was checked, and recommend the lower-risk path.

Do not hide Claude disagreement behind a generic "looks good" summary.

## Consensus Standard

Treat Claude consultation as an iterative review loop, not a one-shot vote.

Consensus is reached when:

- Claude explicitly accepts the current artifact, plan, fix, or test evidence
- your own inspection agrees with Claude's verdict
- any earlier Claude objections are either fixed, disproven by evidence, or documented as accepted tradeoffs

For approval workflows, do not mark a phase or implementation as approved while Claude has unresolved concrete objections, unless the user explicitly overrules them.

## Practical Rules

- Keep prompts focused; Claude is most useful as a reviewer of artifacts and evidence.
- Use the current repo as `cwd`; add `--add-dir` only when Claude needs files outside it.
- Do not paste secrets, tokens, or private data unless the user explicitly authorized that exposure.
- Use `--permission-mode acceptEdits` for code-review and approval workflows. Use a stricter mode if the user only wants read-only advice.
- Do not let Claude make user-visible decisions unless the user authorized that role.
- If Claude output is long, summarize the actionable verdict and save only the important details in the task notes.

## Long-Running Consults

Claude Code can take several minutes before producing any output, especially when
it is inspecting a repo, reading multiple files, or performing a design/code
review. Treat a quiet Claude process as normal unless there is concrete evidence
that it is blocked.

- Do not kill, retry, or replace a Claude request with a tighter prompt merely
  because there has been no output for 1-3 minutes.
- Do not wrap Claude invocations in short `timeout` windows. If a timeout is
  necessary for automation safety, use a generous limit, such as 10-15 minutes,
  and explain that limit in the command context.
- If the user asks to consult Claude on a broad artifact, preserve the broad
  prompt and wait. Only narrow the prompt after Claude fails, exceeds the
  generous timeout, or the user explicitly asks for a narrower consultation.
- While waiting, poll the session and provide brief status updates. If needed,
  use `ps` to confirm the Claude process is still running rather than assuming
  it is hung.
- If a Claude process must be stopped, state why and avoid starting a replacement
  with materially different scope without user approval.
