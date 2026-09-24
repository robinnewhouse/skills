---
name: ascii-progress-board
description: Render Robin's preferred honest ASCII status board for multi-workstream projects. Use when Robin asks where work stands, requests progress or status across workstreams, or wants a workstream diagram.
---

# ASCII Progress Board

Produce one fenced code block containing the following four sections in order. Pull live state first from the relevant sources, such as conversation or agent history, PR status, and recent workstream activity. If live state is inaccessible, state that limitation instead of presenting stale status as current.

## 1. Workstream map

Draw an ASCII dependency graph grouped by relationship, not as a flat list. Use headings such as `INDEPENDENT TRACK`, `CRITICAL PATH`, `PARALLEL`, and `EXTERNAL (not ours)` when applicable.

- Give every node a stable bracketed ID such as `[A]`, `[B]`, or `[C1]` and name its owner on the same line. `Nobody yet` is a valid owner.
- Reuse each ID throughout the board.
- Draw dependencies with `──▶`.
- Mark unowned work with `✗ not spawned` or `⛔`.
- Add a one-line parenthetical below any ambiguous node.

## 2. Progress board

Use 20-cell bars. `▓` means done, `▒` in motion, and `░` untouched. Prefix every estimated percentage with `~`; use `?` when unknown. Keep bars honest, never generous.

Use only these states: `▶ running`, `⛔ gated on [X]`, `💤 endorsed, unscheduled`, and `✗ not spawned`. Every gated item must name its gate by ID.

Add a `└` reality-check line below every non-zero bar. Say what is actually failing, prep-only, or stalled.

```text
                              0%        50%       100%
  [A] short name              ▓▓▓▓▓▓▓▓▓▓▓▒▒░░░░░░░  ~60%  ▶ running
       └ one-line reality check
```

## 3. Project trust axis

Identify what a stakeholder would wrongly conclude from the progress bars alone, then draw that as a second axis.

Adapt the axis to the project. Examples include trust in benchmark numbers, migration reversibility, deploy blast radius, estimate confidence, or how load-bearing a result is. Show completed but untrustworthy results separately from the result actually needed.

```text
     100%  "label"
           trust: [██░░░░░░░░]  ← why it can or cannot bear weight

        ?  "the result actually needed"
           trust: [ ? ? ? ? ? ]  ← does not exist yet, gated on [B] → [D]
```

## 4. Where it really stands

Draw a short vertical runway from the current point to the goal, followed by two or three plain-English assessment sentences.

```text
   ┌─ we are HERE
   ▼
   ├─ milestone ────── unknown, hours away
   ├─ milestone ────── behind that
   └─ milestone ────── behind <external blocker>
```

End with the uncomfortable, load-bearing observation that a polished status deck would bury.

## Output rules

- Put the entire board in a fenced code block so alignment holds.
- Use no emoji beyond the four state glyphs above.
- Mark estimates with `~`; mark unknowns with `?`, never a guessed bar.
- Name an owner on every workstream node.
- Keep all IDs consistent across all four sections.
