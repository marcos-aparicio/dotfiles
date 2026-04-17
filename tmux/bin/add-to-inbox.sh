#!/bin/bash
# Add item to the current Obsidian inbox
# Uses the same repo detection as tmux task tracking

repo_file="$HOME/.config/tmux/task_repo_name"
parent_dir="/home/marcos/Documents/Areas/Obsidian"

# Get the active repo name
if [ -f "$repo_file" ]; then
    repo_name=$(cat "$repo_file")
else
    repo_name="personal"
    echo "personal" > "$repo_file"
fi

repo="$parent_dir/$repo_name"
lists_dir="$repo/lists"
inbox_path="$lists_dir/inbox.md"

# Input text from argument
input_text="$1"

if [ -z "$input_text" ]; then
    echo "Error: No input provided" >&2
    exit 1
fi

# Create lists directory if it doesn't exist
mkdir -p "$lists_dir"

# Create inbox.md if it doesn't exist
if [ ! -f "$inbox_path" ]; then
    echo "# inbox" > "$inbox_path"
    echo "" >> "$inbox_path"
fi

# Append the new item
echo "- ($(date +%c)) : $input_text" >> "$inbox_path"

echo "✓ Added to inbox ($repo_name): $input_text"
