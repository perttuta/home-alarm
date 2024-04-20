#!/bin/bash

# Specify the directory path
directory="/var/cache/alarm-video"

while true; do
  # Find files older than 10 minutes and delete them
  find "$directory" -type f -mmin +10 -exec rm -f {} \;
  sleep 600
done
