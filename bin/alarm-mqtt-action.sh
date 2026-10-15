#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

# Length of each continuous segment in seconds (must match the recorder).
SEGMENT_TIME="${SEGMENT_TIME:-10}"

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

# List the finalized recording segments, oldest first, one "mtime path" per
# line. The recorder (alarm-record-video.sh) writes these files; a segment's
# mtime is the wall-clock time ffmpeg finished it.
list_segments() {
    find "$ALARM_VIDEO_DIR" -maxdepth 1 -type f \
        -name "${ALARM_VIDEO_FILE_PREFIX}*.mp4" -printf '%T@ %p\n' 2>/dev/null | sort -n
}

# Wait (bounded) until a finalized segment ends at or after $1 (epoch seconds).
# A segment file only becomes a valid, playable mp4 once ffmpeg has closed it
# (the moov atom is written at close), so we must not copy a still-open one.
# The newest file in the directory is the segment ffmpeg is currently writing,
# so we look at the newest *closed* segment (the one just before it).
#
# With `-c:v copy` a segment only ends at a keyframe, so it can be longer than
# SEGMENT_TIME when the camera's keyframe interval is large. The wait is
# therefore generous (2*SEGMENT_TIME + 10), but still shorter than the
# recorder's stall timeout, so a dead stream cannot block alarms forever.
wait_for_segment_after() {
    local target="$1" waited=0 limit=$((2 * SEGMENT_TIME + 10)) lines newest
    while [ "$waited" -lt "$limit" ]; do
        lines=$(list_segments)
        if [ -n "$lines" ]; then
            newest=$(printf '%s\n' "$lines" | sed '$d' | tail -n 1 | cut -d' ' -f1)
            if [ -n "$newest" ] && [ "${newest%.*}" -ge "$target" ]; then
                return 0
            fi
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

# Copy a source segment to an alarm file atomically (temp + mv), so the video
# publisher never observes a partially-written file.
copy_alarm_segment() {
    local src="$1" dst="$2"
    cp "$src" "${dst}.tmp" && mv "${dst}.tmp" "$dst"
}

do_work() {
    if ! [ -e "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM" ]; then # delay next execution only if no file is being processed at the moment
        log "Creating alarm"
        # Wait before taking snapshot (configurable delay)
        sleep "${SNAPSHOT_DELAY:-0}"
        # Make a snapshot photo, which will be sent to Telegram as is
        SNAPSHOT_TS=$(date +%s)
        curl --silent --insecure "${CAMERA_SNAPSHOT_URL}" -o "${FILE_PHOTO}.tmp"
        mv "${FILE_PHOTO}.tmp" "${FILE_PHOTO}" # this is needed to make sure that unfinished photo is not uploaded

        RECORDING_MODE="${RECORDING_MODE:-continuous}"

        if [ "$RECORDING_MODE" = "on-demand" ]; then
            # On-demand mode: start ffmpeg directly for 10 seconds
            ON_DEMAND_DURATION="${ON_DEMAND_DURATION:-10}"
            log "Starting on-demand recording for ${ON_DEMAND_DURATION}s"

            /usr/bin/ffmpeg -loglevel error -i rtsp://${CAMERA_USERNAME}:${CAMERA_PASSWORD}@${CAMERA_RTSP_URL} -an -c:v copy -t "$ON_DEMAND_DURATION" "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1-tmp$FILE_EXTENSION_ALARM"

            # Move temp file to final location
            mv "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1-tmp$FILE_EXTENSION_ALARM" "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM"
            log "On-demand recording completed"
        else
            # Continuous mode: the recorder continuously saves the fluent (sub)
            # stream in short segments, which show what happened before the
            # detection. Start a short 4K (main-stream) clip right away so it
            # captures what happens after the detection, then copy the finalized
            # fluent segments around the snapshot moment.
            CLIP_DURATION="${CLIP_DURATION:-10}"
            log "Starting ${CLIP_DURATION}s 4K clip"
            /usr/bin/ffmpeg -loglevel error \
              -i "rtsp://${CAMERA_USERNAME}:${CAMERA_PASSWORD}@${CAMERA_RTSP_URL}" \
              -an -c:v copy -t "$CLIP_DURATION" \
              "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-3-tmp$FILE_EXTENSION_ALARM" &
            CLIP_PID=$!

            # A segment file is only a valid, playable mp4 once ffmpeg has
            # closed it (the moov atom is written at close). Copying the segment
            # ffmpeg is still writing yields a corrupt file, so we first wait for
            # the segment that contains the snapshot to be finalized.
            if ! wait_for_segment_after "$SNAPSHOT_TS"; then
                log "No finalized recording segment for the snapshot; skipping video"
                wait "$CLIP_PID"
                rm -f "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-3-tmp$FILE_EXTENSION_ALARM"
                return
            fi

            mapfile -t segs < <(list_segments)

            # The segment that contains the snapshot is the first one that ends
            # at or after the snapshot time.
            idx=-1
            for i in "${!segs[@]}"; do
                end=${segs[$i]%% *}
                if [ "${end%.*}" -ge "$SNAPSHOT_TS" ]; then
                    idx=$i
                    break
                fi
            done
            [ "$idx" -lt 0 ] && idx=$(( ${#segs[@]} - 1 ))

            snapshot_seg="${segs[$idx]#* }"

            # File 1 always holds the segment that shows the snapshot moment.
            copy_alarm_segment "$snapshot_seg" "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-1$FILE_EXTENSION_ALARM"

            # File 2 holds the preceding segment (about 10s before the snapshot).
            if [ "$idx" -gt 0 ]; then
                copy_alarm_segment "${segs[$((idx - 1))]#* }" "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-2$FILE_EXTENSION_ALARM"
            fi

            # File 3 holds the 4K clip recorded from the detection moment.
            # Publish it once ffmpeg has finalized the file.
            wait "$CLIP_PID"
            mv "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-3-tmp$FILE_EXTENSION_ALARM" \
               "$ALARM_VIDEO_DIR/$FILE_NAME_ALARM-3$FILE_EXTENSION_ALARM"
        fi
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
    log "Graceful shutdown. Killing also Mosquitto pid ${MOSQUITTO_PID}"
    kill $MOSQUITTO_PID
    exit 0
}

trap 'handle_sig' EXIT

mkfifo mosquitto_pipe

while true  # Keep an infinite loop to reconnect when connection lost/broker unavailable
do
    mosquitto_sub -h $MQTT_HOST -u $MQTT_USERNAME -P $MQTT_PASSWORD -t $MQTT_QUEUE > mosquitto_pipe &
    MOSQUITTO_PID=$!

    while read -r payload
    do
        log "Processing received message"
        check_reset_interval
        do_work_throttled
    done < mosquitto_pipe
    sleep 10  # Wait 10 seconds until reconnection
done
