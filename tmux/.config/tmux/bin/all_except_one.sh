#!/bin/bash

 # Define the window index you want to keep
 window_to_keep=1

 tmux select-window -t $window_to_keep
 # Get the list of window indices in the current tmux session
 window_indices=$(tmux list-windows -F '#{window_index}')

 # Close all windows except the window_to_keep

 for window_index in $window_indices; do
     if [ "$window_index" != "$window_to_keep" ]; then
         tmux kill-window -t 2
     fi
 done



 # Define the pane index you want to keep
 pane_to_keep=$(tmux list-panes -t : -F '#{pane_id}' | head -n 1)

 # Get the list of pane IDs in the current window
 pane_ids=$(tmux list-panes -t : -F '#{pane_id}')

 # Construct a tmux command to close all panes except the specified one

 for pane_id in $pane_ids; do
     if [ "$pane_id" != "$pane_to_keep" ]; then
       tmux kill-pane -t $pane_id
     fi
 done

