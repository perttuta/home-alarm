# Change notes: Docker testing environment (multi-camera compatible)

## What was done

Added a Docker-based testing environment for `home-alarm` and made it work with
the `multi-camera` branch. It runs the whole alarm pipeline without real
cameras, MQTT broker, AWS or Telegram, on a Debian GNU/Linux 12 base image.

New `docker/` directory:

- `Dockerfile`            - `debian:12` with supervisor, mosquitto-clients,
                            curl, jq, procps, ffmpeg, awscli; installs the alarm
                            scripts under `/usr/bin`
- `docker-compose.yml`    - `home-alarm` (scripts under supervisord), a Mosquitto
                            broker, an S3-compatible store (Zenko CloudServer),
                            an init job that creates the `halyvideo` bucket, and a
                            `mock` service
- `mock/mock_server.py`   - fake camera (serves a snapshot) + fake Telegram API;
                            logs every request
- `test.env`              - per-camera config file (the `multi-camera` branch
                            model), mounted at `/etc/alarm-camera.env`
- `entrypoint.sh`         - sources the env file, writes `~/.aws` profile used by
                            the S3 scripts, then starts supervisord
- `supervisor-test/`      - supervisor programs for the test container; the
                            `alarm-record-video` recorder is disabled (no RTSP
                            camera)
- `test/run-test.sh`      - smoke test: seeds fake video segments, publishes an
                            MQTT motion event, asserts snapshot + Telegram photo
                            + S3 upload/signed URLs
- `README.md`             - usage and configuration notes
- `NOTES.md`              - this file

## Changes to existing files

- `bin/alarm-publish-photo-action.sh` and `bin/alarm-publish-video-action.sh`
  - Telegram API base URL is now configurable via `TG_API_URL` (default
    `https://api.telegram.org`), so the test can point at the mock.
  - Video publisher supports an S3-compatible endpoint via `S3_ENDPOINT_URL`
    (empty = real AWS). Uses `--endpoint-url` because Debian's aws-cli ignores
    the `endpoint_url` config key and the `AWS_ENDPOINT_URL` env vars.
- `env.template` - documented the new optional `S3_ENDPOINT_URL` and `TG_API_URL`
  settings.
- `.gitignore` - keep `docker/test.env` despite the `*.env` rule.

## Gotchas found

- The alarm scripts do `source "$ENV_FILE"`. In bash, an unquoted `&` in a value
  acts as a background operator, silently truncating URLs that contain query
  strings, e.g. `CAMERA_SNAPSHOT_URL=http://host/a.cgi?cmd=Snap&channel=0`.
  Such values must be quoted in the env file.
- supervisord parses a program's `environment=` line with `shlex`, so `&` must
  be double-quoted there too (no longer needed on this branch, since config
  moved into the env file).
- Docker Hub in this environment denies the `minio/*` images, so Zenko
  CloudServer is used as the S3-compatible store.

## Verification

Smoke test (`docker/test/run-test.sh`) on the `multi-camera` branch passes all
checks:

- camera snapshot requested (mock)
- snapshot photo sent to Telegram (mock)
- both alarm videos uploaded to S3 and signed URLs sent to Telegram (mock)

## How to use

```sh
docker/test/run-test.sh                     # start everything and run the smoke test
docker compose -f docker/docker-compose.yml up -d --build   # start only
```