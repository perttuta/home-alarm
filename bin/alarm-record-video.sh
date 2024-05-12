#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

log("Starting video recording")
/usr/bin/ffmpeg -loglevel error -i rtsp://${ENV_CAMERA_USERNAME}:${ENV_CAMERA_PASSWORD}@${CAMERA_RTSP_URL} -c:v copy -map 0 -f segment -segment_time 10 -segment_format mp4 "${ALARM_VIDEO_DIR}"/"${ALARM_VIDEO_FILE_PREFIX}"%%04d.mp4