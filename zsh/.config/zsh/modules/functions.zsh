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
