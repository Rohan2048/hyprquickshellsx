#!/usr/bin/env bash
# bt-scan-listener.sh — live "what does my machine actually see" bluetooth list.
# Emits one JSON array per line: [{name, mac, connected}, ...]
# Also caches the latest snapshot to disk so it survives a quickshell restart.
#
# Pairing itself is handled separately by bt-scan.sh's `pair <MAC>` action
# (unchanged from your eww setup — dunst passkey confirm, rofi PIN entry).
# This script only discovers + reports what's visible.
#
# Idle backoff: poll interval grows from 3s to 15s if results are unchanged,
# to avoid hammering bluetoothctl/the radio when nothing's actively watching.
#!/usr/bin/env bash
# bt-scan-listener.sh — bounded scan bursts instead of continuous scanning.

CACHE="$HOME/.config/quickshell/state/bt-scan.json"
RAW="/tmp/quickshell/bt_scan_raw"
mkdir -p "$(dirname "$CACHE")" /tmp/quickshell

# self-heal from any previously leaked scan state
bluetoothctl scan off >/dev/null 2>&1
bluetoothctl power on >/dev/null 2>&1

cleanup() { bluetoothctl scan off >/dev/null 2>&1; }
trap cleanup EXIT TERM INT

parse() {
    python3 - "$RAW" "${RAW}.connected" << 'PY'
import sys, re, json
devices_path, connected_path = sys.argv[1], sys.argv[2]
connected_macs = set()
try:
    connected_macs = set(re.findall(r'Device ([0-9A-F:]{17})', open(connected_path).read()))
except FileNotFoundError:
    pass
result = []
try:
    with open(devices_path) as f:
        for line in f:
            m = re.match(r'Device ([0-9A-F:]{17}) (.+)', line.strip())
            if not m: continue
            mac, name = m.group(1), m.group(2)
            result.append({'name': name, 'mac': mac, 'connected': mac in connected_macs})
except FileNotFoundError:
    pass
result.sort(key=lambda r: (not r['connected'], r['name'].lower()))
print(json.dumps(result))
PY
}

MIN_INTERVAL=3
MAX_INTERVAL=15
SCAN_BURST=2   # active discovery capped to 2s per cycle, was unbounded
interval=$MIN_INTERVAL
prev_out=""

while true; do
    # worst-case scanning time is now SCAN_BURST seconds, even if this
    # script gets killed mid-cycle — no more orphaned `scan on &`
    timeout "$SCAN_BURST" bluetoothctl scan on >/dev/null 2>&1
    bluetoothctl scan off >/dev/null 2>&1

    bluetoothctl devices > "$RAW" 2>/dev/null
    bluetoothctl devices Connected > "${RAW}.connected" 2>/dev/null
    OUT=$(parse)
    if [ -n "$OUT" ]; then
        echo "$OUT" > "$CACHE"
        echo "$OUT"
        if [ "$OUT" = "$prev_out" ]; then
            interval=$(( interval + 2 > MAX_INTERVAL ? MAX_INTERVAL : interval + 2 ))
        else
            interval=$MIN_INTERVAL
        fi
        prev_out="$OUT"
    fi
    sleep "$interval"
done
