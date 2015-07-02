basin.sh
=========
**basin.sh** is a bash script that collects all the streams you care about in one place. It supports multiple services and notification methods, with more being added. basin.sh can be used for a single service, or multiple.


## Services
- [twitch.tv](http://twitch.tv)
- [hitbox](http://hitbox.tv)


## Notification Modules
- `echo_notify.sh`
  - Echos any active streams to terminal.
- `kdialog_notify.sh`
  - Gives desktop notifications using kdialog in [KDE](https://www.kde.org/).
- `osx_notify.sh`
  - Sends notifications to OS X's Notification Center. Does not allow for the channel's url to be opened when clicking the notification. There is a workaround using [terminal-notifier](https://github.com/alloy/terminal-notifier), which will open channel urls when clicked. There is a setting for which method to use in the basinrc file.
- `pb_notify.sh`
  - Sends push notifications using [pushbullet](https://pushbullet.com). This can be used for both mobile notifications and desktop notifications when paired with the pushbullet browser extention or desktop app.


## Installation
```
git clone https://github.com/BrowncoatShadow/basin.sh.git basin
cd basin
./basin.sh
```
This will generate `~/.config/basinrc`, which you will need to edit to set your settings. The bare minimal settings that you will need to define are listed in the "Configuration" section below.

The script was designed to be run in crontab. You can quickly add it to your crontab by running the below command.
```
crontab -l | { cat; echo "*/1 * * * * ~/basin/basin.sh"; } | crontab -
```
The above command assumes you installed the script in your home folder and runs it every minute. You can tweak the cronjob to use a custom location for the script and/or the interval for running the script.

Alternitively, you can manually add the script to your crontab by running `crontab -e` and adding the below line.  
```
*/1 * * * * ~/basin/basin.sh
```
Again, this assumes a check every minute and script installation in your home folder. 


## Flags
- `-c <rcfile>`
  - Use alt config file. This will cause the script not to check for, create, or use the default config. Instead it will use the config file given as an argument.
- `-i`
  - Interactive, updating list that shows which streams are live. It uses the offline database, so the script needs to be periodically running in the background (for example, via cronjob) for updates to show.


## Dependencies
- [jq](http://stedolan.github.io/jq/)
- [curl](http://curl.haxx.se/)
- Optional: [terminal-notifier](https://github.com/alloy/terminal-notifier) (OS X)


## Contributing
Want to add support for another service or notification method? Did you find a bug? Feel free to fork our project, and submit a pull request for your contribution.


## License
The MIT License (MIT)  
Copyright (c) 2015
