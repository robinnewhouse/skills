---
name: bench-run-launcher
description: Launch reproducible Harbor benchmark runs, especially Cline CLI Terminal-Bench Modal runs, with baseline config checks, local tarball upload, manifests, and watcher handoff.
---

# Bench Run Launcher

Use this skill when launching or checking Harbor benchmark runs. For Robin's
Cline Terminal-Bench work, optimize for reproducibility over convenience:
inspect the baseline run, copy invariants, smoke first, then launch.

Cline is the default path below. For less common agents, read
[resources/opencode.md](resources/opencode.md) or [resources/pi.md](resources/pi.md)
after the baseline invariant gate.

## Default Context

For Robin's Harbor ATIF Cline-provider runs:

```bash
HARBOR_DIR=/home/robin_cline_bot/harbor
LOCAL_CLINE_DIR=/Users/robin/dev/cline
HARBOR_PY="$HARBOR_DIR/.venv/bin/python"
HARBOR_RUN=(env PYTHONPATH="$HARBOR_DIR/src" "$HARBOR_PY" -m harbor.cli.main run)
```

`HARBOR_DIR` is the Harbor repo on the Harbor VM. It is not the Cline checkout.
Build Cline tarballs locally from `LOCAL_CLINE_DIR`, then copy the packed Linux
x64 tarball to the Harbor VM under `$HARBOR_DIR/local-tarballs/`.

Never use bare `harbor`, `/usr/local/bin/harbor`, or another user's Harbor
checkout for Robin benchmark launches or adapter inspection. On the Harbor VM,
`/usr/local/bin/harbor` has resolved to `/home/ara_cline_bot/harbor`; that is
the wrong source for Robin's runs. Always launch and inspect with
`PYTHONPATH="$HARBOR_DIR/src" "$HARBOR_PY" -m harbor.cli.main ...` from
`/home/robin_cline_bot/harbor`, and verify `inspect.getfile(...)` points under
`$HARBOR_DIR/src/harbor`.

Expected locations:

- Jobs: `$HARBOR_DIR/jobs/<run_name>`
- Logs: `$HARBOR_DIR/logs/<run_name>.log`
- Manifests: `$HARBOR_DIR/jobs/<run_name>/manifest.json`
- Local tarballs: `$HARBOR_DIR/local-tarballs/`

Before making launch decisions, read live Harbor/adapter help:

```bash
cd "$HARBOR_DIR"
PYTHONPATH="$HARBOR_DIR/src" "$HARBOR_PY" -m harbor.cli.main run --help
PYTHONPATH="$HARBOR_DIR/src" "$HARBOR_PY" - <<'PY'
from harbor.agents.installed.cline.cline import ClineCli
import inspect
print(inspect.getfile(ClineCli))
print(inspect.signature(ClineCli.__init__))
PY
```

## 1. Baseline Invariant Gate

When a run will be compared to a prior run, do not start from a generic command.
First inspect the exact baseline and copy every invariant except the intended
variable under test.

```bash
cd "$HARBOR_DIR"
BASELINE_RUN=<baseline_run_name>

python3 -m json.tool "jobs/$BASELINE_RUN/manifest.json" | sed -n '1,220p'

BASELINE_RUN="$BASELINE_RUN" python3 - <<'PY'
import glob, json, os
run = os.environ["BASELINE_RUN"]
for p in glob.glob(f"jobs/{run}/*/result.json")[:5]:
    r = json.load(open(p))
    c = r.get("config", {})
    print(p)
    for k in [
        "dataset", "model", "timeout_multiplier",
        "agent_timeout_multiplier", "verifier_timeout_multiplier",
        "agent_setup_timeout_multiplier",
        "environment_build_timeout_multiplier",
    ]:
        print(k, c.get(k))
    print("agent", c.get("agent", {}).get("name"))
    print("agent.kwargs", c.get("agent", {}).get("kwargs"))
    print("agent.env", c.get("agent", {}).get("env"))
    print()
PY
```

Must match unless intentionally changed:

- dataset/version, task set, include/exclude filters, task limit
- agent, model, provider route
- environment and concurrency
- `--timeout-multiplier` and specific timeout multipliers
- setup retry kwargs and setup command timeout
- reasoning flags
- env-file usage and agent env shape
- tracing/capture envs, if traces are part of the comparison

For comparisons against `cline-provider-dsv4pro-full89-control-20260618T173324Z`,
include:

```bash
--timeout-multiplier 2.0
```

That baseline recorded `config.timeout_multiplier=2.0` and
`config.agent_setup_timeout_multiplier=2.0`. Omitting the flag defaults Harbor to
`1.0` and creates false `AgentTimeoutError` regressions.

