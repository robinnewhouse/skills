---
name: use-clickhouse-mcp
description: Safely use ClickHouse MCP for schema discovery and SQL execution. Use when listing databases/tables, inspecting schemas, drafting SQL, previewing results, or running bounded ClickHouse analytics queries.
---

# Use ClickHouse MCP

Use ClickHouse MCP as the database access layer. Keep queries safe, explainable, and bounded.

## Query workflow

1. Discover schema/model shape if unknown.
2. Draft SQL using documented dbt definitions when available.
3. Explain what the SQL does before expensive execution.
4. Run a preview first when returning rows: `LIMIT 10` or `LIMIT 100`.
5. Prefer aggregate queries for metrics; avoid dumping high-cardinality raw data.
6. Confirm with the user before long-running, broad, or expensive scans.
7. Return the SQL with results so the user can inspect and reuse it.

## Safety checks

- Avoid accidental cross joins.
- Filter by time window whenever possible.
- Avoid `SELECT *` except tiny schema previews.
- Use explicit join keys and explain why the join is valid.
- Check row counts before exporting large result sets.
- If a query might be expensive, ask before running it.

## Large-table boundedness and fallback

Large fact tables can time out or exceed memory even for seemingly simple sanity checks. Keep exploratory and validation queries bounded unless there is strong evidence the table is small.

- Avoid unbounded freshness checks such as full-table `count()`, `uniqExact(...)`, or broad `min/max` scans on large fact tables.
- Prefer bounded recent-window checks, partition-aware filters, table metadata, or known date/key ranges. For example, use `WHERE report_date >= today() - 7` when checking a daily model’s recent freshness.
- If the user asks for a quick metric over “last N days” from a daily aggregate table, default to completed report dates when appropriate and state that assumption. Mention alternatives such as rolling N hours or including today if ambiguous.
- If an exact aggregate query exceeds memory or times out, retry with smaller bounded chunks only when chunking preserves correctness. For example, daily counts can be queried week-by-week and concatenated because each `report_date` belongs to exactly one chunk.
- Do not chunk-and-sum distinct users across chunks unless the requested grain makes chunks independent. Weekly unique users cannot be produced by summing daily unique users because users can appear on multiple days.
- Document chunk boundaries, why the combined result remains exact, and the original failure mode in the SQL notes or artifact metadata.
- If no exact bounded fallback is safe, ask whether an approximate aggregate such as `uniq(...)`, a shorter window, or a different grain is acceptable.

## Result package

Include:

- SQL executed
- row count or aggregate count
- sample output or artifact path
- data freshness or observed time range
- caveats and next query if needed
