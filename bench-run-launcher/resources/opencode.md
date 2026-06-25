# openCode Harbor Notes

Use this only when explicitly running or comparing openCode. Keep the main skill
optimized for Cline.

## Known Reference Runs

Old external reference only; do not use as a launch path:

```text
2026-05-06__21-38-33
```

Observed row:

```text
agent: opencode
model: opencode-go/deepseek-v4-pro
dataset: terminal-bench@2.0
```

Old external reference only; avoid as a token reference:

```text
2026-05-06__21-07-33
```

That run had rejected/missing token data.

## Provider-Controlled Shape

For apples-to-apples OpenRouter comparisons against Cline+OpenRouter, use
openCode through OpenRouter rather than the opencode-go subscription route:

```text
agent: opencode
model: openrouter/deepseek/deepseek-v4-pro
```

### Reasoning Controls

Defaults:

- If no `opencode_config` reasoning option is passed, OpenCode/OpenRouter uses
  the provider/model default.
- Harbor's OpenCode adapter always adds `--thinking` to
  `opencode run --format=json`; this only includes thinking blocks in the JSON
  event stream and does not itself enable or disable model reasoning.

Disable reasoning by passing an explicit OpenCode model option via
`opencode_config`. Do not rely on `--ak variant=none` or
`options.reasoningEffort=none`; both have still emitted reasoning tokens in
task-like runs.

Working Harbor kwarg shape:

```bash
--ak 'opencode_config={"provider":{"openrouter":{"models":{"z-ai/glm-5.2":{"options":{"reasoning":{"effort":"none"}}}}}}}'
```

Enable reasoning and set it to medium:

```bash
--ak 'opencode_config={"provider":{"openrouter":{"models":{"z-ai/glm-5.2":{"options":{"reasoning":{"effort":"medium"}}}}}}}'
```

Other enabled efforts use the same shape with `low` or `high`.

For disabled runs, verify after every smoke/full run that `agent/opencode.txt`
has no `"type":"reasoning"` events and zero
`step_finish.part.tokens.reasoning`. For enabled runs, report the observed
reasoning events/tokens so the comparison record is explicit.

Known passing reasoning-disabled smoke:

```text
opencode-openrouter-glm52-reasoning-effort-none-fixgit-smoke-envfile-20260624T052326Z
```

Local openCode smoke was previously reported to work with:

```bash
opencode run --model openrouter/deepseek/deepseek-v4-pro ...
```

Do not assume the Harbor command shape from memory. Inspect the current adapter:

```bash
cd "$HARBOR_DIR"
sed -n '1,260p' src/harbor/agents/installed/opencode.py
sed -n '1,260p' tests/unit/agents/installed/test_opencode.py
```

Then inspect any baseline run with the main skill's invariant gate and copy all
non-agent variables: dataset, task set, concurrency, timeout multipliers, env,
and retries.

## Notes

- openCode+opencode-go and openCode+OpenRouter are not provider-equivalent.
- Treat opencode-go cost as a separate plan/provider route, not comparable raw
  OpenRouter pricing.
- Do not compare OpenCode `agent_result.n_output_tokens` directly against Cline
  `outputTokens`. Harbor's OpenCode adapter stores visible output tokens in
  `agent_result.n_output_tokens` and stores reasoning tokens separately in
  `agent/opencode.txt` `step_finish.part.tokens.reasoning`. Any token-efficiency
  report must expose all three columns:
  `visible_output_tokens`, `reasoning_tokens`, and
  `output_plus_reasoning_tokens`.
- For cross-agent completion-side comparisons, use
  `output_plus_reasoning_tokens`. Treat visible-only `output_tokens` as a
  debugging field, not a PM/reporting metric.
- Check whether token data is present before using a run in aggregate reports.
  Prefer `resources/extract-token-metrics.py` so OpenCode reasoning tokens are
  not silently dropped.
