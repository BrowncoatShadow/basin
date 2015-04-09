#!/bin/bash
# twitcheck - A twitch.tv Stream Checker by BrowncoatShadow and Crendgrim


# BEGIN BOOTSTRAPPING

# Check for flags.
while getopts ":l:" opt; do
	case $opt in
		l)
			alt_list=$OPTARG >&2
		;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
		;;
	esac
done

# Add jq's install dir (via homebrew) to PATH for cron on OS X.
PATH=$PATH:/usr/local/bin

# Figure out the directory this script is living in.
TC_BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# If the settings do not exist yet, create them from a default template.
[[ -f "$HOME/.config/twitcheckrc" ]] || sed "s#<INSTALL_DIR>#$TC_BASEDIR#g" "$TC_BASEDIR/twitcheckrc.default" > "$HOME/.config/twitcheckrc"

# Load settings.
source $HOME/.config/twitcheckrc

# Generate folders and files if they do not exist.
check_file() {
	if [[ ! -f $1 ]]
	then
		mkdir -p $(dirname $1)
		touch $1
	fi
}
check_file $DBFILE

# Cleanup: If the database file is older than 2 hours, consider it outdated and remove its contents.
[[ -s $DBFILE && $(($(date +%s)-$(cat $DBFILE | jq -r '.lastcheck'))) -gt 7200 ]] && echo > $DBFILE

# END BOOTSTRAPPING


# BEGIN FUNCTIONS

# Get data from the returned json
get_data() {
	echo $returned_data | jq -r '.streams[] | select(.channel.name=="'$1'") | .channel.'$2
}

# Get data from the database
get_db() {
	echo $(cat $DBFILE | jq -r '.online[] | select(.name=="'$1'") | .'$2)
}

main() {

	# Check if stream is active.
	name=$(get_data $1 'name')

	if [ "$name" == "$1" ]
	then
		# Check if it has been active since last check.
		[[ $DBFILE ]] && dbcheck=$(get_db $1 'name')

		notify=true

		# Grab important info from JSON check.
		schannel="$(get_data $1 'display_name')"
		sgame="$(get_data $1 'game')"
		slink="$(get_data $1 'url')"
		sstatus="$(get_data $1 'status')"

		# Sometimes, the API sends broken results. Handle these gracefully.
		if [[ "$sgame" == null || "$sstatus" == null ]]
		then
			# If the stream was live before, assume the results to be broken, so we don't re-notify.
			if [ -n "$dbcheck" ]
			then
				# Recover the old data
				sgame="$(get_db $1 'game')"
				sstatus="$(get_db $1 'status')"
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

			# Send notification by using the module and giving it the arguments.
			$MODDIR$MODULE "$schannel" "$sgame" "$sstatus" "$slink"

		fi
	fi

}

# END FUNCTIONS


# BEGIN PROGRAM

# Check if script has been called with command-line arguments.
if [[ -n "$alt_list" ]]
then

	# Use arguments instead of settings rc file and use the echo module.
	list=$alt_list
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
		list=$FOLLOWLIST

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

# Run the main function for each stream.
for channel in $list
do
	main $channel
done

# Setup online database.
[[ $DBFILE ]] && echo "$returned_data" | jq '{online:[.streams[] | {name:.channel.name, game:.channel.game, status:.channel.status}], lastcheck:'$(date +%s)'}' > $DBFILE

# END PROGRAM

exit 0
