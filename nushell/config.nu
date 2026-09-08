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

use ./modules/functions.nu *
use ./modules/aliases.nu *
