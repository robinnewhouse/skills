---
name: bench-run-launcher
description: Launch full SWE-bench or Terminal-Bench Harbor runs end-to-end with optional tarball build, S3 upload/presign for Modal, Docker or Modal execution, persisted run manifests, and watcher handoff. Use when a user asks to kick off benchmark runs quickly and reproducibly.
---

# Bench Run Launcher

Use this skill when the user wants to start a benchmark run (SWE-bench or Terminal-Bench) and wants a reproducible launch record.

## Core Behavior

- Support **guided mode** (ask for missing required inputs) and **non-interactive mode** (all inputs provided up front).
- Always persist a **run manifest** after launch.
- Hand off monitoring using the bundled watch script at [resources/watch-job.sh](resources/watch-job.sh).

## Important Conventions

> **`tarball_url` uses an UNDERSCORE, not a hyphen.** The correct `--ak` key is `tarball_url`. Do NOT use `tarball-url`. This applies to both the `harbor run` command and the manifest.

> **All paths in this skill are placeholders.** Replace `$HARBOR_DIR`, `$SDK_CLI_DIR`, `$TARBALL_DIR` etc. with the user's actual paths. Never hardcode any user's home directory.

> **SDK CLI tarballs must be packed from `apps/cli`, not the repo root.** The canonical command is:
> ```bash
> cd "$SDK_CLI_DIR/apps/cli" && npm pack --pack-destination "$TARBALL_DIR"
> ```
> Do NOT run `npm pack` from `$SDK_CLI_DIR` root — that produces a broken tarball.

## 1) Collect Inputs

Required inputs:

