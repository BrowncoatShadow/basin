#!/bin/bash
# basin.sh - A bash script that collects all the streams you care about in one place. by BrowncoatShadow and Crendgrim


# BEGIN BOOTSTRAPPING

# Check for flags.
while getopts ":c:Ci" opt; do
	case $opt in
		c)
			alt_config="$OPTARG"
		;;
		C)
			create_config=true
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

# BEGIN CONFIGFILE
# Create a default config file if -C was called.
if [[ "$create_config" == "true" ]]
then
	# If the file exists already, ask the user if he really wants to replace it.
	if [[ -f "$HOME/.config/basinrc" ]]
	then
		read -p "The configuration file \`$HOME/.config/basinrc\` exists already. Are you sure you want to replace it? [y/N] " prompt
		if [[ $prompt != "y" && $prompt != "Y" && $prompt != "yes" && $prompt != "YES" ]]
		then
			echo "Aborting."
			exit 0
		fi
	fi

	cat > $HOME/.config/basinrc <<"CONFIG"
#!/bin/bash
# basin.sh - A bash script that collects all the streams you care about in one place. by BrowncoatShadow and Crendgrim

### GENERAL SETTINGS
# DBFILE - The database file for storing currently online streams.
#	default: DBFILE=$HOME/.local/share/basin/online.json
# DEBUGFILE - The file for storing debug data. This can help to debug the script itself.
#	default: DEBUGFILE=$HOME/.local/share/basin/debug.json
# MODULE - The notification module to use. The order of arguments is $CHANNEL, $GAME, $STATUS, $LINK.
#	default: MODULE=echo_notify
###
DBFILE=$HOME/.local/share/basin/online.json
DEBUGFILE=$HOME/.local/share/basin/debug.json
MODULE=echo_notify


### TWITCH SETTINGS
# TWITCH_USER - Your Twitch user in all lower-case letters. If set, use this user's followed channels.
#	default: TWITCH_USER=
# TWITCH_FOLLOWLIST - Additional list of streams to check on, divided by spaces. Useful for watching yourself.
#	default: TWITCH_FOLLOWLIST=""
# TWITCH_CLIENT_ID - Twitch client_id, generate at <http://www.twitch.tv/kraken/oauth2/clients/new>.
#	default: TWITCH_CLIENT_ID=
TWITCH_USER=
TWITCH_FOLLOWLIST=""
TWITCH_CLIENT_ID=


### HITBOX SETTINGS
# HITBOX_USER - Your Hitbox user in all lower-case letters. If set, use this user's followed channels.
#	default: HITBOX_USER=
# HITBOX_FOLLOWLIST - Additional list of streams to check on, divided by spaces.
#	default: HITBOX_FOLLOWLIST=""
HITBOX_USER=
HITBOX_FOLLOWLIST=""


### PUSHBULLET SETTINGS
# Note: If PB_URLTARGET and PB_URITARGET are unset, the module will send to all targets.
#
# PB_TOKEN - Pushbullet access token. Find at <https://www.pushbullet.com/account>
#	default: PB_TOKEN=
# PB_URLTARGET - Space seperated list of pushbullet device_idens to send the URL to. 
#	default: PB_URLTARGET=""
# PB_URITARGET - Space seperated list of pushbullet device_idens to send the URI to. 
#	default: PB_URLTARGET=""
# PB_ALLURI - Change to 'true' to use application URI instead of URL when sending to all targets.
#	default: PB_URI=false
###
PB_TOKEN=
PB_URLTARGET=""
PB_URITARGET=""
PB_ALLURI=false


### OS X SETTINGS
# OSX_TERMNOTY - Set to 'true' to use terminal-notifier app instead of applescript. This enables clicking the notification to launch URL.
#	default: OSX_TERMNOTY=false
###
OSX_TERMNOTY=false
CONFIG
	$EDITOR $HOME/.config/basinrc
	exit 0
fi
# END CONFIGFILE

# Check if alternative config file is defined.
if [[ -n "$alt_config" ]]
then
	# If the config file does not exist yet, exit with a descriptive error message.
	if [[ ! -f "$HOME/.config/basinrc" ]]
	then
		echo "[ERROR] The specified configuration file $alt_config is missing." >&2
		echo "[ERROR] You can create it by copying the default configuration file at \`$HOME/.config/basinrc\`." >&2
		echo "[ERROR] If that file does not exist, you can create it by calling \`basin.sh -C\`." >&2
		exit 1
	fi

	# Use alt config file if defined.
	CFGFILE=$alt_config
else
	# If the config file does not exist yet, exit with a descriptive error message.
	if [[ ! -f "$HOME/.config/basinrc" ]]
	then
		echo "[ERROR] The default configuration file $HOME/.config/basinrc is missing." >&2
		echo "[ERROR] You can create it by calling \`basin.sh -C\`." >&2
		exit 1
	fi

	# Use default config file.
	CFGFILE=$HOME/.config/basinrc
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

# BEGIN NOTIFIERS

# These are the functions that are called whenever a stream changes its status to execute the
# user-visible notification.
# Each notifier gets the following parameter:
#  $1: The display name of the stream. Must not be the username, but is the user-facing channel name.
#  $2: The game that is currently being played. Can be empty.
#  $3: The channel's status text, a descriptive caption set by the broadcaster.
#  $4: The link to the channel, correctly formatted for the service.
#  $5: The service the livestream is on.

