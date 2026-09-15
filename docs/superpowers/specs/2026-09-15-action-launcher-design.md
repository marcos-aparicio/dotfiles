# Action launcher — design

Date: 2026-09-15

## Problem

A handful of recurring actions need a particular context before they can run:
a working directory (`just sync` in `~/dotfiles`), or a live tmux pane in a
particular session (an agent started on a particular task). Today that means
navigating to the session, `cd`-ing to the directory, and typing the command.
The navigation is the whole cost; the command itself is trivial.

## Shape

A directory of executable action scripts, one engine script that knows how to
place them in tmux, one television channel, one tmux bind.

```
~/dotfiles/actions/<id>          an action; the filename is its id
~/dotfiles/scripts/actions       the engine: list | preview | run
~/dotfiles/television/cable/actions.toml   thin channel over the engine
tmux bind                        opens the channel in a popup
```

Nothing is a config file. An action **is** a script, so it is directly
runnable (`~/.local/actions/sync-dotfiles`) without the picker, gets
shellcheck and syntax highlighting, and needs no parser, no placeholder
substitution, and no prompt schema. This mirrors the split already proven by
`scripts/dokploy-previews` + `television/cable/dokploy-previews.toml`: all
logic in the script, a thin declarative channel on top.

### Explicit non-goals

- No TOML/JSON action config, and therefore no `tomlq`/`jq` dependency.
- No declared prompt schema — an action that needs input calls `read`.
- No placeholder substitution into command strings — there are no command
  strings, so the brace-vs-television-template hazard documented in
  `dokploy-previews.toml` cannot occur here.
- No per-repo action files. One global directory.
- No desktop notifications (unreliable under WSL); tmux-native feedback only.

## Action script format

An action is any executable file in `$ACTIONS_DIR` (default `~/.local/actions`,
linked from `~/dotfiles/actions`). Metadata lives in comment headers in the
first 10 lines. Every header is optional.

| header     | values                                 | default                     |
|------------|----------------------------------------|-----------------------------|
| `desc:`    | free text shown in the picker           | the filename                |
| `cwd:`     | directory, `~` expanded                 | the launching pane's cwd    |
| `land:`    | `popup` \| `window` \| `pane` \| `background` | `popup`               |
| `session:` | target tmux session name                | the current session         |
| `confirm:` | `yes`                                   | no confirmation             |
| `tags:`    | space-separated words                   | none                        |

Tags are not a filter engine: they are appended to the searchable string so
typing `work` narrows the list. Context filtering is by `cwd` (below).

Examples:

```bash
#!/usr/bin/env bash
# desc: sync dotfiles
# cwd:  ~/dotfiles
# land: popup
just sync
```

```bash
#!/usr/bin/env bash
# desc: agent on the API backlog
# cwd:  ~/work/api
# land: window
# session: work
# tags: work agent
read -rp "task: " task
exec omp "$task"
```

## Engine CLI — `scripts/actions`

- `actions list [--here]` — one tab-separated row per action:
  `id <TAB> display <TAB> land <TAB> cwd`. `--here` keeps only actions whose
  `cwd` is unset, equal to, or an ancestor/descendant of the process's own
  `$PWD`. No shell interpolation is needed for this: the popup is opened with
  `-d "#{pane_current_path}"`, so the engine inherits the right cwd.
- `actions preview <id>` — resolved plan (cwd, landing, target session,
  whether it confirms) followed by the script body through `bat`.
- `actions run [--new] <id>` — resolve, confirm if required, dispatch.
  `--new` skips the find-or-create lookup and always spawns a fresh instance.

Header parsing is a `sed -n '1,10p'` plus one `sed` extraction per key. Bash
only; no new dependencies.

## Dispatch

`run` resolves cwd and target session first, creating the session detached if
it does not exist (the same `has-session || new-session -d` pattern already
used by the `prefix n`/`prefix b` binds).

- **popup** — runs in the picker's own popup: `cd "$cwd" && "$script"`, then
  prints `── exit N ── press enter` and waits, so output survives the popup
  closing.
- **window** — `tmux new-window -d -c "$cwd" -n "$id" -t "$session:"`, mark it,
  then `switch-client -t "$session"` + `select-window`. The engine exits, the
  popup closes, and the client is already on the new window.
