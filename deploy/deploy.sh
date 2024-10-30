#!/bin/bash

# exit on error
set -e

# Install packages
apt update
apt install -y curl supervisor ffmpeg mosquitto-clients jq git
timedatectl set-timezone "Europe/Helsinki"

# Create directories
echo Creating directories
# TODO: Assuming here that the default directory is actually used. This is bad, because it would be better to read it from configuration
mkdir /var/cache/alarm-video

# Copy scripts
echo Copying files
cp bin/alarm-util.sh /usr/bin
cp bin/alarm-delete-video.sh /usr/bin
cp bin/alarm-mqtt-action.sh /usr/bin
cp bin/alarm-publish-photo-action.sh /usr/bin
cp bin/alarm-publish-video-action.sh /usr/bin
cp bin/alarm-record-video.sh /usr/bin

chmod ugo+x /usr/bin/alarm-*.sh

# Configure supervisor
echo Configuring supervisor
cp supervisor/alarm-delete-video.conf /etc/supervisor/conf.d
cp supervisor/alarm-record-video.conf /etc/supervisor/conf.d
cp supervisor/alarm-publish-video.conf /etc/supervisor/conf.d
cp supervisor/alarm-extract-video.conf /etc/supervisor/conf.d
cp supervisor/alarm-publish-photo.conf /etc/supervisor/conf.d

# Add environment, which points to file consisting of all needed env configs. This should be done only once!
grep -q "environment=" /etc/supervisor/supervisord.conf ||  sed -i -e "s#\[supervisord\]#\[supervisord\]\nenvironment=ENV_FILE=/root/alarm.env#" /etc/supervisor/supervisord.conf

echo All done!