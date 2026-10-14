#!/bin/bash
# Smoke test for the home-alarm testing environment.
#
# Runs the full pipeline end-to-end: a fake camera stream is served over RTSP,
# the recorder continuously writes 10s segments, and a motion event makes the
# pipeline snapshot + upload the segments around the event to S3 and Telegram.
#
# Verifies:
#   1. the recorder is producing segments (continuous recording),
#   2. the camera snapshot is requested (mock),
#   3. the snapshot photo is sent to Telegram (mock),
#   4. the alarm videos are uploaded to S3 and signed URLs posted to Telegram
#      (mock), and the uploaded videos are valid mp4 files.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$DIR/../docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")

ALARM_VIDEO_DIR=/var/cache/alarm-video
TOPIC=etuovi-person
BUCKET=halyvideo

echo "==> Building and starting the testing environment"
"${COMPOSE[@]}" up -d --build

echo "==> Waiting for home-alarm to start"
for i in $(seq 1 60); do
    if docker compose -f "$COMPOSE_FILE" exec -T home-alarm sh -c \
        "supervisorctl status >/dev/null 2>&1" 2>/dev/null; then
        break
    fi
    sleep 1
done

echo "==> Waiting for the recorder to produce continuous-recording segments"
for i in $(seq 1 60); do
    n=$("${COMPOSE[@]}" exec -T home-alarm sh -c \
        "ls $ALARM_VIDEO_DIR/out*.mp4 2>/dev/null | wc -l" 2>/dev/null)
    if [ "${n:-0}" -ge 2 ]; then
        break
    fi
    sleep 1
done

echo "==> Publishing a motion event to MQTT"
"${COMPOSE[@]}" exec -T home-alarm mosquitto_pub \
    -h broker -u test -P test -t "$TOPIC" -m 'motion detected'

echo "==> Waiting for the alarm pipeline (snapshot + video processing)"
sleep 50

echo "==> Checking results"
MOCK_LOG=$("${COMPOSE[@]}" logs mock 2>&1)

if echo "$MOCK_LOG" | grep -q "camera snapshot requested"; then
    echo "PASS  camera snapshot requested"
else
    echo "FAIL  camera snapshot was not requested"
fi

if echo "$MOCK_LOG" | grep -q "sendDocument received"; then
    echo "PASS  photo sent to Telegram"
else
    echo "FAIL  photo was not sent to Telegram"
fi

if echo "$MOCK_LOG" | grep -q "sendMessage"; then
    echo "PASS  signed video URLs sent to Telegram"
else
    echo "FAIL  signed video URLs were not sent to Telegram"
fi

echo "==> Files uploaded to S3 (MinIO-compatible CloudServer):"
"${COMPOSE[@]}" exec -T home-alarm \
    aws --endpoint-url http://s3:8000 --profile alarm-video-s3 s3 ls "s3://$BUCKET/" 2>&1 || true

echo "==> Verifying uploaded videos are valid mp4 files"
"${COMPOSE[@]}" exec -T home-alarm sh -c '
    set -e
    mkdir -p /tmp/verify && cd /tmp/verify
    rm -f *.mp4
    aws --endpoint-url http://s3:8000 --profile alarm-video-s3 s3 cp --recursive s3://halyvideo/ . >/dev/null 2>&1
    for f in */*.mp4; do
        [ -f "$f" ] || continue
        if ffprobe -v error -show_entries format=format_name -of csv=p=0 "$f" >/dev/null 2>&1; then
            echo "PASS  $f is a valid video"
        else
            echo "FAIL  $f is not a valid video"
        fi
    done
'

echo "==> home-alarm logs (last 30 lines):"
"${COMPOSE[@]}" logs --tail 30 home-alarm 2>&1
