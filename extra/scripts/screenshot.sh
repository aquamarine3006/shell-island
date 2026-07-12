#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-region}"
SAVEDIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVEDIR"
# Append nanoseconds + PID so two screenshots taken in the same second
# don't silently overwrite each other. The previous second-precision
# filename collided on rapid presses of the PrintScreen keybind.
FILE="$SAVEDIR/$(date +%Y-%m-%d_%H-%M-%S)_${EPOCHREALTIME#*.}_$$.png"

case "$MODE" in
  region) grim -g "$(slurp)" "$FILE" && satty --filename "$FILE" ;;
  full)   grim "$FILE" && satty --filename "$FILE" ;;
  window) grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$FILE" && satty --filename "$FILE" ;;
  *) echo "unknown mode: $MODE" >&2; exit 1 ;;
esac
