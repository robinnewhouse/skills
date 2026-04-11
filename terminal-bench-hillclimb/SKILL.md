---
name: terminal-bench-hillclimb
description: Improve Cline's Terminal-Bench benchmark score by analyzing failures, researching prompting best practices, implementing targeted prompt changes, building the CLI, and running Harbor tests. Use when asked to fix a Terminal-Bench failure, improve Cline prompts, hillclimb benchmark scores, or test prompt changes against Terminal-Bench.
---

# Terminal-Bench Hillclimb

End-to-end workflow for improving Cline CLI's Terminal-Bench performance: analyze a failure → research → implement prompt fix → build → test → report.

## Prerequisites

- Cline repo at `~/dev/cline` (prompt source code)
- Harbor repo at `~/dev/harbor` (benchmark runner)
- `gh` CLI authenticated with access to `cline/cline` repo
- Environment variables in `~/.env`: `OPENROUTER_API_KEY` or `CLINE_API_KEY`
- Harbor installed: `cd ~/dev/harbor && uv tool install --force --editable .`

## Step 1: Identify the Failure

The user will point you to a failed task. Find the failure data:

```bash
# If given a job directory, find the failed trial
ls ~/dev/harbor/jobs/<job-id>/

# Or find the latest job
ls -t ~/dev/harbor/jobs/ | head -1

# Read the task's verifier output (what failed)
cat ~/dev/harbor/jobs/<job-id>/<task-name>__*/verifier/test-stdout.txt

# Read the agent conversation log (what the agent did)
cat ~/dev/harbor/jobs/<job-id>/<task-name>__*/agent/cline.txt

# Read the trial result
cat ~/dev/harbor/jobs/<job-id>/<task-name>__*/result.json | jq '.verifier_result'

# Check for exceptions (timeouts etc)
cat ~/dev/harbor/jobs/<job-id>/<task-name>__*/exception.txt 2>/dev/null
```

**Categorize the failure.** Common patterns include (but are not limited to):
- **Self-sabotage**: Agent cleaned up/deleted its own outputs after verifying they worked
- **Wrong output format**: Extra columns, extra lines, wrong file path, debug output in result files
- **Missing dependency**: Script uses third-party package not available in verifier environment
- **Premature completion**: Agent didn't verify its work before declaring done
- **Timeout**: Ran out of time; check if time was wasted on unnecessary operations
- **Near-miss**: Correct approach but output just outside threshold (off by small margin)
- **Context overflow**: Tried to read a file too large for the context window
- **Wrong approach**: Fundamentally incorrect algorithm or strategy

These are examples from prior analysis. Use your judgment — the actual failure may not fit neatly into any of these. Read the agent log and verifier output carefully to understand what actually happened, and describe the root cause in your own words.

## Step 2: Research Prompting Best Practices

Read these resources to inform your prompt improvement:

### 2a. Read Cline's current prompts (the code you'll modify)

```bash
# The variant Opus 4.6 uses (next-gen):
cat ~/dev/cline/src/core/prompts/system-prompt/variants/next-gen/template.ts

# Shared components:
cat ~/dev/cline/src/core/prompts/system-prompt/components/objective.ts
cat ~/dev/cline/src/core/prompts/system-prompt/components/capabilities.ts
cat ~/dev/cline/src/core/prompts/system-prompt/components/rules.ts

# Tool definitions (for execute_command, attempt_completion etc):
ls ~/dev/cline/src/core/prompts/system-prompt/tools/
cat ~/dev/cline/src/core/prompts/system-prompt/tools/attempt_completion.ts
cat ~/dev/cline/src/core/prompts/system-prompt/tools/execute_command.ts
```

### 2b. Read the existing analysis document

```bash
cat ~/dev/cline/docs/TERMINAL_BENCH_OPUS_4_6_ANALYSIS.md
```

This contains the full failure categorization, ranked suggestions, and PR tracking.

### 2c. Check recent prompt-related PRs and commits

```bash
cd ~/dev/cline
# Recent merged prompt PRs
gh pr list --author saoudrizwan --state merged --limit 10 --json number,title,mergedAt --jq '.[] | "\(.number) | \(.mergedAt) | \(.title)"'

# Search for prompt-related commits
git log --oneline --all --grep="prompt" --since="2 weeks ago" | head -20
git log --oneline --all --grep="terminal" --since="2 weeks ago" | head -20

# Check what's already been addressed
gh pr view <number> --json body --jq '.body' | head -50
```

