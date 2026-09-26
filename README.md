
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
- `SEGMENT_TIME=10` (segment length in seconds, continuous mode)
- `STALL_TIMEOUT=60` (restart ffmpeg if no new segment appears within this many seconds)

## Continuous Recording Health

supervisord only sees the recorder wrapper, so it cannot detect an ffmpeg that
is still alive but no longer producing video (for example a stalled RTSP
stream). The wrapper therefore watches its own output: a new segment file is
written every `SEGMENT_TIME` seconds, and if the newest segment is older than
`STALL_TIMEOUT`, ffmpeg is stopped (TERM, then KILL) and restarted. Restarts are
logged to `/var/log/alarm-record-video.out.log`.

The wrapper also:
- runs ffmpeg in its own process group, so `supervisorctl stop` tears down
  both (via `stopasgroup`/`killasgroup`);
- reaps its ffmpeg child on exit (including crashes) with a `trap`;
- holds a singleton lock (`/run/alarm-record-video.lock`), so a second recorder
  refuses to start;
- kills any stray ffmpeg matching its output pattern on startup, as a safety
  net against leaked processes.

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

