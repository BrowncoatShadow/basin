twitcheck
=========
**twitcheck.sh** is a quick and dirty, modular bash script that checks twitch.tv to see if channels you care about are streaming, and then reports the results using a selection of modules.

## Installation
```
git clone https://github.com/BrowncoatShadow/twitcheck.git
cd twitcheck
./twitcheck.sh
```
This will generate `~/.config/twitcheckrc`, which you will need to edit to set your settings.

## Configuration
You will need to set the following settings for the script to run properly.

`USER=`  
Your Twitch user in all lower-case letters. Set this if you want twitcheck to automatically fetch the people you follow.

`FOLLOWLIST=""`  
Additional list of streams to check on, divided by spaces. Useful for watching yourself or for people you are not following on twitch. The list must be in double quotes.

`CLIENT=`  
Twitch client_id, generate at <http://www.twitch.tv/kraken/oauth2/clients/new>. This is to prevent you from hitting twitch's API ratelimit.

`MODULE=echo_notify.sh`  
The notification module to use. 

You will also need to define any settings required for your module of choice. They are all listed in the `twitcheckrc` file.

## Useage
The easiest way to use the script is to configure it and add it as a cronjob.  
`crontab -l | { cat; echo "*/1 * * * * <PATH_TO>/twitcheck.sh"; } | crontab -`  

You can also invoke the script with users as arguments. It will ignore your configuration and only check the users you supply as arguments, echoing any currently streaming channels to terminal with game, status, and link.  
`./twitcheck.sh <channel> [channel2] [channel*]`

## Dependencies
- [jq](http://stedolan.github.io/jq/)
- [curl](http://curl.haxx.se/)
- Optional: KDialog

## Contributing
You are more than welcome to submit patches and features to be added to the project. If you write your own notification module, we would also be interested in looking at it.

## License
The MIT License (MIT)  
Copyright (c) 2015
