#!/usr/bin/env python3
"""Extract benchmark token/cost metrics without dropping OpenCode reasoning.

CSV columns:
agent,run,trial,task,passed,visible_output_tokens,reasoning_tokens,
output_plus_reasoning_tokens,cost_usd
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(errors="replace"))


def passed_from_result(result: dict[str, Any]) -> str:
    reward = (((result.get("verifier_result") or {}).get("rewards") or {}).get("reward"))
    if reward is None:
        return ""
    try:
        return "true" if float(reward) >= 1.0 else "false"
    except Exception:
        return ""


def opencode_reasoning_tokens(trial_dir: Path) -> int:
    path = trial_dir / "agent" / "opencode.txt"
    if not path.exists():
        return 0
    total = 0
    for line in path.read_text(errors="replace").splitlines():
        try:
            event = json.loads(line)
        except Exception:
            continue
        part = event.get("part") or {}
        tokens = part.get("tokens") or {}
        value = tokens.get("reasoning") or 0
        if isinstance(value, (int, float)):
            total += int(value)
    return total


def numeric_or_blank(value: Any) -> int | float | str:
    return value if isinstance(value, (int, float)) else ""


def extract_run(agent: str, run_dir: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for result_path in sorted(run_dir.glob("*/result.json")):
        trial_dir = result_path.parent
        result = load_json(result_path)
        agent_result = result.get("agent_result") or {}
        visible = agent_result.get("n_output_tokens")
        reasoning = opencode_reasoning_tokens(trial_dir) if agent.lower() == "opencode" else ""

        if isinstance(visible, (int, float)) and isinstance(reasoning, (int, float)):
            combined: int | float | str = visible + reasoning
        elif isinstance(visible, (int, float)):
            combined = visible
        else:
            combined = ""

        rows.append(
            {
                "agent": agent,
                "run": run_dir.name,
                "trial": trial_dir.name,
                "task": result.get("task_name") or trial_dir.name.split("__", 1)[0],
                "passed": passed_from_result(result),
                "visible_output_tokens": numeric_or_blank(visible),
                "reasoning_tokens": numeric_or_blank(reasoning),
                "output_plus_reasoning_tokens": numeric_or_blank(combined),
                "cost_usd": numeric_or_blank(agent_result.get("cost_usd")),
            }
        )
    return rows


def parse_run(value: str) -> tuple[str, Path]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("--run must be AGENT=/path/to/run")
    agent, path = value.split("=", 1)
    agent = agent.strip()
    run_dir = Path(path).expanduser()
    if not agent:
        raise argparse.ArgumentTypeError("agent label is empty")
    if not run_dir.is_dir():
        raise argparse.ArgumentTypeError(f"run dir does not exist: {run_dir}")
    return agent, run_dir


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", action="append", type=parse_run, required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    rows: list[dict[str, Any]] = []
    for agent, run_dir in args.run:
        rows.extend(extract_run(agent, run_dir))

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "agent",
        "run",
        "trial",
        "task",
        "passed",
        "visible_output_tokens",
        "reasoning_tokens",
        "output_plus_reasoning_tokens",
        "cost_usd",
    ]
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(out)


if __name__ == "__main__":
    main()
