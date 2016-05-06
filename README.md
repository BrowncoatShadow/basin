basin
=========
**basin** is a bash script that collects all the streams you care about in one
place. Run it as a service, using cron, to check for channels that start live
streaming on services like [twitch.tv](http://twitch.tv), then get notifications
on your machine or push them to a service like
[Pushbullet](https://pushbullet.com).


### Service Plugins
- [azubu.tv](http://azubu.tv)
- [hitbox.tv](http://hitbox.tv)
- [twitch.tv](http://twitch.tv)


### Notifier Plugins
- `echo` Echos any active streams to terminal.
- `kdialog`
- `osx` OS X's Notification Center.
- `pushbullet`


## Dependencies
- [jq](http://stedolan.github.io/jq/)
- [curl](http://curl.haxx.se/)


## Installation
```bash
git clone https://github.com/BrowncoatShadow/basin.git
cd basin
./basin -C
```
This will generate `~/.config/basinrc`, which will then open for you to edit.
It will then ask if you want it to setup a crontab entry. This crontab entry
will run every minute by default. You can change the frequency by editing your
crontab. The default crontab entry looks something like this:
```
*/1 * * * * ~/basin/basin
```


## Command Line Options
- `-c <rcfile>`
  - Use alt config file. This will cause the script not to check for, create, or
    use the default config. Instead it will use the config file given as an
    argument.
- `-C`
  - Create a new config file. This generates `~/.config/basinrc` and then opens
    it in EDITOR for the user to give initial settings.
- `-i`
  - Interactive, updating list that shows which streams are live. It uses the
    offline database, so the script needs to be periodically running in the
    background (for example, via crontab) for updates to show.


## Contributing
Want to add a plugin for another service or notification method? Did you find a
bug? Feel free to fork our project, and submit a pull request for your
contribution.


## License
The MIT License (MIT)

Copyright (c) 2015-2016

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
