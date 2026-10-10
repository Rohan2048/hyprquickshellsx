#!/bin/bash

CHOICES="  Shutdown\n  Reboot\n  Suspend\n  Lock\n  Logout"

CHOICE=$(echo -e "$CHOICES" | rofi -dmenu \
    -theme ~/.config/rofi/powermenu.rasi \
    -p "" \
    -lines 5 \
    -no-custom)

case "$CHOICE" in
  *Shutdown) systemctl poweroff ;;
  *Reboot)   systemctl reboot ;;
  *Suspend)  ~/.config/quickshell/scripts/lock-then-suspend ;;
  *Lock)     qs ipc call lock lock ;;
  *Logout)   loginctl terminate-session "$XDG_SESSION_ID" ;;
esac
