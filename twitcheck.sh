#!/bin/bash
# twitcheck - A twitch.tv Stream Checker by BrowncoatShadow and Crendgrim


# BEGIN BOOTSTRAPPING

# Check for flags.
while getopts ":c:i" opt; do
	case $opt in
		c)
			alt_config="$OPTARG"
		;;
		i)
			interactive=true
		;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
		;;
	esac
done

# Add jq's install dir (via homebrew) to PATH for cron on OS X.
PATH=$PATH:/usr/local/bin

# Figure out the directory this script is living in.
TC_BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Check if alt config file is defined.
if [[ -n "$alt_config" ]]
then
	# Use alt config file if defined.
	CFGFILE=$alt_config
else
	# If the config file does not exist yet, create it from a default template.
	[[ -f "$HOME/.config/twitcheckrc" ]] || sed "s#<INSTALL_DIR>#$TC_BASEDIR#g" "$TC_BASEDIR/twitcheckrc.default" > "$HOME/.config/twitcheckrc"

	# Use defalt config file.
	CFGFILE=$HOME/.config/twitcheckrc
fi

# Load our config file.
source $CFGFILE

# Generate folders and files if they do not exist.
check_file() {
	if [[ ! -f $1 ]]
	then
		mkdir -p $(dirname $1)
		touch $1
	fi
	if [[ -z $(cat $1) ]]
	then
		echo $2 > $1
	fi
}
check_file $DBFILE "{}"
[[ "$debug" == "true" ]] && check_file $DEBUGFILE "[]"

# Cleanup: If the database file is older than 2 hours, consider it outdated and remove its contents.
[[ -s $DBFILE && $(($(date +%s)-$(cat $DBFILE | jq -r '.lastcheck // 0'))) -gt 7200 ]] && echo "{}" > $DBFILE

# END BOOTSTRAPPING


# BEGIN FUNCTIONS

# Twitch service plugin
get_channels_twitch() {

	# Use the specified followlist, if set.
	twitch_list="$TWITCH_FOLLOWLIST"

	# If user is set, fetch user's follow list and add them to the list.
	[[ -n $TWITCH_USER ]] && twitch_list="$twitch_list "$(curl -s --header 'Client-ID: '$TWITCH_CLIENT_ID -H 'Accept: application/vnd.twitchtv.v3+json' -X GET "https://api.twitch.tv/kraken/users/$TWITCH_USER/follows/channels?limit=100" | jq -r '.follows[] | .channel.name' | tr '\n' ' ')

	# Remove duplicates from the list.
	twitch_list=$(echo $(printf '%s\n' $twitch_list | sort -u))

	# Sanitize the list for the fetch url.
	urllist=$(echo $twitch_list | sed 's/ /\,/g')

	# Fetch the JSON for all followed channels.
	returned_data="$(curl -s --header 'Client-ID: '$CLIENT -H 'Accept: application/vnd.twitchtv.v3+json' -X GET "https://api.twitch.tv/kraken/streams?channel=$urllist&limit=100")"

	# Create new database.
	new_online_json="$(echo "$returned_data" | jq '[.streams[] | {name:.channel.name, display_name:.channel.display_name, game:.channel.game, status:.channel.status, url:.channel.url}]')"

	# Notify for new streams.
	for channel in $twitch_list
	do
		output=$(check_notify 'twitch' "$new_online_json" $channel)
		# If we get a broken result, replace the old one.
		if [[ $? != 0 ]]
		then
			# Remove entry.
			new_online_json="$(echo "$new_online_json" | jq 'del(.[] | select(.name=="'$channel'"))')"
			# Re-insert recovered entry.
			new_online_json="$(echo "$new_online_json" | jq '. + ['"$output"']')"
		fi
	done
	echo "$new_online_json"
}

# Hitbox service plugin
get_channels_hitbox() {

	# Use the specified followlist, if set.
	hitbox_list="$HITBOX_FOLLOWLIST"

	# If user is set, fetch user's follow list and add them to the list.
	[[ -n $HITBOX_USER ]] && hitbox_list="$hitbox_list "$(curl -s -X GET "https://api.hitbox.tv/following/user/?user_name=$HITBOX_USER" | jq -r '.following[] | .user_name' | tr '\n' ' ')

	# Remove duplicates from the list.
	hitbox_list=$(echo $(printf '%s\n' $hitbox_list | sort -u))

	# Fetch the JSON for all followed channels.
	new_online_json='[]'
	for channel in $hitbox_list
	do
		returned_data="$(curl -s -X GET "https://api.hitbox.tv/media/live/$channel")"

		is_live="$(echo "$returned_data" | jq -r '.livestream[] | .media_is_live')"
		if [[ "$is_live" == "1" ]]
		then
			# Insert into new database.
			new_online_json="$(echo "$returned_data" | jq "$new_online_json"' + [{name:.livestream[] | .media_name, display_name:.livestream[] | .media_display_name, game:.livestream[] | .category_name, status:.livestream[] | .media_status, url:.livestream[] | .channel.channel_link}]')"
		fi
	done

	# Notify for new streams.
	for channel in $hitbox_list
	do
		check_notify 'hitbox' "$new_online_json" ${channel,,}
	done
	echo "$new_online_json"

}

# Get data from the database.
get_db() {
	cat $DBFILE | jq -r '(.'$1' // [])[] | select(.name=="'$2'") | .'$3
}

