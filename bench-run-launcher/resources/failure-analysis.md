# Harbor Failure Analysis Notes

Use this only after a run completes or when debugging an active run.

## Status

```bash
cd "$HARBOR_DIR/jobs/<run_name>"
TOTAL=$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)
COMPLETED=$(find . -mindepth 2 -maxdepth 2 -name result.json | wc -l)
echo "Tasks: $COMPLETED/$TOTAL completed"
```

## Pass/Fail

```python
import json, os
passed = failed = errors = 0
for d in sorted(os.listdir(".")):
    p = os.path.join(d, "result.json")
    if not os.path.isfile(p):
        continue
    r = json.load(open(p))
    reward = r.get("verifier_result", {}).get("rewards", {}).get("reward")
    if reward == 1.0:
        passed += 1
    else:
        failed += 1
print(passed, failed, passed / max(1, passed + failed))
```

## Compare Runs On Common Tasks

Always compare on the intersection of completed tasks.

```python
common = set(baseline) & set(experiment)
regressions = [t for t in common if baseline[t] == 1.0 and experiment[t] == 0.0]
improvements = [t for t in common if baseline[t] == 0.0 and experiment[t] == 1.0]
```

Report:

- common task count
- pass/pass, fail/fail, regressions, improvements
- whether differences are timeout-driven or verifier failures

## Message Metrics

Do not use a single `output_tokens` column for cross-agent comparisons.
OpenCode's Harbor adapter reports visible output in
`result.json agent_result.n_output_tokens` and leaves reasoning tokens in
`agent/opencode.txt` `step_finish.part.tokens.reasoning`. Cline session metrics
do not currently expose a separate reasoning-token field; its `outputTokens` is
whatever the provider/SDK reports as output. Reports must include:

- `visible_output_tokens`
- `reasoning_tokens`
- `output_plus_reasoning_tokens`

Use the bundled extractor:

```bash
python3 <skill_dir>/resources/extract-token-metrics.py \
  --run Cline=/home/robin_cline_bot/harbor/jobs/<cline_run> \
  --run OpenCode=/home/robin_cline_bot/harbor/jobs/<opencode_run> \
  --run Pi-Code=/home/robin_cline_bot/harbor/jobs/<pi_run> \
  --out /tmp/token-metrics.csv
```

If `result.json` has null token/cost fields, read session messages:

```text
<task>/agent/sessions/*/*.messages.json
```

Assistant messages may include:

```json
{
  "metrics": {
    "inputTokens": 0,
    "outputTokens": 0,
    "cacheReadTokens": 0,
    "cacheWriteTokens": 0,
    "cost": 0
  }
}
```

Aggregate per task:

- gross input: `sum(inputTokens)`
- cache read: `sum(cacheReadTokens)`
- fresh input: `gross input - cache read`
- output: `sum(outputTokens)`
- net+output: `fresh input + output`
- cost: `sum(cost)`

## Known Failure Signatures

Stale launch args:

```bash
grep -R "unknown option '--max-consecutive-mistakes'\\|double_check_completion" \
  "$HARBOR_DIR/jobs/<run_name>" "$HARBOR_DIR/logs/<run_name>.log"
```

Cline provider auth missing:

```bash
grep -R "Unauthorized: Please make sure you're using the latest version of Cline" \
  "$HARBOR_DIR/jobs/<run_name>"/*/agent/cline.txt
```

Timeout mismatch:

```bash
grep -R '"timeout_multiplier"' "$HARBOR_DIR/jobs/<run_name>"/*/result.json | head
grep -R "AgentTimeoutError" "$HARBOR_DIR/jobs/<run_name>" | head
```

Dropped tool call check:

```python
tool_use_ids = []
tool_result_ids = []
for m in msgs:
    content = m.get("content", [])
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "tool_use":
                tool_use_ids.append(c.get("id"))
            if isinstance(c, dict) and c.get("type") == "tool_result":
                tool_result_ids.append(c.get("tool_use_id"))
unmatched = set(tool_use_ids) - set(tool_result_ids)
```
