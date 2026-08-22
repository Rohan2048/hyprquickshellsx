import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import "../Theme"
import "../Widgets"
import "../Services"

ColumnLayout {
    id: btDetail
    signal back()
    spacing: 6

    property string pinDraft: ""

    onVisibleChanged: {
        if (visible) {
            entranceAnimation.restart()
        }
    }

    function handleBack() {
        btDetail.back()
    }

    property bool liveMode: Bluetooth.liveMode
    onLiveModeChanged: {
        entranceAnimation.restart()
    }

    property real entranceX: 0
    property real shakeX: 0
    transform: Translate { x: btDetail.entranceX + btDetail.shakeX }

    layer.enabled: true
    layer.effect: DirectionalBlur {
        angle: 0
        length: Math.min(14, Math.abs(btDetail.shakeX) * 4 + Math.abs(btDetail.entranceX) * 0.5)
        samples: 20
    }

    ParallelAnimation {
        id: entranceAnimation
        NumberAnimation {
            target: btDetail; property: "entranceX"
            from: 16; to: 0
            duration: Animations.scaleDuration(170)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PropertyAction { target: btDetail; property: "shakeX"; value: 3 }
            PauseAnimation { duration: Animations.scaleDuration(30) }
            PropertyAction { target: btDetail; property: "shakeX"; value: -8 }
            PauseAnimation { duration: Animations.scaleDuration(30) }
            PropertyAction { target: btDetail; property: "shakeX"; value: 5 }
            PauseAnimation { duration: Animations.scaleDuration(25) }
            PropertyAction { target: btDetail; property: "shakeX"; value: -6 }
            PauseAnimation { duration: Animations.scaleDuration(25) }
            PropertyAction { target: btDetail; property: "shakeX"; value: 3 }
            PauseAnimation { duration: Animations.scaleDuration(20) }
            PropertyAction { target: btDetail; property: "shakeX"; value: -3 }
            PauseAnimation { duration: Animations.scaleDuration(18) }
            PropertyAction { target: btDetail; property: "shakeX"; value: 0 }
        }
    }

    // ---- Diff-tracked device lists (drives per-item entrance/exit) ----
    property var newDevices: []
    property var pairedDevices: []

    function recomputeNewDevices() {
        const filtered = Bluetooth.scanList.filter(
            d => !Bluetooth.history.some(h => h.name === d.name))
        const oldIds = newDevices.map(d => d.mac)
        const newIds = filtered.map(d => d.mac)
        if (oldIds.join(",") === newIds.join(",")) return

            const removedIds = oldIds.filter(id => !newIds.includes(id))
            if (removedIds.length > 0) {
                removedIds.forEach(id => {
                    const idx = oldIds.indexOf(id)
                    const item = newDevicesRepeater.itemAt(idx)
                    if (item) item.playExit()
                })
                newDevRemoveTimer.restart()
            } else {
                newDevices = filtered
            }
    }

    function recomputePaired() {
        const oldIds = pairedDevices.map(d => d.name)
        const newIds = Bluetooth.history.map(d => d.name)
        if (oldIds.join(",") === newIds.join(",")) return

            const removedIds = oldIds.filter(id => !newIds.includes(id))
            if (removedIds.length > 0) {
                removedIds.forEach(id => {
                    const idx = oldIds.indexOf(id)
                    const item = pairedRepeater.itemAt(idx)
                    if (item) item.playExit()
                })
                pairedRemoveTimer.restart()
            } else {
                pairedDevices = Bluetooth.history
            }
    }

    Timer {
        id: newDevRemoveTimer
        interval: Animations.slideBlurDuration
        onTriggered: {
            btDetail.newDevices = Bluetooth.scanList.filter(
                d => !Bluetooth.history.some(h => h.name === d.name))
        }
    }

    Timer {
        id: pairedRemoveTimer
        interval: Animations.slideBlurDuration
        onTriggered: btDetail.pairedDevices = Bluetooth.history
    }

    Connections {
        target: Bluetooth
        function onScanListChanged() { btDetail.recomputeNewDevices() }
        function onHistoryChanged() { btDetail.recomputeNewDevices(); btDetail.recomputePaired() }
    }

    Component.onCompleted: {
        recomputeNewDevices()
        recomputePaired()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        GlassButton {
            text: "\u2190"
            implicitWidth: 30
            implicitHeight: 26
            Layout.leftMargin: 3
            onClicked: btDetail.handleBack()
        }

        Text {
            text: "Bluetooth"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
            Layout.fillWidth: true
        }

        GlassButton {
            id: settingsButton
            implicitWidth: 30
            implicitHeight: 26
            active: Bluetooth.liveMode
            onClicked: Bluetooth.toggleLiveMode()
            onActiveChanged: settingsIcon.rotation = active ? 90 : 0

            Image {
                id: settingsIcon
                anchors.centerIn: parent
                source: "file://" + Quickshell.env("HOME") + "/.config/icons/settings.svg"
                sourceSize.width: 14
                sourceSize.height: 14
                width: 14; height: 14
                opacity: settingsButton.active ? 1.0 : 0.85
                scale: settingsButton.active ? 1.1 : 1.0
                visible: false

                Behavior on rotation {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }

            ColorOverlay {
                anchors.fill: settingsIcon
                source: settingsIcon
                color: Theme.foreground
                rotation: settingsIcon.rotation
                opacity: settingsIcon.opacity
                scale: settingsIcon.scale
            }

        }

        GlassButton {
            variant: "toggle"
            Layout.rightMargin:3
            active: Bluetooth.radioOn
            text: Bluetooth.radioOn ? "\u25cf ON" : "\u25cb OFF"
            onClicked: Bluetooth.toggleRadio()
        }
    }

    // ---- Pairing status: passkey confirm / PIN entry / error ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: Bluetooth.pendingConfirm !== null || Bluetooth.pendingPin !== null || Bluetooth.pairError !== ""

        ColumnLayout {
            Layout.fillWidth: true
            visible: Bluetooth.pendingConfirm !== null
            spacing: 4
            Text {
                text: "Confirm code on " + Bluetooth.pairingName + ":"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
            Text {
                text: Bluetooth.pendingConfirm ? Bluetooth.pendingConfirm.code : ""
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                GlassButton { text: "Confirm"; onClicked: Bluetooth.confirmYes() }
                GlassButton { text: "Reject"; hoverBorderColor: "red"; onClicked: Bluetooth.confirmNo() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Bluetooth.pendingPin !== null
            onVisibleChanged: if (visible) { pinField.text = ""; pinField.forceActiveFocus() }
            spacing: 4
            TextField {
                id: pinField
                Layout.fillWidth: true
                implicitHeight: 30
                placeholderText: "PIN for " + Bluetooth.pairingName
                focus: Bluetooth.pendingPin !== null
                onTextChanged: btDetail.pinDraft = text
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                background: Rectangle {
                    radius: Theme.radiusSm
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.borderMuted
                }
                onAccepted: { Bluetooth.submitPin(btDetail.pinDraft); btDetail.pinDraft = "" }
            }
            GlassButton {
                text: "Submit"
                implicitHeight: 30
                onClicked: { Bluetooth.submitPin(btDetail.pinDraft); btDetail.pinDraft = "" }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: Bluetooth.pairError !== ""
            Text {
                Layout.fillWidth: true
                text: Bluetooth.pairError
                color: "#ff8080"
                wrapMode: Text.Wrap
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
            GlassButton { text: "\u2715"; implicitWidth: 26; implicitHeight: 26; onClicked: Bluetooth.dismissError() }
        }
    }

    // ---- New devices (live scan) ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: Bluetooth.liveMode

        Text {
            text: "New Devices"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            visible: btDetail.newDevices.length === 0
            text: Bluetooth.scanList.length === 0 ? "Scanning\u2026" : "No new devices nearby"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: 170
            clip: true

            ColumnLayout {
                width: parent.width
                y: 3.5
                x: 3
                spacing: 4

                Repeater {
                    id: newDevicesRepeater
                    model: btDetail.newDevices


                    delegate: Item {
                        id: entry
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 36

                        property bool hoverSuppressed: false

                        property real entranceProgress: 1
                        property real exitProgress: 1
                        property real itemShakeX: 0
                        opacity: entranceProgress * exitProgress
                        scale: 0.85 + 0.15 * Math.min(entranceProgress, exitProgress)
                        property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                        property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                        transform: Translate { x: entry.itemShakeX }
                        layer.enabled: entranceProgress < 1 || exitProgress < 1 || entry.itemShakeX !== 0
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: Math.max(entry.entranceBlur, entry.exitBlur, Math.abs(entry.itemShakeX) * 3)
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }

                        NumberAnimation on entranceProgress {
                            id: entryEntranceAnim
                            from: 0; to: 1
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                            running: false
                            onRunningChanged: if (!running) entry.hoverSuppressed = false
                        }
                        NumberAnimation on exitProgress {
                            id: entryExitAnim
                            from: 1; to: 0
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingIn
                            running: false
                        }
                        SequentialAnimation {
                            id: entryShakeAnim
                            PropertyAction { target: entry; property: "itemShakeX"; value: 2 }
                            PauseAnimation { duration: Animations.scaleDuration(30) }
                            PropertyAction { target: entry; property: "itemShakeX"; value: -5 }
                            PauseAnimation { duration: Animations.scaleDuration(30) }
                            PropertyAction { target: entry; property: "itemShakeX"; value: 3 }
                            PauseAnimation { duration: Animations.scaleDuration(25) }
                            PropertyAction { target: entry; property: "itemShakeX"; value: -4 }
                            PauseAnimation { duration: Animations.scaleDuration(25) }
                            PropertyAction { target: entry; property: "itemShakeX"; value: 2 }
                            PauseAnimation { duration: Animations.scaleDuration(20) }
                            PropertyAction { target: entry; property: "itemShakeX"; value: -2 }
                            PauseAnimation { duration: Animations.scaleDuration(18) }
                            PropertyAction { target: entry; property: "itemShakeX"; value: 0 }
                        }
                        function playEntrance() {
                            entryExitAnim.stop(); exitProgress = 1; entranceProgress = 0
                            entry.hoverSuppressed = true
                            entryEntranceAnim.restart()
                            entryShakeAnim.restart()
                        }
                        function playExit() { entryEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; entryExitAnim.restart() }
                        Component.onCompleted: playEntrance()

                        ScanEntryButton {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.rightMargin: 10 // <--- ADJUST THIS VALUE to change the button width

                            active: Bluetooth.pairingMac === entry.modelData.mac &&
                            (Bluetooth.pendingConfirm !== null || Bluetooth.pendingPin !== null)
                            hoverEnabled: !entry.hoverSuppressed
                            text: entry.modelData.name
                            onClicked: Bluetooth.startPair(entry.modelData.mac, entry.modelData.name)

                            scale: hovered ? 1.02 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Paired devices ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: !Bluetooth.liveMode

        Text {
            text: "Paired Devices"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.preferredHeight: 170
            clip: true

            ColumnLayout {
                width: parent.width
                y: 3
                x: 3
                spacing: 4

                Repeater {
                    id: pairedRepeater
                    model: btDetail.pairedDevices


                    delegate: RowLayout {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4

                        property bool hoverSuppressed: false

                        property real entranceProgress: 1
                        property real exitProgress: 1
                        property real itemShakeX: 0
                        opacity: entranceProgress * exitProgress
                        scale: 0.85 + 0.15 * Math.min(entranceProgress, exitProgress)
                        property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                        property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                        transform: Translate { x: row.itemShakeX }
                        layer.enabled: entranceProgress < 1 || exitProgress < 1 || row.itemShakeX !== 0
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: Math.max(row.entranceBlur, row.exitBlur, Math.abs(row.itemShakeX) * 3)
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }

                        NumberAnimation on entranceProgress {
                            id: rowEntranceAnim
                            from: 0; to: 1
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                            running: false
                            onRunningChanged: if (!running) row.hoverSuppressed = false
                        }
                        NumberAnimation on exitProgress {
                            id: rowExitAnim
                            from: 1; to: 0
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingIn
                            running: false
                        }
                        SequentialAnimation {
                            id: rowShakeAnim
                            PropertyAction { target: row; property: "itemShakeX"; value: 2 }
                            PauseAnimation { duration: Animations.scaleDuration(30) }
                            PropertyAction { target: row; property: "itemShakeX"; value: -5 }
                            PauseAnimation { duration: Animations.scaleDuration(30) }
                            PropertyAction { target: row; property: "itemShakeX"; value: 3 }
                            PauseAnimation { duration: Animations.scaleDuration(25) }
                            PropertyAction { target: row; property: "itemShakeX"; value: -4 }
                            PauseAnimation { duration: Animations.scaleDuration(25) }
                            PropertyAction { target: row; property: "itemShakeX"; value: 2 }
                            PauseAnimation { duration: Animations.scaleDuration(20) }
                            PropertyAction { target: row; property: "itemShakeX"; value: -2 }
                            PauseAnimation { duration: Animations.scaleDuration(18) }
                            PropertyAction { target: row; property: "itemShakeX"; value: 0 }
                        }
                        function playEntrance() {
                            rowExitAnim.stop(); exitProgress = 1; entranceProgress = 0
                            row.hoverSuppressed = true
                            rowEntranceAnim.restart()
                            rowShakeAnim.restart()
                        }
                        function playExit() { rowEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; rowExitAnim.restart() }
                        Component.onCompleted: playEntrance()

                        NameNewButton {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            text: row.modelData.name
                            active: Bluetooth.device === row.modelData.name
                            inactiveTextColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.7)
                            onClicked: Bluetooth.connectTo(row.modelData.name)

                            scale: hovered ? 1.02 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                            }
                        }

                        GlassButton {
                            implicitHeight: 36
                            implicitWidth: 34
                            text: "\u2715"
                            hoverEnabled: !row.hoverSuppressed
                            onClicked: Bluetooth.disconnect(row.modelData.name)
                        }

                        GlassButton {
                            text: "Forget"
                            hoverBorderColor: "red"
                            implicitHeight: 36
                            hoverEnabled: !row.hoverSuppressed
                            onClicked: {
                                instantColor = true
                                hoverEnabled = false
                                Bluetooth.forget(row.modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }
}
