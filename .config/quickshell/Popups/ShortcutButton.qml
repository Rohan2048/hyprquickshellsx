import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Theme"

Rectangle {
    id: btn

    required property string appName
    required property string appExec
    required property string appIcon
    required property string appId

    signal launchRequested()
    signal removeRequested()

    Layout.preferredWidth: 44
    Layout.preferredHeight: 44
    Layout.alignment: Qt.AlignHCenter

    // Scale (not width/height) so the hover grow doesn't reflow neighbors
    // in the ColumnLayout — it just visually pops over them.
    scale: mouseArea.containsMouse ? 1.25 : 1.0
    z: mouseArea.containsMouse ? 1 : 0

    Behavior on scale {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutBack
            easing.overshoot: 4
        }
    }

    radius: 10
    color: "transparent"
    border.width: 0

    Image {
        anchors.centerIn: parent
        width: 36
        height: 36
        source: "file://" + btn.appIcon
        smooth: true
        asynchronous: true
        fillMode: Image.PreserveAspectFit
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                btn.launchRequested()
                else if (mouse.button === Qt.MiddleButton)
                    btn.removeRequested()
        }

        ToolTip {
            parent: mouseArea
            visible: mouseArea.containsMouse
            delay: 400

            // Pin it to the right of the icon instead of the default
            // below-center placement, so it has a predictable, unclipped
            // path to grow into on the widened window surface.
            x: mouseArea.width + 10
            y: (mouseArea.height - height) / 2

            contentItem: Text {
                text: btn.appName
                color: Theme.foreground
                font.pixelSize: 12
                wrapMode: Text.NoWrap
            }

            background: Rectangle {
                readonly property real bgLuminance: 0.299 * Theme.background.r + 0.587 * Theme.background.g + 0.114 * Theme.background.b
                readonly property bool isDark: bgLuminance < 0.5

                color: isDark
                ? Qt.rgba(0, 0, 0, 0.75)
                : Qt.rgba(1, 1, 1, 0.75)
                radius: 6
                border.width: 1
                border.color: Theme.borderMuted
            }

            padding: 6
        }
    }
}
