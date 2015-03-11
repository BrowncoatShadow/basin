#!/bin/bash
# Pushbullet notification module for twitcheck by Browncoatshadow

# SETTINGS
# Pushbullet access token.
TOKEN=
# Pushbullet device ID. Leave blank to push to all devices.
TARGET=
# SETTINGS END

# Check if a target is defined.
if [ -n "$TARGET" ]
	then
		# Push to target device.
		curl --header 'Authorization: Bearer '$TOKEN'' -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"device_iden": "'"$TOKEN"'", "type": "link", "title": "'"$1"' is streaming '"$2"'", "body": "'"$3"'", "url": "'"$4"'"}'
	else
		# Push to all devices, if no target.
		curl --header 'Authorization: Bearer '$TOKEN'' -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{"type": "link", "title": "'"$1"' is streaming '"$2"'", "body": "'"$3"'", "url": "'"$4"'"}'
