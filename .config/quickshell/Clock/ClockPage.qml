import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "../Theme"
import "../Services"

Item {
    id: root
    width: parent ? parent.width : 300
    implicitHeight: 75

    property real shakeX: 0
    property real blurAmount: Math.abs(shakeX) * (Animations.shakyBlurMaxLength / Animations.shakyJitterMax)

    function playShake() {
        shakeAnim.stop()
        shakeAnim.restart()
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeX"; to: Animations.shakyJitterMax; duration: Animations.shakyStepDuration; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "shakeX"; to: -Animations.shakyJitterMax * 0.7; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: Animations.shakyJitterMax * 0.4; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: -Animations.shakyJitterMax * 0.2; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: Animations.shakyJitterMax * 0.1; duration: Animations.shakyStepDuration; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: Animations.shakyStepDuration; easing.type: Easing.OutQuad }
    }

    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    function pad(n) { return n < 10 ? "0" + n : "" + n }

    readonly property string timeString: pad(root.now.getHours()) + ":" + pad(root.now.getMinutes()) + ":" + pad(root.now.getSeconds())
    readonly property string dateString: Qt.formatDate(root.now, "dddd, d MMMM yyyy")

    Item {
        id: content
        anchors.fill: parent
        x: root.shakeX

        layer.enabled: true
        layer.effect: DirectionalBlur {
            angle: Animations.slideBlurHorizontalAngle
            length: root.blurAmount
            samples: Animations.shakyBlurSamples
            transparentBorder: true
        }

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.timeString
                font.pixelSize: 40
                font.bold: true
                font.family: Theme.fontFamily
                color: Theme.foreground
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.dateString
                font.pixelSize: Theme.fontSizeSm
                font.family: Theme.fontFamily
                color: Theme.textMuted
            }
        }
    }
}
