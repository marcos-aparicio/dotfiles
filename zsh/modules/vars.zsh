# for plugins
export ZVM_VI_INSERT_ESCAPE_BINDKEY="kj"

# XDG
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export XDG_CACHE_HOME=$HOME/.cache
export _XDG_CACHE_HOME=$HOME/.cache

# PATH
additional_paths=(
    $HOME/.config/composer/vendor/bin
    $HOME/.local/privbin
    $XDG_DATA_HOME/cargo/bin
    $HOME/.config/vit/sh
    $HOME/.config/zsh/bin
    $HOME/.config/awesome/sh
    $HOME/.config/ranger/sh
    $HOME/.config/tmux/sh
    $HOME/.local/expect
    $HOME/.local/scripts
    $HOME/.local/share/npm-global/bin
    $HOME/.cargo/bin
    /opt/sioyek/
)
additional_paths=$(echo "${additional_paths[@]}" | tr ' ' ':')
# default paths
export PATH=/usr/local/bin:$HOME/.local/bin:$PATH
# additional paths
export PATH="${additional_paths[@]}:$PATH"
[ -v XDG_DATA_DIRS ] &&\
    export XDG_DATA_DIRS=$XDG_DATA_DIRS:$HOME/.local/share ||\
    export XDG_DATA_DIRS=/usr/share:$HOME/.local/share

# ADDITIONAL
export TERM=xterm-256color
export GTK_THEME=Vivid-Dark-GTK
export EDITOR=/usr/bin/nvim
export HISTCONTROL=ignoredups
export JIRA_AUTH_TYPE="basic"
export WORDLISTS=$XDG_DATA_HOME/wordlists

export BROWSER=zen-browser
export MANPAGER="nvim +Man!"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
