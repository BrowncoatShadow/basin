#!/bin/bash
# kdialog notification module for twitcheck by Crendgrim

kdialog --title "$1 is now live" --icon "video-player" --passivepopup "<b>$2</b><br>$3"
