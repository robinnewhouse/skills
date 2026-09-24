---
name: codex-consult
description: Consult Codex from the CLI as a persistent second reviewer,
  approver, or question-answering partner. Use when the user asks to consult
  Codex, ask Codex first, retain a Codex session, compare another model's
  judgment, or maintain a back-and-forth Codex review during implementation.
---

# Codex Consult

Use Codex as an advisory peer with persistent context. Create or resume one
CLI session, record its id, ask focused questions, and iterate on concrete
evidence until the disagreement is resolved or clearly stated.

## Start a session

Run Codex from the task's working directory. Use read-only mode for advice and
review. Use `workspace-write` only when the user has authorized Codex to edit.
Do not use `--ephemeral`, because the session must remain resumable.

```sh
CONSULT_DIR="/tmp/codex-consult/$(date +%F)-task-slug"
mkdir -p "$CONSULT_DIR"

codex exec --json --sandbox read-only \
  --output-last-message "$CONSULT_DIR/last-message.md" \
  "You are consulting on this task. Inspect the available evidence, identify risks, and answer concisely.

Task:
..." | tee "$CONSULT_DIR/events.jsonl"

CODEX_SESSION_ID="$(jq -r 'select(.type == "thread.started") | .thread_id' \
  "$CONSULT_DIR/events.jsonl" | head -n 1)"
printf '%s\n' "$CODEX_SESSION_ID" > "$CONSULT_DIR/session-id"
```

For a prompt file, redirect stdin without passing a literal `-`:

```sh
codex exec --json --sandbox read-only \
  --output-last-message "$CONSULT_DIR/last-message.md" \
  < "$CONSULT_DIR/prompt.md" | tee "$CONSULT_DIR/events.jsonl"
```

Verify that `CODEX_SESSION_ID` is a non-empty UUID and `last-message.md` is
non-empty. Do not trust exit code 0 alone: inspect the JSONL for error or failed
events because configuration and API failures may still exit successfully. The
`thread.started` event is Codex's source of truth for the new session id.

Also record:

- working directory
- reason Codex was consulted
- key approvals or disagreements

## Resume the same conversation

Resume from the original working directory so Codex sees the same repository
and project instructions.

```sh
CODEX_SESSION_ID="$(cat "$CONSULT_DIR/session-id")"

codex exec resume --json \
  --output-last-message "$CONSULT_DIR/last-message.md" \
  "$CODEX_SESSION_ID" \
  "Follow-up: review this new evidence and say whether it changes your prior recommendation.

Evidence:
..." | tee -a "$CONSULT_DIR/events.jsonl"
```

Use `--last` only when the session id is unavailable and no other recent Codex
session could be mistaken for this consultation.

## Before asking the user

When the user says to ask Codex first, consult Codex before sending any
non-trivial question. Ask whether the answer can be inferred from the repo,
logs, docs, or existing artifacts, what inspection would remove uncertainty,
and whether user input is still necessary.

Ask the user only when Codex and your own inspection agree that local discovery
is risky, impossible, or disproportionate. Mention the consultation and why
the question remains.

## Approval requests

When Codex is authorized to approve a phase, provide the concrete artifact and
request an explicit verdict:

```sh
codex exec resume "$CODEX_SESSION_ID" \
  "Approval request.

Phase: Research
Artifact: docs/.../research/summary.md

Review completeness and factual gaps. Reply with exactly one verdict line:
ACCEPTED
or
REVISE: <specific required changes>"
```

Treat `ACCEPTED` as approval only when the user explicitly authorized Codex to
approve that workflow. Otherwise it is advisory.

## Implementation review

Give Codex evidence rather than only the intended change:

- expected behavior and issue summary
- root-cause hypothesis
- relevant diff or file paths
- exact tests and results
- reproduction or verification data

Ask whether the fix reaches the root cause, what remains unexplained, which
edge cases or tests are missing, and what concise reviewer-facing explanation
fits the evidence.

## Resolve disagreement

If Codex finds a gap, inspect it yourself, fix it or gather the missing
evidence, then resume the same session. Repeat until Codex explicitly accepts
the current result or the remaining disagreement is a product preference,
unavailable evidence, or accepted risk. Report unresolved competing views and
recommend the lower-risk option.

Consensus requires both Codex's explicit acceptance and your own agreement.
Never hide a concrete Codex objection behind a generic approval summary.

## Practical rules

- Keep prompts focused and name concrete artifacts.
- Preserve the user's authorization boundary. Advice does not authorize edits,
  comments, merges, deployments, or other external actions.
- Use the current repository as the working directory. Add directories only
  when the task requires them and the user has authorized access.
- Never paste secrets, tokens, or private data into the prompt.
- Prefer `--sandbox read-only` for review. `codex exec` is non-interactive; do
  not add approval flags unless the installed command's help confirms them and
  the workflow needs them. Start a new `workspace-write` session only when
  edits are part of the authorized task.
- Omit `--model` unless the user requests a particular model.
- If the API rejects the configured default model as requiring a newer CLI,
  inspect the error and `codex --version`. Retry once with a model explicitly
  reported as supported by that installation, or tell the user an upgrade is
  required. Never run `codex update` without authorization.
- Outside a Git repository, add `--skip-git-repo-check` deliberately.
- Read the concise answer from `last-message.md`; keep JSONL for the session id
  and diagnostics rather than pasting the full event stream to the user.

## Long-running consults

Repository inspection can take several minutes without output. A quiet process
is not evidence that it is stuck. Keep waiting unless the process exits, emits
an actionable error, or exceeds a generous 10-15 minute safety limit. Provide
brief status updates during long waits. If a run must be stopped, explain why
and preserve the session artifacts before retrying.
