#!/usr/bin/env bash
# Unified sesh session picker shared by the tmux sesh binds.
# $1 selects which filter to open in: all (default) | tmux | dash | configs | zoxide | find
# From inside the menu you can still switch filters at any time:
#   ^a all  ^t tmux  ^r dashboards  ^g configs  ^x zoxide  ^f find  ^d kill session  ^w workmux

# Absolute, so the fzf reload/preview binds below still resolve no matter where
# the picker was invoked from.
self="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/sesh-menu.sh"

# The registry of gh-dash dashboards, in sesh's own [[session]] schema even
# though sesh never starts them (dash/* is blacklisted in sesh.toml, so they
# stay out of the project picker). Listing a repo here is what makes its
# dashboard offerable before it is running.
dash_config="$HOME/dotfiles/sesh-sessions/dash.toml"
dash_start="$HOME/.local/scripts/tmux-dash"

# name<TAB>expanded path, for every dash/* entry in the registry.
# tomllib over a hand-rolled parser: the file is sesh's schema, not ours, and a
# grep for `name =` would also pick up [[window]] blocks if any land in it.
dash_registry() {
  [ -r "$dash_config" ] || return 0
  python3 - "$dash_config" <<'PY' 2>/dev/null
import os, sys, tomllib

with open(sys.argv[1], "rb") as fh:
    doc = tomllib.load(fh)
for entry in doc.get("session", []):
    name, path = entry.get("name", ""), entry.get("path", "")
    if name.startswith("dash/") and path:
        print(f"{name}\t{os.path.expanduser(path)}")
PY
}

# `--list-dash` makes this script its own list command, so the `dash` mode and
# the ^r reload bind share one implementation with no nested quoting.
#
# Two sources, in this order:
#   🐙 live dash/* sessions, most recently active first — the ones you switch to
#   💤 registry entries with nothing running — picking one creates it
# The leading marker is not decoration: every bind below takes the target as
# {2..}, so a bare name would leave its first field stripped off.
if [ "${1:-}" = "--list-dash" ]; then
  # Session names are sanitized to [A-Za-z0-9_-] by tmux-dash, so they are safe
  # to split on whitespace and to match with grep -Fx.
  live="$(tmux list-sessions -F '#{session_activity} #{session_name}' 2>/dev/null \
    | sort -rn \
    | awk '$2 ~ /^dash\// { print $2 }')"

  [ -n "$live" ] && printf '🐙 %s\n' $live

  dash_registry | cut -f1 | while read -r name; do
    printf '%s\n' "$live" | grep -qFx "$name" || printf '💤 %s\n' "$name"
  done
  exit 0
fi

# One preview command for every mode, because ^r can switch the list out from
# under it: dash rows need their own handling, everything else is sesh's job.
if [ "${1:-}" = "--preview" ]; then
  target="${2:-}"
  case "$target" in
    dash/*)
      if tmux has-session -t "=$target" 2>/dev/null; then
        sesh preview "$target"
      else
        path="$(dash_registry | awk -F'\t' -v n="$target" '$1 == n { print $2 }')"
        printf 'not running — Enter starts gh dash in %s\n\n' "${path:-?}"
        [ -n "$path" ] && eza --all --git --icons --color=always "$path"
      fi
      ;;
    *) sesh preview "$target" ;;
  esac
  exit 0
fi

mode="${1:-all}"

# ^d kills the highlighted session and reloads. In dash mode it reloads the dash
# list rather than throwing you back to the full one: killing a stale dashboard
# to force a fresh GitHub fetch is the whole reason that bind gets used there,
# and the row stays visible afterwards as a 💤 entry.
kill_reload="sesh list --icons"
kill_prompt='⚡  '

case "$mode" in
  tmux)    list="sesh list -t --icons";           prompt='🪟  '; label=' tmux sessions ' ;;
  dash)    list="$self --list-dash";              prompt='🐙  '; label=' dashboards '
           kill_reload="$self --list-dash";       kill_prompt='🐙  ' ;;
  configs) list="sesh list -c --icons";           prompt='⚙️  '; label=' configs ' ;;
  zoxide)  list="sesh list -z --icons";           prompt='📁  '; label=' zoxide ' ;;
  find)    list="fd -H -d 2 -t d -E .Trash . ~";  prompt='🔎  '; label=' find ' ;;
  *)       list="sesh list --icons";              prompt='⚡  '; label=' sesh ' ;;
esac

selected="$(
  eval "$list" | fzf-tmux -p 90%,80% \
    --no-sort --ansi --border-label "$label" --prompt "$prompt" \
    --header '  ^a all ^t tmux ^r dash ^g configs ^x zoxide ^d tmux kill ^f find ^w workmux' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
    --bind "ctrl-r:change-prompt(🐙  )+reload($self --list-dash)" \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind "ctrl-d:execute(tmux kill-session -t {2..})+change-prompt($kill_prompt)+reload($kill_reload)" \
    --bind "ctrl-w:execute($HOME/dotfiles/tmux/bin/sesh-workmux.sh {2..})+abort" \
    --preview-window 'right:55%' \
    --preview "$self --preview {2..}"
)"

# No selection means ESC, or the ^w workmux bind handing off via +abort. Both
# are normal exits, but `run-shell` paints any non-zero status across the screen
# as "'sesh-menu.sh' returned 1", so this path has to end at 0 deliberately.
[ -n "$selected" ] || exit 0

# fzf returns the whole line, icon included. `sesh connect` knows how to ignore
# the icons sesh itself printed, but not the markers this script puts on dash
# rows, so each marker is both the branch condition and what gets stripped.
case "$selected" in
  # Running: dash/* is blacklisted and `sesh connect` resolves names through
  # that same list, so switch by exact tmux name instead. The '=' matters —
  # without it dash/foo could resolve to dash/foo-legacy.
  '🐙 '*)
    session="${selected#🐙 }"
    [ -n "${TMUX:-}" ] && exec tmux switch-client -t "=$session"
    exec tmux attach -t "=$session"
    ;;
  # Not running: hand off to tmux-dash rather than starting `gh dash` here. It
  # is run from the registry path and re-derives everything from there — the
  # canonical main worktree, the gh/extension/remote checks, the Dokploy
  # preview pane — and switches the client itself.
  '💤 '*)
    session="${selected#💤 }"
    path="$(dash_registry | awk -F'\t' -v n="$session" '$1 == n { print $2 }')"
    [ -n "$path" ] || { tmux display-message "dash: '$session' is not in $dash_config"; exit 0; }
    [ -d "$path" ] || { tmux display-message "dash: $path does not exist"; exit 0; }
    cd "$path" || exit 0
    exec "$dash_start"
    ;;
esac

# exec so a genuine connect failure still surfaces its own status.
exec sesh connect "$selected"
