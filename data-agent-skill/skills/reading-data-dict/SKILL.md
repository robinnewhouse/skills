---
name: reading-data-dict
description: Read dbt ClickHouse repository context, data dictionaries, manifests, model docs, column descriptions, lineage, and metric definitions before writing analytics SQL. Use for mapping business/product terms to concrete models and columns.
---

# Reading Data Dictionary

Use this before writing SQL for internal metrics.

When invoked from the elicitation flow to resolve specific `LOOK UP` terms, scope the work to those terms — resolve their definitions and surface any options/candidates back to the user. Do not perform a full dbt exploration unless the user explicitly asked for one or no curated model is obvious.

## dbt repository source

Default dbt repository: `https://github.com/cline/dbt-clickhouse/`

Prefer the default git repository remote/link as the source of truth for dbt context, data dictionaries, manifests, model docs, lineage, and metric definitions.

Use the `gh` CLI as the primary method for accessing the remote repository. A local checkout may be used as a secondary fallback if `gh` is unavailable or unauthenticated — only when the directory's `origin` or configured remote matches the default dbt repository and it is sufficiently up to date.

Useful artifacts to inspect first:

- `data_dictionary/**`
- `target/manifest.json`
- `models/**/*.yml`
- `models/**/*.sql`
- metric or semantic model YAML files, if present

## Data dictionary inspection

Always inspect relevant files under `data_dictionary/**` before choosing models, columns, joins, or metric definitions.

Look for business/product terms, metric definitions, entity definitions, grain, filters, exclusions, caveats, owners, rollout notes, and links to dbt models or dashboards.

If no relevant data dictionary entry exists, say so explicitly and continue with dbt model docs, manifest metadata, and SQL model lineage. If the data dictionary conflicts with dbt model docs or observed schema, surface the discrepancy before writing SQL.

## Procedure

1. Locate the dbt repository in this order — stop at the first that works:
   - **`gh` CLI (preferred):** Check `gh auth status`, then read files directly without cloning:
     ```bash
     # List a directory
     gh api repos/cline/dbt-clickhouse/contents/data_dictionary

     # Read a specific file
     gh api repos/cline/dbt-clickhouse/contents/data_dictionary/some-file.md \
       --jq '.content' | base64 -d
     ```
     Fetch `data_dictionary/**` files selectively before any model SQL or YAMLs.
   - **Local clone (fallback):** If `gh` is unavailable or unauthenticated, check for a local directory whose `git remote -v` matches `https://github.com/cline/dbt-clickhouse/`. Use it only if it is sufficiently up to date.
   - **ClickHouse schema fallback:** If both above fail, list databases in ClickHouse MCP. Inspect `analytics_prd` and any `analytics_*` schemas first — these are the live mirrors of curated dbt models. Prefer `gold_*`, `silver_*`, `fct_*`, and `dim_*` tables. Do not query raw databases (e.g., `clinedb`) until `analytics_*` schemas have been exhausted. State explicitly that you fell back to the live schema.
2. Inspect relevant `data_dictionary/**` files first, then locate dbt models, model docs, manifest entries, column descriptions, lineage, or metric docs for the requested concept.
3. Identify the curated model first. Use raw OTel/event tables only when no curated model exists, the curated model is insufficient, or the user explicitly requests raw data.
4. Extract the exact definitions for:
   - metric name
   - entity/population
   - grain and time window
   - filters and exclusions
   - required columns
   - safe join keys/patterns
   - freshness, rollout, or coverage caveats
5. Cross-check lineage when the model is derived from raw events.
6. Summarize definitions back to the user when they affect interpretation.

## Definition summary template

```md
Definitions used:
- Metric: ...
- Population: ...
- Grain/window: ...
- Model/table: ...
- Key columns: ...
- Joins: ...
- Known caveats: ...
```

## Bias toward documented semantics

If a term like “active user,” “daily active,” “tokens,” “revenue,” “timeout,” “SDK,” “telemetry,” “retention,” or “funnel” appears, do not invent a definition. Find a documented definition or ask the user to choose one.
