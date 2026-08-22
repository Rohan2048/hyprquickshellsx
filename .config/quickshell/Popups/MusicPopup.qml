pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Services"
import "../Theme"
import "../Widgets"

PanelWindow {
    id: popup
    visible: false

    property var tracking: null

    WlrLayershell.namespace: "quickshell:musicPopup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property real iconCenterOffset: 0
    property real barBottomOffset: 32
    readonly property real horizontalOverhang: 5
    readonly property real verticalGap: 3

    anchors { bottom: true; left: true }

    readonly property real effectiveLeftMargin: {
        var screenW = popup.screen ? popup.screen.width : implicitWidth
        var desired = iconCenterOffset - implicitWidth / 2

        if (!popup.tracking) {
            var maxLeft = Math.max(0, screenW - implicitWidth)
            return Math.min(Math.max(0, desired), maxLeft)
        }

        var minLeftMargin = popup.tracking.barLeftEdge - horizontalOverhang
        var maxLeftMargin = popup.tracking.barRightEdge + horizontalOverhang - implicitWidth

        var lo, hi
        if (maxLeftMargin >= minLeftMargin) {
            lo = minLeftMargin
            hi = maxLeftMargin
        } else {
            lo = minLeftMargin
            hi = minLeftMargin
        }
        return Math.min(Math.max(lo, desired), hi)
    }

    property real smoothedLeftMargin: effectiveLeftMargin
    Behavior on smoothedLeftMargin {
        NumberAnimation { duration: 260; easing.type: Easing.OutQuint }
    }

    margins {
        bottom: barBottomOffset + verticalGap
        left: smoothedLeftMargin
    }

    implicitWidth: 340
    implicitHeight: content.implicitHeight
    color: "transparent"

    property real openProgress: 0

    function open() {
        closeAnim.stop()
        popup.visible = true
        openAnim.restart()
    }
    function close() {
        openAnim.stop()
        closeAnim.restart()
    }
    function toggle() {
        if (popup.openProgress > 0) popup.close()
            else popup.open()
    }

    NumberAnimation {
        id: openAnim
        target: popup; property: "openProgress"
        to: 1
        duration: Animations.pageSlideDuration
        easing.type: Animations.pageSlideEasingOut
    }
    NumberAnimation {
        id: closeAnim
        target: popup; property: "openProgress"
        to: 0
        duration: Animations.pageSlideDuration
        easing.type: Animations.pageSlideEasingIn
        onStopped: popup.visible = false
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "musicPopupToggle"
        description: "Toggle music player popup"
        onPressed: popup.toggle()
    }

    IpcHandler {
        target: "musicPopup"
        function toggle() { popup.toggle() }
        function open() { popup.open() }
        function close() { popup.close() }
    }

    Connections {
        target: MusicPlayerService
        function onActiveChanged() {
            if (!MusicPlayerService.active)
                popup.close()
        }
    }

    ClickAwayCloser {
        targetWindows: [popup]
        active: popup.visible
        onDismissed: popup.close()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: popup.close()
        z: -1
    }

    // ---- Reusable text swap: blur-out, swap text, blur-in. Used by
    // titleText and artistText below, which differed only in font size
    // and the pause before the swap — everything else was duplicated.
    component SwapText: Text {
        id: swapRoot
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        color: Theme.foreground
        elide: Text.ElideRight

        property int pauseMs: 30
        property real blurLen: 0
        property real swapOpacity: 1

        opacity: swapOpacity
        layer.enabled: true
        layer.effect: DirectionalBlur {
            angle: Animations.slideBlurHorizontalAngle
            length: swapRoot.blurLen
            samples: Animations.slideBlurSamples
            transparentBorder: true
        }

        function swapTo(newText) {
            swapAnim.pendingText = newText
            swapAnim.restart()
        }

        SequentialAnimation {
            id: swapAnim
            property string pendingText: ""
            PauseAnimation { duration: swapRoot.pauseMs }
            ParallelAnimation {
                NumberAnimation { target: swapRoot; property: "blurLen"; to: Animations.trackSwapBlurLength; duration: Animations.trackSwapOutDuration; easing.type: Animations.trackSwapOutEasing }
                NumberAnimation { target: swapRoot; property: "swapOpacity"; to: 0; duration: Animations.trackSwapOutDuration; easing.type: Animations.trackSwapOutEasing }
            }
            ScriptAction {
                script: swapRoot.text = swapAnim.pendingText
            }
            ParallelAnimation {
                NumberAnimation { target: swapRoot; property: "blurLen"; to: 0; duration: Animations.trackSwapInDuration; easing.type: Animations.trackSwapInEasing }
                NumberAnimation { target: swapRoot; property: "swapOpacity"; to: 1; duration: Animations.trackSwapInDuration; easing.type: Animations.trackSwapInEasing }
            }
        }
    }

    GlassPanel {
        id: content
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 340
        implicitHeight: rootCol.implicitHeight + 36
        radius: 20

        y: (1 - popup.openProgress) * (height + 36)
        opacity: popup.openProgress
        property real blurAmount: Math.sin(Math.PI * popup.openProgress) * Animations.slideBlurVerticalLength

        layer.enabled: true
        layer.effect: DirectionalBlur {
            angle: Animations.slideBlurVerticalAngle
            length: content.blurAmount
            samples: Animations.slideBlurSamples
            transparentBorder: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: rootCol
            anchors.centerIn: parent
            width: parent.width - 36
            spacing: 14

            ColumnLayout {
                id: headerCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                // ---- Album art: persistent, always-live element — same
                // lifecycle as titleText/artistText below. Single source
                // of truth for readiness (img.status), single reload
                // path (reload()), single retry mechanism (watchdogTimer)
                // that only acts on genuine failure, never on a load
                // still in progress.
                Rectangle {
                    id: artBox
                    readonly property real fixedHeight: 140
                    Layout.preferredHeight: fixedHeight
                    Layout.preferredWidth: Math.max(fixedHeight, artImage.aspectRatio * fixedHeight)
                    Layout.alignment: Qt.AlignHCenter
                    radius: 16
                    clip: true
                    color: "transparent"

                    Item {
                        id: artImage
                        anchors.fill: parent

                        property real aspectRatio: 1
                        property bool hasArt: img.status === Image.Ready
                        property int retries: 0

                        readonly property string targetUrl: {
                            const a = MusicPlayerService.art
                            if (a === "") return ""
                                return (a.startsWith("http://") || a.startsWith("https://") || a.startsWith("file://"))
                                ? a : "file://" + a
                        }

                        property real blurLen: 0
                        property real swapOpacity: 1

                        opacity: swapOpacity
                        layer.enabled: true
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: artImage.blurLen
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }

                        function reload() {
                            img.source = ""
                            img.source = artImage.targetUrl
                            watchdogTimer.restart()
                        }

                        Timer {
                            id: swapDebounce
                            interval: 30
                            onTriggered: artSwap.restart()
                        }

                        Connections {
                            target: MusicPlayerService
                            function onArtChanged() { swapDebounce.restart() }
                            function onTitleChanged() { swapDebounce.restart() }
                        }

                        SequentialAnimation {
                            id: artSwap
                            ParallelAnimation {
                                NumberAnimation { target: artImage; property: "blurLen"; to: Animations.trackSwapBlurLength; duration: Animations.trackSwapOutDuration; easing.type: Animations.trackSwapOutEasing }
                                NumberAnimation { target: artImage; property: "swapOpacity"; to: 0; duration: Animations.trackSwapOutDuration; easing.type: Animations.trackSwapOutEasing }
                            }
                            ScriptAction {
                                script: {
                                    artImage.retries = 0
                                    artImage.reload()
                                }
                            }
                            ParallelAnimation {
                                NumberAnimation { target: artImage; property: "blurLen"; to: 0; duration: Animations.trackSwapInDuration; easing.type: Animations.trackSwapInEasing }
                                NumberAnimation { target: artImage; property: "swapOpacity"; to: 1; duration: Animations.trackSwapInDuration; easing.type: Animations.trackSwapInEasing }
                            }
                        }

                        Image {
                            id: img
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            Component.onCompleted: artImage.reload()
                            onStatusChanged: {
                                if (status === Image.Ready) {
                                    watchdogTimer.stop()
                                    if (implicitHeight > 0)
                                        artImage.aspectRatio = implicitWidth / implicitHeight
                                }
                            }
                        }

                        Timer {
                            id: watchdogTimer
                            interval: 3000
                            onTriggered: {
                                if ((img.status === Image.Error || img.status === Image.Null)
                                    && artImage.targetUrl !== "" && artImage.retries < 5) {
                                    artImage.retries += 1
                                    artImage.reload()
                                    }
                            }
                        }
                    }

                    // ---- Placeholder: shown when there's no art loaded.
                    // While actively playing, the note gets a slow
                    // breathing neon glow tinted to the theme's accent
                    // color — the glyph itself stays fixed size/opacity;
                    // only the Glow effect's radius/spread breathe with
                    // glowPulse. Same entry/exit blur pattern used by the
                    // popup itself (Animations.slideBlur*), so it feels
                    // consistent rather than bolted-on.
                    Item {
                        id: placeholderWrap
                        anchors.fill: parent
                        visible: !artImage.hasArt

                        property real glowPulse: 0.35

                        SequentialAnimation on glowPulse {
                            running: MusicPlayerService.playing && placeholderWrap.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.25; duration: 1400; easing.type: Easing.InOutSine }
                        }

                        // Entry/exit for the placeholder itself, mirroring
                        // the popup's own open/close blur+fade treatment.
                        property real entryBlur: 0
                        property real entryOpacity: 0

                        SequentialAnimation {
                            id: placeholderEnter
                            ParallelAnimation {
                                NumberAnimation { target: placeholderWrap; property: "entryBlur"; from: Animations.slideBlurHorizontalLength ?? 24; to: 0; duration: Animations.trackSwapInDuration; easing.type: Animations.trackSwapInEasing }
                                NumberAnimation { target: placeholderWrap; property: "entryOpacity"; from: 0; to: 1; duration: Animations.trackSwapInDuration; easing.type: Animations.trackSwapInEasing }
                            }
                        }

                        onVisibleChanged: {
                            if (visible) {
                                entryBlur = 0
                                entryOpacity = 0
                                placeholderEnter.restart()
                            }
                        }

                        opacity: entryOpacity
                        layer.enabled: true
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: placeholderWrap.entryBlur
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }

                        Text {
                            id: noteText
                            anchors.centerIn: parent
                            text: "♪"
                            font.pixelSize: 36
                            color: Theme.color8 ?? Theme.foreground

                            layer.enabled: MusicPlayerService.playing
                            layer.effect: Glow {
                                radius: 6 + placeholderWrap.glowPulse * 14
                                samples: 16
                                color: Theme.color1
                                spread: 0.25 + placeholderWrap.glowPulse * 0.4
                                transparentBorder: true
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 5

                    SwapText {
                        id: titleText
                        font.pixelSize: 15
                        font.bold: true
                        pauseMs: 30
                        text: "Not Playing"

                        Component.onCompleted: text = MusicPlayerService.title !== "" ? MusicPlayerService.title : "Not Playing"

                        Connections {
                            target: MusicPlayerService
                            function onTitleChanged() {
                                titleText.swapTo(MusicPlayerService.title !== "" ? MusicPlayerService.title : "Not Playing")
                            }
                        }
                    }

                    SwapText {
                        id: artistText
                        font.pixelSize: 12
                        pauseMs: 55
                        text: ""

                        Component.onCompleted: text = MusicPlayerService.artist

                        Connections {
                            target: MusicPlayerService
                            function onArtistChanged() { artistText.swapTo(MusicPlayerService.artist) }
                        }
                    }

                    Text {
                        id: albumText
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: MusicPlayerService.album
                        color: Theme.foreground
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            ColumnLayout {
                id: seekGroup
                Layout.fillWidth: true
                spacing: 2

                Item {
                    id: seekTrack
                    Layout.fillWidth: true
                    implicitHeight: 16

                    property bool dragging: false
                    readonly property real ratio: MusicPlayerService.duration > 0
                    ? Math.min(1, Math.max(0, MusicPlayerService.position / MusicPlayerService.duration))
                    : 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(0.5, 0.5, 0.5, 0.35)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * seekTrack.ratio
                        height: 4
                        radius: 2
                        color: Theme.color1
                    }

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.foreground
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.min(parent.width - width, Math.max(0, parent.width * seekTrack.ratio - width / 2))
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: mouse => {
                            seekTrack.dragging = true
                            MusicPlayerService.seeking = true
                            const percent = Math.min(100, Math.max(0, (mouse.x / width) * 100))
                            MusicPlayerService.position = (percent / 100) * MusicPlayerService.duration
                        }
                        onPositionChanged: mouse => {
                            if (!seekTrack.dragging) return
                                const percent = Math.min(100, Math.max(0, (mouse.x / width) * 100))
                                MusicPlayerService.position = (percent / 100) * MusicPlayerService.duration
                                MusicPlayerService.positionFmt = MusicPlayerService.fmt(MusicPlayerService.position)
                        }
                        onReleased: mouse => {
                            const percent = Math.min(100, Math.max(0, (mouse.x / width) * 100))
                            MusicPlayerService.seek(percent)
                            seekTrack.dragging = false
                            MusicPlayerService.seeking = false
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: MusicPlayerService.positionFmt
                        color: Theme.foreground
                        font.pixelSize: 10
                    }
                    Text {
                        text: MusicPlayerService.durationFmt
                        color: Theme.foreground
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                id: controlsRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Rectangle {
                    width: 38; height: 38; radius: 19
                    color: prevArea.containsMouse ? Qt.rgba(Theme.color1.r, Theme.color1.g, Theme.color1.b, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 16; color: Theme.foreground }
                    MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; onClicked: MusicPlayerService.previous() }
                }

                Rectangle {
                    width: 46; height: 46; radius: 23
                    color: Qt.rgba(Theme.color1.r, Theme.color1.g, Theme.color1.b, playArea.containsMouse ? 0.55 : 0.25)
                    border.width: 1.5
                    border.color: Qt.rgba(Theme.color1.r, Theme.color1.g, Theme.color1.b, 0.70)
                    Text {
                        anchors.centerIn: parent
                        // The play triangle's ink isn't centered in its own
                        // glyph box the way the pause bars are, so centering
                        // on the bounding box alone reads as off-center.
                        anchors.horizontalCenterOffset: MusicPlayerService.playing ? 0 : 1.5
                        text: MusicPlayerService.playing ? "⏸" : "▶"
                        font.pixelSize: 18
                        color: Theme.foreground
                    }
                    MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; onClicked: MusicPlayerService.playPause() }
                }

                Rectangle {
                    width: 38; height: 38; radius: 19
                    color: nextArea.containsMouse ? Qt.rgba(Theme.color1.r, Theme.color1.g, Theme.color1.b, 0.25) : "transparent"
                    Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 16; color: Theme.foreground }
                    MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; onClicked: MusicPlayerService.next() }
                }
            }
        }
    }
}