Before the full run, print a short diff:

```text
Allowed differences: run_name, tarball path/SHA, source commit, intended model/provider if requested.
Must match: dataset, task set, agent, provider route, concurrency, timeout multipliers,
setup kwargs, env-file, CLINE_DATA_DIR, capture envs.
```

## Reasoning Controls

Reasoning settings are part of the benchmark invariant. Do not compare runs
unless reasoning/thinking state is intentionally matched and verified in the
agent output.

Defaults:

- Cline: no Harbor reasoning kwarg means no reasoning/thinking effort flag is
  passed; the Cline/model/provider default applies. Use the Harbor kwarg
  `reasoning-effort` rather than hardcoding the raw Cline CLI flag. The current
  live Harbor adapter renders this as `cline ... --thinking <effort>`.
- OpenCode: no `opencode_config` reasoning option means the OpenCode/OpenRouter
  default applies. Harbor always passes OpenCode `--thinking`, but that only
  includes thinking blocks in JSON output; it does not enable or disable model
  reasoning.
- Pi: no `thinking` kwarg means no `--thinking` flag is passed; the Pi/model
  provider default applies.

Reasoning disabled/off:

```bash
# Cline
--ak reasoning-effort=none

# OpenCode through OpenRouter
--ak 'opencode_config={"provider":{"openrouter":{"models":{"z-ai/glm-5.2":{"options":{"reasoning":{"effort":"none"}}}}}}}'

# Pi
--ak thinking=off
```

Reasoning enabled at medium:

```bash
# Cline
--ak reasoning-effort=medium

# OpenCode through OpenRouter
--ak 'opencode_config={"provider":{"openrouter":{"models":{"z-ai/glm-5.2":{"options":{"reasoning":{"effort":"medium"}}}}}}}'

# Pi
--ak thinking=medium
```

Reasoning enabled without pinning medium:

- Cline: pass one of `--ak reasoning-effort=low|medium|high|xhigh`.
- OpenCode: pass `opencode_config` with
  `options.reasoning.effort=low|medium|high` for the model under test.
- Pi: pass one of `--ak thinking=minimal|low|medium|high|xhigh`.

Verification:

- Cline: inspect `trial.log` for the rendered `cline` command and confirm the
  expected effort is present, currently `--thinking none|low|medium|high|xhigh`;
  inspect `agent/cline.txt` and, when available, session/provider usage for
  unexpected reasoning tokens.
- OpenCode: inspect `agent/opencode.txt`; apples-to-apples disabled runs must
  have no `"type":"reasoning"` events and zero
  `step_finish.part.tokens.reasoning`.
- Pi: inspect `agent/pi.txt`; confirm the trial command includes the expected
  `--thinking <value>` and usage events are populated.

## 2. Build Or Locate Cline CLI Tarball

Harbor expects the generated Linux x64 platform package, not `npm pack` from
`apps/cli` root. For Cline runs, build from the local machine's Cline checkout
at `LOCAL_CLINE_DIR` (normally `/Users/robin/dev/cline`), not inside
`HARBOR_DIR` on the Harbor VM.

Build shape on the local machine:

```bash
cd "$LOCAL_CLINE_DIR"
bun install --frozen-lockfile
bun run build:sdk
cd "$LOCAL_CLINE_DIR/apps/cli"
bun script/build.ts --install-native-variants --skip-sdk-build
cd "$LOCAL_CLINE_DIR/apps/cli/dist/cli-linux-x64"
npm pack --pack-destination /tmp
scp "/tmp/$TARBALL_FILE" "harbor:$HARBOR_DIR/local-tarballs/$TARBALL_FILE"
```

Validate on the Harbor VM before launch:

```bash
shasum "$TARBALL_DIR/$TARBALL_FILE"
wc -c < "$TARBALL_DIR/$TARBALL_FILE"
docker run --rm -v "$TARBALL_DIR:/tarballs:ro" node:22-bookworm \
  bash -lc "npm install -g --ignore-scripts -- /tarballs/$TARBALL_FILE && cline --version"
```

For Modal, prefer local upload:

```bash
--ak tarball-path="$HARBOR_DIR/local-tarballs/$TARBALL_FILE"
```

Only use URL/S3 upload as a legacy fallback if local upload is unavailable. The
URL kwarg spelling is `tarball_url`, not `tarball-url`.

## 3. Smoke First

Run one known-fast task with the same config shape as the full run.

Known one-task smoke filter:

```bash
--include-task-name fix-git
```

Harbor does not accept `--task-name`.

Do not launch the full run until smoke:

