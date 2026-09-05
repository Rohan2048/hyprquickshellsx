pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth.qml — event-driven via scripts/bt-history.sh (unchanged, the
// python3-dbus GLib mainloop script from your eww deflisten BT_STATE).
// Bar-level state only for now (connected device name + on/off) —
// BluetoothPopup.qml with the paired-devices list is the next thing to port.
QtObject {
    id: root

    property string device: "Bluetooth-OFF"
    property var history: []

    readonly property bool radioOn: device !== "Bluetooth-OFF"
    readonly property bool connected: radioOn && device !== "Bluetooth-ON"

    // Gear icon next to the ON/OFF toggle — reveals this live list.
    property bool liveMode: false
    function toggleLiveMode() { liveMode = !liveMode }
    property var scanList: [] // [{name, mac, connected}, ...] while liveMode is on

    // ---- In-app pairing agent ----
    // Replaces bt-scan.sh's old `pair` flow (which shelled out to dunstify for
    // passkey confirm and rofi for PIN entry — fragile, and blocked entirely
    // if a notification was already on screen). This talks to a persistent
    // interactive `bluetoothctl` process directly, so confirm/PIN happen as
    // normal QML UI in the popup instead.
    property string pairingMac: ""
    property string pairingName: ""
    property string pairError: ""
    // { code: "123456" } when bluetoothctl needs a yes/no passkey confirmation
    property var pendingConfirm: null
    // {} when bluetoothctl needs a PIN typed in
    property var pendingPin: null

    function startPair(mac, name) {
        pairingMac = mac
        pairingName = name
        pairError = ""
        pendingConfirm = null
        pendingPin = null
        _agent.write("pair " + mac + "\n")
    }
    function confirmYes() {
        _agent.write("yes\n")
        pendingConfirm = null
    }
    function confirmNo() {
        _agent.write("no\n")
        pendingConfirm = null
        pairError = "Pairing rejected for " + pairingName
    }
    function submitPin(pin) {
        _agent.write(pin + "\n")
        pendingPin = null
    }
    function dismissError() { pairError = "" }

    function _handleAgentLine(line) {
        let m
        if ((m = line.match(/Confirm passkey (\d+)/))) {
            pendingConfirm = { code: m[1] }
        } else if (/Request PIN code|Enter PIN code/i.test(line)) {
            pendingPin = {}
        } else if (/Pairing successful/i.test(line)) {
            pendingConfirm = null
            pendingPin = null
            _agent.write("trust " + pairingMac + "\n")
            _agent.write("connect " + pairingMac + "\n")
        } else if (/already paired/i.test(line)) {
            pendingConfirm = null
            pendingPin = null
            _agent.write("trust " + pairingMac + "\n")
            _agent.write("connect " + pairingMac + "\n")
        } else if (/Failed to pair|AuthenticationFailed|AuthenticationCanceled|org\.bluez\.Error/i.test(line)) {
            pendingConfirm = null
            pendingPin = null
            pairError = "Pairing failed with " + pairingName
        } else if (/Connection successful/i.test(line)) {
            pairError = ""
        }
    }

    property Process _agent: Process {
        id: agentProc
        command: ["stdbuf", "-oL", "bluetoothctl"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root._handleAgentLine(line)
        }
        onExited: agentRestart.start()
    }
    property Timer agentRestart: Timer {
        interval: 1000
        onTriggered: root._agent.running = true
    }
    // Register as the pairing agent once bluetoothctl is up.
    property Timer agentInit: Timer {
        interval: 500
        running: true
        onTriggered: root._agent.write("agent KeyboardDisplay\ndefault-agent\n")
    }

    function toggleRadio() {
        Quickshell.execDetached(["bash", "-c",
                                "if rfkill list bluetooth | grep -q 'Soft blocked: no'; then rfkill block bluetooth; else rfkill unblock bluetooth; fi"])
    }

    function scriptPath(name) {
        return Quickshell.env("HOME") + "/.config/quickshell/scripts/" + name
    }

    function connectTo(name) {
        Quickshell.execDetached(["bash", scriptPath("bt-history.sh"), "connect", name])
    }
    function disconnect(name) {
        Quickshell.execDetached(["bash", scriptPath("bt-history.sh"), "disconnect", name])
    }
    function forget(name) {
        Quickshell.execDetached(["bash", scriptPath("bt-history.sh"), "forget", name])
    }

    property Process _proc: Process {
        command: ["bash", root.scriptPath("bt-history.sh")]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line.trim().length) return
                    try {
                        const data = JSON.parse(line)
                        root.device = data.device ?? root.device
                        root.history = data.history ?? root.history
                    } catch (e) {
                        console.warn("Bluetooth: bad JSON from bt-history.sh:", line)
                    }
            }
        }
        onExited: restartTimer.start()
    }

    property Timer restartTimer: Timer {
        interval: 1000
        onTriggered: root._proc.running = true
    }

    // Live scan — only runs while the gear icon has liveMode toggled on.
    property Process _scanProc: Process {
        running: root.liveMode
        command: ["bash", root.scriptPath("bt-scan-listener.sh")]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line.trim().length) return
                    try {
                        root.scanList = JSON.parse(line)
                    } catch (e) {
                        console.warn("Bluetooth: bad JSON from bt-scan-listener.sh:", line)
                    }
            }
        }
    }
}
