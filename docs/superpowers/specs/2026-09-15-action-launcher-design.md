# Action launcher

Some commands only mean something in a particular cwd or a particular tmux
session, and the navigation costs more than the command. `prefix Space` opens
a television picker; the engine puts the command where it belongs.

## Pieces

| path | role |
|---|---|
| `actions/<id>` | an action: an executable, filename is its id |
| `scripts/actions` | engine: `list` / `preview <id>` / `run <id>` |
| `television/cable/actions.toml` | the picker |
| `bind Space` in `tmux/custom-bindings.tmux.conf` | opens it, rooted at the pane's cwd |
| `scripts/test-actions` | dispatch check against an isolated tmux server |

An action **is** a script, so there is no config format, no parser, no
placeholder substitution, and no prompt schema — an action that needs input
calls `read`. Headers in the first 10 lines: `desc`, `cwd`, `land`
(`popup`|`window`|`pane`), `session`, `confirm`.

## Three decisions worth remembering

**Re-fire finds the live pane via `@action`, a pane-local tmux option** — not
the pane title, which agents overwrite, and not the window name, which
`automatic-rename` rewrites. Set once by tmux, invisible to the program.

**`switch-client` from inside `display-popup -E` works.** The `tmux-dash` bind
avoids popups for this reason, so it was the one uncertain mechanic; step 2 of
`scripts/test-actions` proves the client lands on the spawned window.

**The bind runs `cd /` before `tv actions`.** tv resolves its first argument
as a directory before a channel name, so from a pane in `~/dotfiles` — which
has an `actions/` dir — it silently opened the *files* channel rooted there,
with the default `bat` preview. Reproduced both ways with an empty dir. The
pane's path rides in `ACT_PWD` instead of being the picker's cwd.

## Deliberately not built

- `land: background` and completion notifications — no action needed them yet.
- Context filtering / tags — fuzzy search over a handful of entries is enough.
  Add a second `[source]` entry when the list gets long.
- A "force a fresh instance" keybind — re-fire returning to the live pane is
  the point; add `--new` if a second instance ever makes sense.
