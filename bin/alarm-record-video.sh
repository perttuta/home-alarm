#!/bin/bash

source /usr/bin/alarm-util.sh
# shellcheck source=../template.env
set -a; source "${ENV_FILE}"; set +a

# Ensure recording mode is set, default to continuous
RECORDING_MODE="${RECORDING_MODE:-continuous}"
# Length of each continuous segment in seconds
SEGMENT_TIME="${SEGMENT_TIME:-10}"
# Restart ffmpeg if no new segment appears within this many seconds
STALL_TIMEOUT="${STALL_TIMEOUT:-60}"

if [ "$RECORDING_MODE" != "continuous" ]; then
    log "On-demand recording mode - service not needed"
    exit 123
fi

FFMPEG_PID=""
FFMPEG_START=0
SLEEP_PID=""
STOPPING=0

stop_ffmpeg() {
    [ -n "$FFMPEG_PID" ] || return 0
    kill -TERM "$FFMPEG_PID" 2>/dev/null
    for _ in $(seq 1 10); do
        kill -0 "$FFMPEG_PID" 2>/dev/null || break
        sleep 1
    done
    kill -KILL "$FFMPEG_PID" 2>/dev/null
    wait "$FFMPEG_PID" 2>/dev/null
    FFMPEG_PID=""
}

cleanup() {
    STOPPING=1
    [ -n "$SLEEP_PID" ] && kill "$SLEEP_PID" 2>/dev/null
    stop_ffmpeg
}
trap cleanup EXIT INT TERM

start_ffmpeg() {
    log "Starting continuous video recording"
    # fd 9 (the singleton lock) is closed for ffmpeg, so the lock is tied to
    # this wrapper only and is released as soon as the wrapper exits.
    /usr/bin/ffmpeg -loglevel error \
      -i "rtsp://${CAMERA_USERNAME}:${CAMERA_PASSWORD}@${CAMERA_RTSP_URL}" \
      -an -c:v copy -map 0 -f segment -segment_time "$SEGMENT_TIME" \
      -segment_format mp4 \
      "${ALARM_VIDEO_DIR}/${ALARM_VIDEO_FILE_PREFIX}%04d.mp4" 9>&- &
    FFMPEG_PID=$!
    FFMPEG_START=$(date +%s)
}

# A new segment is written every SEGMENT_TIME seconds, so the newest segment
# acts as a heartbeat. Before the first segment exists, fall back to the time
# since ffmpeg was started.
is_stalled() {
    local newest now age
    newest=$(find "$ALARM_VIDEO_DIR" -maxdepth 1 \
        -name "${ALARM_VIDEO_FILE_PREFIX}*.mp4" -printf '%T@\n' \
        2>/dev/null | sort -n | tail -1)
    now=$(date +%s)
    if [ -n "$newest" ]; then
        age=$(( now - ${newest%.*} ))
    else
        age=$(( now - FFMPEG_START ))
    fi
    [ "$age" -gt "$STALL_TIMEOUT" ]
}

# Reap any ffmpeg left over from a previous leak or a manual run. The pattern
# only matches the output argument of our ffmpeg, not this wrapper.
reap_stray_ffmpeg() {
    local pattern="${ALARM_VIDEO_DIR}/${ALARM_VIDEO_FILE_PREFIX}%04d.mp4"
    pkill -TERM -f "$pattern" 2>/dev/null
    sleep 2
    pkill -KILL -f "$pattern" 2>/dev/null
}

# Singleton: only one recorder wrapper may run at a time. The lock is released
# automatically when this process exits, so a crash never leaves a stale lock.
exec 9>/run/alarm-record-video.lock
if ! flock -n 9; then
    log "Another recorder is already running; not starting"
    sleep 5
    exit 1
fi

reap_stray_ffmpeg
start_ffmpeg

while [ "$STOPPING" -eq 0 ]; do
    # fd 9 is closed for the sleep too, so it cannot hold the singleton lock
    # if this wrapper exits without reaping it.
    sleep "$SEGMENT_TIME" 9>&- &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null || true
    SLEEP_PID=""
    [ "$STOPPING" -eq 0 ] || break

    if ! kill -0 "$FFMPEG_PID" 2>/dev/null; then
        log "ffmpeg exited; restarting"
        FFMPEG_PID=""
        sleep 2
        start_ffmpeg
        continue
    fi

    if is_stalled; then
        log "No new segment for more than ${STALL_TIMEOUT}s; restarting ffmpeg"
        stop_ffmpeg
        sleep 2
        start_ffmpeg
    fi
done
