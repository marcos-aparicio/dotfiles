# Nushell environment, kept close to zsh/modules/vars.zsh.

# XDG base directories.
$env.XDG_CONFIG_HOME = ($env.XDG_CONFIG_HOME? | default ($env.HOME | path join ".config"))
$env.XDG_DATA_HOME = ($env.XDG_DATA_HOME? | default ($env.HOME | path join ".local" "share"))
$env.XDG_STATE_HOME = ($env.XDG_STATE_HOME? | default ($env.HOME | path join ".local" "state"))
$env.XDG_CACHE_HOME = ($env.XDG_CACHE_HOME? | default ($env.HOME | path join ".cache"))
$env._XDG_CACHE_HOME = $env.XDG_CACHE_HOME

# Nushell exposes PATH as a list, so prepend directories directly.
let additional_paths = [
    ($env.HOME | path join ".config" "composer" "vendor" "bin")
    ($env.HOME | path join ".local" "privbin")
    ($env.XDG_DATA_HOME | path join "cargo" "bin")
    ($env.HOME | path join ".config" "vit" "sh")
    ($env.HOME | path join ".config" "zsh" "bin")
    ($env.HOME | path join ".config" "awesome" "sh")
    ($env.HOME | path join ".config" "ranger" "sh")
    ($env.HOME | path join ".config" "tmux" "sh")
    ($env.HOME | path join ".local" "expect")
    ($env.HOME | path join ".local" "scripts")
    ($env.HOME | path join ".local" "share" "npm-global" "bin")
    ($env.HOME | path join ".cargo" "bin")
    ($env.HOME | path join ".opencode" "bin")
    "/opt/sioyek"
]

$env.PNPM_HOME = ($env.HOME | path join ".local" "share" "pnpm")
$env.BUN_INSTALL = ($env.HOME | path join ".bun")

# Homebrew, mirroring `brew shellenv` from zsh/.zsh_after (it has no `nu` output yet).
$env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
$env.HOMEBREW_CELLAR = ($env.HOMEBREW_PREFIX | path join "Cellar")
$env.HOMEBREW_REPOSITORY = ($env.HOMEBREW_PREFIX | path join "Homebrew")
$env.INFOPATH = (
    [($env.HOMEBREW_PREFIX | path join "share" "info")]
    | append ($env.INFOPATH? | default "" | split row (char esep) | where {|it| $it != "" })
    | str join (char esep)
)

$env.PATH = ($env.PATH | prepend ($additional_paths | prepend [
    ($env.HOMEBREW_PREFIX | path join "bin")
    ($env.HOMEBREW_PREFIX | path join "sbin")
    $env.PNPM_HOME
    ($env.BUN_INSTALL | path join "bin")
    "/usr/local/bin"
    ($env.HOME | path join ".local" "bin")
]))

# Keep XDG_DATA_DIRS string-compatible for external applications.
let xdg_data_dirs = ($env.XDG_DATA_DIRS? | default "/usr/share")
$env.XDG_DATA_DIRS = ($xdg_data_dirs | split row (char esep) | append $env.XDG_DATA_HOME | str join (char esep))

# General environment.
$env.TERM = "xterm-256color"
$env.GTK_THEME = "Vivid-Dark-GTK"
$env.EDITOR = "nvim"
$env.VISUAL = $env.EDITOR
$env.JIRA_AUTH_TYPE = "basic"
$env.MANPAGER = "nvim +Man!"
$env.DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env.WORDLISTS = ($env.XDG_DATA_HOME | path join "wordlists")
$env.NVM_DIR = ($env.XDG_CONFIG_HOME | path join "nvm")

# pi / omp (oh-my-pi) coding agents: cap how much tool output each call keeps.
# Their default is PI_TASK_MAX_OUTPUT_BYTES=500_000 -- 500 KB per call, which is
# ~16x Claude Code's 30 KB. Tool output is retained per session, so a generous
# ceiling here translates directly into heap growth and, on this box, swap.
# 150 KB is still plenty for a build log or test run to be readable.
$env.PI_TASK_MAX_OUTPUT_BYTES = "150000"
$env.PI_TASK_MAX_OUTPUT_LINES = "2000"

# fnm. It generates no Nushell syntax (bash/zsh/fish/powershell only), but
# `fnm env --json` hands over its environment as JSON, which load-env takes
# directly -- no parsing of `export FOO="bar"` lines.
#
# Call it exactly once: every `fnm env` invocation mints a fresh multishell
# directory under /run/user, and only the one we keep is the one on PATH.
if (which fnm | is-not-empty) {
    fnm env --json | from json | load-env
    $env.PATH = ($env.PATH | prepend ($env.FNM_MULTISHELL_PATH | path join "bin"))
}
