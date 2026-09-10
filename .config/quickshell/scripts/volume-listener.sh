#!/usr/bin/env bash
# volume-listener.sh — emits {volume, muted, sink, sinks, label} JSON
# driven by pactl subscribe

mkdir -p /tmp/quickshell

# ── Sink list cache ───────────────────────────────────────────────────────
# Re-fetching pactl list sinks on every volume event is expensive.
# We cache it and only refresh when a sink add/remove/server event fires,
# not on every volume/mute change (which is the common case).

_refresh_sinks_cache() {
    pactl list sinks 2>/dev/null | awk -F': ' '
    /Description/ {
        desc=$2
        gsub(/^ +| +$/,"",desc)
        gsub(/"/,"",desc)
        printf "%s\"%s\"", sep, desc
        sep=","
    }
    END { print "" }' | awk '{print "["$0"]"}' > /tmp/quickshell/sinks_cache
}

# Warm up on start if not already done (preload.sh may have done this)
[ ! -f /tmp/quickshell/sinks_cache ] && _refresh_sinks_cache

emit() {
    RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
    VOL=$(echo "$RAW" | awk '{printf "%d", $2*100}')
    MUTED=false
    LABEL="ON"
    if echo "$RAW" | grep -q MUTED; then
        MUTED=true
        LABEL="MUTED"
    fi

    DEFAULT=$(pactl get-default-sink)
    SINK=$(pactl list sinks 2>/dev/null \
        | grep -A15 "Name: $DEFAULT" \
        | grep 'Description:' | head -n1 \
        | cut -d: -f2- | xargs)
    SINK=${SINK:-Unknown}
    echo "$SINK" > /tmp/quickshell/active_sink

    # Use cached sink list — avoid re-running pactl list sinks
    SINKS=$(cat /tmp/quickshell/sinks_cache 2>/dev/null || echo "[]")

    printf '{"volume":%s,"muted":%s,"label":"%s","sink":"%s","sinks":%s}\n' \
        "$VOL" "$MUTED" "$LABEL" "$SINK" "$SINKS"
}

emit

LAST_EMIT=0
while IFS= read -r EVENT; do
    NOW=$(date +%s%3N)
    if (( NOW - LAST_EMIT > 100 )); then
        LAST_EMIT=$NOW

        # Refresh sink list only when device topology changes, not on volume events
        if echo "$EVENT" | grep -qE "sink #|server"; then
            _refresh_sinks_cache
        fi

        emit
    fi
done < <(pactl subscribe 2>/dev/null | grep --line-buffered -E "sink|server")