- **pane** — `tmux split-window -c "$cwd" -t "$session:"` against that
  session's active window, mark it, then switch and `select-pane`.
- **background** — `tmux new-window -d`, window-local `remain-on-exit on` so a
  finished action's output stays readable, and a `tmux display-message` when
  it completes. No switch.

### Find-or-create

Spawned panes are marked with a pane-local user option:
`tmux set-option -p -t "$pane" @action "$id"`. Lookup is
`tmux list-panes -a -F '#{@action} #{session_name}:#{window_index}.#{pane_index}'`.
If a live pane carries the id, `run` switches to it instead of spawning a
second one — the open-or-create idempotence of `workmux add -o`.

A pane user option is deliberate. The obvious alternative, the pane title, is
overwritten by any program that sets the terminal title — which agents do —
so a title-keyed lookup would silently lose track of exactly the long-lived
actions this feature exists for. Window names are similarly unreliable once
`automatic-rename` is in play. `@action` is set once by tmux and never touched
by the running program. Requires tmux ≥ 3.0; this machine runs 3.4.

`land: popup` and `land: background` actions are not marked and always run
fresh: neither is something you return to.

## Confirmation

`confirm: yes` prints the resolved plan — action id, description, the command
file, cwd, landing mode, target session, and whether an existing instance was
found — and waits for `y`. Anything else aborts with a visible `aborted`. This
always runs inside the popup, which is a real terminal, so the prompt is
always usable.

## Television channel

```toml
[metadata]
name = "actions"
requirements = ["actions", "tmux"]

[source]
command = ["actions list --here", "actions list"]
display = "{split:\\t:1}"
output  = "{split:\\t:0}"

[preview]
command = "actions preview '{split:\\t:0}'"

[keybindings]
enter = "actions:run"
alt-n = "actions:run_new"
ctrl-e = "actions:edit"
```

Two sources rather than a filter flag: `ctrl-s` (`cycle_sources`, already
bound globally) toggles between *actions relevant here* and *everything*, and
the status bar names the active source. `actions:run` is `mode = "execute"`;
`actions:edit` opens the script in `$EDITOR`.

The `\\t` escaping is copied verbatim from the working `dokploy-previews`
channel, not from the television docs. `~/.local/scripts` is already on PATH
(`nushell/env.nu`), so the bare `actions` in these commands resolves.

No `watch`, for the reason recorded in `dokploy-previews.toml`: a reload that
lands while the `ctrl-x` action picker is open resolves the action against the
wrong row. The action list is static anyway; `ctrl-r` covers edits.

## tmux bind

```tmux
bind Space display-popup -h80% -w80% -d "#{pane_current_path}" -E "tv actions"
```

`prefix Space` overrides tmux's default `next-layout`, which is unused here;
every lowercase letter is already taken by existing binds.

## Installation

`install.conf.yaml` gains `~/.local/actions: actions`. `~/.local/scripts` and
`~/.config/television` are already linked, so the engine and the channel need
no new entries.

## Verification

Manual, in a real tmux client — this is tmux plumbing, so a test harness would
prove less than running it:

1. `sync-dotfiles` (`land: popup`) — output visible, popup closes on enter.
2. `agent-api` (`land: window`, `session: work`) fired from an unrelated
   session — the `work` session is created if absent, the window opens in the
   right cwd, and the client lands on it.
3. Re-fire `agent-api` while it is alive — switches to the existing pane, no
   duplicate. `alt-n` spawns a second one.
4. An action with `confirm: yes` — aborts on any key but `y`, and the plan it
   prints matches what runs.
5. `--here` filtering from inside `~/dotfiles` versus elsewhere; `ctrl-s`
   shows the full list.

The one genuinely uncertain mechanic is whether `switch-client` from inside a
`display-popup -E` lands correctly once the popup exits (the `tmux-dash` bind
avoids popups for exactly this reason, using `run-shell` instead). Step 2
settles it. If it does not hold, the fallback is the `sesh-menu.sh` pattern:
`run-shell` launching `fzf-tmux -p`, so the engine runs outside the popup.
That would change the launcher, not the engine or the action format.
