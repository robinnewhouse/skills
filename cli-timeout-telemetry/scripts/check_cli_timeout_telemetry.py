#!/usr/bin/env python3
"""Check Cline SDK CLI timeout telemetry in ClickHouse.

Run with:
  uv run --with clickhouse-connect scripts/check_cli_timeout_telemetry.py --days 7
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=7, help="UTC lookback window when --start is omitted")
    parser.add_argument("--start", help="UTC start, e.g. '2026-06-03 00:00:00'")
    parser.add_argument("--end", help="UTC end, e.g. '2026-06-10 00:00:00' (defaults to now)")
    parser.add_argument(
        "--settings",
        default="~/.cline/data/settings/cline_mcp_settings.json",
        help="Cline MCP settings JSON containing mcp-clickhouse env",
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    return parser.parse_args()


def parse_utc(value: str) -> datetime:
    normalized = value.strip().replace("T", " ").replace("Z", "")
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            parsed = datetime.strptime(normalized, fmt)
            return parsed.replace(tzinfo=UTC)
        except ValueError:
            pass
    raise SystemExit(f"Could not parse UTC datetime: {value!r}")


def sql_time(value: datetime) -> str:
    return value.astimezone(UTC).strftime("%Y-%m-%d %H:%M:%S")


def load_clickhouse_env(settings_path: str) -> dict[str, str]:
    env = {
        key: value
        for key, value in os.environ.items()
        if key.startswith("CLICKHOUSE_")
    }
    if {"CLICKHOUSE_HOST", "CLICKHOUSE_USER", "CLICKHOUSE_PASSWORD"} <= set(env):
        return env

    path = Path(settings_path).expanduser()
    if not path.exists():
        raise SystemExit(
            "Missing ClickHouse env and settings file. Configure mcp-clickhouse or pass --settings."
        )

    with path.open() as f:
        data = json.load(f)

    servers = data.get("mcpServers", {})
    for name in ("mcp-clickhouse", "clickhouse"):
        server = servers.get(name)
        if server and isinstance(server.get("env"), dict):
            env.update({k: str(v) for k, v in server["env"].items()})
            break

    required = {"CLICKHOUSE_HOST", "CLICKHOUSE_USER", "CLICKHOUSE_PASSWORD"}
    missing = sorted(required - set(env))
    if missing:
        raise SystemExit(f"Missing ClickHouse config keys: {', '.join(missing)}")
    return env


def connect(env: dict[str, str]) -> Any:
    try:
        import clickhouse_connect
    except ModuleNotFoundError as exc:
        raise SystemExit("Install/run with clickhouse-connect, e.g. uv run --with clickhouse-connect ...") from exc

    def bool_env(name: str, default: bool) -> bool:
        return env.get(name, str(default)).lower() in {"1", "true", "yes"}

    return clickhouse_connect.get_client(
        host=env["CLICKHOUSE_HOST"],
        port=int(env.get("CLICKHOUSE_PORT", "8443")),
        username=env["CLICKHOUSE_USER"],
        password=env["CLICKHOUSE_PASSWORD"],
        secure=bool_env("CLICKHOUSE_SECURE", True),
        verify=bool_env("CLICKHOUSE_VERIFY", True),
        connect_timeout=int(env.get("CLICKHOUSE_CONNECT_TIMEOUT", "30")),
        send_receive_timeout=int(env.get("CLICKHOUSE_SEND_RECEIVE_TIMEOUT", "300")),
    )


def run_query(client: Any, sql: str) -> dict[str, Any]:
    result = client.query(sql)
    return {
        "columns": list(result.column_names),
        "rows": [list(row) for row in result.result_rows],
    }


def print_table(title: str, table: dict[str, Any], max_width: int = 42) -> None:
    print(f"\n## {title}")
    rows = table["rows"]
    columns = table["columns"]
    if not rows:
        print("(no rows)")
        return

    rendered_rows = []
    for row in rows:
        rendered = []
        for value in row:
            text = str(value)
            if len(text) > max_width:
                text = text[: max_width - 1] + "..."
            rendered.append(text)
        rendered_rows.append(rendered)

    widths = [
        min(max(len(str(col)), *(len(row[idx]) for row in rendered_rows)), max_width)
        for idx, col in enumerate(columns)
    ]
    header = " | ".join(str(col).ljust(widths[idx]) for idx, col in enumerate(columns))
    sep = "-+-".join("-" * width for width in widths)
    print(header)
    print(sep)
    for row in rendered_rows:
        print(" | ".join(row[idx].ljust(widths[idx]) for idx in range(len(columns))))


def main() -> int:
    args = parse_args()
    end = parse_utc(args.end) if args.end else datetime.now(UTC)
    start = parse_utc(args.start) if args.start else end - timedelta(days=args.days)
    if start >= end:
        raise SystemExit("--start must be earlier than --end")

    start3 = sql_time(start)
    end3 = sql_time(end)

    queries = {
        "sdk_bodies_by_day": f"""
            SELECT
              toDate(Timestamp) AS report_date,
              Body,
              count() AS rows,
              min(Timestamp) AS first_seen,
              max(Timestamp) AS last_seen
            FROM otel.otel_logs
            PREWHERE Timestamp >= toDateTime64('{start3}', 3, 'UTC')
              AND Timestamp <  toDateTime64('{end3}', 3, 'UTC')
            WHERE startsWith(Body, 'sdk.')
            GROUP BY report_date, Body
            ORDER BY report_date ASC, rows DESC
            LIMIT 200
            SETTINGS max_execution_time = 60
        """,
        "daily_timeouts": f"""
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
            PREWHERE Timestamp >= toDateTime64('{start3}', 3, 'UTC')
              AND Timestamp <  toDateTime64('{end3}', 3, 'UTC')
            WHERE Body = 'sdk.tool_timeout'
            GROUP BY report_date
            ORDER BY report_date ASC
            SETTINGS max_execution_time = 60
        """,
        "timeout_shape": f"""
            SELECT
              Body,
              count() AS rows,
              arraySort(groupUniqArrayArray(mapKeys(LogAttributes))) AS keys
            FROM otel.otel_logs
            PREWHERE Timestamp >= toDateTime64('{start3}', 3, 'UTC')
              AND Timestamp <  toDateTime64('{end3}', 3, 'UTC')
            WHERE Body = 'sdk.tool_timeout'
            GROUP BY Body
            SETTINGS max_execution_time = 60
        """,
        "version_split": f"""
            SELECT
              LogAttributes['extension_version'] AS sdk_cli_version,
              count() AS timeout_rows,
              uniqExact(LogAttributes['session_id']) AS sessions,
              uniqExact(LogAttributes['tool_call_id']) AS tool_calls,
              min(Timestamp) AS first_seen,
              max(Timestamp) AS last_seen
            FROM otel.otel_logs
            PREWHERE Timestamp >= toDateTime64('{start3}', 3, 'UTC')
              AND Timestamp <  toDateTime64('{end3}', 3, 'UTC')
            WHERE Body = 'sdk.tool_timeout'
            GROUP BY sdk_cli_version
            ORDER BY timeout_rows DESC
            LIMIT 50
            SETTINGS max_execution_time = 60
        """,
        "duration_summary": f"""
            SELECT
              toDate(Timestamp) AS report_date,
              count() AS rows,
              uniqExact(LogAttributes['tool_call_id']) AS tool_calls,
              uniqExact(LogAttributes['session_id']) AS sessions,
              min(toFloat64OrNull(LogAttributes['duration_ms'])) AS min_duration_ms,
              quantileExact(0.5)(toFloat64OrNull(LogAttributes['duration_ms'])) AS p50_duration_ms,
              quantileExact(0.9)(toFloat64OrNull(LogAttributes['duration_ms'])) AS p90_duration_ms,
              quantileExact(0.99)(toFloat64OrNull(LogAttributes['duration_ms'])) AS p99_duration_ms,
              max(toFloat64OrNull(LogAttributes['duration_ms'])) AS max_duration_ms,
              groupArrayDistinct(LogAttributes['effective_timeout_ms']) AS effective_timeout_ms_values
            FROM otel.otel_logs
            PREWHERE Timestamp >= toDateTime64('{start3}', 3, 'UTC')
              AND Timestamp <  toDateTime64('{end3}', 3, 'UTC')
            WHERE Body = 'sdk.tool_timeout'
            GROUP BY report_date
            ORDER BY report_date ASC
            SETTINGS max_execution_time = 60
        """,
        "duplicate_check": f"""
            SELECT
              count() AS timeout_rows,
              uniqExact(LogAttributes['tool_call_id']) AS unique_tool_call_ids,
              timeout_rows - unique_tool_call_ids AS duplicate_rows,
              countIf(LogAttributes['tool_call_id'] = '') AS blank_tool_call_id_rows
            FROM otel.otel_logs
            PREWHERE Timestamp >= toDateTime64('{start3}', 3, 'UTC')
              AND Timestamp <  toDateTime64('{end3}', 3, 'UTC')
            WHERE Body = 'sdk.tool_timeout'
            SETTINGS max_execution_time = 60
        """,
        "run_commands_denominator": f"""
            SELECT
              toDate(event_timestamp) AS report_date,
              count() AS run_command_rows,
              countIf(success = 'true') AS success_true_rows,
              countIf(success = 'false') AS success_false_rows,
              uniqExact(ulid) AS sessions
            FROM analytics_prd.bronze_task_events
            WHERE event_timestamp >= toDateTime64('{start3}', 9, 'UTC')
              AND event_timestamp <  toDateTime64('{end3}', 9, 'UTC')
              AND task_event = 'task.tool_used'
              AND platform = 'cline'
              AND cline_type = 'cli'
              AND tool = 'run_commands'
            GROUP BY report_date
            ORDER BY report_date ASC
            SETTINGS max_execution_time = 60
        """,
    }

    client = connect(load_clickhouse_env(args.settings))
    output: dict[str, Any] = {
        "window_utc": {"start": start3, "end": end3},
        "queries": {},
    }
    for name, sql in queries.items():
        output["queries"][name] = run_query(client, sql)

    if args.json:
        print(json.dumps(output, default=str, indent=2))
        return 0

    print(f"Window UTC: {start3} to {end3}")
    for title, name in (
        ("SDK Bodies By Day", "sdk_bodies_by_day"),
        ("Daily sdk.tool_timeout Counts", "daily_timeouts"),
        ("Timeout Attribute Shape", "timeout_shape"),
        ("Version Split", "version_split"),
        ("Duration Summary", "duration_summary"),
        ("Duplicate Check", "duplicate_check"),
        ("Run Commands Denominator", "run_commands_denominator"),
    ):
        print_table(title, output["queries"][name])

    return 0


if __name__ == "__main__":
    sys.exit(main())
