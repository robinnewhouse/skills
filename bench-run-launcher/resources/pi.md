# Pi Harbor Notes

Use this only when explicitly running Pi. Keep the main skill optimized for
Cline.

## Confirmed Adapter Details

Harbor source:

```text
src/harbor/agents/installed/pi.py
tests/unit/agents/installed/test_pi.py
```

Agent name:

```text
pi
```

Model format must be:

```text
provider/model_name
```

The adapter splits the model into:

```bash
pi --print --mode json --no-session --provider <provider> --model <model_name>
```

Optional Harbor kwarg:

```bash
--ak thinking=off|minimal|low|medium|high|xhigh
```

## Reasoning Controls

Defaults:

- If no `thinking` kwarg is passed, Harbor does not pass Pi a `--thinking`
  flag; the Pi/model/provider default applies.

Disable reasoning:

```bash
--ak thinking=off
```

Enable reasoning and set it to medium:

```bash
--ak thinking=medium
```

Other enabled reasoning levels are:

```bash
--ak thinking=minimal
--ak thinking=low
--ak thinking=high
--ak thinking=xhigh
```

Verify after every smoke/full run that the trial command in `trial.log` includes
the expected `--thinking <value>` and that `agent/pi.txt` usage events are
populated.

Output file:

```text
/logs/agent/pi.txt
```

Token/cost parsing comes from JSONL events:

```text
message_end.message.usage.input
message_end.message.usage.output
message_end.message.usage.cacheRead
message_end.message.usage.cacheWrite
message_end.message.usage.cost.total
```

## Env Keys

The Pi adapter forwards provider-specific keys from the Harbor process
environment. Use `--env-file ~/.env` when running through Modal.

Common provider keys:

- `openrouter/*`: `OPENROUTER_API_KEY`
- `anthropic/*`: `ANTHROPIC_API_KEY`, `ANTHROPIC_OAUTH_TOKEN`
- `openai/*`: `OPENAI_API_KEY`
- `google/*`: Gemini/Google/Vertex envs
- `amazon-bedrock/*`: AWS credential/region envs

## Smoke Shape

Do not launch full runs before a smoke. First inspect baseline invariants with
the main skill.

Approximate smoke command:

```bash
cd "$HARBOR_DIR"
RUN_NAME=pi-dsv4pro-fixgit-smoke-$(date -u +%Y%m%dT%H%M%SZ)
LOG_FILE="$HARBOR_DIR/logs/$RUN_NAME.log"

nohup env PYTHONPATH="$HARBOR_DIR/src" "$HARBOR_PY" -m harbor.cli.main run \
  --job-name "$RUN_NAME" \
  -d terminal-bench@2.0 \
  -a pi \
  -m openrouter/deepseek/deepseek-v4-pro \
  --env modal \
  --env-file ~/.env \
  --timeout-multiplier 2.0 \
  --include-task-name fix-git \
  -l 1 -n 1 \
  --ak thinking=off \
  > "$LOG_FILE" 2>&1 & echo $!
```

Before trusting this for a full benchmark, verify:

- `agent/pi.txt` exists
- the trial command uses the expected provider/model
- token/cost data is populated from `message_end` events
- the task passes or fails for task reasons, not adapter/auth reasons
