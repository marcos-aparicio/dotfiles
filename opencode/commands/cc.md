---
description: Generate a conventional commit message for staged changes
---

Here are the staged changes in the repository:

!`git diff --cached`

Based on these changes, generate a conventional commit message following the Conventional Commits standard:

- Start with a type: feat, fix, docs, style, refactor, perf, test, chore, ci
- Format: `type(scope): subject`
- Keep the subject line under 50 characters
- Use imperative mood ("add" not "added")
- No period at the end
- Optionally include a detailed body separated by a blank line

Only provide the commit message without any additional commentary.
