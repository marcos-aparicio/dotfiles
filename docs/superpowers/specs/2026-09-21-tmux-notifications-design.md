# tmux notifications

A reminder that fires in 20 minutes, a build that finishes while you are in a
browser, a script that wants to tell you something — all of it currently has
nowhere to go. `notify-send` on this box is a nushell *function*, so tmux (which
runs `sh`) cannot see it, and every `notify-send` call in the bash scripts here
fails silently.

One CLI collects events. The bar shows them. A popup reads them.

## Pieces

| path | role |
|---|---|
| `scripts/notify` | the only writer: append to the inbox, push the bar segment, toast |
| `scripts/notify-send` | PATH shim replacing the nushell function; routes to `wsl-notify-send.exe` |
| `scripts/notify-popup` | fzf over the inbox, per-item dismissal |
| `scripts/remind` | one-shot and recurring timers, backed by systemd |
| `scripts/notify-done` | run a command, notify with exit code and duration |
| `scripts/notify-attach` | notify when the command already running in a pane exits |
| `tmux/notifications.tmux.conf` | bar segments + `prefix N` / `T` / `B` |

Inbox: `$XDG_STATE_HOME/tmux-notify/inbox.jsonl`, one object per line —
`{ts, urgency, source, text, read}`. Append-only on write; rewritten whole on
dismissal. It is a handful of lines a day, so there is no rotation and no index.

## The bar is pushed, never polled

`status-interval` is `1` here (pomodoro sets it), so a `#(script)` segment forks
a process **every second, forever**. Instead `notify` renders the entire styled
segment — colours included — into the `@notif_seg` user option, and the bar is
one line:

```tmux
set -ag status-format[1] "#{E:@notif_seg}"
```

`E:` forces the second expansion pass that turns `#[...]` styles and `#{@thm_*}`
colour refs inside the option's value into real styling, the same trick
catppuccin uses for its own modules. An unset option renders as nothing and
takes zero columns, so an empty inbox is free.

This also keeps the loud/quiet decision in shell, where it is an `if`, instead
of in nested `#{?...}` conditionals where every literal comma needs escaping as
`#,`.

**Consequence:** options live in the server's memory and die with it, and
`sh/switch_mode.sh` runs `tmux kill-server`. So tmux.conf recounts the inbox at
startup and repushes the badge.

## Three attention tiers

| urgency | bar | toast | popup |
|---|---|---|---|
| `low` | quiet badge only | no | no |
| default | pulses red with the message text for 3s, then settles to the count | yes | no |
| `critical` | same pulse | yes | auto-opens |

The pulse is the producer toggling `@notif_seg` and calling `refresh-client -S`
after each toggle — the bar's own 1 Hz redraw is far too slow to read as a
flash, so the producer sets the rate (450 ms).

Auto-popup is restricted to `critical` because `display-popup` **takes the
keyboard**. One firing unbidden mid-command sends your next keystrokes into the
popup. The default tier is already a pulsing red bar plus a Windows toast;
neither can eat a keystroke.

## Timers

One-shot and recurring need different machinery, and the split is not cosmetic:
`--on-unit-active` on a *transient* unit is broken — the service never runs at
all, verified. Recurring reminders are written unit files, which is what you
want anyway for something you keep.

```
remind 20m check the deploy        → systemd-run --user --on-active=20m
remind 14:30 standup               → systemd-run --user --on-calendar=14:30
remind every 50m posture           → ~/.config/systemd/user/notif-posture.timer
remind daily 09:30 standup         → OnCalendar=09:30, Persistent=true
remind list | remind cancel <name>
```

Systemd is the store. There is no pending-timer state file to keep consistent,
and `systemctl --user list-timers` already knows everything `remind list` needs.

Ad-hoc timers die on reboot; recurring ones survive, because a posture nag that
vanished on reboot would be useless.

`AccuracySec=1s` on both kinds, overriding systemd's 1 minute default. That
default exists so systemd can batch wakeups, and it is badly wrong here:
measured, a `remind 5s` fired **18 seconds** late and a 4s recurring interval
managed one fire in 13 seconds. On a 50 minute nag the saving was one wakeup an
hour, which is not worth reminders that drift.

Pending timers show in the bar at minute resolution (`⏲ 6m`, `<1m` in the last
minute). The updater is a detached job that rewrites `@notif_timer` every 30s
and **exits when the last timer fires**, so an idle machine runs no process at
all — strictly cheaper than the cached-`#()` pattern `ram-warn` uses, which
forks every second regardless.

## Command completion

Two producers, because they answer different moments.

`notify-done cargo build` is the planned one, and it is the parent, so it
reports *"cargo build failed (exit 101) after 4m12s"*.

`prefix B` is the rescue hatch for when it is already running. `#{pane_pid}` is
the shell, not the command, so the test for "is something running here" is the
terminal's foreground process group: `ps -o tpgid= -p <pane_pid>` differing from
the pane's own pgid. That is definitive, not a heuristic — verified against live
panes. Then `tail --pid=<pid> -f /dev/null` blocks until it exits, which works
on processes you did not spawn.

**It cannot report an exit code.** You are not the parent, so you cannot reap
it; you only learn that it ended, and a Ctrl-C looks identical to success. That
is the price of not having planned ahead.

## Keys

Every lowercase prefix key is already bound here, so these are shifted. `n`
(work notes), `w` (`tv workmux`) and `t` (repo toggle) keep their meanings.

| key | action |
|---|---|
| `prefix N` | open the inbox popup |
| `prefix T` | `command-prompt` for a reminder |
| `prefix B` | bell me when this pane's command finishes |

## Deliberately not built

- **No daemon.** Volume is a few notifications a day; a socket buys push updates
  and in-memory state, neither of which is needed, and adds a process that can
  die quietly.
- **Not a fork of `ssterling/tmux-notify`.** Its 40 lines have no timestamps, no
  per-item state and no urgency; keeping them would mean rewriting all of it
  while inheriting someone else's names.
- **No automatic "command took >30s" hook.** Rejected in favour of the explicit
  wrapper: it needs per-shell hooks and a rule for "you weren't watching".
- **No jump-to-originating-pane from the popup.** Add it if the inbox ever fills
  with pane-scoped events; today most entries are reminders, which have no pane.
- **No rotation or read-state compaction.** Revisit if the file passes a few
  thousand lines.
