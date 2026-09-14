src_module(){
  ZSH_MODULES="$HOME/.config/zsh/modules"
  module="$ZSH_MODULES/$1"
  if [[ -f "$module" ]]; then
    source "$module"
  fi
}

# ORDER MATTERS

# defined enviroment variables(not related to xdg compliance)
src_module "vars.zsh"

# load plugins
src_module "plugins.zsh"

# then some custom bindings
src_module "bindings.zsh"

# defined aliases (not related to xdg compliance)
src_module "aliases.zsh"

src_module "functions.zsh"

# env vars and aliases related to xdg compliance
src_module "cleanup.vars.zsh"
src_module "cleanup.aliases.zsh"

# completion setups for zsh
src_module "completion.zsh"

# extra stuff, like lazy loading applications or setting up wrappers
src_module "extra.zsh"

# optional module that you can have for specific device stuff
if [[ -f "$HOME/.config/zsh/.zsh_after" ]]; then
  source "$HOME/.config/zsh/.zsh_after"
fi

# pnpm
export PNPM_HOME="/home/marcos/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"

export USERPROFILE=$(wslpath -u $(powershell.exe -NoLogo -NoProfile -Command 'Write-Output ${env:USERPROFILE}'))

# Typing `omp` runs the memory-capped version (4 GB ceiling on omp and its
# children, including the headless browser that caused the Sep 11/14 crashes).
# A function, not a PATH wrapper: omp's self-updater installs into the first
# writable PATH entry and overwrote a wrapper script there on 2026-09-14.
# OMP_NO_CAP=1 omp ... runs it uncapped.
omp() { command omp-capped "$@"; }
