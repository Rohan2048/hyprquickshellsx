import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Wayland

Item {
    id: root
    property var screen

    // True once the live compositor feed has actually delivered a frame
    readonly property bool liveReady: capture.hasContent

    // Scripted jitter offset -- driven by a fixed animation curve
    property real shakeX: 0

    // Always-present solid base. Nothing renders on top of this until
    // the async Image below has actually decoded, so there is never a
    // gap where the surface's own default background can show through.
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Static screenshot grabbed BEFORE the lock surface existed (see
    // LockScreen.qml's lockRequested()). This is on screen the instant
    // the surface appears, so there's no black flash while the live
    // Wayland capture spins up.
    Image {
        id: staticShot
        anchors.fill: parent
        source: root.screen ? "file:///tmp/quickshell-lockshot-" + root.screen.name + ".png" : ""
        cache: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }

    MultiEffect {
        id: staticBlur
        anchors.fill: staticShot
        source: staticShot
        autoPaddingEnabled: false

        blurEnabled: true
        blur: 1.0
        blurMax: 96
        blurMultiplier: 1.6

        saturation: -0.08
        brightness: -0.06
        contrast: 0.05

        opacity: root.liveReady ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // Live capture, running from the moment the surface exists. Once it
    // has its first frame, it fades in over the static shot and freezes
    // (matches prior behavior of stopping after first frame).
    ScreencopyView {
        id: capture
        anchors.fill: parent
        captureSource: root.screen
        live: true
        onHasContentChanged: if (hasContent) live = false
    }

    MultiEffect {
        id: blurred
        anchors.fill: capture
        source: capture
        autoPaddingEnabled: false

        blurEnabled: true
        blur: 1.0
        blurMax: 96
        blurMultiplier: 1.6

        saturation: -0.08
        brightness: -0.06
        contrast: 0.05

        opacity: root.liveReady ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        transform: Translate { x: root.shakeX }

        layer.enabled: true
        layer.effect: DirectionalBlur {
            angle: 0
            length: Math.min(10, Math.abs(root.shakeX) * 3)
            samples: 16
        }
    }

    // Entrance jitter animation -- can start immediately now since the
    // static shot is already on screen (no more waiting on "ready").
    SequentialAnimation {
        running: true
        loops: 1

        PropertyAction { target: root; property: "shakeX"; value: 3 }
        PauseAnimation { duration: 35 }
        PropertyAction { target: root; property: "shakeX"; value: -3 }
        PauseAnimation { duration: 35 }
        PropertyAction { target: root; property: "shakeX"; value: 2 }
        PauseAnimation { duration: 30 }
        PropertyAction { target: root; property: "shakeX"; value: -2 }
        PauseAnimation { duration: 30 }
        PropertyAction { target: root; property: "shakeX"; value: 0 }
    }
}
