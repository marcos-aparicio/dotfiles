#!/bin/bash

# Thyme pomodoro completion hook
# $1 = repeat_suffix

REPEAT_SUFFIX="$1"

# Search for sound file in XDG_DATA_DIRS
SOUND_FILE=""
for dir in ${XDG_DATA_DIRS//:/ }; do
  if [[ -f "$dir/sounds/freedesktop/stereo/interval-end.oga" ]]; then
    SOUND_FILE="$dir/sounds/freedesktop/stereo/interval-end.oga"
    break
  fi
done

notify-send "Pomodoro done $REPEAT_SUFFIX"
[[ -n "$SOUND_FILE" ]] && paplay "$SOUND_FILE"
