#!/bin/bash
# Pushbullet notification module for twitcheck by Browncoatshadow

source $HOME/.config/twitcheckrc

# Check if a target is defined.
if [ -n "$PB_TARGET" ]
	then
		# Push to target device.
		curl -s --header 'Authorization: Bearer '$PB_TOKEN'' -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"device_iden": "'"$PB_TOKEN"'", "type": "link", "title": "'"$1"' is streaming '"$2"'", "body": "'"$3"'", "url": "'"$4"'"}' > /dev/null
	else
		# Push to all devices, if no target.
		curl -s --header 'Authorization: Bearer '$PB_TOKEN'' -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"type": "link", "title": "'"$1"' is streaming '"$2"'", "body": "'"$3"'", "url": "'"$4"'"}' > /dev/null
fi
