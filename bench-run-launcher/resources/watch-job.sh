#!/usr/bin/env bash
set -euo pipefail

# watch-job.sh — Monitor a Harbor benchmark job (SWE-bench or Terminal-Bench).
#
# Usage:
#   bash watch-job.sh <JOB_DIR>
#   bash watch-job.sh <JOB_NAME>            # resolved under $HARBOR_DIR/jobs/
#   watch -n 15 'bash watch-job.sh <JOB>'   # auto-refresh every 15s
#
# The script auto-detects the harbor root from the job directory or falls back
# to the current working directory.

# --- resolve job directory ------------------------------------------------

resolve_job_dir() {
  local input="$1"
  if [[ -d "$input" ]]; then
    printf '%s\n' "$input"
    return
  fi
  # Try common Harbor job locations
  for candidate in \
    "${HARBOR_DIR:-$PWD}/jobs/$input" \
    "${HARBOR_DIR:-$PWD}/jobs_sdk/$input" \
    "$PWD/jobs/$input" \
    "$PWD/jobs_sdk/$input"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  return 1
}

# --- helpers --------------------------------------------------------------

format_duration() {
  local s="${1:-0}"
  local h=$((s / 3600)) m=$(((s % 3600) / 60)) sec=$((s % 60))
  if [[ $h -gt 0 ]]; then printf '%sh %sm %ss' "$h" "$m" "$sec"
  elif [[ $m -gt 0 ]]; then printf '%sm %ss' "$m" "$sec"
  else printf '%ss' "$sec"
  fi
}

# --- show active harbor run processes ------------------------------------

show_runners() {
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Harbor runners:"
  local found=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    found=1
    local pid elapsed cmd
    pid="$(awk '{print $1}' <<< "$line")"
    elapsed="$(awk '{print $2}' <<< "$line")"
    cmd="$(cut -d' ' -f3- <<< "$line")"
    echo "  PID $pid (${elapsed}): $cmd"
  done < <(ps -Ao pid=,etime=,command= 2>/dev/null \
    | grep -E "harbor run.*(swebench-verified|terminal-bench)" \
    | grep -v grep || true)
  [[ $found -eq 0 ]] && echo "  none"
  echo
}

# --- summarize a single job directory ------------------------------------

