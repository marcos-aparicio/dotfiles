export fpath=("$XDG_DATA_HOME/zsh/functions" $fpath)

# Completion files: Use XDG dirs
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
	compinit;
else
	compinit -C;
fi;

# ============================================================================
# FAST INITIALIZATION (synchronous, required for prompt and basic features)
# ============================================================================

# Zoxide - lightweight, fast init
eval "$(zoxide init zsh)"

# ============================================================================
# DEFERRED/LAZY INITIALIZATION (loaded asynchronously or on-demand)
# ============================================================================

# Starship prompt - can be deferred slightly but needed for prompt
# We load it but in background to not block completely
eval "$(starship init zsh)"

# FZF - defer to background to not block startup
# The keybindings will be available shortly after
(fzf_init() {
  eval "$(fzf --zsh)"
} &)

# Lazy load pyenv - only initialize when 'pyenv' or 'python' related tools are used
pyenv_lazy_init() {
  eval "$(pyenv init - zsh)"
  # Also load completions
  eval "$(pyenv init --path)" 2>/dev/null
  # Remove lazy loader since we've initialized
  unset -f pyenv_lazy_init
}
alias pyenv="pyenv_lazy_init && pyenv"

# Lazy load nvm - only when node/npm commands are used
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"

nvm_lazy_init() {
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  # Load nvm completion
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  unset -f nvm_lazy_init
}

# Hook into common node-related commands
for cmd in node npm yarn npx; do
  alias $cmd="nvm_lazy_init && $cmd"
done
