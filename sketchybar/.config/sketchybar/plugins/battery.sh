#!/usr/bin/env bash

PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

# Battery level glyphs from Hack Nerd Font
case ${PERCENTAGE} in
  9[0-9]|100) ICON="󰁹" ;;
  [6-8][0-9]) ICON="󰂀" ;;
  [3-5][0-9]) ICON="󰁾" ;;
  [1-2][0-9]) ICON="󰁼" ;;
  *)          ICON="󰂃" ;;
esac

# Override with charging bolt if plugged in
if [[ "$CHARGING" != "" ]]; then
  ICON="󰂄"
fi

# Ensure icon drawing is explicitly enabled and update bar
sketchybar --set $NAME icon.drawing=on icon="$ICON" label="${PERCENTAGE}%"