import QtQuick
import QtQuick.Layouts
import "../Theme"

// Edge-to-edge list button, purpose-built for "New Networks" (Wi-Fi)
// and "New Devices" (Bluetooth) rows. Unlike NameEntryButton, this has
// no internal padding/implicitWidth that can cause a gap against the
// container edge — it anchors.fill to whatever width it's given.
Item {
    id: control

    signal clicked()

    property string text: ""
    property bool active: false
    property color inactiveTextColor: Theme.foreground
    property alias hoverEnabled: mouseArea.hoverEnabled


    readonly property bool hovered: mouseArea.containsMouse

    implicitWidth: 310
    implicitHeight: 36
    y:-3.5
    scale: control.hovered ? 1.03 : 1.0
    transformOrigin: Item.Center
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radiusSm
        border.width: 1

        color: control.active ? (control.hovered ? Theme.accentHover : Theme.accentActive)
        : (control.hovered ? Theme.hoverBgStrong : "transparent")
        border.color: control.active ? (control.hovered ? Theme.accentHover : Theme.accentActive)
        : (control.hovered ? Theme.accentHover : Theme.borderMuted)

        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        text: control.text
        color: control.active ? Theme.textOnAccent : control.inactiveTextColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }
}
