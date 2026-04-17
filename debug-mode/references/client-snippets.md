# Debug Client Snippets

Instrumentation snippets that match the Cursor debug-mode pattern. All
instrumentation must live inside a `// #region agent log` … `// #endregion`
block so cleanup is mechanical: delete the regions, done.

Key conventions:

- **`hypothesisId`** — short tag (`"A"`, `"B"`, `"sampler"`) tying an event to a specific hypothesis. Lets you test several hypotheses in one run.
- **`location`** — `"file:function"` or `"subsystem:event"`. Keeps summaries useful.
- **`message`** — one short human line.
- **`data`** — structured details. Include IDs, counts, durations.
- **Counter + sampler** for hot paths. Incrementing a counter every call and posting a 5 s rollup is far cheaper than logging every call, and it exposes rate-based bugs (runaway spawns, leaks) that per-event logs hide.

Replace `DEBUG_SERVER` with the URL printed by `scripts/log-server.js` on
startup (includes the session UUID).

## TypeScript / Node (recorder + sampler)

```ts
// #region agent log
// Temporary instrumentation for <bug description>. Remove when fixed.

const DEBUG_SERVER = "http://127.0.0.1:7695/ingest/<session-uuid>";
const DEBUG_SESSION = "<short>";

let samplerStarted = false;
let lastCpu: NodeJS.CpuUsage | null = null;
let lastSampleAt = 0;
const counters = { ptySpawns: 0, ptyExits: 0, sdkEvents: 0 };

function postLog(payload: Record<string, unknown>) {
  void fetch(DEBUG_SERVER, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Debug-Session-Id": DEBUG_SESSION },
    body: JSON.stringify({ sessionId: DEBUG_SESSION, timestamp: Date.now(), ...payload }),
  }).catch(() => {});
}

export function recordPtySpawn(taskId: string, pid: number): void {
  counters.ptySpawns += 1;
  postLog({
    hypothesisId: "B",
    location: "session-manager:spawn",
    message: "pty spawn",
    data: { taskId, pid, active: counters.ptySpawns - counters.ptyExits },
  });
}

export function recordPtyExit(taskId: string, pid: number, exitCode: number): void {
  counters.ptyExits += 1;
  postLog({
    hypothesisId: "B",
    location: "session-manager:exit",
    message: "pty exit",
    data: { taskId, pid, exitCode },
  });
}

export function recordSdkEvent(): void { counters.sdkEvents += 1; }

export function startEnergyDebugSampler(): void {
  if (samplerStarted) return;
  samplerStarted = true;
  lastCpu = process.cpuUsage();
  lastSampleAt = Date.now();
  const timer = setInterval(() => {
    const now = Date.now();
    const cpu = process.cpuUsage(lastCpu ?? undefined);
    const elapsed = now - lastSampleAt;
    lastCpu = process.cpuUsage();
    lastSampleAt = now;
    const totalMs = (cpu.user + cpu.system) / 1000;
    const mem = process.memoryUsage();
    postLog({
      hypothesisId: "sampler",
      location: "cli:sampler",
      message: "5s sample",
      data: {
        elapsedMs: elapsed,
        cpuPercent: Math.round((totalMs / elapsed) * 1000) / 10,
        rssMb: Math.round(mem.rss / 1024 / 1024),
        ...counters,
      },
    });
    counters.sdkEvents = 0;
  }, 5000);
  timer.unref();
}
// #endregion
```

Call `startEnergyDebugSampler()` once at process start, and the recorder
functions at each instrumentation point.

## TypeScript / Browser

```ts
// #region agent log
const DEBUG_SERVER = "http://127.0.0.1:7695/ingest/<session-uuid>";
const DEBUG_SESSION = "<short>";

export function dlog(hypothesisId: string, location: string, message: string, data?: unknown) {
  void fetch(DEBUG_SERVER, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Debug-Session-Id": DEBUG_SESSION },
    body: JSON.stringify({ sessionId: DEBUG_SESSION, timestamp: Date.now(), hypothesisId, location, message, data }),
    keepalive: true,
  }).catch(() => {});
}
// #endregion
```

## Python

```python
# region agent log
import time, requests
DEBUG_SERVER = "http://127.0.0.1:7695/ingest/<session-uuid>"
DEBUG_SESSION = "<short>"

def dlog(hypothesis_id, location, message, data=None):
    try:
        requests.post(
            DEBUG_SERVER,
            headers={"X-Debug-Session-Id": DEBUG_SESSION},
            json={
                "sessionId": DEBUG_SESSION,
                "timestamp": int(time.time() * 1000),
                "hypothesisId": hypothesis_id,
                "location": location,
                "message": message,
                "data": data,
            },
            timeout=0.5,
        )
    except Exception:
        pass
# endregion
```

Python has no `#region` directive, but the `# region agent log` / `# endregion`
comments still let grep-based cleanup work.

## Go

```go
// #region agent log
var debugServer = "http://127.0.0.1:7695/ingest/<session-uuid>"
var debugSession = "<short>"

func dlog(hypID, location, message string, data any) {
    body, _ := json.Marshal(map[string]any{
        "sessionId": debugSession, "timestamp": time.Now().UnixMilli(),
        "hypothesisId": hypID, "location": location, "message": message, "data": data,
    })
    req, _ := http.NewRequest("POST", debugServer, bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("X-Debug-Session-Id", debugSession)
    go func() { _, _ = http.DefaultClient.Do(req) }()
}
// #endregion
```

## Cleanup (works across languages)

```bash
# Show every instrumentation region in the repo
rg -n --multiline '#region agent log[\s\S]*?#endregion'

# Find files that contain regions (for batched review)
rg -l '#region agent log'
```

Delete each region in its entirety, then run the full test suite and visually
reproduce the original bug to confirm the fix holds without the instrumentation.
