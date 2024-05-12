#!/bin/bash

source /usr/bin/alarm-util.sh
set -a; source "${ENV_FILE}"; set +a

log("Setting up old file removal")
while true; do
  # Find files older than 10 minutes and delete them
  find "$ALARM_VIDEO_DIR" -type f -mmin +10 -exec rm -f {} \;
  sleep 600
done