# Notification function: Check differences between old and new online list and notify accordingly.
check_notify() {

	service="$1"
	new_online_json="$2"
	channel="$3"

	# Help function to get a given key.
	get_data() {
		echo "$new_online_json" | jq -r '.[] | select(.name=="'$channel'") | .'$1
	}

	# Check if stream is active.
	name=$(get_data 'name')
	if [ "$name" == "$channel" ]
	then
		# Check if it has been active since last check.
		[[ -n "$DBFILE" ]] && dbcheck=$(get_db $service $name 'name')

		notify=true

		# Grab important info from JSON check.
		sdisplay_name="$(get_data 'display_name')"
		sgame="$(get_data 'game')"
		slink="$(get_data 'url')"
		sstatus="$(get_data 'status')"

		# Sometimes, the API sends broken results. Handle these gracefully.
		if [[ "$sgame" == null && "$sstatus" == null ]]
		then

			# If the stream was live before, assume the results to be broken, so we don't re-notify.
			if [ -n "$dbcheck" ]
			then
				# Recover the old data
				sdisplay_name="$(get_db $service $name 'display_name')"
				sgame="$(get_db $service $name 'game')"
				sstatus="$(get_db $service $name 'status')"
				slink="$(get_db $service $name 'url')"
				# Output the broken stream
				echo null | jq '{"name":"'$name'", "display_name":"'$sdisplay_name'", "game":"'"$sgame"'", "status":'"$(echo "$sstatus" | jq -R '.')"', "url": "'"$slink"'"}'
			fi

			return -1 # Otherwise ignore the broken result to not get a null/null notification.
		fi

		# Already streaming last time, check for updates
		if [ -n "$dbcheck" ]
		then

			notify=false

			dbgame="$(get_db $service $name 'game')"
			dbstatus="$(get_db $service $name 'status')"

			# Notify when game or status change
			[[ "$dbgame" != "$sgame" || "$dbstatus" != "$sstatus" ]] && notify=true
		fi

		if [ $notify == true ]
		then

			# Send notification by using the module and giving it the arguments. Include the config as an environment variable.
			MOD_CFGFILE="$CFGFILE" $MODDIR$MODULE "$sdisplay_name" "$sgame" "$sstatus" "$slink"
		fi
	fi

}

# Main function
main() {

	new_online_db='{}'

	# Check if we have a user set or any channels to follow.
	if [[ -n "$TWITCH_USER" || -n "$TWITCH_FOLLOWLIST" ]]
	then
		new_online_db="$(get_channels_twitch | jq "$new_online_db + {twitch: .}")"
	fi

	if [[ -n "$HITBOX_USER" || -n "$HITBOX_FOLLOWLIST" ]]
	then
		new_online_db="$(get_channels_hitbox | jq "$new_online_db + {hitbox: .}")"
	fi

	# Save online database
	[[ -n "$DBFILE" ]] && echo "$new_online_db" | jq '. + {lastcheck:'$(date +%s)'}' > $DBFILE

}

# END FUNCTIONS


# BEGIN PROGRAM

# Check if we are supposed to be running in interactive mode.
if [ "$interactive" == "true" ]
then

	# Updating bash output. Thanks a lot to <https://stackoverflow.com/questions/27945567/bash-script-overwrite-output-without-filling-scrollback/27946484#27946484>.

	# If we exit with Ctrl-C, exit gracefully and restore normal state.
	interactive_cleanup()
	{
		# Revert black magic, exit the screen and recover old cursor position.
		stty sane
		# Exit the screen and recover old cursor position. At this point, all changes done by our script should be reverted.
		tput rmcup
		# End the script here, don't query the API at all.
		exit 0
	}

	# Our actual output
	interactive_output()
	{
		tput clear

		last_checked=$(cat $DBFILE | jq -r '.lastcheck // 0')
		if [ $last_checked -eq 0 ]
		then
			echo "Database too old, updating..."
			main
			last_checked=$(cat $DBFILE | jq -r '.lastcheck')
		fi
		echo "Streams currently live: (last checked at $(date --date="@$last_checked" "+%H:%M"))"
		echo "[press q to exit]"

		# Pretty-print the database json
		echo -e "$(cat $DBFILE | jq -r '
			(.twitch + .hitbox)[] |
			[
				"\n\\033[1;34m", .display_name, "\\033[0m",
				(
					# Properly align the game for shorter channel names
					.display_name | length |
					if . < 8 then
						"\t\t"
					else
						"\t"
					end
				),
				"\\033[0;36m", .game, "\\033[0m",
				"\n\\033[0;32m", .url, "\\033[0m",
				"\n", .status
			] |
			add')"
		echo

	}

	# Black Magic (see stty(1)).
	# Enables deletion of output, and sets the read timeout so we have immediate reactions.
	stty -icanon time 0 min 0

	# Saves current position of the cursor, and opens new screen.
	tput smcup

	# Let's start by displaying our data.
	interactive_output

	# We have to constantly run the loop to give a fast reaction should the user want to quit,
	# but we do not want to constantly update the output. Let's keep track of how many iterations
	# there were and only update every 25 * 0.4 = 10 seconds.
	i=0

	keypress=''
	# Run the loop until [q] is pressed.
	while [ "$keypress" != "q" ]; do

		# We need some kind of timeout so we don't waste CPU time.
		sleep 0.4

		# Make sure to only update every ten seconds.
		((i+=1))
		if [ $i -eq 25 ]
		then
			# Output our stuff.
			interactive_output
			i=0
		fi

		# If a button is pressed, read it. Since we set the minimum read length to 0 using stty,
		# we do not wait for an input here but also accept empty input (i.e. no keys pressed).
		read keypress

		# Handle Ctrl-C (SIGINT) gracefully and restore the proper prompt.
		trap interactive_cleanup SIGINT
	done

	# Reset and exit.
	interactive_cleanup

else

	# Run the main program.
	main

fi

# END PROGRAM

exit 0
