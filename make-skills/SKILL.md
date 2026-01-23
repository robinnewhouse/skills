---
name: make-skills
description: Create or update Cline skills. Use when asked to write a new skill, edit an existing skill, or set up skill resources.
---

# Make Skills

Use this skill to create or update Cline skills in the correct directory structure.

## Workflow

1. Confirm the skill name and purpose.
2. Create a directory named exactly after the skill under the target skills path (global: `~/.cline/skills/`, project: `.cline/skills/`).
3. Add a `SKILL.md` with YAML frontmatter:
   - `name` must exactly match the directory name.
   - `description` should clearly indicate when to use the skill.
4. Write concise, step-by-step instructions that Cline can follow.
5. If supporting docs are needed, place them under a `docs/` folder and reference them with relative links.

## Reference Guide

Refer to the full skills guide at [skills.mdx](docs/skills.mdx) for structure, examples, and best practices.