# Echo notifier.
echo_notify() {
	echo "$5 | $1 [$2]: $3 <$4>"
}

# Kdialog notifier.
kdialog_notify() {
	kdialog --title "$1 is now live on $5" --icon "video-player" --passivepopup "<b>$2</b><br>$3"
}

# OS X notifier.
osx_notifiy() {
	# Check which notification type to use.
	if [ "$OSX_TERMNOTY" == "true" ]
	then

		# Send using terminal-notifier
		terminal-notifier -message "$3" -title "basin.sh" -subtitle "$1 is now streaming $2" -open "$4"

	else

		# Send using OS X applescript (no URL support)
		osascript -e "display notification \"$3\" with title \"basin.sh\" subtitle \"$1 is now streaming $2\""
	fi
}

# Pushbullet notifier.
pb_notify() {
	# Make sure we have a token.
	if [[ -z "$PB_TOKEN" ]]
	then
		echo "ERROR You need to set PB_TOKEN in your settings file." >&2
		exit 1
	fi
	
	# Place the arguments from script into variables that the functions can use.
	name="$1"; game="$2"; stat="$3"; url="$4"; uri="twitch://stream/$1"
	
	# Create functions for sending pushes. 
	allpush() {
		curl -s --header 'Authorization: Bearer '$PB_TOKEN'' -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"type": "link", "title": "'"$name"'", "body": "'"[$game] \\n$stat"'", "url": "'"$1"'"}' > /dev/null
	}
	
	targetpush() {
		curl -s --header 'Authorization: Bearer '$PB_TOKEN'' -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"device_iden": "'"$1"'", "type": "link", "title": "'"$name"'", "body": "'"[$game] \\n$stat"'", "url": "'"$2"'"}' > /dev/null
	}
	
	# If no targets are defined, send to all targets.
	if [[ -z "$PB_URLTARGET" && -z "$PB_URITARGET" ]]
	then
		# If PB_URI is true, send the uri link instead of url.
		if [ "$PB_ALLURI" == "true" ]
		then
			link="$uri"
		else
			link="$url"
		fi
	
		# Push to all.
		allpush $link
	fi
	
	# For each target in URL list, send a push.
	if [ -n "$PB_URLTARGET" ]
	then
		for target in $PB_URLTARGET
		do
			targetpush $target $url
		done
	fi
	
	# For each target in URI list, send a push.
	if [ -n "$PB_URITARGET" ]
	then
		for target in $PB_URITARGET
		do
			targetpush $target $uri
		done
	fi
}

# END NOTIFIERS


# BEGIN SERVICES

# The plugins for the different streaming services. These functions are responsible for fetching
# data from the foreign APIs, parsing this data and calling `check_notify` for any live streams.
# That function will then decide whether to send a notification.
# Also, these plugins will output all current live channels as JSON, which then gets accumulated
# and saved into the database file.

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

		# Sometimes the hitbox API returns garbage. If that happens, handle it gracefully.
		is_live="$(echo "$returned_data" | jq -r '.livestream[] | .media_is_live' 2>/dev/null)"
		if [[ $? == 4 ]]
		then
			# Insert entry recovered from database.
			sdisplay_name="$(get_db 'hitbox' $channel 'display_name')"
			# Did it even exist in the database?
			if [[ -n "$sdisplay_name" ]]
			then
				sgame="$(get_db 'hitbox' $channel 'game')"
				sstatus="$(get_db 'hitbox' $channel 'status')"
				slink="$(get_db 'hitbox' $channel 'url')"
				new_online_json="$(echo '[{"name":"'$name'", "display_name":"'$sdisplay_name'", "game":"'"$sgame"'", "status":'"$(echo "$sstatus" | jq -R '.')"', "url": "'"$slink"'"}]' | jq "$new_online_json"' + .')"
			fi
		elif [[ "$is_live" == "1" ]]
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

# END SERVICES


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
				# Recover the old data.
				sdisplay_name="$(get_db $service $name 'display_name')"
				sgame="$(get_db $service $name 'game')"
				sstatus="$(get_db $service $name 'status')"
				slink="$(get_db $service $name 'url')"
				# Output the broken stream.
				# This output can be used by the service plugins to replace the broken record,
				# so it does not show up in the database.
				echo null | jq '{"name":"'$name'", "display_name":"'$sdisplay_name'", "game":"'"$sgame"'", "status":'"$(echo "$sstatus" | jq -R '.')"', "url": "'"$slink"'"}'
			fi

			return -1 # Otherwise ignore the broken result to not get a null/null notification.
		fi

		# Already streaming last time, check for updates.
		if [ -n "$dbcheck" ]
		then

			notify=false

			dbgame="$(get_db $service $name 'game')"
			dbstatus="$(get_db $service $name 'status')"

			# Notify when game or status change.
			[[ "$dbgame" != "$sgame" || "$dbstatus" != "$sstatus" ]] && notify=true
		fi

		if [ $notify == true ]
		then

			# Send notification by using the module and giving it the arguments.
			$MODULE "$sdisplay_name" "$sgame" "$sstatus" "$slink" "$service"
		fi
	fi

}

# Main function.
# Calls the service plugins for the configured lists, which in turn call the notification
# function, and saves their output to the database if wanted.
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

# Non-interactive mode: Update the database.
else

	# Run the main program.
	main

fi

# END PROGRAM

exit 0
