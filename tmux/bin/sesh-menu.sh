#!/usr/bin/env bash
# Unified sesh session picker shared by the tmux sesh binds.
# $1 selects which filter to open in: all (default) | tmux | configs | zoxide | find
# From inside the menu you can still switch filters at any time:
#   ^a all  ^t tmux  ^g configs  ^x zoxide  ^f find  ^d kill session  ^w workmux

mode="${1:-all}"

case "$mode" in
  tmux)    list="sesh list -t --icons";           prompt='🪟  '; label=' tmux sessions ' ;;
  configs) list="sesh list -c --icons";           prompt='⚙️  '; label=' configs ' ;;
  zoxide)  list="sesh list -z --icons";           prompt='📁  '; label=' zoxide ' ;;
  find)    list="fd -H -d 2 -t d -E .Trash . ~";  prompt='🔎  '; label=' find ' ;;
  *)       list="sesh list --icons";              prompt='⚡  '; label=' sesh ' ;;
esac

selected="$(
  eval "$list" | fzf-tmux -p 90%,80% \
    --no-sort --ansi --border-label "$label" --prompt "$prompt" \
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find ^w workmux' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
    --bind "ctrl-w:execute($HOME/dotfiles/tmux/bin/sesh-workmux.sh {2..})+abort" \
    --preview-window 'right:55%' \
    --preview 'sesh preview {2..}'
)"

# No selection means ESC, or the ^w workmux bind handing off via +abort. Both
# are normal exits, but `run-shell` paints any non-zero status across the screen
# as "'sesh-menu.sh' returned 1", so this path has to end at 0 deliberately.
[ -n "$selected" ] || exit 0

# exec so a genuine connect failure still surfaces its own status.
exec sesh connect "$selected"
