#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

# Ensure recording mode is set, default to continuous
RECORDING_MODE="${RECORDING_MODE:-continuous}"

if [ "$RECORDING_MODE" = "continuous" ]; then
    log "Starting continuous video recording"
    /usr/bin/ffmpeg -loglevel error -i rtsp://${CAMERA_USERNAME}:${CAMERA_PASSWORD}@${CAMERA_RTSP_URL} -an -c:v copy -map 0 -f segment -segment_time 10 -segment_format mp4 "${ALARM_VIDEO_DIR}"/"${ALARM_VIDEO_FILE_PREFIX}"%04d.mp4
else
    log "On-demand recording mode - service not needed"
    exit 0
fi