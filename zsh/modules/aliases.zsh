# # JIRA ALIASES
# alias sprint="jira sprint list --current --order-by status --reverse"
# alias sprintme="jira sprint list --current --order-by status --reverse -a$(jira me)"
# alias current-sprint-id="jira sprint list --table --plain --no-headers --columns ID | head -n +1"
# alias backlog="jira issue list -q \"Sprint is EMPTY AND status != 'Done'\""

# GIT ALIASES
alias gps="git push"
alias gpl="git pull"
alias gck="git checkout "

# CALCURSE ALIASES
alias today="calcurse -a"
alias tomorrow="calcurse -d tomorrow"
alias yesterday="calcurse -d yesterday"
alias tod="calcurse -a"
alias tom="calcurse -d tomorrow"
alias week="calcurse -d 7"
alias days="calcurse -d "

# TASKWARRIOR ALIASES
if [[ $(command -v task) ]]; then
  alias t="task"
  alias ti="task ls +interesting"
  alias ta="task add"
  alias in="task add +in"
  alias inbox="task in"
  alias ibx="task in limit:1"
  alias now="task active"
  alias tl="task list sort:pri-"
  alias tlt="task list sch:tod"
  alias tlm="task list sch:tom"
  alias projs="task projects"
  alias tac="task add +comprar"
  alias cn="task context no-work"
  alias cw="task context work"
  alias cc="task context college"
  alias ts="task summary"
  alias next="task next"
  alias tickler="task waiting +in"
  alias buy="task ls +buy"
  alias gro="task ls +groceries"
  alias comp="task ls +comprar"
fi

# TIMEWARRIOR ALIASES
if [[ $(command -v timew) ]]; then
  alias tw="timew "
  alias tis="timew summary :ids"
  alias work="timew summary work"
  alias tsw="timew summary :week"
fi

# PROGRAM ALIASES(starting programs in a certain way)
alias vim="vim -u ~/.config/vim/init.vim"
alias lg="lazygit"
alias v="nvim "
alias rm="trash -vi"
alias abook="abook -C $ABOOKRC --datafile $ABOOKDATA"
alias mbsync="mbsync -c \"$HOME/.config/isync/mbsyncrc\""

# UTILS (programs that do something useful)
alias zf='cd "$(cat "$_Z_DATA" | cut -f1 -d "|" | fzf)"'
alias c="clear"
alias cwd="pwd | xclip -selection clipboard && echo 'Current working directory copied to clipboard'"
alias clip="xclip -selection clipboard"
alias screen="xrandr --output HDMI-0 --auto --left-of eDP-1-1"
alias lockscreen="dm-tool switch-to-greeter"
alias makegif="giph -f 30 -s -l -c 0.3,0,0.5,0.3 -d 3 $HOME/Videos/gifs/$(date +%s).gif && espeak 'Your GIF file is ready sir'"
alias lockscreen='dm-tool switch-to-greeter'
alias weather="curl -s wttr.in/~Hamilton\?format=j1 | bat - --language=json"
alias j="just --choose"
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'
alias lzd="lazydocker"
alias st="systemctl-tui"

[ -f "$HOME/.local/privbin/prueba.sh" ] && alias prueba="nvim $HOME/.local/privbin/prueba.sh"
[ -d "$HOME/.local/bin" ] && alias localbin="nvim $HOME/.local"


if [[ $(command -v boxxy) ]]; then
  alias ollama="boxxy ollama"
fi
