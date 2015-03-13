#!/bin/bash
# OS X Notification Center module for twitcheck by BrowncoatShadow and Crendgrim
# Optional: terminal-notifier <https://github.com/alloy/terminal-notifier>

# Fetch settings
source $HOME/.config/twitcheckrc

# Check which notification type to use.
if [ "$OSX_TERMNOTY" == "true" ]
then

	# Send using terminal-notifier
	terminal-notifier -message "$3" -title "Twitch" -subtitle "$1 is now streaming $2" -open "$4"

else

	# Send using OS X applescript (no URL support)
	osascript -e 'display notification "$3" with title "Twitch" subtitle "$1 is now streaming $2"'
fi