### 2d. Read leaked system prompts for inspiration

Use `curl` or `web_fetch` to read:
- Claude Opus 4.6: `https://raw.githubusercontent.com/asgeirtj/system_prompts_leaks/main/Anthropic/claude-opus-4.6.md`
- Look for patterns around: verification behavior, output formatting, cleanup behavior, reasoning effort

### 2e. Read agent best practices

Key principles from Cursor's guide (https://cursor.com/blog/agent-best-practices):
- **Verifiable goals**: Give agents clear signals for whether changes are correct
- **Plan before acting**: Complex tasks benefit from planning first
- **Iterate until tests pass**: Agents perform best with a clear target to iterate against
- **Start simple**: Don't over-optimize before understanding patterns

## Step 3: Design the Prompt Change

Based on your failure analysis and research:

1. **State the failure pattern** in one sentence
2. **Identify which prompt file** needs changing (usually `next-gen/template.ts` rules section or `objective.ts`)
3. **Write the exact rule text** to add or modify
4. **Explain why** this change addresses the failure without risking regressions on passing tasks
5. **Check for conflicts** with existing rules — don't contradict what's already there

**Guidelines for prompt changes:**
- Be surgical: add ONE rule that addresses the specific failure
- Use clear, imperative language the model will follow
- Don't be vague ("be careful") — be specific ("verify file exists with `test -f`")
- Place the new rule near related existing rules
- Keep it short — long rules get less attention from the model

## Step 4: Implement the Change

```bash
cd ~/dev/cline

# Create a branch from main
git checkout main
git pull origin main
git checkout -b fix/prompt-<descriptive-name>

# Edit the prompt file (usually one of these):
# - src/core/prompts/system-prompt/variants/next-gen/template.ts
# - src/core/prompts/system-prompt/components/objective.ts
# - src/core/prompts/system-prompt/components/rules.ts

# Make your targeted edit
# ... (use replace_in_file or write_to_file)

# Update prompt snapshots
npm run test:unit -- src/core/prompts/system-prompt/__tests__/integration.test.ts --update-snapshots

# Verify tests pass
npm run test:unit -- src/core/prompts/system-prompt/__tests__/integration.test.ts

# Commit and push
git add -A
git commit -m "fix(prompt): <description of what you changed and why>"
git push origin fix/prompt-<descriptive-name>
```

## Step 5: Build the CLI from Your Branch

Use the `pack-cli.yml` GitHub Actions workflow to create a pre-built tarball:

```bash
cd ~/dev/cline

# Trigger the build
gh workflow run pack-cli.yml -f ref=fix/prompt-<descriptive-name>

# Monitor the build (~2-3 min)
gh run list --workflow=pack-cli.yml --limit 3

# Wait for completion (blocks until done)
gh run watch $(gh run list --workflow=pack-cli.yml --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status

# Get the tarball URL from the release
RELEASE_TAG=$(gh release list --limit 1 --json tagName --jq '.[0].tagName')
TARBALL_URL=$(gh release view $RELEASE_TAG --json assets --jq '.assets[0].url')
echo "Tarball URL: $TARBALL_URL"
```

## Step 6: Run the Harbor Test

Test the specific failing task with your new build:

```bash
cd ~/dev/harbor
source ~/.env
export API_KEY=$OPENROUTER_API_KEY  # or $CLINE_API_KEY

# Run the specific failing task
harbor run \
  -d terminal-bench@2.0 \
  -t "<task-name>" \
  -a cline-cli \
  -m openrouter:anthropic/claude-opus-4.6 \
  --ak tarball_url=$TARBALL_URL \
  --env docker \
  -n 1 \
  --force-build
```

For Modal (parallel/full runs):
```bash
harbor run \
  -d terminal-bench@2.0 \
  -t "<task-name>" \
  -a cline-cli \
  -m openrouter:anthropic/claude-opus-4.6 \
  --ak tarball_url=$TARBALL_URL \
  --env modal \
  -n 1
```

## Step 7: Check Results

