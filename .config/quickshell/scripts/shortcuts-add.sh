#!/usr/bin/env bash
FILE="$HOME/.config/quickshell/state/shortcuts.json"
mkdir -p "$(dirname "$FILE")"
[ ! -s "$FILE" ] && echo "[]" > "$FILE"

ICONS_DIR="$HOME/.config/quickshell/icons"
mkdir -p "$ICONS_DIR"

# --- Prevent concurrent runs from truncating/corrupting the shared cache ---
LOCK_FD=9
exec 9>"$ICONS_DIR/.shortcuts-add.lock"
if ! flock -n 9; then
  notify-send "Shortcuts" "Already scanning — hang tight, rofi will pop up shortly"
  exit
fi

COUNT=$(python3 -c "import json,sys
try:
    print(len(json.load(open('$FILE'))))
except Exception:
    print(0)")
[ "$COUNT" -ge 10 ] && notify-send "Shortcuts" "Maximum 10 shortcuts reached" && exit

CACHE_STAMP="$ICONS_DIR/.last_scan"
APP_CACHE="$ICONS_DIR/.app_cache.tsv"  # name\tdesktop_path\ticon_path

ICON_DIRS=(
  "/usr/share/icons/Papirus/48x48/apps"
  "/usr/share/icons/Papirus-Dark/48x48/apps"
  "/usr/share/icons/Papirus-Light/48x48/apps"
  "/usr/share/icons/hicolor/48x48/apps"
  "/usr/share/icons/hicolor/64x64/apps"
  "/usr/share/icons/hicolor/128x128/apps"
  "/usr/share/icons/hicolor/256x256/apps"
  "/usr/share/icons/hicolor/scalable/apps"
  "/usr/share/icons/Adwaita/48x48/apps"
  "/usr/share/icons/Adwaita/scalable/apps"
  "/usr/share/icons/breeze/apps/48"
  "/usr/share/icons/breeze-dark/apps/48"
  "/usr/share/icons/gnome/48x48/apps"
  "/usr/share/icons/oxygen/base/48x48/apps"
  "/usr/share/pixmaps"
  "$HOME/.local/share/icons/hicolor/48x48/apps"
  "$HOME/.local/share/icons/hicolor/scalable/apps"
  "$HOME/.local/share/icons"
  "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps"
  "/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps"
  "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps"
  "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps"
  "$HOME/.local/share/flatpak/exports/share/icons/hicolor/48x48/apps"
  "$HOME/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps"
  "/usr/share/icons/hicolor"
  "/usr/share/icons"
)

# Memoize icon lookups within this run so repeated icon names (many apps
# share the same generic icon) don't re-walk the filesystem each time.
declare -A RESOLVED_CACHE

resolve_icon() {
  local ICON="$1"
  if [ -n "${RESOLVED_CACHE[$ICON]+x}" ]; then
    echo "${RESOLVED_CACHE[$ICON]}"
    return
  fi
  local RESULT=""
  if [ -f "$ICON" ]; then
    RESULT="$ICON"
  else
    for DIR in "${ICON_DIRS[@]}"; do
      [ ! -d "$DIR" ] && continue
      for EXT in png svg xpm; do
        if [ -f "$DIR/$ICON.$EXT" ]; then
          RESULT="$DIR/$ICON.$EXT"
          break 2
        fi
      done
    done
  fi
  if [ -z "$RESULT" ]; then
    for BASE in /usr/share/icons /usr/share/pixmaps \
      "$HOME/.local/share/icons" \
      /var/lib/flatpak/exports/share/icons \
      "$HOME/.local/share/flatpak/exports/share/icons"; do
      [ ! -d "$BASE" ] && continue
      # timeout guards against pathologically large icon themes stalling
      # the whole scan on a single unresolved icon name.
      FOUND=$(timeout 2 find "$BASE" -type f \( -name "${ICON}.png" -o -name "${ICON}.svg" -o -name "${ICON}.xpm" \) 2>/dev/null | sort | head -1)
      if [ -n "$FOUND" ]; then
        RESULT="$FOUND"
        break
      fi
    done
  fi
  RESOLVED_CACHE["$ICON"]="$RESULT"
  echo "$RESULT"
}

cache_icon() {
  local ICON_PATH="$1"
  local ICON_SAFE="$2"
  local OUT="$ICONS_DIR/${ICON_SAFE}.png"
  [ -f "$OUT" ] && echo "$OUT" && return 0
  if [[ "$ICON_PATH" == *.svg ]]; then
    command -v rsvg-convert &>/dev/null && rsvg-convert -w 48 -h 48 "$ICON_PATH" -o "$OUT" 2>/dev/null && echo "$OUT" && return 0
    command -v convert &>/dev/null && convert -background none -resize 48x48 "$ICON_PATH" "$OUT" 2>/dev/null && echo "$OUT" && return 0
    command -v inkscape &>/dev/null && inkscape --export-type=png --export-width=48 --export-height=48 --export-filename="$OUT" "$ICON_PATH" 2>/dev/null && echo "$OUT" && return 0
  elif [[ "$ICON_PATH" == *.xpm ]]; then
    command -v convert &>/dev/null && convert "$ICON_PATH" -resize 48x48 "$OUT" 2>/dev/null && echo "$OUT" && return 0
  else
    command -v convert &>/dev/null && convert "$ICON_PATH" -resize 48x48 "$OUT" 2>/dev/null && echo "$OUT" && return 0
    [[ "$ICON_PATH" == *.png ]] && cp "$ICON_PATH" "$OUT" && echo "$OUT" && return 0
  fi
  return 1
}

# --- Scan check ---

SCAN_NEEDED=false
{ [ ! -f "$CACHE_STAMP" ] || [ ! -s "$APP_CACHE" ]; } && SCAN_NEEDED=true

if ! $SCAN_NEEDED; then
  CHANGED=$(find /usr/share/applications "$HOME/.local/share/applications" \
    /var/lib/flatpak/exports/share/applications \
    "$HOME/.local/share/flatpak/exports/share/applications" \
    /var/lib/snapd/desktop/applications \
    -maxdepth 1 -name "*.desktop" -newer "$CACHE_STAMP" 2>/dev/null | wc -l)
  [ "$CHANGED" -gt 0 ] && SCAN_NEEDED=true
fi

# --- Rebuild TSV cache only when needed ---

if $SCAN_NEEDED; then
  notify-send "Shortcuts" "Scanning applications…" -t 3000

  TMP_CACHE="${APP_CACHE}.building"
  > "$TMP_CACHE"

  for DIR in \
    /usr/share/applications \
    /usr/local/share/applications \
    "$HOME/.local/share/applications" \
    /var/lib/flatpak/exports/share/applications \
    "$HOME/.local/share/flatpak/exports/share/applications" \
    /var/lib/snapd/desktop/applications; do
    [ ! -d "$DIR" ] && continue
    while IFS= read -r -d '' DFILE; do
      NAME=$(grep -m1 "^Name=" "$DFILE" | cut -d= -f2-)
      [ -z "$NAME" ] && continue
      [ "$(grep -m1 "^NoDisplay=" "$DFILE" | cut -d= -f2-)" = "true" ] && continue
      [ "$(grep -m1 "^Hidden=" "$DFILE" | cut -d= -f2-)" = "true" ] && continue

      APP_ICON=$(grep -m1 "^Icon=" "$DFILE" | cut -d= -f2-)
      CACHED_ICON=""

      if [ -n "$APP_ICON" ]; then
        ICON_SAFE=$(echo "$APP_ICON" | tr '/' '_' | tr ' ' '_')
        CACHED="$ICONS_DIR/${ICON_SAFE}.png"
        if [ ! -f "$CACHED" ]; then
          ICON_PATH=$(resolve_icon "$APP_ICON")
          [ -n "$ICON_PATH" ] && cache_icon "$ICON_PATH" "$ICON_SAFE" >/dev/null
        fi
        [ -f "$CACHED" ] && CACHED_ICON="$CACHED"
      fi

      # Skip if name contains tab (would break TSV)
      [[ "$NAME" == *$'\t'* ]] && continue
      printf '%s\t%s\t%s\n' "$NAME" "$DFILE" "$CACHED_ICON" >> "$TMP_CACHE"
    done < <(find "$DIR" -maxdepth 1 -name "*.desktop" -print0 2>/dev/null)
  done

  # Deduplicate by name, keep last (user entries override system)
  awk -F'\t' '!seen[$1]++' "$TMP_CACHE" > "${TMP_CACHE}.deduped" && mv "${TMP_CACHE}.deduped" "$TMP_CACHE"

  # Atomic swap — readers never see a half-written cache file.
  mv "$TMP_CACHE" "$APP_CACHE"
  touch "$CACHE_STAMP"
fi

# --- Load cache into maps (fast, no disk scan) ---

declare -A DESKTOP_MAP
declare -A ICON_MAP

while IFS=$'\t' read -r NAME DFILE ICON; do
  DESKTOP_MAP["$NAME"]="$DFILE"
  [ -n "$ICON" ] && ICON_MAP["$NAME"]="$ICON"
done < "$APP_CACHE"

if [ "${#DESKTOP_MAP[@]}" -eq 0 ]; then
  notify-send "Shortcuts" "No applications found — check $APP_CACHE"
  rm -f "$CACHE_STAMP"  # force a rescan next time instead of staying stuck empty
  exit 1
fi

# --- Rofi picker ---

CHOSEN=$(
  printf '%s\n' "${!DESKTOP_MAP[@]}" | sort | while IFS= read -r NAME; do
    if [ -n "${ICON_MAP[$NAME]}" ]; then
      printf '%s\0icon\x1f%s\n' "$NAME" "${ICON_MAP[$NAME]}"
    else
      printf '%s\n' "$NAME"
    fi
  done | rofi -dmenu -p "Add Shortcut" -i -show-icons -format s
)

[ -z "$CHOSEN" ] && exit

DESKTOP_PATH="${DESKTOP_MAP[$CHOSEN]}"
[ -z "$DESKTOP_PATH" ] && notify-send "Shortcuts" "No .desktop found for: $CHOSEN" && exit

APP_NAME=$(grep -m1 "^Name=" "$DESKTOP_PATH" | cut -d= -f2-)
APP_EXEC=$(grep -m1 "^Exec=" "$DESKTOP_PATH" | cut -d= -f2- | sed 's/ %[a-zA-Z]//g')
APP_ICON=$(grep -m1 "^Icon=" "$DESKTOP_PATH" | cut -d= -f2-)

ICON_SAFE=$(echo "$APP_ICON" | tr '/' '_' | tr ' ' '_')
CACHED_ICON="$ICONS_DIR/${ICON_SAFE}.png"

[ ! -f "$CACHED_ICON" ] && notify-send "Shortcuts" "Icon missing for $APP_NAME — install imagemagick or librsvg2-tools" && exit

ID=$(date +%s%N)

if ! python3 - <<PYEOF
import json, sys
try:
    with open('$FILE') as f:
        data = json.load(f)
except Exception:
    data = []
data.append({
    'id': '$ID',
    'name': '$APP_NAME',
    'exec': '$APP_EXEC',
    'icon': '$CACHED_ICON'
})
with open('$FILE', 'w') as f:
    json.dump(data, f, indent=2)
PYEOF
then
  notify-send "Shortcuts" "Failed to write $FILE — check permissions"
  exit 1
fi

notify-send "Shortcuts" "Added: $APP_NAME"
# No eww update call needed — QuickShell's FileView watches shortcuts.json
# directly and picks up this write on its own.
