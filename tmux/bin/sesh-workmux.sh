#!/usr/bin/env bash
# Open the workmux picker for the worktrees of a sesh session.
# $1 is a sesh entry as rendered by `sesh list` (the name column, without icon).
#
# This lives in a script rather than inline in an fzf `execute(...)` binding on
# purpose: fzf runs execute bodies through $SHELL, which here is nushell, and
# nushell cannot parse POSIX `var=$(...)` command substitution. A bare external
# command call is the only form both shells agree on.

set -u

name=$1

# Defensive only: --ansi already strips escape codes out of fzf placeholders.
name=$(printf '%s' "$name" | sed $'s/\033\\[[0-9;]*m//g')

path=$(sesh list --json | jq -r --arg name "$name" '.[] | select(.Name == $name) | .Path' | head -n 1)

# zoxide entries are named by their path (`~/Projects`), so they survive even if
# the session disappears from `sesh list` between render and keypress.
if [ -z "$path" ]; then
    case "$name" in
        "~/"*) path="$HOME/${name#\~/}" ;;
        /*) path=$name ;;
    esac
fi

if [ -z "$path" ] || [ ! -d "$path" ]; then
    tmux display-message "workmux: no directory for session '$name'"
    exit 0
fi

exec tv workmux "$path"
