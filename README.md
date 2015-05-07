twitcheck
=========
**twitcheck.sh** is a quick and dirty, modular bash script that checks [twitch.tv](https://twitch.tv) to see if channels you care about are streaming, and then reports the results using a selection of modules.


## Modules
- `echo_notify.sh`
  - Echos any active streams to terminal.
- `kdialog_notify.sh`
  - Gives desktop notifications using kdialog in [KDE](https://www.kde.org/).
- `osx_notify.sh`
  - Sends notifications to OS X's Notification Center. Does not allow for the channel's url to be opened when clicking the notification. There is a workaround using [terminal-notifier](https://github.com/alloy/terminal-notifier), which will open channel urls when clicked. There is a setting for which method to use in the twitcheckrc file.
- `pb_notify.sh`
  - Sends push notifications using [pushbullet](https://pushbullet.com). This can be used for both mobile notifications and desktop notifications when paired with the pushbullet browser extention or desktop app.


## Installation
```
git clone https://github.com/BrowncoatShadow/twitcheck.git
cd twitcheck
./twitcheck.sh
```
This will generate `~/.config/twitcheckrc`, which you will need to edit to set your settings. The bare minimal settings that you will need to define are listed in the "Configuration" section below.

The script was designed to be run in crontab. You can quickly add it to your crontab by running the below command.
```
crontab -l | { cat; echo "*/1 * * * * ~/twitcheck/twitcheck.sh"; } | crontab -
```
The above command assumes you installed the script in your home folder and runs it every minute. You can tweak the cronjob to use a custom location for the script and/or the interval for running the script.

Alternitively, you can manually add the script to your crontab by running `crontab -e` and adding the below line.  
```
*/1 * * * * ~/twitcheck/twitcheck.sh
```
Again, this assumes a check every minute and script installation in your home folder. 


## Configuration
You will need to set the following settings for the script to run properly.

- `USER=`
  - Your Twitch user in all lower-case letters. Set this if you want twitcheck to automatically fetch the people you follow.
- `FOLLOWLIST=""`
  - Additional list of streams to check on, divided by spaces. Useful for watching yourself or for people you are not following on twitch. The list must be in double quotes.
- `CLIENT=`
  - Twitch client_id, generate at <http://www.twitch.tv/kraken/oauth2/clients/new>. This is to prevent you from hitting twitch's API ratelimit.
- `MODULE=echo_notify.sh`
  - The notification module to use.

You will also need to define any settings required for your module of choice. They are all listed in the `twitcheckrc` file.


## Flags
- `-c <rcfile>`
  - Use alt config file. This will cause the script not to check for, create, or use the default config. Instead it will use the config file given as an argument.
- `-d`
  - Debug flag. This will cause the script to output useful debug information.
- `-l "<channel>..."`
  - This uses the channels provided in the argument instead of any defined in the config, ignores the database of channels the script already knows are streaming, and then echos any currently streaming channels to the console using the echo_notify.sh module. This is useful if you want to quickly do a manual check on a handful of channels.
- `-i`
  - Interactive, updating list that shows which streams are live. It uses the offline database, so the script needs to be periodically running in the background (for example, via cronjob) for updates to show.


## Dependencies
- [jq](http://stedolan.github.io/jq/)
- [curl](http://curl.haxx.se/)
- Optional: [terminal-notifier](https://github.com/alloy/terminal-notifier) (OS X)


## Contributing
We are welcome to accepting patches and additional modules. Feel free to fork our project, and then submit a pull request for your contribution.


## License
The MIT License (MIT)  
Copyright (c) 2015
