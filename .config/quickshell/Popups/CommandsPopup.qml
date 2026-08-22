import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Services"
import "../Widgets"
import "../Theme"


PanelWindow {
    id: popup
    property bool shown: false
    property bool hiding: false
    property real openProgress: 0
    visible: shown || hiding
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:commands"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors.right: true
    margins.right: 0

    implicitWidth: 220
    implicitHeight: 280

    onShownChanged: {
        if (shown) {
            hiding = false
            closeAnim.stop()
            openAnim.restart()
        } else {
            hiding = true
            hideTimer.restart()
            openAnim.stop()
            closeAnim.restart()
        }
    }
    NumberAnimation {
        id: openAnim
        target: popup; property: "openProgress"
        to: 1
        duration: Animations.slideBlurDuration    // was: slideBlurDuration(50)
        easing.type: Animations.slideBlurEasingOut
    }
    NumberAnimation {
        id: closeAnim
        target: popup; property: "openProgress"
        to: 0
        duration: Animations.slideBlurDuration    // was: slideBlurDuration(50)
        easing.type: Animations.slideBlurEasingIn
    }

    Timer {
        id: hideTimer
        interval: 220
        onTriggered: popup.hiding = false
    }
    ClickAwayCloser {
        targetWindows: [popup]
        active: popup.shown
        onDismissed: popup.shown = false
    }
    IpcHandler {
        target: "commands"
        function toggle() { popup.shown = !popup.shown }

    }

    Item {
        id: content
        anchors.fill: parent
        opacity: popup.openProgress
        x: Animations.slideBlurHorizontalLength * (1 - popup.openProgress)

        GlassPanel {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4
                    Text {
                        text: "Commands"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fontSize
                        Layout.fillWidth: true
                    }
                    GlassButton {
                        text: "+"
                        elevated: true
                        fontSize: Theme.fontSizeXl -5
                        implicitWidth: 34
                        implicitHeight: 34
                        onClicked: Commands.addNew()
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderMuted }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: Commands.groups
                    delegate: CommandGroup {
                        width: ListView.view.width
                        group: modelData.group
                        commands: modelData.commands
                        onLaunched: popup.shown = false
                    }
                }
            }
        }
    }

    DirectionalBlur {
        anchors.fill: content
        source: content
        angle: Animations.slideBlurHorizontalAngle
        length: Animations.slideBlurHorizontalLength * 1.1 * Animations.blurEnvelope(popup.openProgress)
        samples: Animations.slideBlurSamples
        opacity: content.opacity
        x: content.x
    }
}
