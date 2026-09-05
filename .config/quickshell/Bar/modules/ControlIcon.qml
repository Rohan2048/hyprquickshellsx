import QtQuick
import Qt5Compat.GraphicalEffects
import "../../Theme"

// Generic bar-right icon button: wifi / bluetooth / volume / battery / bell.
// Equivalent of eww's (button :class "control-icon" :onclick "eww open X --toggle").
Item {
    id: root
    // grows to fit icon+text (e.g. a song name); stays at 34 for icon-only buttons
    implicitWidth: Math.max(34, contentRow.implicitWidth + 10)
    implicitHeight: Theme.barHeight

    property string glyph: ""
    property string text: ""     // optional label next to glyph, e.g. "82%" for battery
    property url iconSource: ""  // e.g. "file:///home/rohan/.config/icons/wifion.svg"
    property int iconSize: 16
    signal activated()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: mouse.containsMouse ? Theme.hoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        Image {
            id: iconImg
            visible: root.iconSource.toString().length > 0
            source: root.iconSource
            sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
            sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
            width: root.iconSize
            height: root.iconSize
            anchors.verticalCenter: parent.verticalCenter
            smooth: true

            layer.enabled: root.iconSource.toString().length > 0
            layer.smooth: true
            layer.textureSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            layer.effect: ColorOverlay {
                color: Theme.iconColor
            }

        }
        Text {
            visible: root.iconSource.toString().length === 0
            text: root.glyph
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.text.length > 0
            text: root.text
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
