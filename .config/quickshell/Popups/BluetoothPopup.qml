import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Qt5Compat.GraphicalEffects
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

    WlrLayershell.namespace: "quickshell:popup:bluetooth"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Distance from the screen's right edge to the bluetooth icon's horizontal center.
    property real iconCenterOffset: 0
    // Distance from the screen's bottom edge to the bar's own top edge —
    // live, so the popup rides along with the bar's auto-hide animation.
    property real barBottomOffset: 32

    readonly property real horizontalOverhang: 5
    readonly property real verticalGap: 3

    anchors { bottom: true; left: false; right: true }

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
        // Scanning must never outlive the popup — closing always drops
        // liveMode back to false, regardless of how the gear icon was
        // last left, so bt-scan-listener.sh can't keep running unseen.
        Bluetooth.liveMode = false
        headerTitle.playExit()
        gearBtn.playExit()
        radioBtn.playExit()
        newDevicesLabel.playExit()
        pairedDevicesLabel.playExit()
        emptyStateText.playExit()
        for (let i = 0; i < newDevicesRepeater.count; i++)
            newDevicesRepeater.itemAt(i).playExit()
            for (let i = 0; i < pairedRepeater.count; i++)
                pairedRepeater.itemAt(i).playExit()
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
            headerTitle.playEntrance()
            gearBtn.playEntrance()
            radioBtn.playEntrance()
            newDevicesLabel.playEntrance()
            pairedDevicesLabel.playEntrance()
            emptyStateText.playEntrance()
            for (let i = 0; i < newDevicesRepeater.count; i++)
                newDevicesRepeater.itemAt(i).playEntrance()
                for (let i = 0; i < pairedRepeater.count; i++)
                    pairedRepeater.itemAt(i).playEntrance()
        }
    }

    ClickAwayCloser {
        targetWindows: [popup]
        active: popup.visible && !popup.closing
        onDismissed: popup.close()
    }

    // Devices the gear icon should show: ones never paired with before.
    // Same removal handling as WifiPopup's recomputeNewNetworks: devices
    // leaving the set play their exit blur before the array is reassigned,
    // instead of just popping out. Pure additions reassign immediately;
    // RSSI-only rescans with the same device set don't reassign at all,
    // so delegates (and their hover/marquee state) survive routine rescans.
    property var newDevices: []
    function recomputeNewDevices() {
        const filtered = Bluetooth.scanList.filter(
            d => !Bluetooth.history.some(h => h.name === d.name))
        const oldIds = newDevices.map(d => d.mac)
        const newIds = filtered.map(d => d.mac)
        if (oldIds.join(",") === newIds.join(",")) return

            const removedIds = oldIds.filter(id => !newIds.includes(id))
            if (removedIds.length > 0) {
                removedIds.forEach(id => {
                    const idx = oldIds.indexOf(id)
                    const item = newDevicesRepeater.itemAt(idx)
                    if (item) item.playExit()
                })
                removeTimer.restart()
            } else {
                newDevices = filtered
            }
    }

    Timer {
        id: removeTimer
        interval: Animations.slideBlurDuration
        onTriggered: {
            const filtered = Bluetooth.scanList.filter(
                d => !Bluetooth.history.some(h => h.name === d.name))
            popup.newDevices = filtered
        }
    }
    Connections {
        target: Bluetooth
        function onScanListChanged() { popup.recomputeNewDevices() }
        function onHistoryChanged() { popup.recomputeNewDevices() }
    }
    Component.onCompleted: recomputeNewDevices()

    property string pinDraft: ""

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

                Text {
                    id: headerTitle
                    text: "Bluetooth"
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
                    layer.enabled: true
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
                        active: Bluetooth.liveMode
                        onClicked: {
                            instantColor = true
                            Bluetooth.toggleLiveMode()
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
                        active: Bluetooth.radioOn
                        text: (Bluetooth.radioOn ? "\u25cf ON" : "\u25cb OFF")
                        onClicked: {
                            instantColor = true
                            Bluetooth.toggleRadio()
                        }

                        scale: radioHover.hovered ? 1.06 : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        HoverHandler { id: radioHover }
                    }
                }
            }

            // ---- In-app pairing prompts ----
            ColumnLayout {
                id: pairingPrompt

                Layout.fillWidth: true
                spacing: 6

                readonly property bool active:
                Bluetooth.pendingConfirm !== null ||
                Bluetooth.pendingPin !== null ||
                Bluetooth.pairError !== ""

                opacity: active ? 1 : 0
                visible: opacity > 0.01

                transform: Translate {
                    y: pairingPrompt.active ? 0 : -6
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: Bluetooth.pendingConfirm !== null
                    spacing: 4
                    Text {
                        text: "Confirm code on " + Bluetooth.pairingName + ":"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Text {
                        text: Bluetooth.pendingConfirm ? Bluetooth.pendingConfirm.code : ""
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        GlassButton {
                            text: "Confirm"
                            onClicked: {
                                instantColor = true
                                Bluetooth.confirmYes()
                            }
                            scale: confirmHover.hovered ? 1.04 : 1.0
                            transformOrigin: Item.Center
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            HoverHandler { id: confirmHover }
                        }
                        GlassButton {
                            text: "Reject"
                            hoverBorderColor: "red"
                            onClicked: {
                                instantColor = true
                                Bluetooth.confirmNo()
                            }
                            scale: rejectHover.hovered ? 1.04 : 1.0
                            transformOrigin: Item.Center
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            HoverHandler { id: rejectHover }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Bluetooth.pendingPin !== null
                    onVisibleChanged: if (visible) { pinField.text = ""; pinField.forceActiveFocus() }
                    spacing: 4
                    TextField {
                        id: pinField
                        Layout.fillWidth: true
                        implicitHeight: 30
                        placeholderText: "PIN for " + Bluetooth.pairingName
                        focus: Bluetooth.pendingPin !== null
                        onTextChanged: popup.pinDraft = text
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        background: Rectangle {
                            radius: Theme.radiusSm
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.borderMuted
                        }
                        onAccepted: { Bluetooth.submitPin(popup.pinDraft); popup.pinDraft = "" }
                    }
                    GlassButton {
                        text: "Submit"
                        implicitHeight: 30
                        onClicked: {
                            instantColor = true
                            Bluetooth.submitPin(popup.pinDraft)
                            popup.pinDraft = ""
                        }

                        scale: submitHover.hovered ? 1.04 : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        HoverHandler { id: submitHover }
                    }
                }

                // ---- Pair-error row — same shaky directional-blur jitter
                // as Timer's "Time's Up!" entrance (timesUpShakeX /
                // timesUpShakeAnim). Fires once whenever Bluetooth.pairError
                // transitions from empty to non-empty. ----
                RowLayout {
                    id: pairErrorRow
                    Layout.fillWidth: true
                    visible: Bluetooth.pairError !== ""

                    property real shakeX: 0

                    transform: Translate { x: pairErrorRow.shakeX }

                    layer.enabled: pairErrorRow.shakeX !== 0
                    layer.effect: DirectionalBlur {
                        angle: 0
                        length: Math.min(28, Math.abs(pairErrorRow.shakeX) * 5)
                        samples: 21
                    }

                    SequentialAnimation {
                        id: pairErrorShakeAnim
                        NumberAnimation { target: pairErrorRow; property: "shakeX"; to: 3; duration: Animations.scaleDuration(35); easing.type: Easing.OutQuad }
                        NumberAnimation { target: pairErrorRow; property: "shakeX"; to: -4; duration: Animations.scaleDuration(35); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pairErrorRow; property: "shakeX"; to: 2; duration: Animations.scaleDuration(30); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pairErrorRow; property: "shakeX"; to: -3; duration: Animations.scaleDuration(30); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pairErrorRow; property: "shakeX"; to: 3; duration: Animations.scaleDuration(28); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pairErrorRow; property: "shakeX"; to: -3; duration: Animations.scaleDuration(25); easing.type: Easing.InOutQuad }
                        NumberAnimation { target: pairErrorRow; property: "shakeX"; to: 0; duration: Animations.scaleDuration(25); easing.type: Easing.OutQuad }
                    }

                    Connections {
                        target: Bluetooth
                        function onPairErrorChanged() {
                            if (Bluetooth.pairError !== "") {
                                pairErrorShakeAnim.stop()
                                pairErrorShakeAnim.start()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Bluetooth.pairError
                        color: "#ff8080"
                        wrapMode: Text.Wrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                    GlassButton {
                        text: "\u2715"
                        implicitWidth: 26
                        implicitHeight: 26
                        onClicked: {
                            instantColor = true
                            Bluetooth.dismissError()
                        }

                        scale: dismissHover.hovered ? 1.08 : 1.0
                        transformOrigin: Item.Center
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        HoverHandler { id: dismissHover }
                    }
                }
            }

            // ---- New/Paired crossfade — both sections now carry a
            // crossfadeBlur layer keyed off their own opacity, same as
            // WifiPopup's liveSection, so the swap itself reads as a
            // motion-blur transition rather than a plain cut. ----
            Item {
                Layout.fillWidth: true
                implicitHeight: 194

                // ---- Live scan: new/unknown devices only ----
                ColumnLayout {
                    id: liveSection
                    anchors.fill: parent
                    spacing: 4
                    opacity: Bluetooth.liveMode ? 1 : 0
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
                        id: newDevicesLabel
                        text: "New Devices"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true

                        property real entranceProgress: 1
                        property real exitProgress: 1
                        opacity: entranceProgress * exitProgress
                        property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                        property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                        layer.enabled: true
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: Math.max(newDevicesLabel.entranceBlur, newDevicesLabel.exitBlur)
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }
                        NumberAnimation on entranceProgress {
                            id: newDevicesLabelEntranceAnim
                            from: 0; to: 1
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                            running: false
                        }
                        NumberAnimation on exitProgress {
                            id: newDevicesLabelExitAnim
                            from: 1; to: 0
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingIn
                            running: false
                        }
                        function playEntrance() { newDevicesLabelExitAnim.stop(); exitProgress = 1; entranceProgress = 0; newDevicesLabelEntranceAnim.restart() }
                        function playExit() { newDevicesLabelEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; newDevicesLabelExitAnim.restart() }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 170
                        clip: true

                        ColumnLayout {
                            width: parent.width - 6
                            x: 3
                            y: 0
                            spacing: 4

                            Text {
                                id: emptyStateText
                                visible: popup.newDevices.length === 0
                                text: Bluetooth.scanList.length === 0 ? "Scanning\u2026" : "No new devices nearby"
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
                                id: newDevicesRepeater
                                model: popup.newDevices

                                delegate: ScanNewButton {
                                    id: entry
                                    Layout.leftMargin:4
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    active: Bluetooth.pairingMac === modelData.mac &&
                                    (Bluetooth.pendingConfirm !== null || Bluetooth.pendingPin !== null)
                                    text: modelData.name
                                    onClicked: {
                                        instantColor = true
                                        Bluetooth.startPair(modelData.mac, modelData.name)
                                    }

                                    scale: entryHover.hovered ? 1.03 : 1.0
                                    transformOrigin: Item.Center
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    HoverHandler { id: entryHover }

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
                                    }
                                    NumberAnimation on exitProgress {
                                        id: entryExitAnim
                                        from: 1; to: 0
                                        duration: Animations.slideBlurDuration
                                        easing.type: Animations.slideBlurEasingIn
                                        running: false
                                    }
                                    function playEntrance() { entryExitAnim.stop(); exitProgress = 1; entranceProgress = 0; entryEntranceAnim.restart() }
                                    function playExit() { entryEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; entryExitAnim.restart() }
                                    Component.onCompleted: playEntrance()
                                }
                            }
                        }
                    }
                }

                // ---- Paired devices — anything ever paired with, always here ----
                ColumnLayout {
                    id: pairedSection
                    anchors.fill: parent
                    spacing: 4
                    opacity: Bluetooth.liveMode ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    property real crossfadeBlur: Math.sin(Math.PI * opacity) * Animations.slideBlurHorizontalLength
                    layer.enabled: true
                    layer.effect: DirectionalBlur {
                        angle: Animations.slideBlurHorizontalAngle
                        length: pairedSection.crossfadeBlur
                        samples: Animations.slideBlurSamples
                        transparentBorder: true
                    }

                    Text {
                        id: pairedDevicesLabel
                        text: "Paired Devices"
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true

                        property real entranceProgress: 1
                        property real exitProgress: 1
                        opacity: entranceProgress * exitProgress
                        property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                        property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                        layer.enabled: true
                        layer.effect: DirectionalBlur {
                            angle: Animations.slideBlurHorizontalAngle
                            length: Math.max(pairedDevicesLabel.entranceBlur, pairedDevicesLabel.exitBlur)
                            samples: Animations.slideBlurSamples
                            transparentBorder: true
                        }
                        NumberAnimation on entranceProgress {
                            id: pairedDevicesLabelEntranceAnim
                            from: 0; to: 1
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                            running: false
                        }
                        NumberAnimation on exitProgress {
                            id: pairedDevicesLabelExitAnim
                            from: 1; to: 0
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingIn
                            running: false
                        }
                        function playEntrance() { pairedDevicesLabelExitAnim.stop(); exitProgress = 1; entranceProgress = 0; pairedDevicesLabelEntranceAnim.restart() }
                        function playExit() { pairedDevicesLabelEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; pairedDevicesLabelExitAnim.restart() }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 170
                        clip: true

                        ColumnLayout {
                            width: parent.width - 6
                            x: 3
                            y: 3
                            spacing: 4

                            Repeater {
                                id: pairedRepeater
                                model: Bluetooth.history

                                delegate: RowLayout {
                                    id: pairedEntry
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 4

                                    property real entranceProgress: 1
                                    property real exitProgress: 1
                                    opacity: entranceProgress * exitProgress
                                    property real entranceBlur: Math.sin(Math.PI * entranceProgress) * Animations.slideBlurHorizontalLength
                                    property real exitBlur: Math.sin(Math.PI * exitProgress) * Animations.slideBlurHorizontalLength
                                    layer.enabled: entranceProgress < 1 || exitProgress < 1
                                    layer.effect: DirectionalBlur {
                                        angle: Animations.slideBlurHorizontalAngle
                                        length: Math.max(pairedEntry.entranceBlur, pairedEntry.exitBlur)
                                        samples: Animations.slideBlurSamples
                                        transparentBorder: true
                                    }
                                    NumberAnimation on entranceProgress {
                                        id: pairedEntryEntranceAnim
                                        from: 0; to: 1
                                        duration: Animations.slideBlurDuration
                                        easing.type: Animations.slideBlurEasingOut
                                        running: false
                                    }
                                    NumberAnimation on exitProgress {
                                        id: pairedEntryExitAnim
                                        from: 1; to: 0
                                        duration: Animations.slideBlurDuration
                                        easing.type: Animations.slideBlurEasingIn
                                        running: false
                                    }
                                    function playEntrance() { pairedEntryExitAnim.stop(); exitProgress = 1; entranceProgress = 0; pairedEntryEntranceAnim.restart() }
                                    function playExit() { pairedEntryEntranceAnim.stop(); entranceProgress = 1; exitProgress = 1; pairedEntryExitAnim.restart() }
                                    Component.onCompleted: playEntrance()

                                    NameEntryButton {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 40
                                        implicitHeight: 36
                                        text: modelData.name
                                        active: Bluetooth.device === modelData.name
                                        inactiveTextColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.7)
                                        onClicked: Bluetooth.connectTo(modelData.name)

                                        scale: nameHover.hovered ? 1.02 : 1.0
                                        transformOrigin: Item.Center
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        HoverHandler { id: nameHover }
                                    }

                                    GlassButton {
                                        implicitHeight: 36
                                        implicitWidth: 34
                                        text: "\u2715"
                                        onClicked: {
                                            instantColor = true
                                            Bluetooth.disconnect(modelData.name)
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
                                        onClicked: {
                                            instantColor = true
                                            Bluetooth.forget(modelData.name)
                                        }

                                        scale: forgetHover.hovered ? 1.04 : 1.0
                                        transformOrigin: Item.Center
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                        HoverHandler { id: forgetHover }
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
