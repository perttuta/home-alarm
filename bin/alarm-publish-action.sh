#!/bin/bash

ALARM_VIDEO_DIR=/var/cache/alarm-video
FILE_NAME_ALARM=current-alarm
FILE_EXTENSION_ALARM=.mp4

FILE1="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM"
FILE2="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-2$FILE_EXTENSION_ALARM"

TARGET_FILE_PREFIX=$(date "+%Y-%m-%d-%H-%M-%S")
TARGET_S3_URL1="s3://halyvideo/etuovi/$TARGET_FILE_PREFIX-1$FILE_EXTENSION_ALARM"
TARGET_S3_URL2="s3://halyvideo/etuovi/$TARGET_FILE_PREFIX-2$FILE_EXTENSION_ALARM"

while true
do
    if [ -e "$FILE1" ]; then # if first alarm file is found, do work
        echo -e "\n"$(date)" Publishing new alarm"
        # fetch snapshot from camera
        curl --silent --insecure "https://etuovi.home/cgi-bin/api.cgi?cmd=Snap&channel=0&rs=sdaf&user=$ENV_CAMERA_USERNAME_ETUOVI&password=$ENV_CAMERA_PASSWORD_ETUOVI" -o "$ALARM_VIDEO_DIR/etuovi.jpg"
        # send it via Telegram
        curl --silent -X POST -H "Content-Type:multipart/form-data" -F "chat_id=$ENV_TG_CHAT_ID" -F document=@"$ALARM_VIDEO_DIR/etuovi.jpg" "https://api.telegram.org/bot$ENV_TG_BOT_TOKEN/sendDocument"
        rm "$ALARM_VIDEO_DIR/etuovi.jpg"

        aws  --profile alarm-video-s3 s3 cp "$FILE1" "$TARGET_S3_URL1"
        aws  --profile alarm-video-s3 s3 cp "$FILE2" "$TARGET_S3_URL2"
        # set to expire after one week
        SIGNED_URL1=$(aws --profile alarm-video-s3 s3 presign "$TARGET_S3_URL1" --expires-in 604800)
        SIGNED_URL2=$(aws --profile alarm-video-s3 s3 presign "$TARGET_S3_URL2" --expires-in 604800)

        # TODO: send URL to telegram
        #curl --silent 'https://api.telegram.org/bot$ENV_TG_BOT_TOKEN/sendMessage?chat_id=$ENV_TG_CHAT_ID&text=$SIGNED_URL1'
        #curl --silent 'https://api.telegram.org/bot$ENV_TG_BOT_TOKEN/sendMessage?chat_id=$ENV_TG_CHAT_ID&text=$SIGNED_URL2'

        rm "$FILE1"
        rm "$FILE2"
    fi
    sleep 1  # Wait 1 second until recheck
done
