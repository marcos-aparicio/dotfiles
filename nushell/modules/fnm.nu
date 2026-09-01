# fnm (Fast Node Manager) for Nushell.
#
# fnm has no `--shell nu` -- it only generates bash/zsh/fish/powershell -- but
# it doesn't need one. `fnm env --json` prints its environment as JSON, which
# Nu loads directly, so none of the `export FOO="bar"` string-mangling the
# older recipes do is necessary. That part lives in env.nu, so `nu -c ...` and
# scripts get node as well, not just interactive shells.
#
# fnm points $FNM_MULTISHELL_PATH at a per-shell symlink directory. Once its
# bin is on PATH, `fnm use` and `fnm install` just re-point that symlink, which
# means every fnm subcommand already works in Nu with no wrapper around it.
# The only piece missing is `--use-on-cd`, which is what this module adds.

# Version files that trigger an automatic switch. package.json is deliberately
# left out: it would fire in every JS project, including ones that pin nothing.
const TRIGGERS = [".nvmrc" ".node-version"]

def has-trigger [dir: path]: nothing -> bool {
    $TRIGGERS | any {|f| $dir | path join $f | path exists }
}

# Switch node to whatever the current directory pins, like fnm's `--use-on-cd`.
# Never installs and never prompts -- `complete` keeps fnm's stdin detached,
# and an attached prompt inside a hook is exactly what hangs the shell (the
# reason fnm's own docs say --use-on-cd is unsupported on Nu).
export def fnm-use-cwd [--quiet] {
    if not (has-trigger $env.PWD) { return }

    let res = (do { ^fnm use --silent-if-unchanged } | complete)
    if $res.exit_code != 0 {
        if not $quiet {
            print --stderr $"fnm: ($res.stderr | str trim)"
        }
        return
    }
    if not $quiet and ($res.stdout | str trim | is-not-empty) {
        print ($res.stdout | str trim)
    }
}

# Register the directory-change hook. Call this from config.nu.
export def --env fnm-use-on-cd [] {
    $env.config.hooks.env_change.PWD = (
        $env.config.hooks.env_change.PWD? | default [] | append {|before, after| fnm-use-cwd }
    )
    # Apply it to the directory the shell started in.
    fnm-use-cwd --quiet
}

