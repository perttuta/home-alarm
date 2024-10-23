
# home-alarm

ONVIF (HomeAssistant) / MQTT / S3 alarm video storage with Telegram notification. Works with Reolink-820A.

# Basic supervisor usage

## Status

`supervisorctl status`

## Rereading config

Reread the configuration, but don't touch running processes.
`supervisorctl reread`

## Update

Restart service(s) whose configuration has changed (by reread).
`supervisorctl update`

## Reloading services

Reread supervisor configuration, reload supervisord and supervisorctl, restart services that were started.
`supervisorctl reload`

## Restarting services

Restart services. Restart does not reread config files. For that, do reread and update.

All processes
`supervisorctl restart all`

Single process
`supervisorctl restart alarm-extract-video`

## Stopping services

All processes
`supervisorctl stop alarm-publish-photo`

Single process
`supervisorctl stop alarm-publish-photo`

