#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

# initial delay in seconds
INITIAL_DELAY=$((60 * 1)) # 1 min

DELAY=0
MAX_DELAY=$((60 * 15)) # maximum delay
LAST_ACTION_TIME=$(date +%s )
RESET_INTERVAL=$((60 * 30))  # Half an hour in seconds

# exponential backoff
calculate_backoff() {
    FACTOR=3
    [ "$DELAY" -eq 0 ] && DELAY="$INITIAL_DELAY"
    DELAY=$((DELAY * FACTOR))
    # Cap the delay at the maximum value
    [ "$DELAY" -gt "$MAX_DELAY" ] && DELAY="$MAX_DELAY"
}

# reset operation waits after some time
check_reset_interval() {
    CURRENT_TIME=$(date +%s )
    if [ "$((CURRENT_TIME - LAST_RESET_TIME))" -ge "$RESET_INTERVAL" ]; then
        LAST_RESET_TIME="$CURRENT_TIME"
        DELAY=0
    fi
}

do_work() {
    if ! [ -e "$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM" ]; then # delay next execution only if no file is being processed at the moment
        log("Creating alarm")
        # Make a snapshot photo, which will be sent to Telegram as is
        curl --silent --insecure "https://${CAMERA_HOST}/cgi-bin/api.cgi?cmd=Snap&channel=0&rs=sdaf&user=${ENV_CAMERA_USERNAME}&password=${ENV_CAMERA_PASSWORD}" -o "${FILE_PHOTO}.tmp"
        mv "${FILE_PHOTO}.tmp" "${FILE_PHOTO}" # this is needed to make sure that unfinished photo is not uploaded
        sleep 5 # allow some time for video capture of the latest event
        # two latest files from recordings (only the files ffmpeg is creating, skip alarm files being processed)
        latest_files=($(find $ALARM_VIDEO_DIR -maxdepth 1 -type f -name "${ALARM_VIDEO_FILE_PREFIX}*.mp4" -printf "%T@ %p\n" | sort -n | tail -2 | cut -d' ' -f2))
        # sleep a while to get complete video files
        sleep 10
        cp "${latest_files[0]}" "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM"
        cp "${latest_files[1]}" "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-2$FILE_EXTENSION_ALARM"
    fi
}

do_work_throttled() {
    CURRENT_TIME=$(date +%s )
    if [ "$((CURRENT_TIME - LAST_ACTION_TIME))" -ge "$DELAY" ]; then
        calculate_backoff # wait some time before doing more work
        LAST_ACTION_TIME="$CURRENT_TIME"
        do_work
    fi
}

LAST_RESET_TIME=$(date +%s)
MOSQUITTO_PID=a

handle_sig() {
    log("Graceful shutdown. Killing also Mosquitto pid ${MOSQUITTO_PID}")
    kill $MOSQUITTO_PID
    exit 0
}

trap 'handle_sig' EXIT

mkfifo mosquitto_pipe

while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
do
    mosquitto_sub -h mqtt.home -u $ENV_MQTT_USERNAME -P $ENV_MQTT_PASSWORD -t $MQTT_QUEUE > mosquitto_pipe &
    MOSQUITTO_PID=$!

    while read -r payload
    do
        log("Processing received message")
        check_reset_interval
        do_work_throttled
    done < mosquitto_pipe
    sleep 10  # Wait 10 seconds until reconnection
done
