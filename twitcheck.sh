#!/bin/bash
# twitcheck - A twitch.tv Stream Checker by BrowncoatShadow and Crendgrim


# BEGIN BOOTSTRAPPING

# Check for flags.
while getopts ":c:dl:i" opt; do
	case $opt in
		c)
			alt_config="$OPTARG"
		;;
		d)
			debug=true
		;;
		l)
			alt_list=$OPTARG
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
[[ -s $DBFILE && $(($(date +%s)-$(cat $DBFILE | jq -r '.lastcheck // 0'))) -gt 7200 ]] && echo > $DBFILE

# END BOOTSTRAPPING


# BEGIN FUNCTIONS

# Output debug info to file, if requested.
debug_output() {
	if [ "$debug" == "true" ]
	then

		unset $database_json
		if [ -n "$DBFILE" ]
		then
			database_json=', "database":'$(cat $DBFILE)
		fi

		debug_data=$(echo '{"old":'$(cat $DEBUGFILE)', "new":{"id":"'$(date +%s)'", "date":"'$(date +%F\ %T)'", "list":"'$list'", "return":'$debug_return$database_json'}}' | jq '[.old[], .new]')
		echo "$debug_data" > $DEBUGFILE
	fi
}

# Get data from the returned json
get_data() {
	echo "$returned_data" | jq -r '.streams[] | select(.channel.name=="'$1'") | .channel.'$2
}

# Get data from the database
get_db() {
	cat $DBFILE | jq -r '.online[] | select(.name=="'$1'") | .'$2
}

main() {

	# Check if stream is active.
	name=$(get_data $1 'name')

	if [ "$name" == "$1" ]
	then

		# Check if it has been active since last check.
		[[ -n "$DBFILE" ]] && dbcheck=$(get_db $1 'name')

		notify=true

		# Grab important info from JSON check.
		schannel="$(get_data $1 'display_name')"
		sgame="$(get_data $1 'game')"
		slink="$(get_data $1 'url')"
		sstatus="$(get_data $1 'status')"

		# Sometimes, the API sends broken results. Handle these gracefully.
		if [[ "$sgame" == null && "$sstatus" == null ]]
		then
			# Remove it from the returned json, so we don't even save it to the online db
			returned_data="$(echo "$returned_data" | jq 'del(.streams[] | select(.channel.name=="'$1'"))')"

			# If the stream was live before, assume the results to be broken, so we don't re-notify.
			if [ -n "$dbcheck" ]
			then
				# Recover the old data
				sgame="$(get_db $1 'game')"
				sstatus="$(get_db $1 'status')"
				# Re-insert the broken stream
				returned_data="$(echo "$returned_data" | jq '{"streams": (.streams + [{"channel":{"name":"'$1'", "game":"'"$sgame"'","status":'"$(echo "$sstatus" | jq -R '.')"'}}])}')"
			else
				return # Stream was not live, ignore the broken result to not get a null/null notification.
			fi
		fi

		# Already streaming last time, check for updates
		if [ -n "$dbcheck" ]
		then

			notify=false

			dbgame="$(get_db $1 'game')"
			dbstatus="$(get_db $1 'status')"

			# Notify when game or status change
			[[ "$dbgame" != "$sgame" || "$dbstatus" != "$sstatus" ]] && notify=true
		fi

		if [ $notify == true ]
		then

			# Send notification by using the module and giving it the arguments. Include the config as an environment variable.
			MOD_CFGFILE="$CFGFILE" $MODDIR$MODULE "$schannel" "$sgame" "$sstatus" "$slink"
		fi
	fi

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

		echo "Streams currently live: (last checked at $(date --date="@$(cat $DBFILE | jq -r '.lastcheck')" "+%H:%M"))"
		echo "[press q to exit]"

		# Pretty-print the database json
		echo -e "$(cat $DBFILE | jq -r '
			.online[] |
			[
				"\n\\033[1;34m", .name, "\\033[0m",
				(
					# Properly align the game for shorter channel names
					.name | length |
					if . < 8 then
						"\t\t"
					else
						"\t"
					end
				),
				"\\033[0;36m", .game, "\\033[0m",
				"\n\\033[0;32mhttp://twitch.tv/", .name, "\\033[0m",
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

# Check if script is using an alternitive channel list.
elif [[ -n "$alt_list" ]]
then

	# Use arguments instead of settings rc file and use the echo module.
	list="$alt_list"
	MODULE=echo_notify.sh
	unset DBFILE
else

	# Check if we have a user set or any channels to follow.
	if [[ -z "$USER" && -z "$FOLLOWLIST" ]]
	then
		>&2 echo "You have to supply a user to fetch followed channels from, or set a FOLLOWLIST in the config!"
		>&2 echo "The configuration file can be found at $HOME/.config/twitcheckrc"
		exit 1
	else
		# Use the specified followlist, if set.
		list="$FOLLOWLIST"

		# If user is set fetch users follow list and add them to the list.
		[[ -n $USER ]] && list="$list "$(curl -s --header 'Client-ID: '$CLIENT -H 'Accept: application/vnd.twitchtv.v3+json' -X GET "https://api.twitch.tv/kraken/users/$USER/follows/channels?limit=100" | jq -r '.follows[] | .channel.name' | tr '\n' ' ')
	fi
fi

# Remove duplicates from the list.
list=$(echo $(printf '%s\n' $list | sort -u))

# Sanitize the list for the fetch url.
urllist=$(echo $list | sed 's/ /\,/g')

# Fetch the JSON for all followed channels.
returned_data=$(curl -s --header 'Client-ID: '$CLIENT -H 'Accept: application/vnd.twitchtv.v3+json' -X GET "https://api.twitch.tv/kraken/streams?channel=$urllist&limit=100")

# If debug, save an unmodified copy of the return for the debug file.
if [ "$debug" == "true" ]
then
	debug_return="$returned_data"
fi

# Run the main function for each stream.
for channel in $list
do
	main $channel
done

# Setup online database.
[[ -n "$DBFILE" ]] && echo "$returned_data" | jq '{online:[.streams[] | {name:.channel.name, game:.channel.game, status:.channel.status}], lastcheck:'$(date +%s)'}' > $DBFILE

debug_output

# END PROGRAM

exit 0
