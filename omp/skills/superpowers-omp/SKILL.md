---
name: superpowers-omp
description: Use when running any superpowers workflow in omp (subagent-driven-development, dispatching-parallel-agents, requesting-code-review, systematic-debugging, writing-plans) - maps superpowers' "Subagent (general-purpose)" dispatches onto omp's task agents and states what omp does differently.
---

# Superpowers on omp

Superpowers skills were written against Claude Code. They say
`Subagent (general-purpose):` with a `model:` field. omp works differently in two
ways that change how you dispatch. This skill is the translation layer.

## Role → agent

| Superpowers role | omp agent | Model |
|---|---|---|
| Implementer (`implementer-prompt.md`) | `sp-implementer` | `@sp_impl` (sonnet-5:high) |
| Fix-loop rounds 4-5 escalation | `sp-implementer-hard` | `@sp_capable` (opus-5:high) |
| Task reviewer (`task-reviewer-prompt.md`) | `sp-task-reviewer` | `@sp_review` |
| Scoped re-review (`re-review-prompt.md`) | `sp-re-reviewer` | `@sp_review` |
| Final whole-branch review (`code-reviewer.md`) | `sp-final-reviewer` | `@sp_capable` |
| Parallel bug investigation | `sp-debugger` | `@sp_impl` |
| Plan authoring (`writing-plans`) | `sp-planner` | `@sp_capable` |
| Transcription-only batch (plan contains the complete code) | bundled `sonic` | `@sp_cheap` (haiku-4-5:high) |

Each agent already carries its superpowers prompt as its system prompt. **Do not
paste the template body into the dispatch.** Send only the task-specific
material: paths, context, constraints, findings.

`brainstorming` and `using-superpowers` never become subagents — brainstorming is
a one-question-at-a-time dialogue with your human partner, and it dies in an
isolated context.

## Entry point → what actually happens

Superpowers' own skills only dispatch during execution. Plan authoring is written
as an in-session activity. On omp you delegate it:

| You say | Skill | Runs where |
|---|---|---|
| "let's build X" | `brainstorming` | **This session.** It is a dialogue: one question per message, and a hard gate on the user's approval. A subagent cannot hold it. |
| spec approved → plan | `writing-plans` | **Dispatch `sp-planner`** with the spec path. Reading the codebase and drafting a long plan is exactly the context you want out of this session. It returns the plan path, a task list, and its sequencing constraints — read the plan yourself before offering execution options. |
| plan's self-review checklist | `writing-plans` §Self-Review | **This session**, on the returned plan. The skill is explicit that this is not a dispatch, and `sp-planner` already ran its own pass. |
| "execute the plan" | `subagent-driven-development` | **Dispatch** per task: `sp-implementer` → `sp-task-reviewer` → fix loop → `sp-final-reviewer`. |
| several unrelated failures | `dispatching-parallel-agents` | **Dispatch** one `sp-debugger` per independent domain, all in one `tasks[]` array. |
| "review this" | `requesting-code-review` | **Dispatch `sp-final-reviewer`.** |

`sp-planner` is not in superpowers' own text — it is the omp addition that keeps
plan authoring out of the controller's context. Give it the spec path and the
repo; do not paste the spec.

## What omp does differently

**1. You cannot set a model per dispatch.** omp's `task` wire schema has no
`model` field; the model comes from the agent's frontmatter role alias, resolved
through `modelRoles` in `~/.omp/agent/config.yml`. So superpowers' "always specify
the model explicitly" becomes **choose the agent whose tier you want**. That is
why `sp-implementer-hard` exists as a separate agent: it is the rounds-4-5
capability bump.

To retune tiers globally, edit `modelRoles.sp_*` — never edit the agent files.

**2. Resuming a live subagent is `hub send`.** SDD fix rounds 1-3 say "resume the
original implementer". In omp: record the agent id from the dispatch result, then
`hub send` the findings verbatim to that id. It wakes idle and parked agents. Only
if that fails do you dispatch a fresh `sp-implementer` carrying the brief path,
report path, and findings — the report file is the persistent memory either way.

Implementers reach back the same way: they `hub send` questions to you. Answer
them; do not let a blocked implementer sit.

**3. Dispatch several agents by putting several entries in one `tasks[]` array.**
One call, one array = parallel. Separate calls = serialized. This is what
`dispatching-parallel-agents` means by "issue all dispatches in the same
response".

**4. Hand artifacts over as file paths, never inline text.** Everything you paste
into a dispatch stays resident in your context for the rest of the session and is
re-read every turn. The superpowers scripts exist for this:

```bash
skill://subagent-driven-development/scripts/sdd-workspace  PLAN_FILE
skill://subagent-driven-development/scripts/task-brief      PLAN_FILE N
skill://subagent-driven-development/scripts/review-package  PLAN_FILE BASE HEAD
```

Each prints the path it wrote. Pass the path. The content never enters your
context.

## Dispatch shapes

Implementer:

```json
{
  "context": "<one line: what this project is and where this task fits>",
  "tasks": [{
    "agent": "sp-implementer",
    "name": "Task3Auth",
    "task": "Task 3: <name>\n\nBrief (read first — your requirements, exact values verbatim): <BRIEF_PATH>\nReport file: <REPORT_PATH>\n\nInterfaces from earlier tasks the brief cannot know: <...>\nAmbiguity I already resolved: <...>"
  }]
}
```

Task review — three paths plus the constraints lens, nothing else:

```json
{
  "context": "Reviewing Task 3 of <plan>.",
  "tasks": [{
    "agent": "sp-task-reviewer",
    "task": "Brief: <BRIEF_PATH>\nImplementer report: <REPORT_PATH>\nDiff file: <PACKAGE_PATH>\nBase <BASE_SHA>, head <HEAD_SHA>.\n\nGlobal constraints binding this task (verbatim from the spec):\n<...>"
  }]
}
```

Parallel debugging — one array, one agent per independent failure domain:

```json
{
  "context": "6 failures after the refactor, three independent domains.",
  "tasks": [
    { "agent": "sp-debugger", "task": "Domain: src/agents/agent-tool-abort.test.ts ..." },
    { "agent": "sp-debugger", "task": "Domain: src/agents/batch-completion.test.ts ..." },
    { "agent": "sp-debugger", "task": "Domain: src/agents/tool-approval-race.test.ts ..." }
  ]
}
```

## Rules that still bind you

- **BASE is the commit you recorded before dispatching**, never `HEAD~1` — that
  silently drops all but the last commit of a multi-commit task.
- **Never dispatch two implementers in parallel** on the same worktree. Reviewers
  and debuggers on independent domains are fine.
- **Never fix findings yourself in the controller session.** Your context stays
  clean for coordination, and controller fixes skip review.
- **The ledger survives compaction; your memory does not.** Keep it at
  `<workspace>/progress.md` per the SDD skill.
- `task` results auto-deliver. Do not poll `hub jobs` in a loop — keep doing local
  work (ledger, next review package) and results arrive on their own.
