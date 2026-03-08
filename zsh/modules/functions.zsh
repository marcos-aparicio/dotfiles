mkt(){
  mkdir -p {content,exploits,nmap,scripts}
}

# passing a word definition to sdcv and parsing it correctly with pandoc
def() {
	sdcv -n --utf8-output --color "$@" 2>&1 | \
	fold --width=$(tput cols) | \
  pandoc -f html -t plain | \
	less --quit-if-one-screen -RX
}

mirar()
{
  yt-dlp -o - $1 | vlc -
}

superkill()
{
  # kills a window clicked by xprop
  kill -9 $(xprop | grep _NET_WM_PID | grep -oE "[0-9]+")
}
copy()
{
  # copies the first argument to the clipboard, as simple as that
  echo $1 | xclip -selection clipboard
}


# shortcut that i created for zaread(zathura for other files)
zr()
{
    nohup zaread $1 >/dev/null 2>&1 &
}

fm()
{
    setsid pcmanfm $1 >/dev/null 2>&1 &
}

canvass(){
  canvas -S -p "$(pass show canvas-pass)"
}

sendm(){
  signal-cli -a $(pass show "phones/1") send -m "$1" $(pass show "phones/2")
}

au(){
  rfkill unblock bluetooth && bluetoothctl connect $(pass show bluetooth/headphones)
}

send_to_kindle(){
  email="$2"

  # if [ ! -z "$2" ]; then
  #   email=$(pass show "emails/kindle2")
  # else
  email=$(pass show "emails/kindle1")
  # fi
  echo "Sent to $email"

  echo "" | mailx -a "$1" -s "Book" $email
}

load_openai_key(){
  export OPENAI_API_KEY=$(pass show personal/api_keys/openai)
}

y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	\rm -f -- "$tmp"
}

to_avif() {
	local count=0
	for image in *.{jpg,jpeg,png,webp,gif}(N); do
		if [ -f "$image" ]; then
			local output="${image%.*}.avif"
			local temp_resized="${image%.*}_resized.png"
			echo "Converting $image to $output..."
			magick "$image" -resize 1000x1000\> "$temp_resized"
			avifenc -s 8 "$temp_resized" "$output" 2>/dev/null
			rm -f "$temp_resized"
			if [ $? -eq 0 ]; then
				((count++))
				echo "✓ $output"
			else
				echo "✗ Failed to convert $image"
			fi
		fi
	done
	echo "Converted $count images to AVIF"
}
