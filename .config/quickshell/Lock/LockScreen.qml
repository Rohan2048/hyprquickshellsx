import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../Theme"
import "../Widgets"
import "../Services"
Scope {
    id: root

    // ---- inlined LockContext state (was a separate QtObject) ----
    property string currentText: ""
    property bool unlocking: false
    property bool failed: false
    property bool actionPrompt: false      // true briefly when a power action was clicked with no password typed
    property var pendingAction: null
    property var confirmAction: null
    property string confirmActionName: ""

    // Hyprland-only: this lock config gets loaded under other DEs too, and
    // we don't want to force-suspend those sessions. Gated on
    // HYPRLAND_INSTANCE_SIGNATURE, which is only set when Hyprland is the
    // running compositor.
    readonly property bool isHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE").length > 0

    // Idle-tracking baseline for auto-suspend. -1 means "no baseline yet",
    // so the first position event after a lock (or after a resume) just
    // records a baseline instead of counting as movement (avoids a
    // spurious synthetic hover-enter event resetting the timer
    // immediately every time).
    property real lastCursorX: -1
    property real lastCursorY: -1
    readonly property real idleMoveThreshold: 4

    onCurrentTextChanged: if (currentText.length > 0) actionPrompt = false

    Timer {
        id: confirmActionTimer
        interval: 4000
        onTriggered: {
            root.confirmAction = null
            root.confirmActionName = ""
        }
    }

    Timer {
        id: actionPromptTimer
        interval: 2200
        onTriggered: {
            root.actionPrompt = false
        }
    }

    PamContext {
        id: pam

        onCompleted: (result) => {
            console.warn("[lock] PAM completed with result:", result)
            root.unlocking = false
            if (result === PamResult.Success) {
                console.warn("[lock] PAM Success")
                if (root.pendingAction) {
                    console.warn("[lock] running pendingAction instead of unlocking")
                    const action = root.pendingAction
                    root.pendingAction = null
                    root.currentText = ""
                    action()
                } else {
                    console.warn("[lock] unlocking")
                    lock.locked = false
                }
            } else {
                console.warn("[lock] PAM failed/error, result:", result)
                root.failed = true
                root.currentText = ""
                root.pendingAction = null
            }
        }

        onError: (err) => {
            console.warn("[lock] PAM error:", err)
            root.unlocking = false
            root.failed = true
            root.pendingAction = null
        }

        onPamMessage: {
            console.warn("[lock] PAM message:", pam.message, "responseRequired:", pam.responseRequired)
            if (pam.responseRequired) {
                console.warn("[lock] PAM requesting response, sending currentText")
                pam.respond(root.currentText)
            }
        }
    }

    function tryUnlock() {
        console.warn("[lock] tryUnlock() called, unlocking:", unlocking, "textLen:", currentText.length)
        if (unlocking || currentText.length === 0) {
            console.warn("[lock] tryUnlock() bailed early")
            return
        }
        failed = false
        unlocking = true
        const started = pam.start()
        console.warn("[lock] pam.start() returned:", started)
    }

    function authenticate(action, name) {
        console.warn("[lock] authenticate() called, unlocking:", unlocking, "textLen:", currentText.length)
        if (currentText.length === 0) {
            console.warn("[lock] authenticate() blocked - no password entered, showing prompt")
            failed = false
            pendingAction = action
            actionPrompt = true
            actionPromptTimer.restart()
            return
        }
        if (unlocking) {
            console.warn("[lock] authenticate() bailed early - already unlocking")
            return
        }
        if (confirmActionName === name) {
            console.warn("[lock] action confirmed, proceeding")
            confirmAction = null
            confirmActionName = ""
            confirmActionTimer.stop()
            failed = false
            actionPrompt = false
            pendingAction = action
            unlocking = true
            const started = pam.start()
            console.warn("[lock] pam.start() returned:", started)
            return
        }
        console.warn("[lock] action requires confirmation - waiting for second click")
        confirmAction = action
        confirmActionName = name
        confirmActionTimer.restart()
    }

    function cancelPendingAction() {
        console.warn("[lock] cancelPendingAction() called")
        pendingAction = null
        actionPrompt = false
        confirmAction = null
        confirmActionName = ""
        confirmActionTimer.stop()
    }

    function resetLock() {
        currentText = ""
        failed = false
        actionPrompt = false
        pendingAction = null
        confirmAction = null
        confirmActionName = ""
        confirmActionTimer.stop()
        if (pam.active) pam.abort()
    }

    FileView {
        id: unlockTokenFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/lock-unlock-token"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }

    function remoteUnlock(token) {
        const expected = unlockTokenFile.text().trim()
        if (expected.length === 0) {
            console.warn("[lock] remoteUnlock() rejected - no token file configured")
            return
        }
        if (typeof token !== "string" || token.length === 0 || token !== expected) {
            console.warn("[lock] remoteUnlock() rejected - token mismatch")
            return
        }
        console.warn("[lock] remoteUnlock() accepted")
        root.failed = false
        root.currentText = ""
        root.pendingAction = null
        root.unlocking = false
        if (pam.active) pam.abort()
            lock.locked = false
    }

    Timer {
        id: autoSuspendTimer
        interval: 30000
        repeat: false
        onTriggered: {
            console.warn("[lock] auto-suspend timer fired after", interval, "ms idle")
            autoSuspendProc.running = true
        }
    }

    function startAutoSuspendIfNeeded() {
        root.lastCursorX = -1
        root.lastCursorY = -1
        if (root.isHyprland) {
            console.warn("[lock] starting auto-suspend idle countdown")
            autoSuspendTimer.restart()
        } else {
            console.warn("[lock] non-Hyprland DE - auto-suspend disabled")
        }
    }

    Process {
        id: autoSuspendProc
        command: ["systemctl", "suspend"]
        stderr: SplitParser {
            onRead: (line) => console.warn("[lock] auto-suspend stderr:", line)
        }
        onExited: (exitCode, exitStatus) => {
            console.warn("[lock] auto-suspend systemctl exited (resumed), code:", exitCode, "status:", exitStatus)
            if (lock.locked) {
                console.warn("[lock] still locked after resume - restarting idle countdown")
                root.startAutoSuspendIfNeeded()
            }
        }
    }
    // ---- end auto-suspend ----

    // ---- pre-lock screenshot capture ----
    property int pendingCaptures: 0

    Component {
        id: captureComponent
        Process {
            property string screenName
            command: ["grim", "-o", screenName, "/tmp/quickshell-lockshot-" + screenName + ".png"]
            stderr: SplitParser {
                onRead: (line) => console.warn("[lock] grim stderr for", screenName, ":", line)
            }
            onExited: (exitCode, exitStatus) => {
                console.warn("[lock] pre-capture done for", screenName, "exit:", exitCode)
                root.pendingCaptures--
                if (root.pendingCaptures <= 0) {
                    lock.locked = true
                    root.startAutoSuspendIfNeeded()
                }
                destroy()
            }
        }
    }

    function lockRequested() {
        const screens = Quickshell.screens
        if (!screens || screens.length === 0) {
            lock.locked = true
            root.startAutoSuspendIfNeeded()
            return
        }
        pendingCaptures = screens.length
        for (let i = 0; i < screens.length; i++) {
            const proc = captureComponent.createObject(root, { screenName: screens[i].name })
            proc.running = true
        }
    }
    // ---- end pre-lock screenshot capture ----

    WlSessionLock {
        id: lock

        Component.onCompleted: console.warn("[lock] WlSessionLock instance created, isHyprland:", root.isHyprland)

        onLockedChanged: {
            console.warn("[lock] onLockedChanged fired, locked:", locked)
            if (!locked) {
                console.warn("[lock] unlocked - cancelling auto-suspend countdown")
                autoSuspendTimer.stop()
                root.lastCursorX = -1
                root.lastCursorY = -1
            }
        }

        WlSessionLockSurface {
            id: surface

            property bool settingsOpen: false

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                onEntered: pwField.forceActiveFocus()
                onPositionChanged: (mouse) => {
                    if (!pwField.activeFocus) pwField.forceActiveFocus()

                        if (root.lastCursorX < 0) {
                            // First event since lock/resume - just record a
                            // baseline, don't treat it as movement.
                            root.lastCursorX = mouse.x
                            root.lastCursorY = mouse.y
                            return
                        }

                        const dx = mouse.x - root.lastCursorX
                        const dy = mouse.y - root.lastCursorY
                        root.lastCursorX = mouse.x
                        root.lastCursorY = mouse.y

                        if (Math.abs(dx) < root.idleMoveThreshold && Math.abs(dy) < root.idleMoveThreshold) {
                            return
                        }

                        if (root.isHyprland && lock.locked) {
                            console.warn("[lock] real cursor movement detected - resetting idle countdown")
                            autoSuspendTimer.restart()
                        }
                }
                z: -1
            }

            LockBackground {
                anchors.fill: parent
                screen: surface.screen
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.background.hslLightness < 0.5 ? "black" : "white"
                opacity: Theme.background.hslLightness < 0.5 ? 0.40 : 0.40
            }

            RowLayout {
                id: powerRow
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 24
                spacing: 10

                readonly property string iconDir: "file://" + Quickshell.env("HOME") + "/.config/icons/"

                function requestAction(action, name) {
                    console.warn("[power] requestAction() called, currentText length:", root.currentText.length)
                    root.authenticate(action, name)
                }

                GlassButton {
                    id: suspendBtn
                    icon: powerRow.iconDir + "suspend.svg"
                    elevated: true
                    implicitWidth: 48
                    implicitHeight: 48
                    property real shakeX: 0
                    transform: Translate { x: suspendBtn.shakeX }
                    layer.enabled: true
                    layer.effect: DirectionalBlur {
                        angle: 0
                        length: Math.min(10, Math.abs(suspendBtn.shakeX) * 3)
                        samples: 16
                    }
                    SequentialAnimation {
                        id: suspendShake
                        running: false
                        PropertyAction { target: suspendBtn; property: "shakeX"; value: 5 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: suspendBtn; property: "shakeX"; value: -5 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: suspendBtn; property: "shakeX"; value: 3 }
                        PauseAnimation { duration: 25 }
                        PropertyAction { target: suspendBtn; property: "shakeX"; value: -3 }
                        PauseAnimation { duration: 25 }
                        PropertyAction { target: suspendBtn; property: "shakeX"; value: 0 }
                    }
                    onClicked: {
                        console.warn("[power] suspend clicked")
                        suspendShake.stop()
                        suspendShake.start()
                        suspendProc.running = true
                    }
                }
                GlassButton {
                    id: restartBtn
                    icon: powerRow.iconDir + "restart.svg"
                    elevated: true
                    implicitWidth: 48
                    implicitHeight: 48
                    property real shakeX: 0
                    transform: Translate { x: restartBtn.shakeX }
                    layer.enabled: true
                    layer.effect: DirectionalBlur {
                        angle: 0
                        length: Math.min(10, Math.abs(restartBtn.shakeX) * 3)
                        samples: 16
                    }
                    SequentialAnimation {
                        id: restartShake
                        running: false
                        PropertyAction { target: restartBtn; property: "shakeX"; value: 5 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: restartBtn; property: "shakeX"; value: -5 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: restartBtn; property: "shakeX"; value: 3 }
                        PauseAnimation { duration: 25 }
                        PropertyAction { target: restartBtn; property: "shakeX"; value: -3 }
                        PauseAnimation { duration: 25 }
                        PropertyAction { target: restartBtn; property: "shakeX"; value: 0 }
                    }
                    onClicked: {
                        console.warn("[power] restart clicked")
                        restartShake.stop()
                        restartShake.start()
                        powerRow.requestAction(() => rebootProc.running = true, "restart")
                    }
                }
                GlassButton {
                    id: poweroffBtn
                    icon: powerRow.iconDir + "power-off.svg"
                    elevated: true
                    implicitWidth: 48
                    implicitHeight: 48
                    property real shakeX: 0
                    transform: Translate { x: poweroffBtn.shakeX }
                    layer.enabled: true
                    layer.effect: DirectionalBlur {
                        angle: 0
                        length: Math.min(10, Math.abs(poweroffBtn.shakeX) * 3)
                        samples: 16
                    }
                    SequentialAnimation {
                        id: poweroffShake
                        running: false
                        PropertyAction { target: poweroffBtn; property: "shakeX"; value: 5 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: poweroffBtn; property: "shakeX"; value: -5 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: poweroffBtn; property: "shakeX"; value: 3 }
                        PauseAnimation { duration: 25 }
                        PropertyAction { target: poweroffBtn; property: "shakeX"; value: -3 }
                        PauseAnimation { duration: 25 }
                        PropertyAction { target: poweroffBtn; property: "shakeX"; value: 0 }
                    }
                    onClicked: {
                        console.warn("[power] poweroff clicked")
                        poweroffShake.stop()
                        poweroffShake.start()
                        powerRow.requestAction(() => poweroffProc.running = true, "shutdown")
                    }
                }

                Process {
                    id: suspendProc
                    command: ["systemctl", "suspend"]
                    stderr: SplitParser {
                        onRead: (line) => console.warn("[power] suspend stderr:", line)
                    }
                    onExited: (exitCode, exitStatus) => console.warn("[power] suspend exited, code:", exitCode, "status:", exitStatus)
                }
                Process {
                    id: rebootProc
                    command: ["systemctl", "reboot"]
                    stderr: SplitParser {
                        onRead: (line) => console.warn("[power] reboot stderr:", line)
                    }
                    onExited: (exitCode, exitStatus) => console.warn("[power] reboot exited, code:", exitCode, "status:", exitStatus)
                }
                Process {
                    id: poweroffProc
                    command: ["systemctl", "poweroff"]
                    stderr: SplitParser {
                        onRead: (line) => console.warn("[power] poweroff stderr:", line)
                    }
                    onExited: (exitCode, exitStatus) => console.warn("[power] poweroff exited, code:", exitCode, "status:", exitStatus)
                }
            }

            LockSettingsButton {
                id: settingsBtn
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 24
                anchors.rightMargin: 24
                active: surface.settingsOpen
                onToggled: surface.settingsOpen = !surface.settingsOpen
            }

            LockSettingsPanel {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 76
                anchors.rightMargin: 24
                transformOrigin: Item.TopRight
                shown: surface.settingsOpen
            }

            LockClock {
                id: clock
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: surface.settingsOpen ? -140 : 0
                Behavior on anchors.horizontalCenterOffset {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            Text {
                id: statusLabel
                anchors.horizontalCenter: clock.horizontalCenter
                anchors.top: pwRow.bottom
                anchors.topMargin: 8
                text: root.failed ? "Wrong password"
                : root.confirmAction !== null ? "Click again to confirm " + root.confirmActionName + "."
                : (root.pendingAction !== null ? "Password required to perform action." : "")
                visible: text.length > 0
                color: root.failed ? "#ff6b6b" : "white"
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Text {
                id: cancelActionLabel
                anchors.horizontalCenter: clock.horizontalCenter
                anchors.top: statusLabel.visible ? statusLabel.bottom : pwRow.bottom
                anchors.topMargin: 6
                visible: root.pendingAction !== null || root.confirmAction !== null
                text: "Cancel"
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.underline: true
                color: "white"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelPendingAction()
                }
            }

            RowLayout {
                id: pwRow
                anchors.horizontalCenter: clock.horizontalCenter
                anchors.top: clock.bottom
                anchors.topMargin: 24
                spacing: 6

                function submit() {
                    console.warn("[lock] submit() called, currentText length:", root.currentText.length)
                    root.tryUnlock()
                }

                function reset() {
                    root.resetLock()
                    pwField.text = ""
                }

                TextField {
                    id: pwField
                    Layout.preferredWidth: 180
                    implicitHeight: 20
                    echoMode: TextInput.Password
                    passwordCharacter: "\u2022"
                    horizontalAlignment: TextInput.AlignHCenter
                    placeholderText: "Password"

                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: Theme.foreground
                    placeholderTextColor: "white"

                    property real shakeX: 0
                    transform: Translate { x: pwField.shakeX }
                    layer.enabled: true
                    layer.effect: DirectionalBlur {
                        angle: 0
                        length: Math.min(28, Math.abs(pwField.shakeX) * 5)
                        samples: 24
                    }

                    SequentialAnimation {
                        id: pwShake
                        running: false
                        PropertyAction { target: pwField; property: "shakeX"; value: 6 }
                        PauseAnimation { duration: 35 }
                        PropertyAction { target: pwField; property: "shakeX"; value: -18 }
                        PauseAnimation { duration: 35 }
                        PropertyAction { target: pwField; property: "shakeX"; value: 12 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: pwField; property: "shakeX"; value: -14 }
                        PauseAnimation { duration: 30 }
                        PropertyAction { target: pwField; property: "shakeX"; value: 8 }
                        PauseAnimation { duration: 28 }
                        PropertyAction { target: pwField; property: "shakeX"; value: -6 }
                        PauseAnimation { duration: 25 }
                        PropertyAction { target: pwField; property: "shakeX"; value: 0 }
                    }

                    Connections {
                        target: root
                        function onFailedChanged() {
                            if (root.failed) {
                                pwShake.stop()
                                pwShake.start()
                            }
                        }
                    }

                    background: Rectangle {
                        radius: 10
                        color: Qt.rgba(Theme.popupBg.r, Theme.popupBg.g, Theme.popupBg.b, 0.5)
                        border.width: 2
                        border.color: pwField.activeFocus ? Theme.accentActive : Theme.borderMuted
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }

                    text: root.currentText
                    onTextChanged: if (root.currentText !== text) root.currentText = text

                    focus: true
                    onAccepted: pwRow.submit()
                    Component.onCompleted: forceActiveFocus()
                }

                Rectangle {
                    id: submitBtn
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: mouse.containsMouse ? Theme.hoverBgStrong : Qt.rgba(Theme.popupBg.r, Theme.popupBg.g, Theme.popupBg.b, 0.5)
                    border.width: 1
                    border.color: Theme.borderMuted
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u2192"
                        color: Theme.foreground
                        font.pixelSize: 15
                        font.bold: true
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pwRow.submit()
                    }
                }
            }

            BatteryStatus {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: 24
                anchors.rightMargin: 24
            }

            onVisibleChanged: {
                if (visible) {
                    pwRow.reset()
                    pwField.forceActiveFocus()

                    pwShake.stop()
                    pwShake.start()
                    settingsBtn.triggerShake()
                    root.startAutoSuspendIfNeeded()
                } else {
                    settingsBtn.triggerShake()
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock() { root.lockRequested() }
        function unlock(token: string): void { root.remoteUnlock(token) }
    }
}