1. `benchmark`: `swebench` or `terminalbench`
2. `environment`: `modal` or `docker`
3. `model`: model string (e.g., `openrouter:google/gemini-3-flash-preview`)
   - **Exacto variants:** Append `:exacto` to any OpenRouter model ID for quality-first provider routing (e.g., `openrouter:moonshotai/kimi-k2.5:exacto`). See [OpenRouter Exacto docs](https://openrouter.ai/docs/guides/routing/model-variants/exacto). When using `:exacto`, also pass `--ak refresh-models=true` so the CLI doesn't reject the model ID against its local catalog.
4. `tarball_source`: one of:
   - `existing_url` — user provides a URL directly
   - `build_and_upload` — build from source, optionally upload to S3, (suggest to user that they can provide the repository from which to build the tarball)
   - `local_tarball` — user points to an existing `.tgz` file on disk

Optional inputs (with defaults):

- `agent` (default `cline-cli`)
- `run_name` (default: `<benchmark>-<model_short>-<env>-$(date +%Y%m%d-%H%M%S)`)
- `task_limit` (`-l`; full defaults: SWE=500, TB=89)
- `concurrency` (`-n`; default 100 for Modal, 5 for Docker)
- `timeout` (default 1000)
- `reasoning_effort` (default `none`)
- `max_consecutive_mistakes` (default 15)
- `double_check_completion` (default `false`)
- `canary_first` (default false — if true, run 4 tasks first as a smoke test)

If required inputs are missing, ask concise questions only for the missing fields.

## 2) Resolve Dataset + Defaults

Map benchmark to dataset flag:

- `swebench` → `-d swebench-verified@1.0`
- `terminalbench` → `-d terminal-bench@2.0`

Default panel sizes:

- SWE-bench full: `-l 500`
- Terminal-Bench full: `-l 89`

Concurrency guardrails:

- Docker local: keep `-n` ≤ 9 unless user explicitly overrides.
- Modal: use the requested concurrency (typical: 30–100).

## 3) Build / Locate Tarball

### If `tarball_source=build_and_upload`

1. Ask for the SDK CLI source directory (`$SDK_CLI_DIR`).
2. Build the tarball — **from `apps/cli`, not the repo root**:
   ```bash
   TARBALL_FILE=$(cd "$SDK_CLI_DIR/apps/cli" && npm pack --pack-destination "$TARBALL_DIR" | tail -n 1)
   ```
3. Compute checksum + size:
   ```bash
   shasum "$TARBALL_DIR/$TARBALL_FILE"
   wc -c < "$TARBALL_DIR/$TARBALL_FILE"
   ```

### If `tarball_source=local_tarball`

1. Verify the tarball path exists.
2. Compute checksum + size.
3. For Docker: serve the tarball directory over HTTP if not already running:
   ```bash
   # Start once; skip if port 8199 is already in use
   lsof -i :8199 >/dev/null 2>&1 || \
     nohup python3 -m http.server 8199 --directory "$TARBALL_DIR" >/tmp/tarball-server.log 2>&1 &
   ```
   Then the tarball URL for Docker containers is:
   ```
   http://host.docker.internal:8199/<tarball_filename>
   ```

### If `tarball_source=existing_url`

- Use the URL as-is. Validate it is reachable if practical.

## 4) Upload + Presign (Modal path)

When environment is Modal and the tarball is local (not already a URL):

1. Upload to S3:
   ```bash
   aws s3 cp "$TARBALL_DIR/$TARBALL_FILE" \
     "s3://cline-test-builds/cline-builds/$TARBALL_FILE" \
     --profile cline-builds --region us-west-2
   ```
2. Generate a presigned URL (24h expiry):
   ```bash
   aws s3 presign "s3://cline-test-builds/cline-builds/$TARBALL_FILE" \
     --expires-in 86400 --profile cline-builds --region us-west-2
   ```
3. Use the presigned URL as the `tarball_url` value.

## 5) Launch Harbor Run

Build the launch command. Always use `nohup` and background with `&`.

Template:

```bash
nohup harbor run \
  --job-name "$RUN_NAME" \
  -d <dataset> \
  -a <agent> \
  -m <model> \
  --env <modal|docker> \
  -l <task_limit> -n <concurrency> \
  --ak timeout=<timeout> \
  --ak reasoning-effort=<reasoning_effort> \
  --ak max-consecutive-mistakes=<max_consecutive_mistakes> \
  --ak double-check-completion=<true|false> \
  --ak tarball_url="<url>" \
  > "$LOG_FILE" 2>&1 & echo $!
```

**Key details:**
- The `--ak` key for the tarball is **`tarball_url`** (underscore).
- Capture the PID from `echo $!` for the manifest.
- `--job-name` sets the job directory name (matches `$RUN_NAME`).
- The harbor CLI command is `harbor run` (NOT `harbor bench run`).

## 6) Persist Run Manifest (Required)

Write a JSON manifest immediately after launch. **Use the canonical template at [resources/manifest-template.json](resources/manifest-template.json) as the schema reference.** Every manifest must include all fields from the template; use `null` for unknown values rather than omitting keys.

Path: `$HARBOR_DIR/jobs_sdk/manifests/<run_name>.json`

Create the directory if it doesn't exist:
```bash
mkdir -p "$HARBOR_DIR/jobs_sdk/manifests"
```

Key rules:
- **Always use `task_limit`** (not `limit`) for the `-l` flag value.
- **Always include `requested_at` and `launched_at`** as separate ISO8601 timestamps.
- **Always include `log_file`** with the absolute path.
- **Always include `watcher`** with watch/cancel commands.
- **Always include `status`** (initially `"launched"`).
- **Always include `benchmark`** (`swebench` or `terminalbench`).
- **Include `tarball.sdk_branch` and `tarball.sdk_commit`** when known (the SDK repo branch/commit the tarball was built from).
- **Include `tarball.prs_included`** as an array of PR descriptions when the tarball includes unmerged PRs.
- **Include `comparison_runs`** when this run is explicitly being compared against prior runs.
- **Include `notes`** with a human-readable description of what this run is testing.

See [resources/manifest-template.json](resources/manifest-template.json) for the full field reference.

## 7) Start Monitoring / Handoff

This skill bundles a robust watch script at [resources/watch-job.sh](resources/watch-job.sh).

Copy it to the harbor directory and use it:

```bash
cp <skill_resources>/watch-job.sh "$HARBOR_DIR/scripts/"
chmod +x "$HARBOR_DIR/scripts/watch-job.sh"
```

Usage:

```bash
# One-shot status check
bash "$HARBOR_DIR/scripts/watch-job.sh" <job_name_or_dir>

# Auto-refresh every 15 seconds
watch -n 15 "bash $HARBOR_DIR/scripts/watch-job.sh <job_name_or_dir>"
```

The script shows: active harbor PIDs, trial pass/fail/error/running counts, pass rate, score bounds, mean completion time, aggregate tool/command/turn metrics, and active + recent-finished trial samples.

If the repo already has `scripts/watch-swebench-job.sh` or `scripts/watch-hillclimb-jobs.sh`, those also work and can be used instead.

## 8) Return a Short Launch Report

After launching, report to the user:

1. Benchmark + environment + model
2. Job / run name
3. PID + log file path
4. Manifest path
5. Commands to monitor and cancel:
   ```
   Monitor:  watch -n 15 'bash scripts/watch-job.sh <run_name>'
   Tail log: tail -f <log_file>
   Cancel:   kill <pid>
   ```

## 9) Post-Run Failure Analysis

When the user asks to analyze failures from a completed (or in-progress) run, follow these steps.

### 9a) Get Run Status

```bash
cd "$HARBOR_DIR/jobs/<run_name>"
TOTAL=$(ls -d */ | wc -l)
COMPLETED=$(ls -d */result.json 2>/dev/null | wc -l)
echo "Tasks: $COMPLETED/$TOTAL completed"
```

### 9b) Count Pass/Fail

```python
import json, os
pass_count = fail_count = 0
for d in sorted(os.listdir('.')):
    rpath = os.path.join(d, 'result.json')
    if not os.path.isfile(rpath): continue
    with open(rpath) as f:
        r = json.load(f)
    if r['verifier_result']['rewards']['reward'] == 1.0:
        pass_count += 1
    else:
        fail_count += 1
print(f"Pass: {pass_count}, Fail: {fail_count}, Rate: {pass_count/(pass_count+fail_count)*100:.1f}%")
```

### 9c) Analyze Failures with Tool Counts

**Critical: messages.json format.** The file at `<task_dir>/agent/api_history/<id>/<id>.messages.json` is a **dict** (not a list) with keys: `version`, `updated_at`, `messages`, `systemPrompt`. The actual message array is `data['messages']`.

**Critical: glob path.** Messages files are nested two levels deep under `api_history/`:
```
<task_dir>/agent/api_history/<conversation_id>/<conversation_id>.messages.json
```
Use glob pattern: `os.path.join(d, 'agent', 'api_history', '*', '*.messages.json')`

**Critical: tool names vary by SDK version.** The editor tool may be called `editor` (PR#42 anchor_line), `write_to_file`, `replace_in_file`, or `insert_content` depending on which SDK tarball was used. Always check for all variants:
```python
editor_calls = sum(tool_names.get(t, 0) for t in ['editor', 'write_to_file', 'replace_in_file', 'insert_content'])
```

**Failure categorization by editor call count:**
- **0 editor calls** = "no-edit" — agent explored but never attempted a fix
- **1-2 editor calls** = "minimal-edit" — attempted but wrong/incomplete fix
- **3+ editor calls** = "wrong-fix" — substantial effort, wrong approach

### 9d) Check for Known Bug Patterns

**Dropped tool calls (PR#38 streaming bug):**
```python
# For each failed task, check tool_use/tool_result pairing
tool_use_ids = []
tool_result_ids = []
for m in msgs:
    content = m.get('content', [])
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict):
                if c.get('type') == 'tool_use':
                    tool_use_ids.append(c.get('id'))
                elif c.get('type') == 'tool_result':
                    tool_result_ids.append(c.get('tool_use_id'))
unmatched = set(tool_use_ids) - set(tool_result_ids)
# If unmatched is non-empty, tool calls were silently dropped
```

**Negative line number / "Too small" errors:**
```bash
# Check cline.txt for Zod validation errors
grep -rl "Too small" "$HARBOR_DIR/jobs/<run_name>/*/agent/cline.txt" | wc -l
```

### 9e) Compare Across Runs (Apples-to-Apples)

When comparing two runs on the same task set, always compute on the **intersection** of completed tasks:

```python
common = set(baseline.keys()) & set(experiment.keys())
both_pass = [t for t in common if baseline[t]==1.0 and experiment[t]==1.0]
both_fail = [t for t in common if baseline[t]==0.0 and experiment[t]==0.0]
regressions = [t for t in common if baseline[t]==1.0 and experiment[t]==0.0]
improvements = [t for t in common if baseline[t]==0.0 and experiment[t]==1.0]
```

Key metrics to report:
- **Apples-to-apples pass rate** on common tasks (not raw totals which may differ in completion)
- **Regressions** (baseline pass → experiment fail) — these are the most important to flag
- **Improvements** (baseline fail → experiment pass) — validates the changes
- **Shared failures** — hard tasks that fail regardless of changes

### 9f) Summary Template

Present results in this format:

```
## Run Analysis: <run_name>
- Status: X/Y completed, Z pass, W fail (rate%)
- Known bugs: [list any detected: dropped calls, Too small, etc.]
- Failure breakdown: A no-edit, B minimal-edit, C wrong-fix
- vs Baseline (<baseline_name>): +/-N% on K common tasks, R regressions, I improvements
```

## 10) Failure Policy

- If any critical step fails (build / upload / launch), **stop immediately** and report the exact command + stderr.
- Do NOT claim launch success unless PID, log file, and manifest are all present and verified.
- If the tarball HTTP server is needed for Docker and port 8199 is already in use, report that rather than silently skipping.
