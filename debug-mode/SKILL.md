---
name: debug-mode
description: Cursor-style runtime debugging. Triggers on "debug mode", "help me debug", stack traces, failed fix loops, or intermittent/performance bugs. Generates competing hypotheses, instruments the code with HTTP-posted NDJSON log events tagged by hypothesisId, runs a local ingest server that writes to .cursor/debug-<hash>.log, analyzes the NDJSON, fixes, then deletes every instrumentation region.
---

# Debug Mode

Systematic debugging modeled on Cursor's debug mode: multiple competing
hypotheses, HTTP-based runtime instrumentation, NDJSON log file on disk,
surgical cleanup via region markers.

## When to activate

- User says "debug mode", "help me debug", "why is X happening"
- A fix attempt already failed once
- Bug is intermittent, performance-related, or spans async boundaries
- Stack trace alone isn't enough — you need runtime state

If the bug is a straightforward exception with an obvious cause, skip this
workflow and just fix it.

## Workflow

### 1. Hypothesize (before touching code)

Read enough of the codebase to propose **3–5 competing hypotheses**, then
pick the top 2 to instrument in parallel. Name them with short IDs (`A`,
`B`, `C`) — those IDs flow through every log event.

```
## Hypotheses
A. [most likely] PTY processes aren't being reaped after task completion
B. [likely]      SDK host isn't disposing its subscribers on session end
C. [possible]    Workspace poll loop keeps firing post-task

Instrumenting: A, B, C (sampler covers all three)
```

Never pick only one. The whole point of this mode is to let runtime data
decide between hypotheses rather than you guessing.

### 2. Start the ingest server

```bash
node ~/.claude/plugins/debug-mode/skills/debug-mode/scripts/log-server.js
```

Prints the session UUID, port, and the log file path it will append to
(`.cursor/debug-<short>.log`). Copy the `POST` URL and session ID shown on
startup — you'll paste them into the instrumentation.

Override with `--port 7695` or `--out .cursor` if needed.

### 3. Instrument

**Every edit goes inside a region block** so cleanup is mechanical:

```ts
// #region agent log
// Temporary instrumentation for <bug>. Remove when fixed.
// ... code ...
// #endregion
```

Each posted event carries:

| field          | purpose                                                  |
|----------------|----------------------------------------------------------|
| `hypothesisId` | `"A"`, `"B"`, `"sampler"` — ties the event to a guess    |
| `location`     | `"file:function"` or `"subsystem:event"`                 |
| `message`      | one short human line                                     |
| `data`         | structured details: IDs, counts, durations, sizes        |

Patterns to reach for:

- **One-shot events** (spawn, dispose, error) → post directly
- **Hot paths** (per-request, per-tick) → increment a counter; the sampler reports it
- **Ambient state** (CPU, memory, queue depth, open handles) → periodic sampler posting every 5 s with `hypothesisId: "sampler"`

Copy-paste-ready TypeScript/Python/Go/browser snippets including the
recorder + sampler pattern live in [references/client-snippets.md](references/client-snippets.md).

### 4. Reproduce

Ask the user to reproduce the bug with the instrumented build running.
Watch events stream in:

```bash
node ~/.claude/plugins/debug-mode/skills/debug-mode/scripts/read-logs.js --watch
```

If nothing arrives, the instrumented path isn't executing — check HMR
issues (Node/TS dev servers often need a full restart, not just a reload),
verify the `DEBUG_SERVER` URL matches the server's startup output, and
confirm requests aren't being blocked by CORS or CSP.

### 5. Analyze

Pull per-hypothesis slices and a rollup:

```bash
# Summary of event counts by hypothesis and location
node scripts/read-logs.js --summary

# Just hypothesis B
node scripts/read-logs.js --hyp B --tail 100

# Search messages
node scripts/read-logs.js --grep "pty exit"
```

State the conclusion in the form:

```
## Analysis
A (pty reap): FALSIFIED — ptySpawns=ptyExits across 40 samples, active=0
B (sdk host): CONFIRMED — sdkHostSpawns=17, sdkHostDisposes=9; 8 leaked
sampler: cpuPercent ramps 2% → 38% over 30s with no PTY activity
Root cause: session-runtime disposes the host on explicit end but not on
error paths; subscribers keep holding CPU via the subscribe callback.
```

Only move to a fix when the data actually narrows the cause. If results
are ambiguous, add more targeted logs rather than guessing.

### 6. Fix, verify, clean up

1. Implement the fix with instrumentation **still in place**
2. Reproduce again — the sampler should show the metric returning to baseline
3. Find every region:

   ```bash
   rg -l '#region agent log'
   ```

4. Delete each region in full (don't leave stubs behind)
5. Run the test suite and do one final manual reproduction without instrumentation

## Server and file layout

- **Ingest**: `POST http://127.0.0.1:<port>/ingest/<sessionId>` with header `X-Debug-Session-Id: <short>`, body is a single event or array of events
- **Response**: `204 No Content` on success
- **Storage**: `.cursor/debug-<short>.log` — one NDJSON event per line
- **Health check**: `GET /health` returns `{ ok, sessionId, logFile, events }`

This mirrors Cursor's debug-mode ingest (dynamic port, `/ingest/<uuid>`,
NDJSON into a `.cursor/debug-*.log`) so instrumentation written for one
environment works in the other.

## Anti-patterns

- Single hypothesis — you'll confirmation-bias your way into the wrong fix
- `console.log` with ad-hoc prefixes — unreliable to grep, gets committed by accident, no structured fields
- Posting inside a hot loop without a counter — floods the server and hides the signal
- Cleaning up by deleting specific lines — you'll miss some. Delete regions.
- Declaring the bug fixed because the error is gone. Confirm via the sampler that the underlying metric (CPU, handle count, memory) returned to baseline.

## Scripts

- [scripts/log-server.js](scripts/log-server.js) — NDJSON ingest server, writes `.cursor/debug-<short>.log`
- [scripts/read-logs.js](scripts/read-logs.js) — filter/tail/summarize the NDJSON log
- [references/client-snippets.md](references/client-snippets.md) — language-specific instrumentation templates
