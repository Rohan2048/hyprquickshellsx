#!/bin/bash
# bt-history.sh — names only storage, MAC resolved dynamically

HIST="$HOME/.config/quickshell/state/bt-history.json"
PIDFILE="$HOME/.config/quickshell/state/bt-history.pid"
mkdir -p "$(dirname "$HIST")"

if [ ! -f "$HIST" ] || ! python3 -c "import json; json.load(open('$HIST'))" 2>/dev/null; then
    echo '[]' > "$HIST"
fi

normalize() {
    echo "$1" | sed 's/ *$//'
}

update_device() {
    NAME="$1"
    [ -z "$NAME" ] && return
    NAME=$(normalize "$NAME")
    python3 - "$HIST" "$NAME" << 'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
    if isinstance(data, list) and data and isinstance(data[0], dict):
        data = [x.get("name", "") for x in data if x.get("name")]
except:
    data = []
if name in data:
    data.remove(name)
data.insert(0, name)
data = data[:10]
with open(path, 'w') as f:
    json.dump(data, f)
PY
}

# NEW — removes a name from the history file. Used by forget_device below.
remove_from_history() {
    NAME="$1"
    [ -z "$NAME" ] && return
    NAME=$(normalize "$NAME")
    python3 - "$HIST" "$NAME" << 'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
    if isinstance(data, list) and data and isinstance(data[0], dict):
        data = [x.get("name", "") for x in data if x.get("name")]
except:
    data = []
if name in data:
    data.remove(name)
with open(path, 'w') as f:
    json.dump(data, f)
PY
}

list_devices() {
    python3 - "$HIST" << 'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    if isinstance(data, list) and data and isinstance(data[0], dict):
        data = [x.get("name", "") for x in data if x.get("name")]
except:
    data = []
print(json.dumps([{"name": x} for x in data]))
PY
}

get_mac_from_name() {
    bluetoothctl devices | grep -F "$1" | awk '{print $2; exit}'
}

connect_device() {
    MAC=$(get_mac_from_name "$1")
    [ -n "$MAC" ] && bluetoothctl connect "$MAC" &>/dev/null &
}

disconnect_device() {
    MAC=$(get_mac_from_name "$1")
    [ -n "$MAC" ] && bluetoothctl disconnect "$MAC" &>/dev/null &
}

# NEW — actually clears the entry from history.json, then nudges the
# running monitor (long-running `bash bt-history.sh`, no args — the one
# Bluetooth.qml's `_proc` is subscribed to) to re-emit immediately via
# SIGUSR1, instead of waiting for a PropertiesChanged signal that
# device-removal never fires.
forget_device() {
    NAME="$1"
    MAC=$(get_mac_from_name "$NAME")
    [ -n "$MAC" ] && bluetoothctl remove "$MAC" &>/dev/null
    remove_from_history "$NAME"
    if [ -f "$PIDFILE" ]; then
        kill -USR1 "$(cat "$PIDFILE")" 2>/dev/null
    fi
}

case "$1" in
    list)       list_devices;           exit ;;
    update)     update_device "$2";     exit ;;
    connect)    connect_device "$2";    exit ;;
    disconnect) disconnect_device "$2"; exit ;;
    forget)     forget_device "$2";     exit ;;
esac

# --------------------------
# MONITOR — D-Bus subscriber
# Emits {"device":"...","history":[...]} to stdout on startup and on every
# connection change. deflisten binds directly to this stdout stream —
# no cache file, no polling, no while loop.
# Requires: python3-dbus (python3-dbus package)
# --------------------------

echo $$ > "$PIDFILE"

# `exec` replaces this bash process with python3 in-place, keeping the same
# PID — required so the PID written above still points at the process that
# actually receives SIGUSR1 below (otherwise it'd be bash's PID, and bash
# would just be sitting there waiting on python3 as a child, never seeing
# the signal itself).
exec python3 - "$HIST" << 'PY'
import sys, json, signal, dbus, dbus.mainloop.glib
from gi.repository import GLib

HIST = sys.argv[1]

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()

def get_connected_name():
    try:
        mgr = dbus.Interface(
            bus.get_object('org.bluez', '/'),
            'org.freedesktop.DBus.ObjectManager'
        )
        for path, ifaces in mgr.GetManagedObjects().items():
            dev = ifaces.get('org.bluez.Device1', {})
            if dev.get('Connected') and dev.get('Name'):
                return str(dev['Name']).rstrip()
    except Exception:
        pass
    try:
        import subprocess
        out = subprocess.check_output(
            ['rfkill', 'list', 'bluetooth'], text=True
        )
        if 'Soft blocked: no' in out:
            return 'Bluetooth-ON'
    except Exception:
        pass
    return 'Bluetooth-OFF'

def load_history():
    try:
        with open(HIST) as f:
            data = json.load(f)
        if data and isinstance(data[0], dict):
            data = [x.get('name', '') for x in data if x.get('name')]
        return [{"name": x} for x in data]
    except Exception:
        return []

def update_history(name):
    if not name or name in ('Bluetooth-OFF', 'Bluetooth-ON'):
        return
    try:
        with open(HIST) as f:
            data = json.load(f)
        if data and isinstance(data[0], dict):
            data = [x.get('name', '') for x in data if x.get('name')]
    except Exception:
        data = []
    if name in data:
        data.remove(name)
    data.insert(0, name)
    data = data[:10]
    with open(HIST, 'w') as f:
        json.dump(data, f)

def emit(device):
    print(json.dumps({"device": device, "history": load_history()}), flush=True)

def on_properties_changed(interface, changed, invalidated, path=None):
    if interface == 'org.bluez.Adapter1' and 'Powered' in changed:
        if changed['Powered']:
            emit(get_connected_name())
        else:
            emit('Bluetooth-OFF')
        return
    if interface == 'org.bluez.Device1' and 'Connected' in changed:
        name = get_connected_name()
        update_history(name)
        emit(name)

# NEW — forget_device() in the bash script above already rewrote HIST and
# sent us SIGUSR1. This just re-reads the file it edited and re-emits, so
# QML's history array updates immediately instead of only on the next
# incidental connect/disconnect.
def on_sigusr1():
    emit(get_connected_name())
    return GLib.SOURCE_CONTINUE

GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, on_sigusr1)

current = get_connected_name()
update_history(current)
emit(current)

bus.add_signal_receiver(
    on_properties_changed,
    signal_name='PropertiesChanged',
    dbus_interface='org.freedesktop.DBus.Properties',
    bus_name=None,
    path_keyword='path'
)

GLib.MainLoop().run()
PY
