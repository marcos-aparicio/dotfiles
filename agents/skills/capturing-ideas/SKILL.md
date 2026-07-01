---
name: capturing-ideas
description: Use when the user wants to quickly capture a bug, idea, or feature request into GitHub Issues without interrupting their current work — trigger phrases like "capture this", "log this for later", "add to the backlog", "note this down". Always dispatch as a subagent so the calling session's context stays untouched. Do NOT use this for full issue triage, grooming, or deciding what's ready to build — that's a separate, deliberate action (the `triage` skill).
disable-model-invocation: true
---

# Capturing Ideas

Fire-and-forget capture of a bug, idea, or feature request into GitHub
Issues. Zero judgment, zero blocking questions — a fragment or a full
paragraph are equally valid input. All refinement happens later, in the
separate `triage` skill.

## When invoked

Always run as a dispatched subagent/subtask. The calling session's context
must stay untouched — the user should be back to what they were doing
immediately after firing this.

## Process

1. **Determine the repo.** Run `git remote get-url origin` in the current
   working directory to resolve `owner/repo`. If there is no git repo
   here, ask once for the target repo — the only situation where a
   question is acceptable, since there's no way to infer it.

2. **Look for something similar before filing new.**
   - Search existing issues by the distinctive nouns/phrases in the
     capture (`gh issue list --search "..."` or `gh search issues "..."
     --repo owner/repo`), not a verbatim dump of the raw text.
   - If a clear duplicate is open: don't create a new issue — post a
     comment on the existing one instead (see comment format below), and
     report back that issue's number rather than a new one.
   - If something is loosely related but not a duplicate: file as normal,
     but add `Relates to #NN` in the body.
   - If a `.out-of-scope/` directory exists (written by the `triage`
     skill) and something in it clearly matches: still file it, but flag
     the prior rejection prominently in the one-line report back — don't
     silently drop it, don't block on it either.

3. **Categorize widely — `bug` or `enhancement`, nothing finer.** Guess
   from the text; default to `enhancement` if genuinely ambiguous. A wrong
   guess costs one label edit later; it's never blocking, so don't
   overthink it.

4. **File the issue** (or comment, per step 2) using the templates below.
   Title: a short line distilled from the capture (first sentence,
   trimmed) — never invented, never padded beyond what was actually said.

5. **Apply labels**: `needs-triage` + (`bug` | `enhancement`), using
   exactly these strings — unless `docs/agents/triage-labels.md` exists
   (written by `setup-matt-pocock-skills`) and maps them to different
   strings for this repo, in which case use that mapping instead.

6. **Report back one line**: issue number + URL, plus a prior-rejection
   flag if step 2 found one. Nothing else — no restating the capture, no
   follow-up questions.

## Issue body template

```markdown
## Captured

<the user's raw text, verbatim, untouched>

## Notes at capture time

<optional — only if something is genuinely obvious from a quick
grep/search: a pointer to a possibly-relevant file, an ambiguity worth
flagging, a `Relates to #NN`. Omit this section entirely rather than
force content into it.>
```

## Comment format (existing duplicate found)

```markdown
## Additional capture (<date>)

<the user's raw text, verbatim>
```

## What this skill does NOT do

- Does not ask clarifying questions, except resolving which repo when it
  truly can't be inferred.
- Does not grill, flesh out, or scope the idea — that's `triage`.
- Does not decide readiness (`ready-for-agent` / `ready-for-human`) —
  only ever applies `needs-triage`.
- Does not edit, close, or relabel any issue other than the one just
  created or commented on.
