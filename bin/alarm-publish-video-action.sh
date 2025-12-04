#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

FILE1="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM"
FILE2="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-2$FILE_EXTENSION_ALARM"

RECORDING_MODE="${RECORDING_MODE:-continuous}"

while true
do
    if [ -e "$FILE1" ]; then # if first alarm file is found, do work
        log "Publishing new alarm video"

        TARGET_FILE_PREFIX=$(date "+%Y-%m-%d-%H-%M-%S")
        TARGET_S3_URL1="s3://${S3_BUCKET}/${ENV}/$TARGET_FILE_PREFIX-1$FILE_EXTENSION_ALARM"

        aws  --profile alarm-video-s3 s3 cp "$FILE1" "$TARGET_S3_URL1"
        # set to expire after one week
        SIGNED_URL1=$(aws --profile alarm-video-s3 s3 presign "$TARGET_S3_URL1" --expires-in 604800)
        ESCAPED_URL1=$(echo -n "$SIGNED_URL1" | jq -s -R -r @uri)

        curl --silent "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&text=$ESCAPED_URL1"

        rm "$FILE1"

        # In continuous mode, also handle the second file
        if [ "$RECORDING_MODE" = "continuous" ] && [ -e "$FILE2" ]; then
            TARGET_S3_URL2="s3://${S3_BUCKET}/${ENV}/$TARGET_FILE_PREFIX-2$FILE_EXTENSION_ALARM"

            aws  --profile alarm-video-s3 s3 cp "$FILE2" "$TARGET_S3_URL2"
            SIGNED_URL2=$(aws --profile alarm-video-s3 s3 presign "$TARGET_S3_URL2" --expires-in 604800)
            ESCAPED_URL2=$(echo -n "$SIGNED_URL2" | jq -s -R -r @uri)

            curl --silent "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&text=$ESCAPED_URL2"

            rm "$FILE2"
        fi
    fi
    sleep 1  # Wait 1 second until recheck
done
