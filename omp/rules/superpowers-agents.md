---
name: superpowers-agents
description: Routes superpowers workflows onto omp task agents instead of generic subagents.
alwaysApply: true
---

# Superpowers runs on omp task agents

Superpowers skills were written for Claude Code and say `Subagent (general-purpose):`.
In omp that is wrong. The roles are real task agents — dispatch them by name:

`sp-planner` · `sp-implementer` · `sp-implementer-hard` · `sp-task-reviewer` ·
`sp-re-reviewer` · `sp-final-reviewer` · `sp-debugger`

Each already carries its superpowers prompt and its own model tier. Never paste a
superpowers template body into a dispatch, and never dispatch the generic `task`
agent for a superpowers role.

Before the first dispatch of any superpowers workflow, read `skill://superpowers-omp`.

Two exceptions that stay in this session: `brainstorming` (it is a dialogue with
the user) and the plan self-review checklist in `writing-plans`.
