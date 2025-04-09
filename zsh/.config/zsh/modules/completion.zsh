eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(pyenv init - zsh)"

export fpath=("$HOME/.config/zsh/functions" $fpath)

# Completion files: Use XDG dirs
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
	compinit;
else
	compinit -C;
fi;
