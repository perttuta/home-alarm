#!/bin/bash

ALARM_VIDEO_DIR=/var/cache/alarm-video
FILE_NAME_ALARM=current-alarm
FILE_EXTENSION_ALARM=.mp4
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
        echo $(date) Creating alarm
        # two latest files from recordings (only the files ffmpeg is creating, skip alarm files being processed)
        latest_files=($(find $ALARM_VIDEO_DIR -maxdepth 1 -type f -name "out*.mp4" -printf "%T@ %p\n" | sort -n | tail -2 | cut -d' ' -f2))
        # Make a snapshot photo, which will be sent to Telegram as is
        curl --silent --insecure "https://etuovi.home/cgi-bin/api.cgi?cmd=Snap&channel=0&rs=sdaf&user=$ENV_CAMERA_USERNAME_ETUOVI&password=$ENV_CAMERA_PASSWORD_ETUOVI" -o "$ALARM_VIDEO_DIR/etuovi.jpg"
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

while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
do
    mosquitto_sub -h mqtt.home -u $ENV_MQTT_USERNAME -P $ENV_MQTT_PASSWORD -t etuovi-person | while read -r payload
    do
        echo $(date) Processing received message
        check_reset_interval
        do_work_throttled
    done
    sleep 10  # Wait 10 seconds until reconnection
done
