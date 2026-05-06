---
phase: questions
description: Use as QRSPI step 2 after approved goals.md to produce neutral research questions; avoids leaking intended solution into research.
---

# QRSPI Questions

Announce: "I'm using QRSPI Questions to generate neutral research questions."

## Required input

- Approved `goals.md`

If missing, return to the router and run the Goals phase first.

## Steps

1. Read approved `goals.md` only to understand what must be learned.
2. Generate `questions.md` with tagged questions:
   - `codebase`: how current code works
   - `web`: external docs/best practices/competitors
   - `hybrid`: needs both
3. Keep questions neutral. Do not reveal the planned change or desired answer.
4. Present `questions.md` for approval.
5. On approval, mark it `status: approved`.
6. Tell the user the next phase is Research, then return to the router before opening `phases/research/README.md`.

## Good question examples

- "Where is authentication state initialized and persisted?" (`codebase`)
- "What are recommended retry/backoff patterns for this provider API?" (`web`)
- "How do existing CLI commands validate input and report errors?" (`codebase`)

## Avoid

- "How should we add the new authentication feature?"
- "Which files need to change to implement the user's request?"
- Anything that gives researchers the user's desired solution.
