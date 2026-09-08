# Nushell interactive configuration.

$env.config.show_banner = false
$env.config.edit_mode = "vi"
$env.config.buffer_editor = $env.EDITOR
$env.config.history.path = ($env.XDG_STATE_HOME | path join "nushell" "history.txt")
mkdir ($env.config.history.path | path dirname)
$env.config.cursor_shape = {
    vi_insert: line
    vi_normal: block
}

def copy-commandline-to-clipboard [] {
    let line = (commandline)

    if (($env.XDG_SESSION_TYPE? | default "") == "wayland") and (which wl-copy | is-not-empty) {
        $line | wl-copy
    } else if (which xclip | is-not-empty) {
        $line | xclip -selection clipboard
    } else {
        error make { msg: "Neither wl-copy nor xclip is available" }
    }
}

# Save the clipboard image to a fixed path and print it, for fx /image.
def clip-img [] {
    let dst = ($nu.temp-dir | path join "clipboard-latest.png")
    if ($env.XDG_SESSION_TYPE? | default "") == "wayland" and (which wl-paste | is-not-empty) {
        wl-paste --type image/png | save -f $dst
    } else if (which xclip | is-not-empty) {
        xclip -selection clipboard -t image/png -o | save -f $dst
    } else {
        error make { msg: "Neither wl-paste nor xclip is available" }
    }
    if ((ls $dst | get 0.size) == 0b) {
        error make { msg: "Clipboard does not contain an image" }
    }
    $dst
}

$env.config.keybindings ++= [{
    name: copy_commandline_to_clipboard
    modifier: control
    keycode: char_y
    mode: [vi_insert vi_normal]
    event: {
        send: executehostcommand
        cmd: "copy-commandline-to-clipboard"
    }
}]

# Starship and zoxide generate Nushell hooks into Nu's XDG-aware vendor
# autoload directory. Nu loads these files after config.nu.
let autoload_dir = ($nu.data-dir | path join "vendor" "autoload")
mkdir $autoload_dir

if (which starship | is-not-empty) {
    starship init nu | save -f ($autoload_dir | path join "starship.nu")
}

if (which zoxide | is-not-empty) {
    zoxide init nushell | save -f ($autoload_dir | path join "zoxide.nu")
}

if not (which fnm | is-empty) {
    ^fnm env --json | from json | load-env

    $env.PATH = $env.PATH | prepend ($env.FNM_MULTISHELL_PATH | path join (if $nu.os-info.name == 'windows' {''} else {'bin'}))
    $env.config.hooks.env_change.PWD = (
        $env.config.hooks.env_change.PWD? | append {
            condition: {|| ['.nvmrc' '.node-version', 'package.json'] | any {|el| $el | path exists}}
            code: {|| ^fnm use --install-if-missing --silent-if-unchanged}
        }
    )
}


use ./modules/functions.nu *
use ./modules/aliases.nu *
