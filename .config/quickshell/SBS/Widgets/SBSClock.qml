import QtQuick
import Quickshell

// Center clock + date, no animation, no blur -- matches the flat
// black/white line-art look of SBSRadiosPanel.qml.
Column {
    id: root
    spacing: 6

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(clock.date, "hh:mm")
        color: "white"
        font.pixelSize: 64
        font.family: "monospace"
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(clock.date, "d MMMM, yyyy")
        color: "white"
        font.pixelSize: 20
        font.family: "monospace"
    }
}
