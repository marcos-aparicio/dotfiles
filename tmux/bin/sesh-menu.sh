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
    --bind 'ctrl-w:execute(session_name=$(echo {2..} | sed "s/\x1b\[[0-9;]*m//g"); session_path=$(sesh list --json | jq -r ".[] | select(.Name == \"$session_name\") | .Path"); tv workmux "$session_path")+abort' \
    --preview-window 'right:55%' \
    --preview 'sesh preview {2..}'
)"

[ -n "$selected" ] && sesh connect "$selected"
