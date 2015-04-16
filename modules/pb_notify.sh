#!/bin/bash
# Pushbullet notification module for twitcheck by Browncoatshadow

# Fetch settings
source $MOD_CFGFILE

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
