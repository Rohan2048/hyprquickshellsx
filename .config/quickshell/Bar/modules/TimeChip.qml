import QtQuick
import "../../Theme"

// Bar button showing a short time string (timer remaining / stopwatch elapsed).
// Same footprint and hover style as ControlIcon, but the width is derived from
// `templateText` instead of the live text. ControlIcon sizes itself to its
// text, which would make the whole bar twitch every second as digit widths
// change; here the width only changes when the template does.
Item {
    id: root

    property string text: ""
    // Widest string the button will show, e.g. "00:00" or "00:00:00".
    property string templateText: "00:00"
    // Draw a filled rounded square behind the text (used by the timer).
    property bool chip: false
    property color chipColor: "#e5484d"
    property color chipTextColor: "white"
    signal activated()

    readonly property real _inner: metrics.advanceWidth + (chip ? 12 : 0)

    implicitWidth: Math.max(34, _inner + 10)
    implicitHeight: Theme.barHeight

    TextMetrics {
        id: metrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        font.bold: root.chip
        text: root.templateText
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSm
        color: mouse.containsMouse ? Theme.hoverBg : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
    }

    Rectangle {
        visible: root.chip
        anchors.centerIn: parent
        width: root._inner
        height: 18
        radius: 4
        color: root.chipColor
    }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.chip ? root.chipTextColor : Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        font.bold: root.chip
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