### Trial directory structure
```
jobs/<job-id>/<task-name>__<random-id>/
├── result.json          ← Main result file
│   └── .verifier_result.rewards  ← 1.0 = pass, 0.0 = fail
│   └── .exception_info          ← null if no crash
│   └── .config.agent.kwargs     ← confirms which tarball was used
├── config.json          ← Full trial configuration
├── exception.txt        ← If infrastructure crashed (Modal timeout, sandbox died, etc.)
├── trial.log            ← Harbor orchestration log
├── agent/
│   ├── cline.txt        ← Full agent conversation log (THE key file for debugging)
│   ├── install.sh       ← Generated install script (verify tarball URL was templated correctly)
│   ├── setup/           ← Install output (check if cline installed successfully)
│   ├── command-0/       ← Setup config command output
│   ├── command-1/       ← Auth command output
│   └── command-2/       ← Cline run command output
└── verifier/
    ├── test-stdout.txt  ← Pytest output (GROUND TRUTH — did tests pass?)
    ├── reward.txt       ← Numeric reward value
    └── ctrf.json        ← Test results in CTRF format
```

### Quick commands
```bash
# Find the latest job
JOB=$(ls -t ~/dev/harbor/jobs/ | head -1)

# Quick pass/fail check
cat ~/dev/harbor/jobs/$JOB/<task-name>__*/result.json | jq '.verifier_result.rewards'

# Read verifier output (ground truth)
cat ~/dev/harbor/jobs/$JOB/<task-name>__*/verifier/test-stdout.txt

# Read what the agent actually did (end of conversation)
tail -50 ~/dev/harbor/jobs/$JOB/<task-name>__*/agent/cline.txt

# Check for specific behavior patterns
grep -n "rm\|reset\|clean\|delete" ~/dev/harbor/jobs/$JOB/<task-name>__*/agent/cline.txt

# Check if infrastructure crashed (Modal sandbox died, timeout, etc.)
cat ~/dev/harbor/jobs/$JOB/<task-name>__*/exception.txt 2>/dev/null

# Verify which tarball was used
cat ~/dev/harbor/jobs/$JOB/<task-name>__*/result.json | jq '.config.agent.kwargs'

# Check install succeeded
cat ~/dev/harbor/jobs/$JOB/<task-name>__*/agent/setup/stdout.txt | tail -10
```

### Common result patterns
- `verifier_result.rewards = {"1.0": [...]}` → PASSED
- `verifier_result.rewards = {"0.0": [...]}` → FAILED (read test-stdout.txt)
- `verifier_result = null` + `exception_info.exception_type = "NotFoundError"` → Modal sandbox died before verifier ran (inconclusive, retry needed)
- `exception_info.exception_type = "AgentTimeoutError"` → Agent ran out of time
- No `cline.txt` file → Agent install or auth failed (check setup/stdout.txt)

## Step 8: Report to User

Present a summary with:

1. **Task that failed**: `<task-name>`
2. **Failure category**: (from Step 1 categorization)
3. **Root cause**: What the agent did wrong and why
4. **Prompt change made**: The exact rule text added/modified
5. **Why this should help**: How the rule addresses the root cause
6. **Branch**: `fix/prompt-<name>` on `cline/cline`
7. **CLI Build URL**: The GitHub Release tarball URL
8. **Harbor Job**: The job directory or Modal dashboard URL
9. **Result**: Did the task pass? If not, what happened differently?

Example output:
```
## Hillclimb Result

**Task**: configure-git-webserver (previously FAILED)
**Category**: Self-sabotage — agent deleted deployed files after verification
**Branch**: fix/prompt-no-cleanup-rule
**Build**: https://github.com/cline/cline/releases/download/cli-build-6b07e8c/cline-2.0.5.tgz
**Harbor Job**: jobs/2026-02-07__15-31-40/

### Prompt Change
Added to next-gen rules_template:
> "After completing a task, NEVER clean up, reset, or remove files, services, 
> or deployed content you created. Leave everything in its working state."

### Why
The agent previously verified hello.html was served correctly, then ran 
`rm -rf /var/www/html/*` "to start fresh," causing the verifier to find HTTP 404.

### Result
✅ PASSED — Agent left deployed files intact. Verifier confirmed hello.html served.
```

## Tips

- **Test one change at a time** — Don't combine multiple prompt changes in one test
- **Run the exact failing task** — Don't run the full 89-task suite until you've confirmed the fix works on the specific task
- **Check for regressions** — After confirming the fix, run 2-3 previously-passing tasks to make sure you didn't break them
- **Keep the analysis doc updated** — Update `~/dev/cline/docs/TERMINAL_BENCH_OPUS_4_6_ANALYSIS.md` with findings
- **The verifier is the ground truth** — Don't trust agent self-reports; always check `verifier/test-stdout.txt`
