#!/bin/bash

ALARM_VIDEO_DIR=/var/cache/alarm-video

FILE_PHOTO="$ALARM_VIDEO_DIR/etuovi.jpg"

while true
do
    if [ -e "$FILE_PHOTO" ]; then # if alarm photo is found, send it
        echo -e "\n"$(date)" Publishing new alarm photo"
        # send it via Telegram
        curl --silent -X POST -H "Content-Type:multipart/form-data" -F "chat_id=$ENV_TG_CHAT_ID" -F document=@"$FILE_PHOTO" "https://api.telegram.org/bot$ENV_TG_BOT_TOKEN/sendDocument"
        rm "$FILE_PHOTO"
    fi
    sleep 1  # Wait 1 second until recheck
done
