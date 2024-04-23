#!/bin/bash

ALARM_VIDEO_DIR=/var/cache/alarm-video
FILE_NAME_ALARM=current-alarm
FILE_EXTENSION_ALARM=.mp4

while true
do
    if [ -e "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM" ]; then # if first alarm file is found, do work
        echo -e "\n"$(date)" Publishing new alarm"
        # fetch snapshot from camera
        curl --silent --insecure "https://etuovi.home/cgi-bin/api.cgi?cmd=Snap&channel=0&rs=sdaf&user=$ENV_CAMERA_USERNAME_ETUOVI&password=$ENV_CAMERA_PASSWORD_ETUOVI" -o "$ALARM_VIDEO_DIR/etuovi.jpg"
        # send it via Telegram
        curl --silent -X POST -H "Content-Type:multipart/form-data" -F "chat_id=$ENV_TG_CHAT_ID" -F document=@"$ALARM_VIDEO_DIR/etuovi.jpg" "https://api.telegram.org/bot$ENV_TG_BOT_TOKEN/sendDocument"
        rm "$ALARM_VIDEO_DIR/etuovi.jpg"

        # TODO: handle S3 upload
        # TODO: send S3 URL to Telegram
        rm "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM"
        rm "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-2$FILE_EXTENSION_ALARM"
    fi
    sleep 1  # Wait 1 second until recheck
done
