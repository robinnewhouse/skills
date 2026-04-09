---
name: pr-review
description: Review GitHub pull requests using the gh CLI. Use when asked to review a PR, check a pull request, or give feedback on a GitHub PR. Gathers PR info, analyzes changes, and helps approve or request changes.
---

# PR Review

You have access to the `gh` terminal command (already authenticated). Use it to review the PR the user asked about. You're already in the repo.

## 1. Gather PR Information

```bash
# Get PR details
gh pr view <PR-number> --json title,body,comments,author

# Get the full diff
gh pr diff <PR-number>

# Get list of changed files
gh pr view <PR-number> --json files
```

## 2. Understand the Context

For each modified file, read the original to understand what's being changed:

- Use `read_file` to examine original files in the main branch
- Use `search_files` to find related code patterns across the codebase
- Understand the "why" from the PR description and comments

## 3. Analyze the Changes

For each modified file, assess:
- What was changed and why (based on PR description)
- How it affects the codebase and potential side effects
- Code quality issues, potential bugs, performance implications
- Security concerns and test coverage

## 4. Ask for User Confirmation

Before submitting a review, present your assessment and ask the user:

```
Based on my review of PR #<number>, I recommend [approving/requesting changes]. Here's my justification:

[Key points about PR quality, implementation, and any concerns]

Would you like me to proceed?
```

Options: "Yes, approve the PR", "Yes, request changes", "No, I'd like to discuss further"

## 5. Ask if User Wants a Comment Drafted

After the user decides, ask if they'd like a comment drafted that they can review before submission.

Options: "Yes, please draft a comment", "No, I'll handle the comment myself"

## 6. Submit the Review

For single-line comments:
```bash
gh pr review <PR-number> --approve --body "Your approval message"
gh pr review <PR-number> --request-changes --body "Your feedback message"
```

For multi-line comments (preserves whitespace):
```bash
cat << EOF | gh pr review <PR-number> --approve --body-file -
Your multi-line
approval message with

proper whitespace formatting
EOF
```

## Comment Style Guidelines

- Talk normally, like a friendly reviewer. Keep it short.
- Start by thanking the author and @mentioning them.
- Give a quick, humble summary of the changes ("from what I can tell..." style).
- If you have suggestions or things that need changing, request changes instead of approving.
- Inline code comments are good, but only if you have something specific to say. Leave those first, then submit the overall review with a short comment explaining the theme of requested changes.

## Example Comments

**Brief approve:**
> Looks good, though we should make this generic for all providers & models at some point

**Approve with detail:**
> This looks great! I like how you've handled the global endpoint support - adding it to the ModelInfo interface makes total sense since it's just another capability flag.
>
> The filtered model list approach is clean and will be easier to maintain than hardcoding which models work with global endpoints.
>
> Thanks for adding the docs about the limitations too.

**Request changes:**
> This is awesome. Thanks @author.
>
> My main concern though - does this work for all the possible VS Code themes? We struggled with this initially which is why it's not super styled currently. Please test and share screenshots with the different themes to make sure before we can merge.

**Request changes (multiple points):**
> Heya @author thanks for working on this!
>
> A few notes:
> 1 - First concern
> 2 - Second concern
> 3 - What we'd need to see before merging
>
> So until X is addressed, I don't think we can merge this. Please bear with us.

## Common gh Commands Reference

```bash
# List open PRs
gh pr list

# View PR with specific fields
gh pr view <PR-number> --json title,body,comments,files,commits

# Check PR status
gh pr status

# View PR checks
gh pr checks <PR-number>

# Check out a PR locally
gh pr checkout <PR-number>

# Add a comment (without approval/rejection)
gh pr review <PR-number> --comment --body "Your comment"
```
