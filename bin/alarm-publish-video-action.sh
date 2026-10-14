#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

FILE1="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM"
FILE2="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-2$FILE_EXTENSION_ALARM"
FILE3="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-3$FILE_EXTENSION_ALARM"

# Optional S3-compatible endpoint (empty = real AWS), e.g. a local server for testing
S3_ENDPOINT_ARGS=()
[ -n "${S3_ENDPOINT_URL:-}" ] && S3_ENDPOINT_ARGS=(--endpoint-url "$S3_ENDPOINT_URL")

while true
do
    if [ -e "$FILE1" ] || [ -e "$FILE2" ] || [ -e "$FILE3" ]; then
        log "Publishing new alarm video"

        TARGET_FILE_PREFIX=$(date "+%Y-%m-%d-%H-%M-%S")

        for i in 1 2 3; do
            FILE="$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-$i$FILE_EXTENSION_ALARM"
            [ -e "$FILE" ] || continue

            TARGET_S3_URL="s3://${S3_BUCKET}/${ENV}/$TARGET_FILE_PREFIX-$i$FILE_EXTENSION_ALARM"

            aws "${S3_ENDPOINT_ARGS[@]}" --profile alarm-video-s3 s3 cp "$FILE" "$TARGET_S3_URL"
            # set to expire after one week
            SIGNED_URL=$(aws "${S3_ENDPOINT_ARGS[@]}" --profile alarm-video-s3 s3 presign "$TARGET_S3_URL" --expires-in 604800)
            ESCAPED_URL=$(echo -n "$SIGNED_URL" | jq -s -R -r @uri)

            curl --silent "${TG_API_URL:-https://api.telegram.org}/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&text=$ESCAPED_URL"

            rm "$FILE"
        done
    fi
    sleep 1  # Wait 1 second until recheck
done
