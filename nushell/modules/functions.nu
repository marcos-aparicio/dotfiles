# Utility functions translated from zsh/modules/functions.zsh.

export def mkt [] {
    mkdir content exploits nmap scripts
}

export def tweek [tag: string, last_n_weeks: int] {
    if $last_n_weeks < 1 {
        return
    }

    for i in 0..($last_n_weeks - 2) {
        let week1 = (^date -d $"(($i + 1)) weeks ago" "+%GW%V" | str trim)
        let week2 = (^date -d $"($i) weeks ago" "+%GW%V1" | str trim)
        print $week1
        timew recap $tag $week1 - $week2
    }

    let week1 = (^date "+%GW%V" | str trim)
    let week2 = (^date -d "1 week" "+%GW%V1" | str trim)
    print $week1
    timew recap $tag $week1 - $week2
}

export def s [] {
    let selected = (
        sesh list --icons
        | fzf-tmux -p "80%,70%" --no-sort --ansi --border-label " sesh " --prompt "⚡  "
    )

    if ($selected | is-not-empty) {
        sesh connect ($selected | str trim)
    }
}

# `def` is a Nushell keyword, so the dictionary helper is named `dict`.
export def dict [...words: string] {
    sdcv -n --utf8-output --color ...$words
    | fold --width (tput cols | into int)
    | pandoc -f html -t plain
    | less --quit-if-one-screen -RX
}

export def mirar [url: string] {
    yt-dlp -o - $url | vlc -
}

export def superkill [] {
    let pids = (xprop | grep _NET_WM_PID | grep -oE "[0-9]+" | lines | into int)
    $pids | each {|pid| kill -9 $pid }
}

export def copy [text: string] {
    $text | xclip -selection clipboard
}

export def zr [file: string] {
    setsid zaread $file out+err>| ignore
}

export def fm [path?: string] {
    if ($path | is-empty) {
        setsid pcmanfm out+err>| ignore
    } else {
        setsid pcmanfm $path out+err>| ignore
    }
}

export def canvass [] {
    canvas -S -p (pass show canvas-pass | str trim)
}

export def sendm [message: string] {
    let sender = (pass show phones/1 | str trim)
    let recipient = (pass show phones/2 | str trim)
    signal-cli -a $sender send -m $message $recipient
}

export def au [] {
    rfkill unblock bluetooth
    bluetoothctl connect (pass show bluetooth/headphones | str trim)
}

export def send-to-kindle [attachment: string] {
    let email = (pass show emails/kindle1 | str trim)
    print $"Sent to ($email)"
    ^mailx -a $attachment -s Book $email
}

export def --env load-openai-key [] {
    $env.OPENAI_API_KEY = (pass show personal/api_keys/openai | str trim)
}

export def to-avif [] {
    mut count = 0

    for image in (glob "*.{jpg,jpeg,png,webp,gif}" | where {|path| ($path | path type) == file }) {
        let parsed = ($image | path parse)
        let output = ($parsed.parent | path join $"($parsed.stem).avif")
        let resized = ($parsed.parent | path join $"($parsed.stem)_resized.png")

        print $"Converting ($image) to ($output)..."
        magick $image -resize "1000x1000>" $resized
        let result = (avifenc -s 8 $resized $output | complete)
        rm -f -- $resized

        if $result.exit_code == 0 {
            $count += 1
            print $"✓ ($output)"
        } else {
            print $"✗ Failed to convert ($image)"
        }
    }

    print $"Converted ($count) images to AVIF"
}

export def weather [] {
    let data = (curl -s "wttr.in/?format=j1")
    print "Current:"
    $data | jq -r '.current_condition[0] | "Feels like: \(.FeelsLikeC)°C, Weather: \(.temp_C)°C"'
    print ""
    $data | jq -r '.weather[] | "\(.date): avg temp \(.avgtempC)°C"'
}

export def --env y [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	^yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != $env.PWD and ($cwd | path exists) {
		cd $cwd
	}
	^rm -fp $tmp
}

# --- agent memory smoothing -------------------------------------------------
# Goal: trade a little agent speed for a machine that stays usable. Neither of
# these caps the heap, so neither can kill a session -- they only make garbage
# collection run more often, in smaller increments, instead of letting memory
# pile up into one big spike.
#
# Deliberately NOT used here: --max-old-space-size (node) sets a hard V8 wall
# and hitting it hard-aborts with SIGABRT (verified: exit code 134, the catch
# block never runs), which would lose the conversation.

# pi runs on node, so V8's GC flags apply.
# --max-semi-space-size enlarges the young generation: short-lived garbage gets
# collected in frequent cheap minor GCs rather than being promoted and dealt
# with in one expensive major GC.
export def --wrapped pi [...args] {
    with-env { NODE_OPTIONS: "--max-semi-space-size=64" } { ^pi ...$args }
}

# omp runs on bun/JavaScriptCore, where V8 flags are silently ignored. Bun's
# equivalent is --smol, which makes its GC run more frequently. It must be
# passed to the bun runtime (before the script), not to omp's own arg parser --
# omp already has its own unrelated --smol flag for model selection.

# --- SCOPED variants, for testing --------------------------------------------
# Same agents, but launched inside a transient systemd cgroup so the agent AND
# every child it spawns share one memory ceiling. When the group exceeds it the
# kernel kills its LARGEST process -- verified to be the runaway child, not the
# agent (dmesg: "Killed process ... (python3)" while the parent survived).
#
# Separate names on purpose: these are unproven for interactive TUIs. If the
# terminal misbehaves, plain `omp` / `pi` are untouched.
#
# IOWeight is deliberately absent -- the io controller is not delegated to
# user.slice on this box (subtree_control shows "cpu memory pids"), so it would
# be silently ignored.
#
# MemorySwapMax=512M rather than 0: leaves a little give before the hard kill.


export def --wrapped pic [...args] {
    with-env { NODE_OPTIONS: "--max-semi-space-size=64" } {
        ^systemd-run --user --scope --collect -q --description "pic agent" "-p" "MemoryMax=4G" "-p" "MemorySwapMax=512M" "-p" "CPUWeight=20" -- pi ...$args
    }
}

# Typing `omp` interactively runs the memory-capped version.
#
# A nushell def is safe here, unlike the earlier PATH-shadowing attempt: omp's
# self-updater installs into the first writable directory on PATH, and on
# 2026-09-14 it overwrote a wrapper script that lived there. A def is not a file
# on PATH, so nothing can install over it.
#
# workmux does not need this -- it resolves `agent: omp` through the agents map
# in ~/.config/workmux/config.yaml, which already points at omp-capped.
#
# OMP_NO_CAP=1 omp ...   runs it uncapped (omp-capped honours the variable).
export def --wrapped omp [...args] { ^omp-capped ...$args }
