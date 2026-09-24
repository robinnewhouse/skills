# Explaining real code

## Establish the evidence

Record the repository and revision, relevant paths/symbols, and any uncommitted changes that affect the explanation. Read the entry point, responsible implementation, important callers/callees, and relevant tests. Follow one concrete execution before drawing a broad architecture map.

Identify the input/output contract, state owner, important side effects, invariant, and failure behavior. For asynchronous code, inspect ordering, retries, cancellation, cleanup, and ownership changes when relevant to the question. Do not infer behavior from names alone.

Prefer a minimal executable example or existing test that demonstrates the narrated behavior. Capture its inputs, environment assumptions, events, and outputs. Keep verification isolated from unrelated working-tree changes. If execution is unavailable, distinguish what follows directly from the source from an unverified runtime assumption.

Every material claim should map to a source location or observed result. A compact evidence table in the project notes is enough:

| Claim | Source/revision | Check or observation | Qualification |
|---|---|---|---|
| What the viewer learns | File and symbol | Test, trace, or source reasoning | Limits of the claim |

## Choose the visual form

| Learning question | Useful form |
|---|---|
| What does this function do? | Worked input, short code excerpt, evolving state, output |
| Why did this behavior occur? | Execution trace with cause and consequence |
| What changes if this condition changes? | Matched examples with one controlled difference |
| Where did this value come from? | Data provenance through transformations |
| What happens across awaits or retries? | Event lanes with explicit ownership and ordering |
| How do these modules cooperate? | Follow one request through a small system map |
| Why this abstraction? | Concrete repetition followed by the extracted rule |

Choose one primary form. A full editor recreation or typing animation is useful only when the act of editing is part of the lesson.

## Keep the picture faithful

Use one event model to drive the active code, state display, arrows, and output. For example, a trace event can carry an ID, source symbol/span, event kind, before/after state, and visible result; the video timeline assigns its presentation frame. Exact schema is project-specific.

Preserve source text when claiming to show actual code. Label pseudocode, omitted setup, reduced examples, and illustrative values. Keep a visible link between each excerpt and its file/symbol; do not cram the whole file into the frame. Highlight the smallest meaningful expression or block and explain its purpose.

Distinguish three evidence modes in the project notes and on screen where viewers could confuse them:

- **Live execution:** the displayed result was obtained by running the current example.
- **Recorded trace:** the animation replays an observed run. It does not execute arbitrary new input.
- **Illustrative simulation:** a constructed sequence demonstrates an explanation. It is not runtime evidence.

A video's presentation timing is usually chosen for teaching. Do not imply measured latency, concurrency, or relative speed unless the trace actually supports it. A valid possible asynchronous ordering is not necessarily the only ordering.

Animate a change of state at the correct event. Interpolate spatial motion freely when useful, but do not tween discrete facts such as status codes, identifiers, enum values, or years into invented intermediate facts.

## Check the lesson

Ask whether a viewer could predict a nearby case, explain the causal step, and locate the responsible implementation. Include a brief pause and reveal for a prediction when it fits the duration. This is a design check, not evidence that human comprehension has been measured.

Recheck the trace against the final script after edits. Watch particularly for a new narration order leaving an old highlight, a simplified diagram hiding an essential owner, or a happy-path example being narrated as a universal guarantee.
