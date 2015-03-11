#!/bin/bash
# twitcheck - A twitch.tv Stream Checker by BrowncoatShadow and Crendgrim

# GENERAL SETTINGS

# Your Twitch user in all lower-case letters. If set, use this user's followed channels.
USER=
# Additional list of streams to check on, divided by spaces.
FOLLOWLIST=
# Twitch client_id, generate at <http://www.twitch.tv/kraken/oauth2/clients/new>.
CLIENT=
# The file to store the stream data returned from the Twitch API in.
DATAFILE=/tmp/twitch.json
# A database file to store currently online streams in.
DBFILE=/tmp/twitch.txt
# The notification module to use. The order of arguments is $CHANNEL, $GAME, $STATUS, $LINK.
SENDIT=./kdialognotify.sh

# GENERAL SETTINGS END


# PUSHBULLET SETTINGS

# Pushbullet access token.
PB_TOKEN=
# Pushbullet device ID. Leave blank to push to all devices.
PB_TARGET=

# PUSHBULLET SETTINGS END