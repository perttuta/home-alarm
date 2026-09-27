#!/bin/bash
# Smoke test for the home-alarm testing environment.
#
# Simulates a camera motion event:
#   1. seed a couple of "recorded" out*.mp4 files
#   2. publish a message to the MQTT topic the alarm listens on
#   3. wait for the alarm pipeline to run
#   4. verify: snapshot posted to Telegram, videos uploaded to S3 (MinIO),
#      signed URLs posted to Telegram
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

echo "==> Seeding fake recorded videos"
"${COMPOSE[@]}" exec -T home-alarm sh -c "
    mkdir -p $ALARM_VIDEO_DIR
    head -c 1024 /dev/urandom > $ALARM_VIDEO_DIR/out0001.mp4
    head -c 1024 /dev/urandom > $ALARM_VIDEO_DIR/out0002.mp4
"

echo "==> Publishing a motion event to MQTT"
"${COMPOSE[@]}" exec -T home-alarm mosquitto_pub \
    -h broker -u test -P test -t "$TOPIC" -m 'motion detected'

echo "==> Waiting for the alarm pipeline (snapshot + video processing)"
sleep 40

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

echo "==> home-alarm logs (last 30 lines):"
"${COMPOSE[@]}" logs --tail 30 home-alarm 2>&1