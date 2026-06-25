---
name: consult-cline
description: Consult Cline from the CLI as a persistent second reviewer,
  approver, or question-answering partner. Use when the user asks to "ask
  Cline", "ask Cline first", keep a Cline session id, get Cline's approval for
  QRSPI or similar phases, compare another model's judgment before asking the
  user, or maintain a back-and-forth Cline consultation during implementation.
  Takes an optional model parameter; defaults to claude-opus-4-7.
disabled: true
---

# Consult Cline

Use Cline as an advisory peer with persistent context. The core pattern is: create or resume one CLI session, save the session id, ask focused questions, iterate on evidence until consensus is reached, and record decisions that affect the work.

## Model Selection

Default model: `claude-opus-4-7`. Accept alternate model via the `model` parameter, e.g.:

```
/consult-cline model=claude-sonnet-4-5
```

When a model is provided, pass it via `--model` on every invocation.

## Start A Session

Prefer a named, explicit session id instead of relying on `--continue`; it makes later resumes deterministic.

```sh
CLINE_SESSION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
cline -p --session-id "$CLINE_SESSION_ID" --model claude-opus-4-7 \
  "You are consulting on this task. Read the prompt below, identify risks, and answer concisely.

Task:
..."
```

Record the session id somewhere durable for the task, for example:

```text
docs/qrspi/YYYY-MM-DD-task-slug/cline-session.md
```

At minimum, save:

- session id
- model used
- working directory
- reason Cline was consulted
- key approvals or disagreements

## Resume The Same Conversation

Reuse the same session id for follow-up questions so Cline retains task context.

```sh
cline -p --resume "$CLINE_SESSION_ID" --model claude-opus-4-7 \
  "Follow-up: review this new evidence and say whether it changes your prior recommendation.

Evidence:
..."
```

If the command cannot resume by id, retry with:

```sh
cline -p -r "$CLINE_SESSION_ID" --model claude-opus-4-7 "..."
```

## Before Asking The User

When the user says to ask Cline first, consult Cline before sending the user any non-trivial question.

Ask Cline:

- whether the answer can be inferred from the repo, logs, docs, or existing artifacts
- what command or inspection would remove the uncertainty
- whether the user question is still necessary

Only ask the user when Cline and your own inspection agree that local discovery would be risky, impossible, or too costly. If asking the user is still necessary, mention that Cline was consulted first and summarize why the question remains.

## QRSPI Approval Pattern

When Cline is authorized to approve QRSPI phases, provide the artifact path and ask for an explicit verdict.

```sh
cline -p --resume "$CLINE_SESSION_ID" --model claude-opus-4-7 \
  "QRSPI approval request.

Phase: Research
Artifact: docs/qrspi/.../research/summary.md

Please review for completeness, factual gaps, and whether implementation can proceed.
Reply with exactly one verdict line:
ACCEPTED
or
REVISE: <specific required changes>"
```

Treat `ACCEPTED` as approval only if the user has explicitly authorized Cline to approve that phase or workflow. Otherwise, use Cline's response as advisory and ask the user for final approval.

## Implementation Review Pattern

For bug fixes or PR readiness, ask Cline to review the concrete evidence, not just the intended fix.

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

If Cline disagrees with your plan or finds a gap:

1. Inspect the evidence yourself.
2. Fix the issue or run the missing check when practical.
3. Resume the same Cline session with the new evidence.
4. Ask Cline whether the new evidence resolves the concern.
5. Continue this loop until you and Cline reach consensus, or until the remaining disagreement is clearly about product preference, unavailable evidence, or an explicit risk tradeoff.
6. If consensus cannot be reached, tell the user the competing views, what evidence was checked, and recommend the lower-risk path.

Do not hide Cline disagreement behind a generic "looks good" summary.

## Consensus Standard

Treat Cline consultation as an iterative review loop, not a one-shot vote.

Consensus is reached when:

- Cline explicitly accepts the current artifact, plan, fix, or test evidence
- your own inspection agrees with Cline's verdict
- any earlier Cline objections are either fixed, disproven by evidence, or documented as accepted tradeoffs

For approval workflows, do not mark a phase or implementation as approved while Cline has unresolved concrete objections, unless the user explicitly overrules them.

## Practical Rules

- Keep prompts focused; Cline is most useful as a reviewer of artifacts and evidence.
- Use the current repo as `cwd`; add `--add-dir` only when Cline needs files outside it.
- Do not paste secrets, tokens, or private data unless the user explicitly authorized that exposure.
- Use `--permission-mode acceptEdits` for code-review and approval workflows. Use a stricter mode if the user only wants read-only advice.
- Do not let Cline make user-visible decisions unless the user authorized that role.
- If Cline output is long, summarize the actionable verdict and save only the important details in the task notes.
