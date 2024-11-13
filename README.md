
# home-alarm

ONVIF (HomeAssistant) / MQTT / S3 alarm video storage with Telegram notification. Works with Reolink-820A.

# Deployment

1. Create new env
2. Clone the home-alarm repository
3. Copy env template to /root/alarm.env and fill in missing values
4. Deploy CDK project
   1. cd cdk/alarm-video
   2. npx cdk deploy
5. Create /root/.aws/credentials file with profile `alarm-video-s3`
   1. Use the user that CDK deployment creates
6. Run `deploy/deploy.sh` in project root (all the references are relative to project root)

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

