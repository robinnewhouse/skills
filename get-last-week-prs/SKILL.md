---
name: get-last-week-prs
description: Summarize GitHub pull request activity. Use when asked about recent PRs, work summary, what was accomplished, or weekly updates. Supports custom time ranges, repos, and authors.
---

# Get PR Activity Summary

This skill retrieves and summarizes GitHub pull request activity for a user.

## Parameters

Extract these from the user's request (all optional):
- **since**: Time range (e.g., "last week", "last day", "14 days ago", "2024-01-01"). Default: "7 days ago"
- **repo**: Repository in owner/repo format. Default: "cline/cline"
- **author**: GitHub username. Default: "robinnewhouse"

## Steps

1. **Parse the user's request** to extract any custom parameters:
   - "last day" / "yesterday" → `-s "1 day ago"`
   - "last 2 weeks" → `-s "14 days ago"`
   - "since January 1st" → `-s "2024-01-01"`
   - Specific repo mentioned → `-r owner/repo`
   - Specific author mentioned → `-a username`

2. **Run the PR script** with appropriate flags:
   ```bash
   /Users/robin/dev/tools/gh_prs.sh [-r REPO] [-a AUTHOR] [-s SINCE]
   ```
   
   Examples:
   - Default (last week): `/Users/robin/tools/gh_prs.sh`
   - Last day: `/Users/robin/tools/gh_prs.sh -s "1 day ago"`
   - Custom repo: `/Users/robin/tools/gh_prs.sh -r facebook/react`
   - All options: `/Users/robin/tools/gh_prs.sh -r cline/cline -a robinnewhouse -s "14 days ago"`

3. **Analyze the output** and create a comprehensive summary that includes:
   - **Overview**: Total PRs opened and merged in the time period
   - **Key Accomplishments**: High-level themes of what was achieved (group related PRs)
   - **Notable PRs**: Highlight significant or complex work
   - **Status Breakdown**: What's merged, what's still open, what's closed without merge
   - **Impact Summary**: Brief statement on overall contribution

4. **Inspect code changes if needed**: If a PR title/description is unclear about the actual contribution, use gh CLI to inspect the diff:
   ```bash
   # View the diff for a specific PR
   gh pr diff <PR_NUMBER> --repo <OWNER/REPO>
   
   # View files changed
   gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json files
   
   # View commits in the PR
   gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json commits
   ```
   Use this to provide accurate descriptions of what was actually changed.

## Output Format

Present the summary in a clear, readable format like:

```
## PR Activity Summary
**Period**: [date range]
**Repository**: [repo]
**Author**: [username]

### Overview
- X PRs opened
- Y PRs merged  

### Key Accomplishments
- [Theme 1]: Brief description (PRs #X, #Y)
- [Theme 2]: Brief description (PR #Z)

### Status
- ✅ Merged: #A, #B, #C
- 🔄 Open: #D
- ❌ Closed: #E

### Summary
[1-2 sentence summary of the work accomplished]
```

## Notes

- The script requires `gh` CLI to be authenticated
- It automatically detects macOS vs Linux for date handling
- If jq is available, JSON output is used for cleaner parsing
