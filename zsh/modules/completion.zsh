export fpath=("$XDG_DATA_HOME/zsh/functions" $fpath)

# ============================================================================
# FAST INITIALIZATION (synchronous, required for prompt and basic features)
# ============================================================================

# Zoxide - lightweight, fast init
eval "$(zoxide init zsh)"

# Starship prompt - critical for prompt display
eval "$(starship init zsh)"

# direnv
eval "$(direnv hook zsh)"

# ============================================================================
# COMPLETIONS - defer to background since not needed immediately
# ============================================================================

# Initialize completions asynchronously
_init_completions() {
  autoload -Uz compinit
  if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
  else
    compinit -C
  fi
}

# Run in background - completions aren't needed until user presses TAB
_init_completions &!

# ============================================================================
# DEFERRED/LAZY INITIALIZATION (loaded asynchronously or on-demand)
# ============================================================================

# FZF - defer to background to not block startup
(eval "$(fzf --zsh)" 2>/dev/null &)

# Lazy load pyenv - only initialize when 'pyenv' or 'python' related tools are used
# pyenv_lazy_init() {
#   eval "$(pyenv init - zsh)" 2>/dev/null
#   eval "$(pyenv init --path)" 2>/dev/null
#   unset -f pyenv_lazy_init
# }
# alias pyenv="pyenv_lazy_init && pyenv"

# Lazy load nvm - only when node/npm commands are used
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"

nvm_lazy_init() {
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  for cmd in node npm yarn npx; do
    unalias $cmd 2>/dev/null
  done
  unset -f nvm_lazy_init
}

# Hook into common node-related commands
# DISABLED: These aliases interfere with the build system's own Node installation
# for cmd in node npm yarn npx; do
#   alias $cmd="nvm_lazy_init && $cmd"
# done
