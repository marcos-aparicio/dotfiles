# setup lf wrapper
LFCD="$HOME/.config/lf/lfcd.sh"
if [ -f "$LFCD" ]; then
    source "$LFCD"
    alias lf='lfcd'
fi

# to get use to yazi
alias lf="y"


# Lazy load sdkman only when 'sdk' is called
export SDKMAN_DIR="$XDG_DATA_HOME/sdkman"

sdk() {
  unset -f sdk
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
  command sdk "$@"
}

#lazy load appman
appman() {
  unset -f appman
  autoload bashcompinit
  bashcompinit
  source "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/appman"
  command appman "$@"
}


# setting up fzf settings
# extracted from Josean Martinez video:
# https://www.youtube.com/watch?v=mmqDYw9C30I

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path(){
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir(){
  fd --type=d --hidden --exclude .git . "$1"
}

bindkey -r '^G'

# Lazy load fzf-git - defer to background
if [[ ! -d "$XDG_DATA_HOME/zsh/fzf-git.sh" ]]; then
  git clone https://github.com/junegunn/fzf-git.sh.git "$XDG_DATA_HOME/zsh/fzf-git.sh" 2>/dev/null &
else
  # Load asynchronously in background
  (source "$XDG_DATA_HOME/zsh/fzf-git.sh/fzf-git.sh" 2>/dev/null &)
fi

# Lazy load direnv - only on first use
direnv_lazy_init() {
  eval "$(direnv hook zsh)"
  unset -f direnv_lazy_init
}
alias direnv="direnv_lazy_init && direnv"

