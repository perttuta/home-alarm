#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

while true
do
    if [ -e "$FILE_PHOTO" ]; then # if alarm photo is found, send it
        log("Publishing new alarm photo")
        # send it via Telegram
        curl --silent -X POST -H "Content-Type:multipart/form-data" -F "chat_id=$ENV_TG_CHAT_ID" -F document=@"${FILE_PHOTO}" "https://api.telegram.org/bot$ENV_TG_BOT_TOKEN/sendDocument"
        # for some reason a short wait is needed, because otherwise curl fails
        sleep 1
        log("Publishing done")
        rm "$FILE_PHOTO"
    fi
    sleep 1  # Wait 1 second until recheck
done
