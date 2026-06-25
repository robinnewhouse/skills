---
name: cli-timeout-telemetry
description: Check Cline SDK CLI shell timeout telemetry in ClickHouse. Use when the user asks whether sdk.tool_timeout is landing, wants the latest CLI timeout telemetry, needs raw OTEL evidence for shell/run_commands timeouts, or wants exact SQL for another agent or dashboard.
---

# CLI Timeout Telemetry

Use this skill to verify whether the Cline SDK CLI is emitting shell timeout telemetry and to summarize the current state with raw evidence.

## Default workflow

1. Treat raw OTEL as the source of truth for timeout events:
   - Timeout numerator: `otel.otel_logs` where `Body = 'sdk.tool_timeout'`.
   - Rough `run_commands` denominator: `analytics_prd.bronze_task_events`.
   - Do not rely on curated SDK tables to prove the timeout event landed unless a curated `sdk.%` model now explicitly contains it.

2. Run the helper from this skill directory:

   ```bash
   cd /Users/robin/.agents/skills/cli-timeout-telemetry
   uv run --with clickhouse-connect scripts/check_cli_timeout_telemetry.py --days 7
   ```

   For a fixed UTC window:

   ```bash
   uv run --with clickhouse-connect scripts/check_cli_timeout_telemetry.py \
     --start "2026-06-03 00:00:00" \
     --end "2026-06-10 00:00:00"
   ```

3. Report the result in this shape:

   ```md
   Answer: sdk.tool_timeout is/is not landing.
   Evidence: raw OTEL table, UTC window, first/last seen, row count, unique tool_call_id count, sessions, versions, tool names.
   Rate context: rough denominator from bronze_task_events, if available.
   Caveats: duplicate rows, partial current day, raw scan cost, curated model coverage, known task.tool_used.success mismatch.
   SQL/source: mention the script path and any manual SQL used.
   ```

## Interpretation rules

- A real timeout event is `Body = 'sdk.tool_timeout'`; expect attributes such as `tool_name`, `tool_call_id`, `session_id`, `effective_timeout_ms`, `duration_ms`, `extension_version`, `platform`, and `cline_type`.
- For CLI shell timeouts, expected shape is usually `tool_name = 'run_commands'`, `platform = 'cline'`, `cline_type = 'cli'`, and `effective_timeout_ms = '30000'`.
- Count unique timeout attempts with `uniqExact(LogAttributes['tool_call_id'])`; duplicate raw rows have been observed.
- Use `task.tool_used` only for a rough denominator. A prior contradiction had timeout tool output showing failure while adjacent `task.tool_used.success` was true, so do not classify timeouts from that success flag.
- If raw OTEL has no recent `sdk.tool_timeout` rows, first widen the window, then verify producer-side OTLP auth/config. Console output alone only proves local emission, not collector ingestion.
- If a raw denominator query is slow, stop it and use `analytics_prd.bronze_task_events` for denominator context.

## Manual SQL

Use these query shapes in the ClickHouse dashboard or another agent if the helper cannot run.

### Find sdk event bodies

```sql
SELECT
  toDate(Timestamp) AS report_date,
  Body,
  count() AS rows,
  min(Timestamp) AS first_seen,
  max(Timestamp) AS last_seen
FROM otel.otel_logs
PREWHERE Timestamp >= toDateTime64('2026-06-03 00:00:00', 3, 'UTC')
  AND Timestamp < now64(3)
WHERE startsWith(Body, 'sdk.')
GROUP BY report_date, Body
ORDER BY report_date ASC, rows DESC
LIMIT 200
SETTINGS max_execution_time = 60;
```

### Daily timeout counts

```sql
SELECT
  toDate(Timestamp) AS report_date,
  count() AS rows,
  min(Timestamp) AS first_seen,
  max(Timestamp) AS last_seen,
  uniqExact(LogAttributes['session_id']) AS sessions,
  uniqExact(LogAttributes['tool_call_id']) AS tool_calls,
  groupArrayDistinct(LogAttributes['tool_name']) AS tool_names,
  groupArrayDistinct(LogAttributes['platform']) AS platforms,
  groupArrayDistinct(LogAttributes['cline_type']) AS cline_types
FROM otel.otel_logs
PREWHERE Timestamp >= toDateTime64('2026-06-03 00:00:00', 3, 'UTC')
  AND Timestamp < now64(3)
WHERE Body = 'sdk.tool_timeout'
GROUP BY report_date
ORDER BY report_date ASC
SETTINGS max_execution_time = 60;
```

### Duplicate check

```sql
SELECT
  count() AS timeout_rows,
  uniqExact(LogAttributes['tool_call_id']) AS unique_tool_call_ids,
  timeout_rows - unique_tool_call_ids AS duplicate_rows,
  countIf(LogAttributes['tool_call_id'] = '') AS blank_tool_call_id_rows
FROM otel.otel_logs
PREWHERE Timestamp >= toDateTime64('2026-06-03 00:00:00', 3, 'UTC')
  AND Timestamp < now64(3)
WHERE Body = 'sdk.tool_timeout'
SETTINGS max_execution_time = 60;
```

### Denominator for rough timeout rate

```sql
SELECT
  toDate(event_timestamp) AS report_date,
  count() AS run_command_rows,
  countIf(success = 'true') AS success_true_rows,
  countIf(success = 'false') AS success_false_rows,
  uniqExact(ulid) AS sessions
FROM analytics_prd.bronze_task_events
WHERE event_timestamp >= toDateTime64('2026-06-03 00:00:00', 9, 'UTC')
  AND event_timestamp < now64(9)
  AND task_event = 'task.tool_used'
  AND platform = 'cline'
  AND cline_type = 'cli'
  AND tool = 'run_commands'
GROUP BY report_date
ORDER BY report_date ASC
SETTINGS max_execution_time = 60;
```
