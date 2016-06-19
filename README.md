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
- [periscope.tv](https://periscope.tv)
- [youtube.com](https://youtube.com)


### Notifier Plugins
- `echo` Echos any active streams to terminal.
- `kdialog`
- `osx` OS X's Notification Center.
- `pushbullet`
- `terminal_notifier` More robust Notification Center messages.


## Dependencies
- [jq](http://stedolan.github.io/jq/)
- [curl](http://curl.haxx.se/)


## Installation
```bash
git clone https://github.com/BrowncoatShadow/basin.git
cd basin
./basin init
./basin start
```
`basin init` will generate `~/.config/basinrc`, which will then open for you to
edit. You can add service and notification specific settings here.

`basin start` will add a crontab entry that will run `basin check` every minute
to check your configured services and send notifications.

Run basin without any arguments to get a more in-depth usage description and
learn how to use its built-in help command.


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
