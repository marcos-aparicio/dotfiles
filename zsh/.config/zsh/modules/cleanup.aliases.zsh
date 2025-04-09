alias wget=wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"
alias mysql-workbench="mysql-workbench --configdir=$XDG_DATA_HOME/mysql/workbench"
alias lynx="lynx -cfg=$XDG_CONFIG_HOME/lynx/lynxrc"
alias feh="feh --no-fehbg"
alias yarn="yarn --use-yarnrc $XDG_CONFIG_HOME/yarn/config"
alias monerod=monerod --data-dir "$XDG_DATA_HOME"/bitmonero

export SDKMAN_DIR="$XDG_DATA_HOME"/sdkman
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

export PYENV_ROOT="$XDG_DATA_HOME"/pyenv
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
