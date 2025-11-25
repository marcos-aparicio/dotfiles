eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(pyenv init - zsh)"
eval "$(fzf --zsh)"

export fpath=("$XDG_DATA_HOME/zsh/functions" $fpath)

# Completion files: Use XDG dirs
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
	compinit;
else
	compinit -C;
fi;

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
