# setup lf wrapper
LFCD="$HOME/.config/lf/lfcd.sh"
if [ -f "$LFCD" ]; then
    source "$LFCD"
    alias lf='lfcd'
fi


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
