#!/bin/bash


parse_devices() {
	local DEVICES="$1"
	local lines id vol devname
	mapfile -t lines <<< "$DEVICES"
	for line in "${lines[@]}"; do
	  id=$(awk '{sub(/\./,"",$1); print $1}' <<< "$line")
	  vol=$(grep -o '\[.*\]' <<< "$line")
	  devname=$(sed -E 's/^[0-9]+\. //; s/ \[vol:.*\]$//' <<< "$line")
	  echo -e "${id}\t${devname#*. }\t${vol}"
	done
}

list_audio_sinks() {
	Audio_Sink_Devices="$(wpctl status| sed -n '/Audio/,/Video/p'| sed -n '/Sinks/,/Sink endpoints/p'|tail -n +2|head -n -2|cut -d ' ' -f3-|sed 's/^ //g'|sed 's/^\*//g'| tr -s ' ')"
        parse_devices "$Audio_Sink_Devices"
	local parse_output=$(parse_devices "$Audio_Sink_Devices")
	IFS=$'\t' read -r id device volume <<< "$parse_output"

}

list_audio_sources() {
	Audio_Source_Devices="$(wpctl status| sed -n '/Audio/,/Video/p'| sed -n '/Sources/,/Source endpoints/p'|tail -n +2|head -n -2|cut -d ' ' -f3-|sed 's/^ //g'|sed 's/^\*//g'| tr -s ' ')"
        parse_devices "$Audio_Source_Devices"
	local parse_output=$(parse_devices "$Audio_Source_Devices")
	IFS=$'\t' read -r id device volume <<< "$parse_output"
}

list_video_sources() {
	Video_Source_Devices="$(wpctl status| sed -n '/Video/,/Settings/p'| sed -n '/Sources/,/Source endpoints/p'|tail -n +2|head -n -2|cut -d ' ' -f3-|sed 's/^ //g'|sed 's/^\*//g'| tr -s ' ')"
	parse_devices "$Video_Source_Devices"
	local parse_output=$(parse_devices "$Video_Source_Devices")
	IFS=$'\t' read -r id device volume <<< "$parse_output"
}

main_menu() {
	echo -e "Set Audio Speakers\nSet Audio Mic\nSet Video Cam\nAdjust Volume Speakers\nAdjust Volume Mic\nHelp\nExit" | rofi -dmenu -p "Choose action:"
}

show_help() {
	local help_text="wpctl-rofi-control script

	Features:
	- Set default Audio Output (output device)
	- Set default Audio Mic (input device)
	- Set default Video Cam (input device)
	- Adjust volume for Audio Output (0-150%)
	- Adjust volume for Audio Mic (0-150%)
	- Uses rofi for interactive menus
	- Uses wpctl to control PipeWire devices
	- Notifications shown via notify-send

	Usage:
	Run the script and select options from the menu.
	Select a device to set as default.
	Adjust volume by entering a value between 0 and 150.

	Requirements:
	- wpctl (PipeWire control CLI)
	- rofi (menu launcher)
	- notify-send (optional, for notifications)

	Press Enter to close this help message."
	echo "$help_text" | rofi -e -markup-rows -mesg -dmenu -p "Help"
}

select_device() {
	local devices="$1"
	echo "$devices" | rofi -dmenu -p "Select device:" | awk '{print $1, $2}'
}

set_audio_sink() {
	local devices=$(list_audio_sinks)
	local values=$(select_device "$devices")
	read -r id devname <<< "$values"
	if [ -n "$id" ]; then
	  wpctl set-default "$id"
	  notify-send "Audio sink set $devname"
	fi
}

set_audio_source() {
	local devices=$(list_audio_sources)
	local id=$(select_device "$devices")
	if [ -n "$id" ]; then
	  wpctl set-default "$id"
	  notify-send "Audio source set" "$id"
	fi
}

set_video_source() {
	local devices=$(list_video_sources)
	local id=$(select_device "$devices")
	if [ -n "$id" ]; then
	  wpctl set-default "$id"
	  notify-send "Video source set" "$devname"
	fi
}

adjust_volume() {
	local type="$1" # speaker or mic
	local devices
	if [[ "$type" == "speaker" ]]; then
	  devices=$(list_audio_sinks)
	else
	  devices=$(list_audio_sources)
	fi
        local values=$(select_device "$devices")
        read -r id devname <<< "$values"	
	if [ -z "$id" ]; then
	  return
	fi
	local current_vol=$(wpctl get-volume "$id" | awk '{printf "%d", $1 * 100}')
	local new_vol=$(echo "$current_vol" | rofi -dmenu -p "Volume (0-150%) for $id:")
	if [[ "$new_vol" =~ ^[0-9]+$ ]] && [ "$new_vol" -ge 0 ] && [ "$new_vol" -le 150 ]; then
	  wpctl set-volume "$id" "$((new_vol))%"
	  notify-send "Volume set for $type" "$devname : $new_vol%"
	else
	  notify-send "Invalid volume" "Must be 0-150%"
	fi
}

while true; do
	choice=$(main_menu)
	if [ -z "$choice" ]; then
	  show_help
	  continue
	fi

	case "$choice" in
	  "Set Audio Speakers")
	    set_audio_sink
	    ;;
	  "Set Audio Mic")
	    set_audio_source
	    ;;
	  "Set Video Cam")
	    set_video_source
	    ;;
	  "Adjust Volume Speakers")
	    adjust_volume speaker
	    ;;
	  "Adjust Volume Mic")
	    adjust_volume mic
	    ;;
	  "Help")
	    show_help
	    ;;
	  "Exit")
	    exit 0
	    ;;
	  *)
	    exit 0
	    ;;
	esac
done
