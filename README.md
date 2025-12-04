
# home-alarm

ONVIF (HomeAssistant) / MQTT / S3 alarm video storage with Telegram notification. Works with Reolink-820A.

## Recording Modes

The system supports two recording modes:

### Continuous Mode (default)
- ffmpeg runs continuously in the background, creating 10-second video segments
- When an alarm triggers, the two most recent segments are copied and uploaded
- Higher resource usage (disk I/O, storage, CPU) but captures events that just occurred

### On-Demand Mode
- ffmpeg only starts when an alarm is triggered
- Records for 10 seconds (configurable) starting from the alarm event
- Lower resource usage when no alarms occur
- Only one video file is created per alarm

Configure via `RECORDING_MODE` in your environment file:
- `RECORDING_MODE=continuous` (default)
- `RECORDING_MODE=on-demand`
- `ON_DEMAND_DURATION=10` (seconds, only used in on-demand mode)

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

If supervisord is not running, you can start it with something like
`systemctl start supervisor.service`

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
`supervisorctl restart alarm-mqtt-action`

## Stopping services

All processes
`supervisorctl stop alarm-publish-photo`

Single process
`supervisorctl stop alarm-publish-photo`

