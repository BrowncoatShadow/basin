#!/bin/bash
# twitcheck - A twitch.tv Stream Checker by BrowncoatShadow and Crendgrim
# Useage: Copy settings.default.sh to settings.sh, configure settings and add this script to crontab.

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )'/settings.sh'

# Check if we have a user set
if [ ! -n "$USER" ]
then
	>&2 echo "You have to supply a user to fetch followed channels from!"
	exit
fi

# Cleanup: If the database file is older than 2 hours, consider it outdated and remove its contents.
[[ $((`date +%s`-`stat -c %Y $DBFILE`)) -gt 7200 ]] && echo > $DBFILE

# Fetch users follow list.
list=$(curl -s --header 'Client-ID: '$CLIENT -H 'Accept: application/vnd.twitchtv.v3+json' -X GET "https://api.twitch.tv/kraken/users/$USER/follows/channels?limit=100" | jq -r '.follows[] | .channel.name' | tr '\n' ' ')

# Sanitize the list for the fetch url.
urllist=$(echo $list | sed 's/ /\,/g')

# Fetch the JSON for all followed channels.
curl -s --header 'Client-ID: '$CLIENT -H 'Accept: application/vnd.twitchtv.v3+json' -X GET "https://api.twitch.tv/kraken/streams?channel=$urllist&limit=100" > $DATAFILE

# Main function
main() {

	# Check if stream is active.
	name=$(cat $DATAFILE | jq -r '.streams[] | select(.channel.name=="'$1'") | .channel.name')

	if [ "$name" == "$1" ]
	then
		# Check if it has been active since last check.
		dbcheck=$(cat $DBFILE | grep "^$1")

		notify=true

		# Grab important info from JSON check.
		schannel=$(cat $DATAFILE | jq -r '.streams[] | select(.channel.name=="'$1'") | .channel.display_name')
		sgame=$(cat $DATAFILE | jq -r '.streams[] | select(.channel.name=="'$1'") | .channel.game')
		slink=$(cat $DATAFILE | jq -r '.streams[] | select(.channel.name=="'$1'") | .channel.url')
		sstatus=$(cat $DATAFILE | jq -r '.streams[] | select(.channel.name=="'$1'") | .channel.status')

		[[ "$sgame" == null || "$sstatus" == null ]] && return # sometimes the API sends us broken results. Ignore these.

		# Already streaming last time, check for updates
		if [ -n "$dbcheck" ]
		then

			notify=false

			IFS=`printf "\u2008"` read -ra dbdata <<< "$dbcheck"
			dbgame=${dbdata[1]}
			dbstatus=${dbdata[2]}
			
			# Notify when game or status change
			[[ "$dbgame" != "$sgame" || "$dbstatus" != "$sstatus" ]] && notify=true

		fi

		if [ $notify == true ]
		then

			# Add streamer to currently streaming DB; remove him first to discard old information (only status/game may have changed).
			sed -i "/^$1/d" $DBFILE
			DEL=`printf "\u2008"` # use Unicode 2008 ('PUNCTUATION SPACE') as a delimiter for the database file. This is a key that will not appear in the Twitch status.
			echo "$1$DEL$sgame$DEL$sstatus" >> $DBFILE

			# Send notification. NOTE This method has not yet been tested, and the variable probably needs to be renamed, but "notify" is already taken.
			$SENDIT "$schannel" "$sgame" "$sstatus" "$slink"

		else

			# Exit if already streaming in past check and no updates.
			return 

		fi
	else
		# Remove from steaming DB if exists.
		sed -i "/^$1/d" $DBFILE
	fi
}

# Run the main function for each stream.
for var in $list
do
	main $var
done
