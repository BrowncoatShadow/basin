#!/bin/bash
# OS X Notification Center module for twitcheck by BrowncoatShadow and Crendgrim
# Requires: terminal-notifier <https://github.com/alloy/terminal-notifier>

terminal-notifier -message "$3" -title "Twitch" -subtitle "$1 is now streaming $2" -open "$4"
