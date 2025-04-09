eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

export fpath=("$HOME/.config/zsh/functions" $fpath)
# Load and initialise completion system
autoload -Uz compinit
compinit

# Completion files: Use XDG dirs
[ -d "$XDG_CACHE_HOME"/zsh ] || mkdir -p "$XDG_CACHE_HOME"/zsh
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME"/zsh/zcompcache
compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-$ZSH_VERSION

autoload bashcompinit
bashcompinit
source "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/appman"

eval "$(pyenv init - zsh)"

compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-"$ZSH_VERSION"
