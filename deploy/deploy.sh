#!/bin/bash
apt update
apt install -y curl supervisor ffmpeg mosquitto-clients jq git
timedatectl set-timezone "Europe/Helsinki"
