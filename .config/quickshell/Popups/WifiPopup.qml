import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../Theme"
import "../Widgets"
import "../Services"

PanelWindow {
    id: popup
    visible: false

    implicitWidth: 300
    implicitHeight: contentCol.implicitHeight + 20

    property var tracking: null

    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.namespace: "quickshell:popup:wifi"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Distance from the screen's right edge to the wifi icon's horizontal center.
    property real iconCenterOffset: 0
    // Distance from the screen's bottom edge to the bar's own top edge —
    // live, so the popup rides along with the bar's auto-hide animation.
    property real barBottomOffset: 32

    readonly property real horizontalOverhang: 5
    readonly property real verticalGap: 3

    anchors { bottom: true; right: true }
    readonly property real effectiveRightMargin: {
        var screenW = popup.screen ? popup.screen.width : implicitWidth
        var desired = iconCenterOffset - implicitWidth / 2

        if (!popup.tracking) {
            var maxRight = Math.max(0, screenW - implicitWidth)
            return Math.min(Math.max(0, desired), maxRight)
        }

        var minRightMargin = screenW - (popup.tracking.barRightEdge + horizontalOverhang)
        var maxRightMargin = screenW - implicitWidth - popup.tracking.barLeftEdge + horizontalOverhang
        var lo = Math.min(minRightMargin, maxRightMargin)
        var hi = Math.max(minRightMargin, maxRightMargin)
        return Math.min(Math.max(lo, desired), hi)
    }
    property real smoothedRightMargin: effectiveRightMargin
    Behavior on smoothedRightMargin {
        NumberAnimation { duration: 260; easing.type: Easing.OutQuint }
    }

    margins {
        bottom: barBottomOffset + verticalGap
        right: smoothedRightMargin
    }

    property bool closing: false

    function toggle() {
        if (closing) return
            if (visible) close()
                else visible = true
    }

    function close() {
        closing = true
        headerTitle.playExit()
        gearBtn.playExit()
        radioBtn.playExit()
        newNetworksLabel.playExit()
        savedNetworksLabel.playExit()
        emptyStateText.playExit()
        for (let i = 0; i < newNetworksRepeater.count; i++)
            newNetworksRepeater.itemAt(i).playExit()
            for (let i = 0; i < savedRepeater.count; i++)
                savedRepeater.itemAt(i).playExit()
                closeTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: Animations.slideBlurDuration
        onTriggered: {
            popup.visible = false
            popup.closing = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            Wifi.popupOpen = true
            headerTitle.playEntrance()
            gearBtn.playEntrance()
            radioBtn.playEntrance()
            newNetworksLabel.playEntrance()
            savedNetworksLabel.playEntrance()
            emptyStateText.playEntrance()
            for (let i = 0; i < newNetworksRepeater.count; i++)
                newNetworksRepeater.itemAt(i).playEntrance()
                for (let i = 0; i < savedRepeater.count; i++)
                    savedRepeater.itemAt(i).playEntrance()
        } else {
            Wifi.popupOpen = false
            expandedSsid = ""
            Wifi.dismissAuthError()
        }
    }

    ClickAwayCloser {
        targetWindows: [popup]
        active: popup.visible && !popup.closing
        onDismissed: popup.close()
    }

    property var newNetworks: []

    // Only skips reassignment when nothing changed at all — a same-membership
    // update (e.g. just signal numbers changing) still needs to flow through
    // so Repeater delegates rebind to fresh modelData. Only a true membership
    // change (something added/removed) needs the animate-out dance below.
    function recomputeNewNetworks() {
        const filtered = Wifi.scanList.filter(
            n => n && n.ssid && !Wifi.history.some(h => h.ssid === n.ssid))
        const oldIds = newNetworks.map(n => n.ssid)
        const newIds = filtered.map(n => n.ssid)

        if (oldIds.join(",") === newIds.join(",")) {
            newNetworks = filtered
            return
        }

        const removedIds = oldIds.filter(id => !newIds.includes(id))
        if (removedIds.length > 0) {
            removedIds.forEach(id => {
                const idx = oldIds.indexOf(id)
                const item = newNetworksRepeater.itemAt(idx)
                if (item) item.playExit()
            })
            removeTimer.restart()
        } else {
            newNetworks = filtered
        }
    }

    Timer {
        id: removeTimer
        interval: Animations.slideBlurDuration
        onTriggered: {
            const filtered = Wifi.scanList.filter(
                n => n && n.ssid && !Wifi.history.some(h => h.ssid === n.ssid))
            popup.newNetworks = filtered
        }
    }

    // ---- Saved networks: diff-tracked exactly like newNetworks. Forget
    // never touches the animation itself — it just suppresses its own
    // hover and calls Wifi.forget(); this Connections+Timer pair is what
    // notices the removal, plays the outgoing delegate's exit, and only
    // then shrinks the array. ----
    property var savedNetworks: []

    function recomputeSaved() {
        const oldIds = savedNetworks.map(n => n.ssid)
        const newIds = Wifi.history.map(n => n.ssid)

        if (oldIds.join(",") === newIds.join(",")) {
            // Same networks, same order — nothing to animate in/out, but
            // fields like signal may have changed, so refresh in place
            // instead of bailing out entirely (this was the live-refresh bug).
            savedNetworks = Wifi.history
            return
        }

        const removedIds = oldIds.filter(id => !newIds.includes(id))
        if (removedIds.length > 0) {
            removedIds.forEach(id => {
                const idx = oldIds.indexOf(id)
                const item = savedRepeater.itemAt(idx)
                if (item) item.playExit()
            })
            savedRemoveTimer.restart()
        } else {
            savedNetworks = Wifi.history
        }
    }

    Timer {
        id: savedRemoveTimer
        interval: Animations.slideBlurDuration
        onTriggered: popup.savedNetworks = Wifi.history
    }

    Connections {
        target: Wifi
        function onScanListChanged() { popup.recomputeNewNetworks() }
        function onHistoryChanged() { popup.recomputeNewNetworks(); popup.recomputeSaved() }
    }
    Component.onCompleted: {
        recomputeNewNetworks()
        recomputeSaved()
    }

    property string expandedSsid: ""

    GlassPanel {
        anchors.fill: parent

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                anchors.margins: 10
                Text {
                    id: headerTitle
                    text: "Wi-Fi"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    Layout.fillWidth: true

                    property real entranceProgress: 1
                    property real exitProgress: 1
                    opacity: entranceProgress * exitProgress
                    property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                    property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                    layer.enabled: entranceProgress < 1 || exitProgress < 1
                    layer.effect: DirectionalBlur {
                        angle: Animations.slideBlurHorizontalAngle
                        length: Math.max(headerTitle.entranceBlur, headerTitle.exitBlur)
                        samples: Animations.slideBlurSamples
                        transparentBorder: true
                    }
                    NumberAnimation on entranceProgress {
                        id: headerTitleEntranceAnim
                        from: 0; to: 1
                        duration: Animations.slideBlurDuration
                        easing.type: Animations.slideBlurEasingOut
                        running: false
                    }
                    NumberAnimation on exitProgress {
                        id: headerTitleExitAnim
                        from: 1; to: 0
                        duration: Animations.slideBlurDuration
                        easing.type: Animations.slideBlurEasingIn
                        running: false
                    }
                    function playEntrance() { headerTitleExitAnim.stop(); exitProgress = 1; entranceProgress = 0; headerTitleEntranceAnim.restart() }
                    function playExit() { headerTitleEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; headerTitleExitAnim.restart() }
                }

                Item {
                    id: gearBtn
                    implicitWidth: 30
                    implicitHeight: 26

                    property real entranceProgress: 1
                    property real exitProgress: 1
                    opacity: entranceProgress * exitProgress
                    property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                    property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                    layer.enabled: entranceProgress < 1 || exitProgress < 1
                    layer.effect: DirectionalBlur {
                        angle: Animations.slideBlurHorizontalAngle
                        length: Math.max(gearBtn.entranceBlur, gearBtn.exitBlur)
                        samples: Animations.slideBlurSamples
                        transparentBorder: true
                    }
                    NumberAnimation on entranceProgress {
                        id: gearBtnEntranceAnim
                        from: 0; to: 1
                        duration: Animations.slideBlurDuration
                        easing.type: Animations.slideBlurEasingOut
                        running: false
                    }
                    NumberAnimation on exitProgress {
                        id: gearBtnExitAnim
                        from: 1; to: 0
                        duration: Animations.slideBlurDuration
                        easing.type: Animations.slideBlurEasingIn
                        running: false
                    }
                    function playEntrance() { gearBtnExitAnim.stop(); exitProgress = 1; entranceProgress = 0; gearBtnEntranceAnim.restart() }
                    function playExit() { gearBtnEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; gearBtnExitAnim.restart() }

                    GlassButton {
                        anchors.fill: parent
                        active: Wifi.liveMode
                        onClicked: {
                            instantColor = true
                            Wifi.toggleLiveMode()
                        }

                        scale: gearHover.hovered ? 1.06 : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        HoverHandler { id: gearHover }

                        Image {
                            id: gearIcon
                            anchors.centerIn: parent
                            source: "file://" + Quickshell.env("HOME") + "/.config/icons/settings.svg"
                            sourceSize.width: 14
                            sourceSize.height: 14
                            width: 14; height: 14
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: gearIcon
                            source: gearIcon
                            color: Theme.foreground
                        }
                    }
                }

                Item {
                    id: radioBtn
                    implicitWidth: radioBtnInner.implicitWidth
                    implicitHeight: radioBtnInner.implicitHeight

                    property real entranceProgress: 1
                    property real exitProgress: 1
                    opacity: entranceProgress * exitProgress
                    property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                    property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                    layer.enabled: entranceProgress < 1 || exitProgress < 1
                    layer.effect: DirectionalBlur {
                        angle: Animations.slideBlurHorizontalAngle
                        length: Math.max(radioBtn.entranceBlur, radioBtn.exitBlur)
                        samples: Animations.slideBlurSamples
                        transparentBorder: true
                    }
                    NumberAnimation on entranceProgress {
                        id: radioBtnEntranceAnim
                        from: 0; to: 1
                        duration: Animations.slideBlurDuration
                        easing.type: Animations.slideBlurEasingOut
                        running: false
                    }
                    NumberAnimation on exitProgress {
                        id: radioBtnExitAnim
                        from: 1; to: 0
                        duration: Animations.slideBlurDuration
                        easing.type: Animations.slideBlurEasingIn
                        running: false
                    }
                    function playEntrance() { radioBtnExitAnim.stop(); exitProgress = 1; entranceProgress = 0; radioBtnEntranceAnim.restart() }
                    function playExit() { radioBtnEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; radioBtnExitAnim.restart() }

                    GlassButton {
                        id: radioBtnInner
                        anchors.fill: parent
                        variant: "toggle"
                        active: Wifi.radioOn
                        text: (Wifi.radioOn ? "\u25cf ON" : "\u25cb OFF")
                        onClicked: {
                            instantColor = true
                            Wifi.toggleRadio()
                        }

                        scale: radioHover.hovered ? 1.06 : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        HoverHandler { id: radioHover }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 194

                ColumnLayout {
                    id: liveSection
                    anchors.fill: parent
                    spacing: 4
                    opacity: Wifi.liveMode ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    property real crossfadeBlur: Math.sin(Math.PI * opacity) * Animations.slideBlurHorizontalLength
                    layer.enabled: true
                    layer.effect: DirectionalBlur {
                        angle: Animations.slideBlurHorizontalAngle
                        length: liveSection.crossfadeBlur
                        samples: Animations.slideBlurSamples
                        transparentBorder: true
                    }

                    Text {
                        id: newNetworksLabel
                        text: "New Networks"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true

                        property real entranceProgress: 1
                        property real exitProgress: 1
                        opacity: entranceProgress * exitProgress
                        property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                        property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                        layer.enabled: entranceProgress < 1 || exitProgress < 1
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: Math.max(newNetworksLabel.entranceBlur, newNetworksLabel.exitBlur)
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }
                        NumberAnimation on entranceProgress {
                            id: newNetworksLabelEntranceAnim
                            from: 0; to: 1
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                            running: false
                        }
                        NumberAnimation on exitProgress {
                            id: newNetworksLabelExitAnim
                            from: 1; to: 0
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingIn
                            running: false
                        }
                        function playEntrance() { newNetworksLabelExitAnim.stop(); exitProgress = 1; entranceProgress = 0; newNetworksLabelEntranceAnim.restart() }
                        function playExit() { newNetworksLabelEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; newNetworksLabelExitAnim.restart() }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.preferredHeight: 170
                        clip: true

                        ColumnLayout {
                            width: parent.width - 10
                            x: 4
                            y: 3
                            spacing: 4

                            Text {
                                id: emptyStateText
                                visible: popup.newNetworks.length === 0
                                text: Wifi.scanList.length === 0 ? "Scanning\u2026" : "No new networks nearby"
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1

                                property real entranceProgress: 1
                                property real exitProgress: 1
                                opacity: entranceProgress * exitProgress
                                property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                                property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                                layer.enabled: entranceProgress < 1 || exitProgress < 1
                                layer.effect: DirectionalBlur {
                                    angle: Animations.slideBlurHorizontalAngle
                                    length: Math.max(emptyStateText.entranceBlur, emptyStateText.exitBlur)
                                    samples: Animations.slideBlurSamples
                                    transparentBorder: true
                                }
                                NumberAnimation on entranceProgress {
                                    id: emptyStateEntranceAnim
                                    from: 0; to: 1
                                    duration: Animations.slideBlurDuration
                                    easing.type: Animations.slideBlurEasingOut
                                    running: false
                                }
                                NumberAnimation on exitProgress {
                                    id: emptyStateExitAnim
                                    from: 1; to: 0
                                    duration: Animations.slideBlurDuration
                                    easing.type: Animations.slideBlurEasingIn
                                    running: false
                                }
                                function playEntrance() { emptyStateExitAnim.stop(); exitProgress = 1; entranceProgress = 0; emptyStateEntranceAnim.restart() }
                                function playExit() { emptyStateEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; emptyStateExitAnim.restart() }
                            }

                            Repeater {
                                id: newNetworksRepeater
                                model: popup.newNetworks

                                delegate: ColumnLayout {
                                    id: entry
                                    required property var modelData
                                    readonly property bool secured: modelData.security !== "Open" && modelData.security !== "none"
                                    readonly property bool expanded: popup.expandedSsid === modelData.ssid
                                    Layout.fillWidth: true
                                    spacing: 4

                                    property bool hoverSuppressed: false

                                    property real entranceProgress: 1
                                    property real exitProgress: 1
                                    opacity: entranceProgress * exitProgress
                                    property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                                    property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                                    layer.enabled: entranceProgress < 1 || exitProgress < 1
                                    layer.effect: DirectionalBlur {
                                        angle: Animations.slideBlurHorizontalAngle
                                        length: Math.max(entry.entranceBlur, entry.exitBlur)
                                        samples: Animations.slideBlurSamples
                                        transparentBorder: true
                                    }
                                    NumberAnimation on entranceProgress {
                                        id: entryEntranceAnim
                                        from: 0; to: 1
                                        duration: Animations.slideBlurDuration
                                        easing.type: Animations.slideBlurEasingOut
                                        running: false
                                        onRunningChanged: if (!running) entry.hoverSuppressed = false
                                    }
                                    NumberAnimation on exitProgress {
                                        id: entryExitAnim
                                        from: 1; to: 0
                                        duration: Animations.slideBlurDuration
                                        easing.type: Animations.slideBlurEasingIn
                                        running: false
                                    }
                                    function playEntrance() {
                                        entryExitAnim.stop(); exitProgress = 1; entranceProgress = 0
                                        entry.hoverSuppressed = true
                                        entryEntranceAnim.restart()
                                    }
                                    function playExit() { entryEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; entryExitAnim.restart() }
                                    Component.onCompleted: playEntrance()

                                    onExpandedChanged: {
                                        if (expanded) {
                                            pwField.text = ""
                                            pwField.forceActiveFocus()
                                        } else {
                                            Wifi.dismissAuthError()
                                        }
                                    }

                                    ScanNewButton {
                                        active: entry.expanded
                                        width: 320 - 100
                                        hoverEnabled: !entry.hoverSuppressed
                                        text: entry.modelData.ssid + "  \u00b7  " + entry.modelData.signal + "%" +
                                        (entry.secured ? "  \ud83d\udd12" : "")
                                        onClicked: {
                                            if (entry.secured) {
                                                popup.expandedSsid = entry.expanded ? "" : entry.modelData.ssid
                                            } else {
                                                Wifi.connectTo(entry.modelData.ssid)
                                            }
                                        }

                                        scale: scanBtnHover.hovered ? 1.03 : 1.0
                                        transformOrigin: Item.Center
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        HoverHandler { id: scanBtnHover }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 8
                                        clip: true
                                        implicitHeight: entry.expanded ? pwRow.implicitHeight : 0
                                        Behavior on implicitHeight {
                                            NumberAnimation { duration: Animations.accordionDuration; easing.type: Animations.accordionEasing }
                                        }

                                        RowLayout {
                                            id: pwRow
                                            width: parent.width
                                            height:20
                                            spacing: 6
                                            x:-1.1
                                            opacity: entry.expanded ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 140 } }

                                            TextField {
                                                id: pwField
                                                Layout.fillWidth: true
                                                implicitHeight: 27
                                                echoMode: TextInput.Password
                                                placeholderText: "Password"
                                                focus: entry.expanded
                                                color: Theme.foreground
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 1
                                                background: Rectangle {
                                                    radius: Theme.radiusSm
                                                    color: "transparent"
                                                    border.width: 1
                                                    border.color: Theme.borderMuted
                                                }
                                                onTextChanged: Wifi.dismissAuthError()
                                                onAccepted: {
                                                    Wifi.connectWithPassword(entry.modelData.ssid, text)
                                                }
                                            }
                                            GlassButton {
                                                text: "Connect"
                                                implicitHeight: 27
                                                hoverEnabled: !entry.hoverSuppressed
                                                onClicked: {
                                                    Wifi.connectWithPassword(entry.modelData.ssid, pwField.text)
                                                }

                                                scale: connectHover.hovered ? 1.04 : 1.0
                                                transformOrigin: Item.Center
                                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                                HoverHandler { id: connectHover }
                                            }
                                        }
                                    }

                                    Item {
                                        id: authErrorSlot
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 8
                                        clip: true

                                        readonly property bool showError: entry.expanded &&
                                        Wifi.authError !== "" &&
                                        Wifi.authErrorSsid === entry.modelData.ssid

                                        implicitHeight: showError ? authErrorRow.implicitHeight : 0
                                        Behavior on implicitHeight {
                                            NumberAnimation { duration: Animations.accordionDuration; easing.type: Animations.accordionEasing }
                                        }

                                        RowLayout {
                                            id: authErrorRow
                                            width: parent.width
                                            spacing: 4
                                            opacity: authErrorSlot.showError ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 140 } }

                                            property real shakeX: 0
                                            transform: Translate { x: authErrorRow.shakeX }

                                            layer.enabled: authErrorRow.shakeX !== 0
                                            layer.effect: DirectionalBlur {
                                                angle: 0
                                                length: Math.min(28, Math.abs(authErrorRow.shakeX) * 5)
                                                samples: 21
                                            }

                                            SequentialAnimation {
                                                id: authErrorShakeAnim
                                                NumberAnimation { target: authErrorRow; property: "shakeX"; to: 3; duration: Animations.scaleDuration(35); easing.type: Easing.OutQuad }
                                                NumberAnimation { target: authErrorRow; property: "shakeX"; to: -4; duration: Animations.scaleDuration(35); easing.type: Easing.InOutQuad }
                                                NumberAnimation { target: authErrorRow; property: "shakeX"; to: 2; duration: Animations.scaleDuration(30); easing.type: Easing.InOutQuad }
                                                NumberAnimation { target: authErrorRow; property: "shakeX"; to: -3; duration: Animations.scaleDuration(30); easing.type: Easing.InOutQuad }
                                                NumberAnimation { target: authErrorRow; property: "shakeX"; to: 3; duration: Animations.scaleDuration(28); easing.type: Easing.InOutQuad }
                                                NumberAnimation { target: authErrorRow; property: "shakeX"; to: -3; duration: Animations.scaleDuration(25); easing.type: Easing.InOutQuad }
                                                NumberAnimation { target: authErrorRow; property: "shakeX"; to: 0; duration: Animations.scaleDuration(25); easing.type: Easing.OutQuad }
                                            }

                                            Connections {
                                                target: Wifi
                                                function onAuthErrorChanged() {
                                                    if (authErrorSlot.showError) {
                                                        authErrorShakeAnim.stop()
                                                        authErrorShakeAnim.start()
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: Wifi.authError
                                                color: "#ff8080"
                                                wrapMode: Text.Wrap
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 2
                                            }
                                            GlassButton {
                                                text: "\u2715"
                                                implicitWidth: 26
                                                implicitHeight: 26
                                                onClicked: Wifi.dismissAuthError()

                                                scale: authDismissHover.hovered ? 1.08 : 1.0
                                                transformOrigin: Item.Center
                                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                                HoverHandler { id: authDismissHover }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: savedSection
                    anchors.fill: parent
                    spacing: 4
                    opacity: Wifi.liveMode ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    property real crossfadeBlur: Math.sin(Math.PI * opacity) * Animations.slideBlurHorizontalLength
                    layer.enabled: true
                    layer.effect: DirectionalBlur {
                        angle: Animations.slideBlurHorizontalAngle
                        length: savedSection.crossfadeBlur
                        samples: Animations.slideBlurSamples
                        transparentBorder: true
                    }

                    Text {
                        id: savedNetworksLabel
                        text: "Saved Networks"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true

                        property real entranceProgress: 1
                        property real exitProgress: 1
                        opacity: entranceProgress * exitProgress
                        property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                        property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                        layer.enabled: entranceProgress < 1 || exitProgress < 1
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: Math.max(savedNetworksLabel.entranceBlur, savedNetworksLabel.exitBlur)
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }
                        NumberAnimation on entranceProgress {
                            id: savedNetworksLabelEntranceAnim
                            from: 0; to: 1
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                            running: false
                        }
                        NumberAnimation on exitProgress {
                            id: savedNetworksLabelExitAnim
                            from: 1; to: 0
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingIn
                            running: false
                        }
                        function playEntrance() { savedNetworksLabelExitAnim.stop(); exitProgress = 1; entranceProgress = 0; savedNetworksLabelEntranceAnim.restart() }
                        function playExit() { savedNetworksLabelEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; savedNetworksLabelExitAnim.restart() }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.preferredHeight: 170
                        clip: true

                        ColumnLayout {
                            width: parent.width - 6
                            x: 4
                            y: 3
                            spacing: 4

                            Repeater {
                                id: savedRepeater
                                model: popup.savedNetworks

                                delegate: RowLayout {
                                    id: savedEntry
                                    required property var modelData
                                    Layout.fillWidth: true
                                    width: parent ? parent.width : implicitWidth
                                    spacing: 4

                                    // Same suppression pattern as `entry` above.
                                    property bool hoverSuppressed: false

                                    property real entranceProgress: 1
                                    property real exitProgress: 1
                                    opacity: entranceProgress * exitProgress
                                    property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                                    property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                                    layer.enabled: entranceProgress < 1 || exitProgress < 1
                                    layer.effect: DirectionalBlur {
                                        angle: Animations.slideBlurHorizontalAngle
                                        length: Math.max(savedEntry.entranceBlur, savedEntry.exitBlur)
                                        samples: Animations.slideBlurSamples
                                        transparentBorder: true
                                    }
                                    NumberAnimation on entranceProgress {
                                        id: savedEntryEntranceAnim
                                        from: 0; to: 1
                                        duration: Animations.slideBlurDuration
                                        easing.type: Animations.slideBlurEasingOut
                                        running: false
                                        onRunningChanged: if (!running) savedEntry.hoverSuppressed = false
                                    }
                                    NumberAnimation on exitProgress {
                                        id: savedEntryExitAnim
                                        from: 1; to: 0
                                        duration: Animations.slideBlurDuration
                                        easing.type: Animations.slideBlurEasingIn
                                        running: false
                                    }
                                    function playEntrance() {
                                        savedEntryExitAnim.stop(); exitProgress = 1; entranceProgress = 0
                                        savedEntry.hoverSuppressed = true
                                        savedEntryEntranceAnim.restart()
                                    }
                                    function playExit() { savedEntryEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; savedEntryExitAnim.restart() }
                                    Component.onCompleted: playEntrance()

                                    NameEntryButton {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 160
                                        implicitHeight: 36
                                        text: modelData.ssid + (modelData.signal != null ? "  \u00b7  " + modelData.signal + "%" : "")
                                        active: Wifi.ssid === modelData.ssid
                                        inactiveTextColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.7)
                                        onClicked: {
                                            Wifi.forceConnectTo(modelData.ssid)
                                        }

                                        scale: nameHover.hovered ? 1.02 : 1.0
                                        transformOrigin: Item.Center
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        HoverHandler { id: nameHover }
                                    }

                                    GlassButton {
                                        implicitHeight: 36
                                        implicitWidth: 34
                                        text: "\u2715"
                                        hoverEnabled: !savedEntry.hoverSuppressed
                                        onClicked: {
                                            Wifi.disconnect(modelData.ssid)
                                        }

                                        scale: disconnectHover.hovered ? 1.08 : 1.0
                                        transformOrigin: Item.Center
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        HoverHandler { id: disconnectHover }
                                    }

                                    GlassButton {
                                        implicitHeight: 36
                                        text: "Forget"
                                        hoverBorderColor: "red"
                                        hoverEnabled: !savedEntry.hoverSuppressed
                                        onClicked: {
                                            hoverEnabled = false
                                            forgetHover.enabled = false
                                                instantColor = true
                                                Wifi.forget(modelData.ssid)
                                        }

                                        scale: forgetHover.hovered ? 1.04 : 1.0
                                        transformOrigin: Item.Center
                                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                        HoverHandler { id: forgetHover; enabled: !savedEntry.hoverSuppressed }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
