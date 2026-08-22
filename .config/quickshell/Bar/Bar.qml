import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../Theme"
import "../Widgets"
import "../Services"
import "../Popups"
import "./modules"

Item {
    id: root
    required property var modelData


    // Auto-hide trigger area at the very bottom edge of the screen
    PanelWindow {
        id: bottomTrigger
        screen: root.modelData
        WlrLayershell.namespace: "bar-trigger"
        // Fix: was WlrLayer.Overlay, same layer as the screenshot tool's
        // window. Two surfaces on the same layer compete for input
        // priority, and which one wins at the bottom strip of the screen
        // is effectively nondeterministic depending on surface mapping
        // order — that's what caused the app taskbar (and its hover
        // popups) to intermittently respond to the cursor *through* the
        // screenshot/editor overlay. The rest of the bar lives on
        // WlrLayer.Top, so the trigger should too: it must never be able
        // to out-rank an Overlay-layer surface for input.
        WlrLayershell.layer: WlrLayer.Top
        anchors { bottom: true }
        implicitWidth: bar.targetVisualWidth
        implicitHeight: 10
        color: "transparent"
        exclusiveZone: 0

        HoverHandler {
            id: triggerHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    bar.isHovered = true
                    hideTimer.stop()
                } else {
                    hideTimer.restart()
                }
            }
        }
    }

    PanelWindow {
        id: bar
        property bool isHovered: false
        property bool anyPopupOpen: volumePopup.visible || batteryPopup.visible || notificationsPopup.visible
        || wifiPopup.visible || bluetoothPopup.visible || dateTimePopup.visible || musicPopup.visible
        || appsTray.hoveredEntry !== null || appsTray.contextMenuEntry !== null

        onAnyPopupOpenChanged: {
            if (!anyPopupOpen) {
                bar.isHovered = barHoverHandler.hovered || triggerHoverHandler.hovered
                if (!bar.isHovered)
                    hideTimer.restart()
            }
        }

        screen: root.modelData

        property real barCreationStart: Date.now()
        readonly property int barSlowLoadThresholdMs: 400
        readonly property string iconDir: "file://" + Quickshell.env("HOME") + "/.config/icons/"

        property var minimizeWorkspaceMap: ({})

        property var closeQueue: []


        property var hyprIndex: {
            const byWayland = new Map()
            const list = Hyprland.toplevels.values
            for (let i = 0; i < list.length; i++) {
                const h = list[i]
                if (h.wayland)
                    byWayland.set(h.wayland, h)
            }
            return byWayland
        }

        PopupTracking {
            id: popupTracking
            bar: bar
            barClip: barClip
            barContent: barContent
            leftRow: leftRow
            rightRow: rightRow
        }

        Timer {
            id: closeQueueTimer
            interval: 60
            repeat: true
            onTriggered: {
                if (bar.closeQueue.length === 0) {
                    closeQueueTimer.stop()
                    return
                }
                const w = bar.closeQueue.shift()
                try { w.close() } catch (e) {}
            }
        }

        function closeAll(windows) {
            bar.closeQueue = bar.closeQueue.concat(windows.slice())
            if (!closeQueueTimer.running)
                closeQueueTimer.start()
        }

        function findHyprToplevel(toplevel) {
            const hypr = bar.hyprIndex.get(toplevel)
            if (hypr) return hypr

                const appId = (toplevel.appId ?? "").toLowerCase()
                const title = toplevel.title ?? ""
                const list = Hyprland.toplevels.values
                for (let i = 0; i < list.length; i++) {
                    if ((list[i].class ?? "").toLowerCase() === appId && list[i].title === title)
                        return list[i]
                }
                for (let i = 0; i < list.length; i++) {
                    if (list[i].title === title)
                        return list[i]
                }
                return null
        }

        function isMinimizedFake(toplevel) {
            const hypr = bar.findHyprToplevel(toplevel)
            if (!hypr)
                return false
                const addr = hypr.address.startsWith("0x") ? hypr.address : "0x" + hypr.address
                return addr in bar.minimizeWorkspaceMap
        }

        function toggleMinimize(toplevel) {
            const hypr = bar.findHyprToplevel(toplevel)
            if (!hypr) {
                console.warn("toggleMinimize: no matching HyprlandToplevel found for", toplevel.title)
                return
            }
            const addr = hypr.address.startsWith("0x") ? hypr.address : "0x" + hypr.address

            if (addr in bar.minimizeWorkspaceMap) {
                const origin = bar.minimizeWorkspaceMap[addr] || "1"
                Hyprland.dispatch('hl.dsp.window.move({workspace = "' + origin + '", follow = false, window = "address:' + addr + '"})')
                delete bar.minimizeWorkspaceMap[addr]
                bar.minimizeWorkspaceMap = bar.minimizeWorkspaceMap
                toplevel.activate()
            } else {
                const origin = hypr.workspace ? hypr.workspace.name : "1"
                bar.minimizeWorkspaceMap[addr] = origin
                bar.minimizeWorkspaceMap = bar.minimizeWorkspaceMap
                Hyprland.dispatch('hl.dsp.window.move({workspace = "special:minimized", follow = false, window = "address:' + addr + '"})')
            }
        }

        function batteryIconFile() {
            const map = {
                "FULL": "full-battery.svg",
                "ABOVE85": "above85.svg", "ABOVE85_CHG": "above85.svg",
                "HIGH": "high-battery.svg", "HIGH_CHG": "high-battery.svg",
                "MED": "med-battery.svg", "MED_CHG": "med-battery.svg",
                "HALF": "half-battery.svg", "HALF_CHG": "half-battery.svg",
                "BELOW_HALF": "below-half-battery.svg", "BELOW_HALF_CHG": "below-half-battery.svg",
                "LOW": "low-battery.svg", "LOW_CHG": "low-battery.svg",
                "VERY_LOW_CHG": "very-low-battery.svg"
            }
            return map[Battery.icon] || "very-low-battery.svg"
        }
        readonly property bool batteryCharging: [
            "ABOVE85_CHG", "HIGH_CHG", "MED_CHG", "HALF_CHG",
            "BELOW_HALF_CHG", "LOW_CHG", "VERY_LOW_CHG"
        ].includes(Battery.icon)

        function truncate(s, n) {
            return s.length > n ? s.substring(0, n - 1) + "…" : s
        }

        implicitHeight: Theme.barHeight
        color: "transparent"
        exclusiveZone: 0
        surfaceFormat.opaque: false

        WlrLayershell.namespace: "bar-window"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            bottom: true
            left: false
            right: false
            top: false
        }

        margins.bottom: (bar.isHovered || bar.anyPopupOpen) ? Theme.gapSm : -Theme.barHeight

        Behavior on margins.bottom {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
        }

        implicitWidth: screen.width - Theme.gapMd * 1.5
        // height: Theme.barHeight

        readonly property real targetVisualWidth: Math.min(barContent.implicitWidth + Theme.gapMd * 2, bar.implicitWidth)

        property real visualWidth: targetVisualWidth
        Behavior on visualWidth {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutQuint
            }
        }

        mask: Region { item: barClip }

        HoverHandler {
            id: barHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    bar.isHovered = true
                    hideTimer.stop()
                } else {
                    hideTimer.restart()
                }
            }
        }

        Timer {
            id: hideTimer
            interval: 1000
            onTriggered: {
                if (!bar.anyPopupOpen)
                    bar.isHovered = false
            }
        }

        Component.onCompleted: {
            const elapsed = Date.now() - barCreationStart
            if (elapsed > barSlowLoadThresholdMs) {
                barContent.opacity = 0
                barContent.entranceBlur = Animations.slideBlurVerticalLength
                barContent.entranceBlurActive = true
                barEntranceAnim.start()
            }
            Qt.callLater(warmupPopups)
        }

        function warmupPopups() {
            const popups = [volumePopup, batteryPopup, notificationsPopup,
            wifiPopup, bluetoothPopup, dateTimePopup, musicPopup]
            for (const p of popups) {
                p.visible = true
                p.visible = false
                // force clean state so the next *real* open starts fresh
                if (p.glassPanel) {
                    p.glassPanel.entranceProgress = 1
                    p.glassPanel.exitProgress = 1
                }
            }
        }

        Connections {
            target: TransitionSync
            function onTransition() {
                themeBlurAnim.restart()
            }
        }

        Item {
            id: barClip
            anchors.centerIn: parent
            width: bar.visualWidth
            height: parent.height
            clip: true

            GlassPanel {
                id: glassPanel
                anchors.fill: parent
                radius: Theme.barHeight / 2

                Row {
                    id: barContent
                    anchors.centerIn: parent
                    spacing: Theme.gapMd

                    move: Transition {
                        NumberAnimation { properties: "x"; duration: 220; easing.type: Easing.OutQuint }
                    }

                    opacity: 1
                    property real entranceBlur: 0
                    property bool entranceBlurActive: false

                    property real themeBlurProgress: 0
                    property real themeBlurLength: Animations.blurEnvelope(themeBlurProgress) * Animations.wallpaperBlurLength
                    property bool themeBlurActive: false

                    layer.enabled: entranceBlurActive || themeBlurActive
                    layer.effect: DirectionalBlur {
                        angle: barContent.themeBlurActive ? Animations.wallpaperBlurAngle : Animations.slideBlurVerticalAngle
                        length: barContent.entranceBlur + barContent.themeBlurLength
                        samples: Animations.slideBlurSamples
                    }

                    ParallelAnimation {
                        id: barEntranceAnim
                        NumberAnimation {
                            target: barContent; property: "opacity"; to: 1
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                        }
                        NumberAnimation {
                            target: barContent; property: "entranceBlur"; to: 0
                            duration: Animations.slideBlurDuration
                            easing.type: Animations.slideBlurEasingOut
                        }
                        onStopped: barContent.entranceBlurActive = false
                    }

                    SequentialAnimation {
                        id: themeBlurAnim
                        PropertyAction { target: barContent; property: "themeBlurActive"; value: true }
                        NumberAnimation {
                            target: barContent; property: "themeBlurProgress"
                            from: 0; to: 1
                            duration: Animations.wallpaperCrossfadeDuration
                            easing.type: Animations.wallpaperCrossfadeEasing
                        }
                        PropertyAction { target: barContent; property: "themeBlurActive"; value: false }
                        PropertyAction { target: barContent; property: "themeBlurProgress"; value: 0 }
                    }

                    Row {
                        id: leftRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        move: Transition {
                            NumberAnimation { properties: "x"; duration: 220; easing.type: Easing.OutQuint }
                        }

                        ControlIcon {
                            iconSource: bar.iconDir + "power-btn.svg"
                            iconSize: 16
                            onActivated: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/rofi/powermenu.sh"])
                        }

                        Item {
                            id: musicTrayWrapper

                            readonly property bool active: MusicPlayerService.active
                            readonly property string displayTitle: bar.truncate(MusicPlayerService.title, 28)

                            implicitWidth: active ? musicIcon.implicitWidth : 0
                            width: implicitWidth
                            implicitHeight: musicIcon.implicitHeight
                            visible: width > 0 || opacity > 0
                            clip: true

                            Behavior on width {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutQuint
                                }
                            }
                            opacity: active ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Animations.slideBlurDuration
                                    easing.type: musicTrayWrapper.active
                                    ? Animations.slideBlurEasingOut
                                    : Animations.slideBlurEasingIn
                                }
                            }

                            property real blurLength: 0
                            readonly property real blurMagnitude: Animations.slideBlurHorizontalLength * 1.3

                            layer.enabled: blurLength > 0
                            layer.effect: DirectionalBlur {
                                angle: Animations.slideBlurHorizontalAngle
                                length: musicTrayWrapper.blurLength
                                samples: Animations.slideBlurSamples
                            }

                            SequentialAnimation {
                                id: blurPulse
                                NumberAnimation {
                                    target: musicTrayWrapper; property: "blurLength"
                                    to: musicTrayWrapper.blurMagnitude
                                    duration: Animations.slideBlurDuration * 0.35
                                    easing.type: Animations.slideBlurEasingIn
                                }
                                NumberAnimation {
                                    target: musicTrayWrapper; property: "blurLength"
                                    to: 0
                                    duration: Animations.slideBlurDuration * 0.35
                                    easing.type: Animations.slideBlurEasingOut
                                }
                            }

                            Connections {
                                target: MusicPlayerService
                                function onActiveChanged() { blurPulse.restart() }
                                function onTitleChanged() { blurPulse.restart() }
                            }

                            ControlIcon {
                                id: musicIcon
                                text: musicTrayWrapper.displayTitle
                                onActivated: musicPopup.toggle()
                            }
                        }
                    }

                    AppsTray {
                        id: appsTray
                        bar: bar
                        barScreen: bar.screen
                        leftRowWidth: leftRow.implicitWidth
                        rightRowWidth: rightRow.implicitWidth
                        tracking: popupTracking
                    }

                    Row {
                        id: rightRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        move: Transition {
                            NumberAnimation { properties: "x"; duration: 220; easing.type: Easing.OutQuint }
                        }

                        ControlIcon {
                            id: wifiIconItem
                            iconSource: bar.iconDir + (Wifi.radioOn ? "wifion.svg" : "wifi-off.svg")
                            onActivated: wifiPopup.toggle()
                        }

                        ControlIcon {
                            id: bluetoothIconItem
                            iconSource: bar.iconDir + (Bluetooth.radioOn ? "bluetooth-icon.svg" : "bluetooth-off.svg")
                            onActivated: bluetoothPopup.toggle()
                        }

                        ControlIcon {
                            id: volumeIconItem
                            iconSource: bar.iconDir + (Volume.muted ? "sound-mute.svg" : "sound.svg")
                            onActivated: volumePopup.toggle()
                        }

                        ControlIcon {
                            id: batteryIconItem
                            visible: Battery.hasBattery
                            implicitWidth: batteryRow.implicitWidth + 16
                            onActivated: batteryPopup.toggle()

                            Row {
                                id: batteryRow
                                anchors.centerIn: parent
                                spacing: 4

                                Item {
                                    id: boltSlot
                                    width: bar.batteryCharging || boltInner.opacity > 0 ? 10 : 0
                                    height: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: boltInner.opacity > 0

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Animations.scaleDuration(150)
                                            easing.type: Animations.slideBlurEasingOut
                                        }
                                    }

                                    Item {
                                        id: boltInner
                                        width: 12; height: 12
                                        opacity: 0

                                        property real shakeX: 0
                                        transform: Translate { x: boltInner.shakeX }

                                        layer.enabled: boltInner.opacity > 0
                                        layer.effect: DirectionalBlur {
                                            angle: Animations.slideBlurHorizontalAngle
                                            length: Math.max(
                                                (1 - boltInner.opacity) * 15,
                                                             Math.abs(boltInner.shakeX) * 4
                                            )
                                            samples: 12
                                        }

                                        Image {
                                            anchors.fill: parent
                                            source: bar.iconDir + "bolt.svg"
                                            sourceSize.width: 10; sourceSize.height: 10

                                            layer.enabled: true
                                            layer.effect: ColorOverlay {
                                                color: Theme.iconColor
                                            }
                                        }

                                        Component.onCompleted: {
                                            if (bar.batteryCharging) {
                                                boltInner.opacity = 1
                                                boltShakeAnim.start()
                                            }
                                        }

                                        Connections {
                                            target: bar
                                            function onBatteryChargingChanged() {
                                                if (bar.batteryCharging) {
                                                    boltExitAnim.stop()
                                                    boltShakeAnim.stop()
                                                    boltInner.shakeX = 0
                                                    boltEnterAnim.restart()
                                                } else {
                                                    boltEnterAnim.stop()
                                                    boltShakeAnim.stop()
                                                    boltInner.shakeX = 0
                                                    boltExitAnim.restart()
                                                }
                                            }
                                        }

                                        SequentialAnimation {
                                            id: boltEnterAnim
                                            NumberAnimation {
                                                target: boltInner; property: "opacity"; to: 1
                                                duration: Animations.scaleDuration(120)
                                                easing.type: Animations.slideBlurEasingOut
                                            }
                                            ScriptAction { script: boltShakeAnim.start() }
                                        }

                                        SequentialAnimation {
                                            id: boltExitAnim
                                            ScriptAction { script: boltShakeAnim.start() }
                                            PauseAnimation { duration: Animations.scaleDuration(275) }
                                            NumberAnimation {
                                                target: boltInner; property: "opacity"; to: 0
                                                duration: Animations.scaleDuration(120)
                                                easing.type: Animations.slideBlurEasingIn
                                            }
                                        }

                                        SequentialAnimation {
                                            id: boltShakeAnim
                                            NumberAnimation { target: boltInner; property: "shakeX"; to: -2.5; duration: Animations.scaleDuration(55); easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: boltInner; property: "shakeX"; to: 2.5; duration: Animations.scaleDuration(55); easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: boltInner; property: "shakeX"; to: -1.2; duration: Animations.scaleDuration(55); easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: boltInner; property: "shakeX"; to: 1.2; duration: Animations.scaleDuration(55); easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: boltInner; property: "shakeX"; to: 0; duration: Animations.scaleDuration(55); easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }

                                Item {
                                    width: 20; height: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.fill: parent
                                        source: bar.iconDir + bar.batteryIconFile()
                                        sourceSize.width: 20; sourceSize.height: 20

                                        layer.enabled: true
                                        layer.effect: ColorOverlay {
                                            color: Theme.iconColor
                                        }
                                    }
                                }
                                Text {
                                    text: Battery.capacity + "%"
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        ControlIcon {
                            visible: !Battery.hasBattery
                            iconSource: bar.iconDir + "plug.svg"
                        }

                        ControlIcon {
                            id: clockBtn
                            implicitWidth: clockCol.implicitWidth + 16
                            Column {
                                id: clockCol
                                anchors.centerIn: parent
                                spacing: 0
                                Text {
                                    text: Qt.formatTime(clock.date, "hh:mm")
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: Qt.formatDate(clock.date, "ddd dd MMM")
                                    color: Theme.isDark ? Qt.lighter(Theme.color3,1.5) : Qt.darker(Theme.color3, 2.8)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            onActivated: dateTimePopup.toggle()
                        }

                        ControlIcon {
                            id: bellIcon
                            iconSource: bar.iconDir + "bell.svg"
                            onActivated: notificationsPopup.toggle()

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: Theme.color1
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 0
                                anchors.rightMargin: 0
                                visible: Notifications.notificationCount > 0

                                Text {
                                    text: Notifications.notificationCount
                                    color: "white"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                    anchors.centerIn: parent
                                }
                            }
                        }
                    }
                }
            }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        VolumePopup {
            id: volumePopup
            tracking: popupTracking
            iconCenterOffset: popupTracking.offsetFromRight(volumeIconItem)
            barBottomOffset: popupTracking.barTopEdgeFromBottom
        }

        BatteryPopup {
            id: batteryPopup
            tracking: popupTracking
            iconCenterOffset: popupTracking.offsetFromRight(batteryIconItem)
            barBottomOffset: popupTracking.barTopEdgeFromBottom
        }
        NotificationsPopup {
            id: notificationsPopup
            tracking: popupTracking
            iconCenterOffset: popupTracking.offsetFromRight(bellIcon)
            barBottomOffset: popupTracking.barTopEdgeFromBottom
        }
        WifiPopup {
            id: wifiPopup
             tracking: popupTracking
            iconCenterOffset: popupTracking.offsetFromRight(wifiIconItem)
            barBottomOffset: popupTracking.barTopEdgeFromBottom
        }
        BluetoothPopup {
            id: bluetoothPopup
             tracking: popupTracking
            iconCenterOffset: popupTracking.offsetFromRight(bluetoothIconItem)
            barBottomOffset: popupTracking.barTopEdgeFromBottom
        }
        DateTimePopup {
            id: dateTimePopup
            tracking: popupTracking
            iconCenterOffset: popupTracking.offsetFromRight(clockBtn)
            barBottomOffset: popupTracking.barTopEdgeFromBottom
        }
        MusicPopup {
            id: musicPopup
            tracking: popupTracking
            barBottomOffset: popupTracking.barTopEdgeFromBottom
        }
    }
}
