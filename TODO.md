TODO
----
- Handle bad API returns from twitch gracefully.
  Currently, we load the last status for a channel in case of a fishy return,
  but we still write the returned values to the database. This results in the
  false notification popping up in the next iteration.
  The best course of action to fix this is to analyze the returned results in
  hope of finding a broken one and seeing whether it can be easily dealt with
- Handle DISPLAY for kdialog_notify
- Update pb_notify.sh to handle lists of targets for both URLs and URIs.
