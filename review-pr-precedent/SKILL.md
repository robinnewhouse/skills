---
name: review-pr-precedent
description: Find related past pull requests, read their complete human review record, and compare recurring reviewer expectations with a current implementation or plan. Use for PR readiness, implementation or design review, and requests about related PRs, previous feedback, human comments, reviewer style, or "review vibes."
---

# Review PR Precedent

Produce an evidence-backed precedent review. Treat reviewer vibe as engineering preferences inferred from comments, not sentiment.

## Workflow

### 1. Establish the target

- Resolve the repository, current diff or PR, originating issue/spec, feature name, and relevant components.
- Resolve whose prior work to search. Infer the user identity from the current PR or known authored PRs when reliable; ask only when identity is genuinely ambiguous.
- Inspect the current implementation before deciding which precedent applies.

Completion criterion: the comparison target and author identity are explicit.

### 2. Build the candidate PR set

Search from several independent signals:

- issue and project IDs;
- feature, domain, and service names;
- important symbols and changed file paths;
- local `git log` and `git blame` history;
- PR descriptions, stacks, replacements, dependencies, and linked follow-ups;
- PR search scoped to the identified author.

Follow replacement and stack links until they stop yielding directly related work. Classify candidates as:

- **Direct lineage**: implements, replaces, enables, or fixes the same behavior.
- **Adjacent precedent**: touches a boundary or review concern that materially overlaps.

Reject search-result keyword matches that share vocabulary but not behavior. Record why every selected PR is relevant.

Completion criterion: every strong candidate is selected or rejected with a reason, and direct lineage is separated from adjacent precedent.

### 3. Read the complete human record

For every selected PR, fetch the merged discussion timeline plus inline review threads and review submissions when needed. Continue pagination or use a fallback API if results are truncated.

Read every non-empty human comment, including resolved threads and author replies. By default exclude:

- Arbiter and other review bots;
- CI, Linear linkbacks, code coverage, and generated status comments;
- empty approvals or review submissions.

Separate a reviewer's request from the author's explanation or resolution. Do not present the author's reply as independent reviewer feedback.

Completion criterion: all accessible human comments on every selected PR have been read, or an access/pagination gap is stated explicitly.

### 4. Extract precedent

Synthesize concrete engineering preferences, such as:

- explicit contracts versus inferred identity or hidden coupling;
- provider/consumer ownership and deployment order;
- correctness barriers versus best-effort cleanup;
- retry, cancellation, durability, and idempotency expectations;
- lifecycle coverage across every entry path;
- simplicity, naming, established helpers, and test value;
- observability and rollout cleanup obligations.

Keep direct comment links beside each theme. Distinguish repeated preferences from a single reviewer's isolated nit. Check whether old advice was superseded by a later PR or explicitly temporary rollout code.

### 5. Compare with the current work

Verify each precedent against the actual current diff and source. Classify it as:

- **Must fix**: the implementation repeats a concrete prior failure or violates an explicit rollout obligation.
- **Consider**: relevant judgment call with a real tradeoff.
- **Already follows**: current code embodies the precedent.
- **Does not apply**: similar language, different boundary or requirement.

A historical comment becomes a finding only when current evidence supports it. Call out any correction to an earlier review confidently and plainly.

### 6. Report concisely

Return:

1. direct-lineage and adjacent PRs, each linked;
2. the human review themes that matter;
3. must-fix and consider findings for the current work;
4. important precedents already satisfied;
5. any search or access limitation.

Lead with the current verdict. Use plain English and quote only short phrases when the exact wording matters.

## Guardrails

- Prefer live GitHub data; use memory and local history as leads, then verify them.
- Keep this workflow read-only. Change code or post comments only after an explicit follow-up request.
- Treat CI and automated review as status, not human precedent.
- Preserve confidence limits when author identity, deployment state, or comment completeness cannot be verified.