- creates `agent/cline.txt`
- exits with `__CLINE_EXIT=0`
- passes verification
- uses the expected provider/model command

Known passing smoke:

```text
cline-provider-dsv4pro-main-3-0-29-fixgit-smoke-envfile-20260623T0142Z
```

## 4. Launch Current Cline CLI Modal Run

Use `nohup` and background the job.

Current Cline-provider Terminal-Bench shape:

```bash
cd "$HARBOR_DIR"
mkdir -p logs

RUN_NAME=<run_name>
LOG_FILE="$HARBOR_DIR/logs/$RUN_NAME.log"

nohup env PYTHONPATH="$HARBOR_DIR/src" "$HARBOR_PY" -m harbor.cli.main run \
  --job-name "$RUN_NAME" \
  -d terminal-bench@2.0 \
  -a cline-cli \
  -m cline:deepseek/deepseek-v4-pro \
  --env modal \
  --env-file ~/.env \
  --timeout-multiplier 2.0 \
  -l 89 -n 100 \
  --ak setup-retries=3 \
  --ak setup-retry-delay-sec=5 \
  --ak setup-command-timeout-sec=240 \
  --ak tarball-path="$HARBOR_DIR/local-tarballs/<tarball>.tgz" \
  --ak reasoning-effort=none \
  --ae CLINE_DATA_DIR=/logs/agent \
  > "$LOG_FILE" 2>&1 & echo $!
```

If traces/provider request capture are needed, add:

```bash
--ae CLINE_CAPTURE_PROVIDER_REQUEST=full \
--ae CLINE_CAPTURE_WIRE=true \
--ae CLINE_CAPTURE_WIRE_RESPONSE=true \
--ae CLINE_CAPTURE_MAX_PREVIEW_BYTES=5000000 \
--ae CLINE_CAPTURE_CLEANUP=off \
--ae WEAVE_CAPTURE_CONTENT=true
```

Do not pass:

- `double-check-completion`
- `max-consecutive-mistakes`

These are stale for current `cline-cli`/Harbor and have caused failed launches.

For Cline provider runs, always pass `--env-file ~/.env`; this is how
`CLINE_API_KEY` reaches Modal. Unauthorized trials usually mean this was omitted.

Expected trial command shape:

```bash
cline -P cline -k $API_KEY -m $MODELID --yolo --thinking none -- '<task>'
```

## 5. Manifest

Write a manifest immediately after launch:

```bash
while [ ! -d "$HARBOR_DIR/jobs/$RUN_NAME" ]; do sleep 2; done
MANIFEST_FILE="$HARBOR_DIR/jobs/$RUN_NAME/manifest.json"
```

Use [resources/manifest-template.json](resources/manifest-template.json) as the
schema reference. Include:

- run name, PID, log file, launch command
- benchmark, dataset, task limit, concurrency
- model/provider route, agent, environment
- timeout multipliers
- tarball path, SHA, size, source commit, included PRs
- comparison baseline and invariant diff
- notes describing the intended variable under test

## 6. Watch

Use the bundled watcher:

```bash
cp <skill_dir>/resources/watch-job.sh "$HARBOR_DIR/scripts/"
chmod +x "$HARBOR_DIR/scripts/watch-job.sh"

bash "$HARBOR_DIR/scripts/watch-job.sh" <run_name>
watch -n 15 "bash $HARBOR_DIR/scripts/watch-job.sh <run_name>"
```

Report to the user:

```text
Run: <run_name>
PID: <pid>
Log: <log_file>
Manifest: <manifest_file>
Watch: watch -n 15 'bash scripts/watch-job.sh <run_name>'
Cancel: kill <pid>
```

## 7. Post-Run Analysis

For deeper failure or apples-to-apples analysis, use
[resources/failure-analysis.md](resources/failure-analysis.md).

Important current data note: some Cline runs no longer populate token/cost in
`result.json`; extract metrics from `agent/sessions/*/*.messages.json` when
needed.

Important OpenCode token note: never report OpenCode
`agent_result.n_output_tokens` as comparable completion-side output by itself.
Harbor stores OpenCode visible output there, while reasoning tokens live in
`agent/opencode.txt` as `step_finish.part.tokens.reasoning`. Token reports must
include `visible_output_tokens`, `reasoning_tokens`, and
`output_plus_reasoning_tokens`; use
`resources/extract-token-metrics.py` for CSV extraction.

## Failure Policy

- If build, validation, smoke, or launch fails, stop and report the exact command
  and stderr.
- Do not claim launch success unless PID, log file, and manifest are present.
- Do not compare score/token deltas until baseline invariants have been checked.
