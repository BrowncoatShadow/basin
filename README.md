basin.sh
=========
**basin.sh** is a bash script that collects all the streams you care about in one place. It supports multiple services and notification methods, with more being added. basin.sh can be used for a single service, or multiple.


## Services
- [twitch.tv](http://twitch.tv)
- [hitbox.tv](http://hitbox.tv)
- [azubu.tv](http://azubu.tv)


## Notification Modules
- `echo_notify`
  - Echos any active streams to terminal.
- `kdialog_notify`
  - Gives desktop notifications using kdialog in [KDE](https://www.kde.org/).
- `osx_notify`
  - Sends notifications to OS X's Notification Center. Does not allow for the channel's url to be opened when clicking the notification. There is a workaround using [terminal-notifier](https://github.com/alloy/terminal-notifier), which will open channel urls when clicked. There is a setting for which method to use in the basinrc file.
- `pb_notify`
  - Sends push notifications using [pushbullet](https://pushbullet.com). This can be used for both mobile notifications and desktop notifications when paired with the pushbullet browser extention or desktop app.


## Dependencies
- [jq](http://stedolan.github.io/jq/)
- [curl](http://curl.haxx.se/)
- Optional: [terminal-notifier](https://github.com/alloy/terminal-notifier) (OS X)


## Installation
```
git clone https://github.com/BrowncoatShadow/basin.sh.git basin
cd basin
./basin.sh -C
```
This will generate `~/.config/basinrc`, which will then open for you to edit.  
It will then ask if you want it to setup a cronjob in your crontab. This cronjob will run every minute by default. You can change the frequency by editing your crontab.

Alternatively, you can manually add the script to your crontab by running `crontab -e` and adding the below line.  
```
*/1 * * * * ~/basin/basin.sh
```
This assumes a check every minute and script installation in your home folder.


## Flags
- `-c <rcfile>`
  - Use alt config file. This will cause the script not to check for, create, or use the default config. Instead it will use the config file given as an argument.
- `-C`
  - Create a new config file. This generates `~/.config/basinrc` and then opens it in EDITOR for the user to give initial settings.
- `-i`
  - Interactive, updating list that shows which streams are live. It uses the offline database, so the script needs to be periodically running in the background (for example, via cronjob) for updates to show.


## Contributing
Want to add support for another service or notification method? Did you find a bug? Feel free to fork our project, and submit a pull request for your contribution.


## License
The MIT License (MIT)  
Copyright (c) 2015
