#!/bin/bash
# From a workmux worktree window/session, jump to the project's main sesh session.
# Complements the ctrl-w bind in custom-bindings.tmux.conf (sesh session -> workmux worktree picker).

cwd="$1"

# Git exposes the main worktree's repository directory immediately, whereas
# workmux list scans every worktree and can take close to a second in large
# repositories. Keep workmux as a fallback for non-standard Git layouts.
main_git_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
case "$main_git_dir" in
    */.git) main_path=${main_git_dir%/.git} ;;
    *) main_path= ;;
esac

if [ -z "$main_path" ]; then
    main_path=$(cd "$cwd" 2>/dev/null && workmux list --json 2>/dev/null | jq -r '.[] | select(.is_main) | .path')
fi

if [ -z "$main_path" ]; then
    tmux display-message "goto-main: not inside a workmux worktree"
    exit 0
fi

select_session_name() {
    jq -r --arg p "$main_path" '
        [.[] | select(.Path == $p)] as $matches
        | ($matches | map(select(.Src == "tmux")) | .[0].Name) //
          ($matches | map(select(.Src == "config")) | .[0].Name) //
          ($matches | .[0].Name) //
          empty
    '
}

# Most targets are already-running tmux sessions. Avoid sesh's broad all-source
# scan on the hot path, while retaining it as a fallback for sessions that only
# exist in another source.
session_name=$(sesh list -t --json 2>/dev/null | select_session_name)
if [ -z "$session_name" ]; then
    session_name=$(sesh list -c --json 2>/dev/null | select_session_name)
fi
if [ -z "$session_name" ]; then
    session_name=$(sesh list --json 2>/dev/null | select_session_name)
fi

if [ -z "$session_name" ]; then
    tmux display-message "goto-main: no sesh session found for $main_path"
    exit 0
fi

sesh connect "$session_name"
