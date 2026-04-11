---
name: git-worktrees
description: Manage Git worktrees to work on multiple branches simultaneously. Use when the user wants to start a new feature, work on something in parallel, switch context without stashing, or mentions worktrees.
---

# Git Worktrees

Use worktrees to let the user work on multiple branches in separate directories without switching contexts.

## Creating a Worktree

When the user wants to work on something new in parallel:

1. Get the repo name and determine branch name:
   ```bash
   # Get repo name from current directory
   basename "$(git rev-parse --show-toplevel)"
   ```

2. Create the worktree as a sibling directory:
   ```bash
   git fetch origin
   git worktree add ../<repo>-<branch-slug> -b <branch-name> origin/main
   ```

   **Naming conventions:**
   - Branch: `feature/<name>` (e.g., `feature/login`)
   - Directory: `<repo>-<branch-slug>` (e.g., `myapp-feature-login`)
   - Convert slashes to dashes for the directory slug

3. Tell the user to open the worktree in a new Cursor window:
   ```
   Open in new window: cursor ../<repo>-<branch-slug>
   ```

## Example

User: "I want to work on user authentication"

```bash
git fetch origin
git worktree add ../myapp-feature-auth -b feature/auth origin/main
```

Then tell the user:
> Worktree created. Open it in a new window:
> ```
> cursor ../myapp-feature-auth
> ```

## Listing Worktrees

```bash
git worktree list
```

## Cleaning Up

When work is merged or abandoned:

```bash
git worktree remove ../<worktree-dir>
# Or if changes need to be discarded:
git worktree remove --force ../<worktree-dir>
```

## Tips

- Each worktree shares the same `.git` data—no extra clone needed
- If the user is already in a worktree, create new ones relative to the main repo
- Always fetch before creating to ensure origin/main is current
