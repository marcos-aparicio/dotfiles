# Core aliases translated from zsh/modules/aliases.zsh.

# Git.
export alias gps = git push
export alias gpl = git pull
export alias gck = git checkout

# Taskwarrior.
export alias t = task
export alias ti = task ls +interesting
export alias ta = task add
export alias in = task add +in
export alias inbox = task in
export alias ibx = task in limit:1
export alias now = task active
export alias tl = task list sort:pri-
export alias tlt = task list sch:tod
export alias tlm = task list sch:tom
export alias projs = task projects
export alias cn = task context no-work
export alias cw = task context work
export alias cc = task context college
export alias ts = task summary
export alias next = task next

# Timewarrior.
export alias tw = timew
export alias tis = timew summary :ids
export alias work = timew summary work
export alias tsw = timew summary :week

# Programs.
export alias vim = ^vim -u ~/.config/vim/init.vim
export alias lg = lazygit
export alias v = nvim
export alias oc = opencode
export alias rm = trash -vi
export alias j = just --choose
export alias lzd = lazydocker
export alias st = systemctl-tui
export alias tvs = tv sesh
export alias dt = devtitle
export alias lf = y

# Utilities.
export alias c = clear
export alias clip = xclip -selection clipboard
export alias screen = xrandr --output HDMI-0 --auto --left-of eDP-1-1
export alias lockscreen = dm-tool switch-to-greeter
