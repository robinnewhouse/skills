---
name: kanban
description: Manage tasks on the user's Kanban, a tool for orchestrating coding agents in worktrees via a kanban board. This skill helps you create, edit, link, and start tasks using the kanban CLI. The user first launches kanban with e.g. npx kanban, then may ask you to help 'add tasks to kanban' or something to that effect (e.g. link / port over / break work down / split into kanban tasks). Only use this skill when the user mentions kanban.
---

# Kanban

Kanban is a CLI tool for orchestrating multiple coding agents working on tasks in parallel on a kanban board. It manages git worktrees automatically so that each task can run a dedicated CLI agent in its own worktree.

- If the user asks to add tasks to kb, ask kb, kanban, or says add tasks without other context, they likely want to add tasks in Kanban. This includes phrases like "create tasks", "make 3 tasks", "add a task", "break down into tasks", "split into tasks", "decompose into tasks", "turn into tasks", etc.
- Kanban also supports linking tasks. Linking is useful both for parallelization and for dependencies: when work is easy to decompose into multiple pieces that can be done in parallel, link multiple backlog tasks to the same dependency so they all become ready to start once that dependency finishes; when one piece of work depends on another, use links to represent that follow-on dependency. A link requires at least one backlog task, and when the linked review task is moved to trash, that backlog task becomes ready to start.
- Tasks can also enable automatic review actions: auto-commit, auto-open-pr, or auto-move-to-trash once completed, sending the task to trash and kicking off any linked tasks.
- There is a special case where the user may create a Kanban task to create new Kanban tasks. If the current working directory contains .kanban/worktrees/ in its path, you are running inside an ephemeral Kanban worktree. In this case, pass the main worktree path with `--project-path` so the new tasks are created under the correct workspace, not the ephemeral worktree path.
- If a task command fails because the runtime is unavailable, tell the user to start Kanban in that workspace first with `npx -y kanban`, then retry the task command.

# Command Prefix

Use this prefix for every Kanban command in this session:
`npx -y kanban`

# CLI Reference

All commands return JSON.

## task list

Purpose: list Kanban tasks for a workspace, including auto-review settings and dependency links.

Command:
`npx -y kanban task list [--project-path <path>] [--column backlog|in_progress|review]`

Parameters:
- `--project-path <path>` optional workspace path. If omitted, uses the current working directory workspace.
- `--column <value>` optional filter. Allowed values: `backlog`, `in_progress`, `review`.

## task create

Purpose: create a new task in `backlog`, with optional plan mode and auto-review behavior.

Command:
`npx -y kanban task create --prompt "<text>" [--project-path <path>] [--base-ref <branch>] [--start-in-plan-mode <true|false>] [--auto-review-enabled <true|false>] [--auto-review-mode commit|pr|move_to_trash]`

Parameters:
- `--prompt "<text>"` required task prompt text.
- `--project-path <path>` optional workspace path. If not already registered in Kanban, it is auto-added for git repos.
- `--base-ref <branch>` optional base branch/worktree ref. Defaults to current branch, then default branch, then first known branch.
- `--start-in-plan-mode <true|false>` optional. Default false. Set true only when explicitly requested.
- `--auto-review-enabled <true|false>` optional. Default false. Enables automatic action once task reaches review.
- `--auto-review-mode commit|pr|move_to_trash` optional auto-review action. Default `commit`.

## task update

Purpose: update an existing task, including prompt, base ref, plan mode, and auto-review behavior.

Command:
`npx -y kanban task update --task-id <task_id> [--prompt "<text>"] [--project-path <path>] [--base-ref <branch>] [--start-in-plan-mode <true|false>] [--auto-review-enabled <true|false>] [--auto-review-mode commit|pr|move_to_trash]`

Parameters:
- `--task-id <task_id>` required task ID.
- `--project-path <path>` optional workspace path. If not already registered in Kanban, it is auto-added for git repos.
- `--prompt "<text>"` optional replacement prompt text.
- `--base-ref <branch>` optional replacement base ref.
- `--start-in-plan-mode <true|false>` optional replacement of plan-mode behavior.
- `--auto-review-enabled <true|false>` optional replacement of auto-review toggle. Set false to cancel pending automatic review actions.
- `--auto-review-mode commit|pr|move_to_trash` optional replacement auto-review action.

Notes:
- Provide at least one field to change in addition to `--task-id`.

## task link

Purpose: link two tasks so one can wait on another. At least one linked task must be in backlog.

Command:
`npx -y kanban task link --task-id <task_id> --linked-task-id <task_id> [--project-path <path>]`

Parameters:
- `--task-id <task_id>` required first task ID.
- `--linked-task-id <task_id>` required second task ID.
- `--project-path <path>` optional workspace path. If not already registered in Kanban, it is auto-added for git repos.

## task unlink

Purpose: remove an existing task link (dependency) by dependency ID.

Command:
`npx -y kanban task unlink --dependency-id <dependency_id> [--project-path <path>]`

Parameters:
- `--dependency-id <dependency_id>` required dependency ID. Use `task list` to inspect existing links.
- `--project-path <path>` optional workspace path. If not already registered in Kanban, it is auto-added for git repos.

## task start

Purpose: start a task by ensuring its worktree, launching its agent session, and moving it to `in_progress`.

Command:
`npx -y kanban task start --task-id <task_id> [--project-path <path>]`

Parameters:
- `--task-id <task_id>` required task ID.
- `--project-path <path>` optional workspace path. If not already registered in Kanban, it is auto-added for git repos.

# Workflow Notes

- Prefer `task list` first when task IDs or dependency IDs are needed.
- To create multiple linked tasks, create tasks first, then call `task link` for each dependency edge.
- If `pwd` includes `/.kanban/worktrees/`, set `--project-path` to the main workspace path. You can derive it with:
`main_path="${PWD%%/.kanban/worktrees/*}"`