summarize_job() {
  local job_dir="$1"
  python3 - "$job_dir" <<'PYEOF'
from __future__ import annotations
import json, sys, os
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

job_dir = Path(sys.argv[1])

def read_json(p):
    try: return json.loads(p.read_text())
    except Exception: return None

def read_reward(td):
    rp = td / "verifier" / "reward.txt"
    if not rp.exists(): return None
    try: return float(rp.read_text().strip())
    except Exception: return None

def trial_duration(result):
    if not result: return None
    try:
        from datetime import datetime as dt
        s, e = result.get("started_at"), result.get("finished_at")
        if not s or not e: return None
        for fix in [("Z", "+00:00")]:
            if s.endswith(fix[0]): s = s[:-1] + fix[1]
            if e.endswith(fix[0]): e = e[:-1] + fix[1]
        return max(0, int((dt.fromisoformat(e) - dt.fromisoformat(s)).total_seconds()))
    except Exception:
        return None

def fmt_ts(epoch):
    if not epoch: return "unknown"
    return datetime.fromtimestamp(epoch, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

def fmt_dur(s):
    if s is None: return "unknown"
    h, r = divmod(int(s), 3600)
    m, sec = divmod(r, 60)
    if h > 0: return f"{h}h {m}m {sec}s"
    if m > 0: return f"{m}m {sec}s"
    return f"{sec}s"

# --- read config ----------------------------------------------------------
config = read_json(job_dir / "config.json") or {}
orch = config.get("orchestrator") or {}
agents = config.get("agents") or []
datasets = config.get("datasets") or []
n_concurrent = orch.get("n_concurrent_trials")
tarball = ((agents[0] if agents else {}).get("kwargs") or {}).get("tarball_url")
cfg_tasks = None
for ds in datasets:
    n = ds.get("n_tasks")
    if isinstance(n, int) and n > 0:
        cfg_tasks = (cfg_tasks or 0) + n
    else:
        names = ds.get("task_names")
        if isinstance(names, list) and names:
            cfg_tasks = (cfg_tasks or 0) + len(names)

# --- walk trials ----------------------------------------------------------
trial_dirs = sorted([p for p in job_dir.iterdir() if p.is_dir() and not p.name.startswith(".")])
totals = Counter()
dur_sum = 0; dur_count = 0
active_rows = []; finished_rows = []
agg_tools = 0; agg_cmds = 0; agg_turns = 0

for td in trial_dirs:
    reward = read_reward(td)
    result = read_json(td / "result.json")

    if reward is not None:
        status = "passed" if reward >= 1.0 else "failed"
    elif result:
        exc = (result.get("exception_info") or {}).get("exception_type")
        if exc:
            status = "error"
        else:
            vr = result.get("verifier_result")
            if isinstance(vr, dict):
                r = (vr.get("rewards") or {}).get("reward")
                if r is not None:
                    try: status = "passed" if float(r) >= 1.0 else "failed"
                    except: status = "done"
                else: status = "done"
            else: status = "done"
    else:
        status = "running"

    totals[status] += 1
    d = trial_duration(result)
    if d is not None:
        dur_sum += d; dur_count += 1

    # cline.txt light metrics
    cline_path = td / "agent" / "cline.txt"
    tools = cmds = turns = 0
    if cline_path.exists():
        try:
            for raw in cline_path.read_text(errors="replace").splitlines():
                line = raw.strip()
                if not line.startswith("{"): continue
                try: p = json.loads(line)
                except: continue
                if p.get("type") != "say": continue
                s = p.get("say")
                if s == "tool": tools += 1
                elif s == "command": cmds += 1
                elif s == "api_req_started": turns += 1
        except: pass
    agg_tools += tools; agg_cmds += cmds; agg_turns += turns

    parts = td.name.split("__")
    display = "__".join(parts[:2]) if len(parts) >= 2 else td.name
    row = {"name": display, "status": status, "tools": tools, "cmds": cmds, "turns": turns}
    if status == "running":
        active_rows.append(row)
    else:
        finished_rows.append(row)

# --- print ----------------------------------------------------------------
n_total = len(trial_dirs)
n_done = n_total - totals["running"]
n_pass = totals["passed"]
target = cfg_tasks if cfg_tasks and cfg_tasks > n_total else n_total

print(f"Job:           {job_dir.name}")
print(f"Path:          {job_dir}")
if n_concurrent: print(f"Concurrency:   {n_concurrent}")
if tarball: print(f"Tarball:       {tarball.split('/')[-1].split('?')[0]}")
print("---")
print(f"Trials:        {n_done}/{target} complete ({totals['running']} running)")
print(f"  Passed:      {n_pass}")
print(f"  Failed:      {totals['failed']}")
print(f"  Errors:      {totals['error']}")
if n_done:
    print(f"Pass rate:     {100.0*n_pass/n_done:.1f}% ({n_pass}/{n_done})")
if target > 0:
    remaining = target - n_done
    if remaining < 0: remaining = 0
    lo = 100.0 * n_pass / target
    hi = 100.0 * min(n_pass + remaining, target) / target
    print(f"Score bounds:  {lo:.1f}% – {hi:.1f}%")
if dur_count:
    avg = dur_sum / dur_count
    print(f"Mean duration: {avg:.0f}s (~{fmt_dur(avg)}) over {dur_count} trials")

status_label = "complete" if n_done >= target and target > 0 else "running"
print(f"Status:        {status_label}")
print(f"---")
print(f"Agg tools:     {agg_tools}  |  commands: {agg_cmds}  |  api turns: {agg_turns}")

if active_rows:
    print("---")
    print("Active:")
    for r in active_rows[:8]:
        print(f"  {r['name']}: tools={r['tools']} cmds={r['cmds']} turns={r['turns']}")
if finished_rows:
    print("---")
    print("Recent finished:")
    for r in finished_rows[-6:]:
        print(f"  {r['name']}: {r['status']} tools={r['tools']} cmds={r['cmds']} turns={r['turns']}")
PYEOF
}

# --- main -----------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "Usage: bash watch-job.sh <JOB_DIR_OR_NAME> [...]" >&2
  exit 1
fi

show_runners

for arg in "$@"; do
  job_dir="$(resolve_job_dir "$arg")" || { echo "Job not found: $arg" >&2; exit 1; }
  summarize_job "$job_dir"
  echo
done
