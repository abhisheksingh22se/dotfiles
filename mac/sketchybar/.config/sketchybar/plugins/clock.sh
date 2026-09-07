#!/usr/bin/env bash

# Formats date as: Sun Aug 16, 22:53
DATE_TIME=$(date "+%a %b %d, %H:%M")

sketchybar --set $NAME label="$DATE_TIME" icon.drawing=off