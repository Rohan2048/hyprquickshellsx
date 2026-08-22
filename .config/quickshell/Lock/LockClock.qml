import QtQuick
import Qt5Compat.GraphicalEffects
import "../Theme"
import "../Services"

Column {
    id: root
    spacing: 4
    property date now: new Date()

    // Track the current minute to detect exactly when it changes
    property int currentMinute: now.getMinutes()

    property real shakeX: 0
    transform: Translate { x: root.shakeX }

    layer.enabled: true
    layer.effect: DirectionalBlur {
        angle: 0
        length: Math.min(28, Math.abs(root.shakeX) * 5)
        samples: 21
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 95
        font.weight: Font.Medium
        text: Qt.formatTime(root.now, "HH:mm")
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 35
        font.weight: Font.Light
        text: Qt.formatDate(root.now, "dd MMMM, yyyy")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date()
            // Explicitly update to guarantee the change signal fires
            // and bypasses QML Date binding quirks
            root.currentMinute = root.now.getMinutes()
        }
    }

    // Trigger the animation exactly when the minute changes
    onCurrentMinuteChanged: {
        shakeAnimation.start()
    }

    // Subtle ambient jitter -- abrupt snaps, not tweened motion.
    // Triggered manually on minute change to guarantee zero desync.
    SequentialAnimation {
        id: shakeAnimation

        PropertyAction { target: root; property: "shakeX"; value: 6 }
        PauseAnimation { duration: Animations.scaleDuration(35) }
        PropertyAction { target: root; property: "shakeX"; value: -18 }
        PauseAnimation { duration: Animations.scaleDuration(35) }
        PropertyAction { target: root; property: "shakeX"; value: 12 }
        PauseAnimation { duration: Animations.scaleDuration(30) }
        PropertyAction { target: root; property: "shakeX"; value: -14 }
        PauseAnimation { duration: Animations.scaleDuration(30) }
        PropertyAction { target: root; property: "shakeX"; value: 8 }
        PauseAnimation { duration: Animations.scaleDuration(28) }
        PropertyAction { target: root; property: "shakeX"; value: -6 }
        PauseAnimation { duration: Animations.scaleDuration(25) }
        PropertyAction { target: root; property: "shakeX"; value: 0 }
    }

    // Optional: Uncomment the line below if you also want the jitter
    // to play immediately when the component first loads.
    // Component.onCompleted: shakeAnimation.start()
}
