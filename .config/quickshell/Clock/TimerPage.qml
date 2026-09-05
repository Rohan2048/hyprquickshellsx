import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "../Theme"
import "../Services"
import "../Widgets"

Item {
    id: root
    width: parent ? parent.width : 300
    implicitHeight: 75

    property real shakeX: 0
    property real blurAmount: Math.abs(shakeX) * (Animations.shakyBlurMaxLength / Animations.shakyJitterMax)

    function playShake() {
        shakeAnim.stop()
        shakeAnim.restart()
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: Animations.shakyJitterMax; duration: Animations.shakyStepDuration; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "shakeX"; to: -Animations.shakyJitterMax * 0.5; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: Animations.shakyJitterMax * 0.4; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: -Animations.shakyJitterMax * 0.2; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: Animations.shakyJitterMax * 0.1; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
    }

    // Snap-style jitter for the "Time's Up!" entrance — separate property
    // from shakeX so it doesn't fight with playShake()'s tweened shake.
    property real timesUpShakeX: 0

    SequentialAnimation {
        id: timesUpShakeAnim
        NumberAnimation { target: root; property: "timesUpShakeX"; to: 3; duration: Animations.scaleDuration(35); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "timesUpShakeX"; to: -4; duration: Animations.scaleDuration(35); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "timesUpShakeX"; to: 2; duration: Animations.scaleDuration(30); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "timesUpShakeX"; to: -3; duration: Animations.scaleDuration(30); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "timesUpShakeX"; to: 3; duration: Animations.scaleDuration(28); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "timesUpShakeX"; to: -3; duration: Animations.scaleDuration(25); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "timesUpShakeX"; to: 0; duration: Animations.scaleDuration(25); easing.type: Easing.OutQuad }
    }

    property int durationMs: 5 * 60 * 1000
    property real remainingMs: durationMs
    property real accumulatedRemaining: durationMs
    property bool running: false
    property var startTime: null

    // FIX: replaces the old full-screen overlay. When the timer finishes,
    // we just swap what's shown *inside* our own 75px-tall content area
    // instead of spawning an Item with anchors.fill: parent — that Item
    // was filling whatever ancestor layout root sits in (the whole
    // DateTimePopup), so the "Time's Up" card floated over the calendar
    // below instead of staying inside the timer widget.
    property bool timesUp: false

    // Decoupled text property for performance
    property string timeText: "00:00:00"

    // FIX: Initialize timeText correctly when the component loads so it doesn't start at 00:00:00
    Component.onCompleted: {
        timeText = root.fmt(durationMs)
    }

    function start() { if (!running && remainingMs > 0) { startTime = Date.now(); running = true } }
    function pause() { if (running) { accumulatedRemaining = remainingMs; running = false } }
    function reset() {
        running = false; accumulatedRemaining = durationMs; remainingMs = durationMs;
        timeText = root.fmt(durationMs)
        timesUp = false
    }

    function adjust(deltaMs) {
        if (running) return;
        durationMs = Math.max(0, durationMs + deltaMs);
        accumulatedRemaining = durationMs;
        remainingMs = durationMs;
        timeText = root.fmt(durationMs);
    }

    function playAlarmLoop() {
        Quickshell.execDetached(["bash", "-c",
                                "while true; do gst-launch-1.0 -q playbin uri=file://" + Quickshell.env("HOME") + "/.config/sounds/Timer.mp3; done"])
    }

    function stopAlarmLoop() {
        Quickshell.execDetached(["bash", "-c",
                                "pkill -f 'playbin uri=file://" + Quickshell.env("HOME") + "/.config/sounds/Timer.mp3'"])
    }

    onTimesUpChanged: {
        if (timesUp) {
            timesUpShakeAnim.start()
            Quickshell.execDetached(["notify-send", "-u", "critical", "Timer", "Time's Up!"])
            playAlarmLoop()
        } else {
            stopAlarmLoop()
        }
    }

    Timer {
        interval: 200
        running: root.running
        repeat: true
        onTriggered: {
            let elapsed = Date.now() - root.startTime
            root.remainingMs = Math.max(0, root.accumulatedRemaining - elapsed)
            root.timeText = root.fmt(root.remainingMs)

            if (root.remainingMs <= 0) {
                root.running = false
                root.timesUp = true
            }
        }
    }

    function fmt(ms) {
        let t = Math.max(0, ms | 0)
        let h = (t / 3600000) | 0, m = ((t % 3600000) / 60000) | 0, s = ((t % 60000) / 1000) | 0
        function pad(n) { return n < 10 ? "0" + n : "" + n }
        return pad(h) + ":" + pad(m) + ":" + pad(s)
    }

    Item {
        id: content
        anchors.fill: parent
        x: root.shakeX

        layer.enabled: root.shakeX !== 0
        layer.effect: DirectionalBlur {
            angle: Animations.slideBlurHorizontalAngle
            length: root.blurAmount
            samples: Animations.shakyBlurSamples
            transparentBorder: true
        }

        // Normal timer view
        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 6
            visible: !root.timesUp

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.timeText
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
                font.family: Theme.fontFamily
                color: Theme.foreground
            }

            // FIX: this row now actually collapses (height animates to 0)
            // once the timer starts, instead of just fading out while still
            // holding its layout space. Because the ColumnLayout is
            // vertically centered in the 75px widget, collapsing this row
            // shrinks the column and the whole thing re-centers — which is
            // what pulls the countdown text down toward center.
            property bool adjustVisible: !root.running && root.remainingMs === root.durationMs

            RowLayout {
                id: adjustRow
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: parent.adjustVisible ? implicitHeight : 0
                spacing: 16
                clip: true
                opacity: parent.adjustVisible ? 1 : 0
                enabled: parent.adjustVisible

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Item {
                    implicitWidth: 40
                    implicitHeight: 30
                    Text {
                        anchors.centerIn: parent
                        text: "-1h"
                        font.pixelSize: Theme.fontSizeSm
                        font.family: Theme.fontFamily
                        color: Theme.textMuted
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.adjust(-3600000) }
                }
                Item {
                    implicitWidth: 40
                    implicitHeight: 30
                    Text {
                        anchors.centerIn: parent
                        text: "-1m"
                        font.pixelSize: Theme.fontSizeSm
                        font.family: Theme.fontFamily
                        color: Theme.textMuted
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.adjust(-60000) }
                }
                Item {
                    implicitWidth: 40
                    implicitHeight: 30
                    Text {
                        anchors.centerIn: parent
                        text: "+1m"
                        font.pixelSize: Theme.fontSizeSm
                        font.family: Theme.fontFamily
                        color: Theme.textMuted
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.adjust(60000) }
                }
                Item {
                    implicitWidth: 40
                    implicitHeight: 30
                    Text {
                        anchors.centerIn: parent
                        text: "+1h"
                        font.pixelSize: Theme.fontSizeSm
                        font.family: Theme.fontFamily
                        color: Theme.textMuted
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.adjust(3600000) }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Item {
                    implicitWidth: 60
                    implicitHeight: 30
                    Text {
                        anchors.centerIn: parent
                        text: root.running ? "Pause" : "Start"
                        font.pixelSize: Theme.fontSize
                        font.family: Theme.fontFamily
                        color: Theme.foreground
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.running ? root.pause() : root.start() }
                }
                Item {
                    implicitWidth: 60
                    implicitHeight: 30
                    Text {
                        anchors.centerIn: parent
                        text: "Reset"
                        font.pixelSize: Theme.fontSize
                        font.family: Theme.fontFamily
                        color: Theme.textMuted
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.reset() }
                }
            }
        }

        // FIX: inline "Time's Up" state — occupies the same 75px area,
        // no overlay, no z-ordering, no anchors.fill on an ancestor.
        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 8
            visible: root.timesUp
            transform: Translate { x: root.timesUpShakeX }

            layer.enabled: root.timesUpShakeX !== 0
            layer.effect: DirectionalBlur {
                angle: 0
                length: Math.min(28, Math.abs(root.timesUpShakeX) * 5)
                samples: 21
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Time's Up!"
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                font.family: Theme.fontFamily
                color: Theme.foreground
            }

            GlassButton {
                Layout.alignment: Qt.AlignHCenter
                text: "OK"
                onClicked: root.reset()
            }
        }
    }
}
