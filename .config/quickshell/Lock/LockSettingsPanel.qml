import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../Widgets"
import "../Theme"
import "../Services"
GlassPanel {
    id: root
    property string view: "root" // "root" | "wifi" | "bluetooth"
    property bool shown: false

    implicitWidth: 350
    implicitHeight: (root.view === "root" ? 360 : 300)

    // 1. Drive fluid macro-movement via Behaviors (no more manual opacity = 0 fighting)
    visible: opacity > 0.01
    opacity: shown ? 1.0 : 0.0
    scale: shown ? 1.0 : 0.9

    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 160; easing.type: Easing.OutBack }
    }

    property real entranceX: 0
    property real shakeX: 0
    transform: Translate { x: root.entranceX + root.shakeX }

    layer.enabled: true
    layer.effect: DirectionalBlur {
        angle: 0
        length: Math.min(14, Math.abs(root.shakeX) * 4 + Math.abs(root.entranceX) * 0.5)
        samples: 20
    }

    // 2. Trigger the entrance blend exactly when the panel state changes
    onShownChanged: {
        entranceAnimation.restart()
    }

    // 3. Slide-in blended with a light settle shake (shared for entrance/exit)
    ParallelAnimation {
        id: entranceAnimation
        NumberAnimation {
            target: root; property: "entranceX"
            from: 16; to: 0
            duration: Animations.scaleDuration(170)
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PropertyAction { target: root; property: "shakeX"; value: 3 }
            PauseAnimation { duration: Animations.scaleDuration(30) }
            PropertyAction { target: root; property: "shakeX"; value: -8 }
            PauseAnimation { duration: Animations.scaleDuration(30) }
            PropertyAction { target: root; property: "shakeX"; value: 5 }
            PauseAnimation { duration: Animations.scaleDuration(25) }
            PropertyAction { target: root; property: "shakeX"; value: -6 }
            PauseAnimation { duration: Animations.scaleDuration(25) }
            PropertyAction { target: root; property: "shakeX"; value: 3 }
            PauseAnimation { duration: Animations.scaleDuration(20) }
            PropertyAction { target: root; property: "shakeX"; value: -3 }
            PauseAnimation { duration: Animations.scaleDuration(18) }
            PropertyAction { target: root; property: "shakeX"; value: 0 }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 14

        ColumnLayout {
            id: mainContent
            anchors.fill: parent
            spacing: Theme.gapMd
            visible: opacity > 0.01
            opacity: root.view === "root" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            // Same snap-jitter as LockWifiDetail/LockBluetoothDetail's entrance:
            // fires the instant this becomes visible again (i.e. when returning
            // from wifi/bluetooth), so coming back to the settings panel is a
            // single connected transition instead of a separate shake-then-switch.
            property real entranceX: 0
            property real shakeX: 0
            transform: Translate { x: mainContent.entranceX + mainContent.shakeX }

            layer.enabled: true
            layer.effect: DirectionalBlur {
                angle: 0
                length: Math.min(14, Math.abs(mainContent.shakeX) * 4 + Math.abs(mainContent.entranceX) * 0.5)
                samples: 20
            }

            onVisibleChanged: {
                if (visible) {
                    mainEntrance.restart()
                }
            }

            ParallelAnimation {
                id: mainEntrance
                NumberAnimation {
                    target: mainContent; property: "entranceX"
                    from: 16; to: 0
                    duration: Animations.scaleDuration(170)
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    PropertyAction { target: mainContent; property: "shakeX"; value: 3 }
                    PauseAnimation { duration: Animations.scaleDuration(30) }
                    PropertyAction { target: mainContent; property: "shakeX"; value: -8 }
                    PauseAnimation { duration: Animations.scaleDuration(30) }
                    PropertyAction { target: mainContent; property: "shakeX"; value: 5 }
                    PauseAnimation { duration: Animations.scaleDuration(25) }
                    PropertyAction { target: mainContent; property: "shakeX"; value: -6 }
                    PauseAnimation { duration: Animations.scaleDuration(25) }
                    PropertyAction { target: mainContent; property: "shakeX"; value: 3 }
                    PauseAnimation { duration: Animations.scaleDuration(20) }
                    PropertyAction { target: mainContent; property: "shakeX"; value: -3 }
                    PauseAnimation { duration: Animations.scaleDuration(18) }
                    PropertyAction { target: mainContent; property: "shakeX"; value: 0 }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 7
                spacing: Theme.gapMd

                LockWifiRow {
                    Layout.preferredWidth: 70
                    onDevicesRequested: root.view = "wifi"
                }
                LockBluetoothRow {
                    Layout.preferredWidth: 70
                    onDevicesRequested: root.view = "bluetooth"
                }
                LockAirplaneRow {
                    Layout.preferredWidth: 70
                }
                LockLightDarkRow {
                    Layout.preferredWidth: 70
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.gapMd + 8

                LockVolumeRow { Layout.fillWidth: true }
                LockBrightnessRow { Layout.fillWidth: true }
            }

            Item { Layout.fillHeight: true } // soak up the fixed extra height
        }

        LockWifiDetail {
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: root.view === "wifi" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            onBack: root.view = "root"
        }

        LockBluetoothDetail {
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: root.view === "bluetooth" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            onBack: root.view = "root"
        }
    }
}
