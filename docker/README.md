# Docker testing environment for home-alarm

Runs the whole home-alarm pipeline in containers without real cameras, MQTT
broker, AWS or Telegram. Base image is Debian GNU/Linux 12 (`debian:12`).
Compatible with the `multi-camera` branch (env-file based configuration).

## Services

| Service     | Role                                                                  |
|-------------|-----------------------------------------------------------------------|
| `home-alarm`| The alarm scripts under `supervisord` (Debian 12 image)               |
| `broker`    | Mosquitto MQTT broker, listens on host port `1883`                    |
| `s3`        | S3-compatible object store (Zenko CloudServer), listens on `8000`     |
| `s3-init`   | Creates the `halyvideo` bucket once                                   |
| `mock`      | Fake camera (serves a snapshot) + fake Telegram API, listens on `8080`|

The `alarm-record-video` supervisord program is disabled in the test config
(`docker/supervisor-test/`) because there is no real RTSP camera.

## Usage

```sh
# start everything and run a full smoke test (simulates a motion event)
docker/test/run-test.sh

# start the environment only
docker compose -f docker/docker-compose.yml up -d --build

# trigger a motion event manually
docker compose -f docker/docker-compose.yml exec -T home-alarm \
  mosquitto_pub -h broker -u test -P test -t etuovi-person -m 'motion detected'

# inspect what the alarm scripts did
docker compose -f docker/docker-compose.yml logs home-alarm mock
docker compose -f docker/docker-compose.yml exec -T home-alarm \
  supervisorctl status
```

The smoke test asserts that:
1. the camera snapshot is requested (mock),
2. the snapshot photo is sent to Telegram (mock),
3. the two alarm videos are uploaded to S3 and their signed URLs are sent to
   Telegram (mock).

## Configuration

This branch reads all settings from an environment file (one per camera,
identified by `ENV`). `docker/test.env` is mounted at `/etc/alarm-camera.env`
and pointed to via `ENV_FILE` (this mirrors the production setup where
`deploy.sh` sets `ENV_FILE=/root/alarm.env` in `supervisord.conf`). The
container entrypoint sources the same file so it can write the AWS profile
used by the scripts.

Camera/MQTT settings (`MQTT_HOST`, `CAMERA_SNAPSHOT_URL`, `CAMERA_USERNAME`,
`S3_BUCKET`, `TG_BOT_TOKEN`, ...) follow `env.template`. Test-only additions:

| Variable             | Default                     | Purpose                                        |
|----------------------|-----------------------------|------------------------------------------------|
| `TG_API_URL`         | `https://api.telegram.org`  | Point photo/video publishing at the mock       |
| `S3_ENDPOINT_URL`    | (none -> real AWS)          | Point `aws s3 cp/presign` at local S3 (`http://s3:8000`) |
| `S3_PROFILE`         | `alarm-video-s3`            | AWS profile (credentials written to `~/.aws`)  |

## Gotchas found on this branch

* **Quoting in env files**: the alarm scripts do `source "$ENV_FILE"`. In bash
  an unquoted `&` in a value acts as a background operator, so a snapshot URL
  like `CAMERA_SNAPSHOT_URL=http://host/a.cgi?cmd=Snap&channel=0` is silently
  truncated. Quote such values: `CAMERA_SNAPSHOT_URL="http://host/a.cgi?cmd=Snap&channel=0"`.
* **AWS endpoint**: the aws-cli in Debian 12 ignores both the `endpoint_url`
  config key and the `AWS_ENDPOINT_URL` env vars. The publish-video script
  therefore takes `--endpoint-url` from `S3_ENDPOINT_URL`.
* **supervisord `environment=`**: values are parsed with `shlex`, so `&` must
  be double-quoted there too (no longer relevant on this branch, since config
  moved to the env file).