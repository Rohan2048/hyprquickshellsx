import QtQuick

// SBSLockClock.qml — plain monospace time/date readout.
//
// No minute-change shake animation, no DirectionalBlur layer: just a
// value that updates once a second.
Column {
    id: root
    spacing: 4
    property date now: new Date()

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: "white"
        font.family: "monospace"
        font.pixelSize: 90
        text: Qt.formatTime(root.now, "HH:mm")
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: "white"
        font.family: "monospace"
        font.pixelSize: 28
        text: Qt.formatDate(root.now, "dd MMMM, yyyy")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
