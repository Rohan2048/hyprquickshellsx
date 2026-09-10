import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../Theme"
import "../Widgets"
import "../Services"
import "./modules"

Item {
    id: appsTray
    required property var bar
    required property var barScreen
    required property real leftRowWidth
    required property real rightRowWidth
    required property var tracking

    readonly property alias hoveredEntry: taskbarList.hoveredEntry
    readonly property alias contextMenuEntry: taskbarList.contextMenuEntry

    property int maxTaskbarWidth: barScreen.width - leftRowWidth - rightRowWidth - (Theme.gapMd * 4)
    implicitWidth: visible ? Math.max(0, Math.min(taskbarList.contentWidth, maxTaskbarWidth)) : 0
    width: implicitWidth
    height: Theme.barHeight
    visible: ToplevelManager.toplevels.values.length > 0

    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

    Timer {
        id: syncTimer
        interval: 50
        onTriggered: taskbarList.syncGroupedApps()
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { syncTimer.restart() }
    }

    // ============================================================
    // SHARED THUMBNAIL POPUP
    // ============================================================
    PanelWindow {
        id: sharedThumbPopup
        screen: barScreen

        property bool shown: taskbarList.hoveredEntry !== null
        property bool alive: false
        visible: alive

        WlrLayershell.namespace: "quickshell:taskbar-thumb"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        // --- STABILITY & JITTER FIX ---
        property var lastEntry: null
        readonly property var currentEntry: taskbarList.hoveredEntry

        // Geometry Locks: These prevent the window from moving or resizing on exit
        property int lockedWidth: 200
        property int lockedHeight: 120
        property int lockedX: 0

        onCurrentEntryChanged: {
            if (currentEntry) {
                lastEntry = currentEntry
                // Update geometry instantly when hovering a new icon
                var targetW = (thumbCols * thumbW) + ((thumbCols - 1) * thumbSpacing) + 8
                var targetH = actualContentHeight + 30 // Gutter for vertical slide
                var targetX = Math.max(0, appsTray.tracking.offsetFromLeftItem(currentEntry) - (targetW / 2))

                lockedWidth = targetW
                lockedHeight = targetH
                lockedX = targetX
            }
        }

        // Apply locked geometry
        implicitWidth: lockedWidth
        implicitHeight: lockedHeight
        margins.left: lockedX
        anchors.bottom: true
        anchors.left: true
        margins.bottom: appsTray.tracking.barTopEdgeFromBottom

        readonly property var currentGroup: lastEntry ? lastEntry.modelData : null
        readonly property var currentWindows: currentGroup ? currentGroup.windows : []
        readonly property int thumbW: 200
        readonly property int thumbH: 120
        readonly property int thumbSpacing: 6
        readonly property int thumbCols: currentWindows.length > 0 ? Math.min(3, currentWindows.length) : 1
        readonly property var thumbRowsList: {
            var rows = []; var windows = currentWindows;
            for (var i = 0; i < windows.length; i += thumbCols) {
                rows.push(windows.slice(i, i + thumbCols))
            }
            return rows.reverse()
        }
        readonly property int actualContentHeight: Math.min((3 * thumbH) + (2 * thumbSpacing) + 8, (thumbRowsList.length * thumbH) + (Math.max(0, thumbRowsList.length - 1) * thumbSpacing) + 8)

        onShownChanged: {
            if (shown) { closeTimer.stop(); alive = true }
            else { closeTimer.restart() }
        }
        Timer { id: closeTimer; interval: 260; onTriggered: sharedThumbPopup.alive = false }

        // --- VISUAL CONTENT ---
        GlassPanel {
            id: thumbPanelContainer
            width: parent.width
            height: sharedThumbPopup.actualContentHeight
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2// Floating gap
            radius: Theme.radiusSm

            opacity: sharedThumbPopup.shown ? 1 : 0
            transform: Translate {
                // Vertical-only slide: enters from +25px (down), exits to +25px (down)
                y: sharedThumbPopup.shown ? 0 : 25
                Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Flickable {
                id: thumbFlickable
                anchors.fill: parent; anchors.margins: 4
                contentWidth: thumbContent.width; contentHeight: thumbContent.height
                clip: true; interactive: sharedThumbPopup.thumbRowsList.length > 3

                WheelHandler {
                    target: thumbFlickable
                    onWheel: (event) => {
                        var move = thumbFlickable.contentY - event.angleDelta.y
                        var max = thumbFlickable.contentHeight - thumbFlickable.height
                        thumbFlickable.contentY = Math.max(0, Math.min(max, move))
                    }
                }

                Column {
                    id: thumbContent; width: thumbFlickable.width; spacing: sharedThumbPopup.thumbSpacing
                    Repeater {
                        model: sharedThumbPopup.thumbRowsList
                        delegate: Row {
                            id: thumbRow; required property var modelData; spacing: sharedThumbPopup.thumbSpacing
                            Repeater {
                                model: thumbRow.modelData
                                delegate: Rectangle {
                                    id: thumbCell; required property var modelData; width: 200; height: 120
                                    color: Theme.background; radius: Theme.radiusSm
                                    border.color: cellMouse.containsMouse ? Theme.color1 : Theme.hoverBg
                                    border.width: cellMouse.containsMouse ? 2 : 1
                                    clip: true

                                    ScreencopyView {
                                        anchors.fill: parent; anchors.margins: 4
                                        captureSource: thumbCell.modelData
                                        live: (cellMouse.containsMouse || sharedThumbPopup.isLivePulse) && sharedThumbPopup.visible
                                        layer.enabled: true
                                        layer.textureSize: Qt.size(400, 240)
                                        layer.smooth: true
                                    }

                                    MouseArea {
                                        id: cellMouse; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { appsTray.bar.activateWindow(thumbCell.modelData); taskbarList.hoveredEntry = null }
                                    }

                                    Rectangle {
                                        width: 18; height: 18; radius: 4; anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                                        color: closeMouse.containsMouse ? Theme.color1 : Qt.rgba(0, 0, 0, 0.4)
                                        Text { anchors.centerIn: parent; text: "×"; color: "white"; font.bold: true }
                                        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: thumbCell.modelData.close() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        property bool isLivePulse: false
        Timer {
            id: pulseTimer
            interval: 5000; repeat: true; running: sharedThumbPopup.visible; triggeredOnStart: true
            onTriggered: { sharedThumbPopup.isLivePulse = true; stopPulseTimer.restart() }
        }
        Timer { id: stopPulseTimer; interval: 2000; onTriggered: sharedThumbPopup.isLivePulse = false }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) { hideDelay.stop(); appsTray.bar.isHovered = true }
                else { hideDelay.pendingHideEntry = taskbarList.hoveredEntry; hideDelay.restart() }
            }
        }
    }

    // ============================================================
    // SHARED CONTEXT MENU
    // ============================================================
    PanelWindow {
        id: sharedMenuPopup
        screen: barScreen

        property bool shown: taskbarList.contextMenuEntry !== null
        property bool alive: false
        visible: alive

        WlrLayershell.namespace: "quickshell:taskbar-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        property var lastMenuEntry: null
        property int lockedX: 0
        readonly property var currentEntry: taskbarList.contextMenuEntry

        onCurrentEntryChanged: {
            if (currentEntry) {
                lastMenuEntry = currentEntry
                lockedX = Math.max(0, appsTray.tracking.offsetFromLeftItem(currentEntry) - (130 / 2))
            }
        }

        implicitWidth: 130
        implicitHeight: menuColumn.implicitHeight + 25
        anchors.bottom: true; anchors.left: true
        margins.bottom: appsTray.tracking.barTopEdgeFromBottom
        margins.left: lockedX

        onShownChanged: {
            if (shown) { menuCloseTimer.stop(); alive = true }
            else { menuCloseTimer.restart() }
        }
        Timer { id: menuCloseTimer; interval: 250; onTriggered: sharedMenuPopup.alive = false }

        GlassPanel {
            anchors.fill: parent; anchors.bottomMargin: 10; radius: Theme.radiusSm
            opacity: sharedMenuPopup.shown ? 1 : 0
            transform: Translate {
                y: sharedMenuPopup.shown ? 0 : 15
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Column {
                id: menuColumn; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 7; spacing: 2
                Repeater {
                    model: [
                        { text: (sharedMenuPopup.lastMenuEntry && appsTray.bar.isMinimizedFake(sharedMenuPopup.lastMenuEntry.targetWindow) ? "Show" : "Minimize"), action: "toggle" },
                        { text: "Close All", action: "close" }
                    ]
                    delegate: Rectangle {
                        width: parent.width; height: 28; radius: Theme.radiusSm
                        color: mArea.containsMouse ? Theme.hoverBg : "transparent"
                        Text { anchors.centerIn: parent; width: parent.width; text: modelData.text; color: Theme.foreground; font.family: Theme.fontFamily; horizontalAlignment: Text.AlignHCenter }
                        MouseArea {
                            id: mArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                var target = sharedMenuPopup.lastMenuEntry
                                if (!target) return
                                    if (modelData.action === "toggle") appsTray.bar.toggleMinimize(target.targetWindow)
                                        else appsTray.bar.closeAll(target.modelData.windows.slice())
                                            taskbarList.contextMenuEntry = null
                            }
                        }
                    }
                }
            }
        }
        HoverHandler {
            onHoveredChanged: {
                if (hovered) contextMenuHideDelay.stop()
                    else { contextMenuHideDelay.pendingHideEntry = taskbarList.contextMenuEntry; contextMenuHideDelay.restart() }
            }
        }
    }

    // ============================================================
    // TRAY CORE
    // ============================================================
    ControlIcon {
        id: navLeft
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        visible: taskbarList.contentWidth > appsTray.maxTaskbarWidth
        width: visible ? implicitWidth : 0
        glyph: "<"
        onActivated: { taskbarListAnim.to = Math.max(0, taskbarList.contentX - 200); taskbarListAnim.start() }
    }

    ListView {
        id: taskbarList
        anchors.left: navLeft.right; anchors.right: navRight.left; anchors.verticalCenter: parent.verticalCenter
        height: Theme.barHeight; orientation: ListView.Horizontal; clip: true; spacing: 4

        property var appOrder: []
        property var groupedApps: []
        property var hoveredEntry: null
        property var pendingHoverEntry: null
        property var contextMenuEntry: null
        property var iconCache: ({})

        function syncGroupedApps() {
            var vals = ToplevelManager.toplevels.values
            var byAppId = {}
            for (var i = 0; i < vals.length; i++) {
                var id = vals[i].appId ?? "unknown"
                if (!byAppId[id]) byAppId[id] = []
                    byAppId[id].push(vals[i])
            }
            taskbarList.appOrder = taskbarList.appOrder.filter(function(id) { return byAppId[id] !== undefined })
            for (var id in byAppId) {
                if (taskbarList.appOrder.indexOf(id) === -1) taskbarList.appOrder.push(id)
            }
            taskbarList.groupedApps = taskbarList.appOrder.map(function(id) { return { appId: id, windows: byAppId[id] } })
        }

        Component.onCompleted: syncGroupedApps()
        model: ScriptModel { values: taskbarList.groupedApps; objectProp: "appId" }

        Timer { id: hoverDelay; interval: 200; onTriggered: taskbarList.hoveredEntry = taskbarList.pendingHoverEntry }
        Timer { id: hideDelay; interval: 250; property var pendingHideEntry: null; onTriggered: { if (taskbarList.hoveredEntry === pendingHideEntry && !bar.isTriggerHovered) taskbarList.hoveredEntry = null } }
        Timer { id: contextMenuHideDelay; interval: 250; property var pendingHideEntry: null; onTriggered: { if (taskbarList.contextMenuEntry === pendingHideEntry) taskbarList.contextMenuEntry = null } }

        function resolveIconCandidates(appId) {
            if (appId in taskbarList.iconCache) return taskbarList.iconCache[appId]
                var lower = appId.toLowerCase()
                var tail = appId.includes(".") ? appId.split(".").pop() : ""
                var names = [appId, lower, tail].filter(function(n) { return n !== "" })

                var candidates = []
                for (var i = 0; i < names.length; i++) {
                    var entry = DesktopEntries.heuristicLookup(names[i])
                    var icon = entry ? entry.icon : names[i]
                    var src = icon.startsWith("/") ? ("file://" + icon) : Quickshell.iconPath(icon, "")
                    if (src && candidates.indexOf(src) === -1) candidates.push(src)
                }

                taskbarList.iconCache[appId] = candidates
                return candidates
        }

        NumberAnimation { id: taskbarListAnim; target: taskbarList; property: "contentX"; duration: 300; easing.type: Easing.OutQuart }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                taskbarListAnim.stop()
                var delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                taskbarList.contentX = Math.max(0, Math.min(taskbarList.contentWidth - taskbarList.width, taskbarList.contentX - delta))
            }
        }

        delegate: Item {
            id: taskDelegate
            required property var modelData
            readonly property bool groupActivated: modelData.windows.some(function(w) { return w.activated })
            readonly property var targetWindow: modelData.windows.find(function(w) { return w.activated }) ?? modelData.windows[0]
            implicitWidth: Theme.barHeight; implicitHeight: Theme.barHeight

            Rectangle {
                anchors.fill: parent; radius: Theme.radiusSm
                color: taskMouse.containsMouse ? Qt.rgba(Theme.hoverBg.r, Theme.hoverBg.g, Theme.hoverBg.b, 0.35)
                : (groupActivated ? Qt.rgba(Theme.hoverBg.r, Theme.hoverBg.g, Theme.hoverBg.b, 0.18) : "transparent")
            }

            Loader {
                anchors.centerIn: parent; width: 16; height: 16
                property var themeKey: Theme.palette
                sourceComponent: Item {
                    property var candidates: taskbarList.resolveIconCandidates(taskDelegate.modelData.appId ?? "")
                    property int candidateIndex: 0
                    IconImage {
                        anchors.fill: parent; visible: candidateIndex < candidates.length
                        source: visible ? candidates[candidateIndex] : ""
                        onStatusChanged: if (status === Image.Error) candidateIndex++
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 3; visible: candidateIndex >= candidates.length; color: Theme.hoverBg
                        Text { anchors.centerIn: parent; text: (taskDelegate.modelData.appId ?? "?")[0].toUpperCase(); color: Theme.foreground; font.pixelSize: 10; font.bold: true }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 2; spacing: 2
                visible: modelData.windows.length > 1
                Repeater {
                    model: Math.min(modelData.windows.length, 5)
                    delegate: Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.foreground }
                }
            }

            Rectangle {
                visible: modelData.windows.length > 5; width: 11; height: 11; radius: 3; color: Theme.color1
                anchors.top: parent.top; anchors.right: parent.right
                Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 9; font.bold: true }
            }

            MouseArea {
                id: taskMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        taskbarList.hoveredEntry = null
                        taskbarList.contextMenuEntry = (taskbarList.contextMenuEntry === taskDelegate) ? null : taskDelegate
                    } else {
                        appsTray.bar.activateWindow(taskDelegate.targetWindow)
                    }
                }
            }

            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        hideDelay.stop(); taskbarList.pendingHoverEntry = taskDelegate; hoverDelay.restart()
                    } else {
                        hoverDelay.stop()
                        if (taskbarList.hoveredEntry === taskDelegate) { hideDelay.pendingHideEntry = taskDelegate; hideDelay.restart() }
                    }
                }
            }
        }
    }

    ControlIcon {
        id: navRight
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        visible: taskbarList.contentWidth > appsTray.maxTaskbarWidth
        width: visible ? implicitWidth : 0
        glyph: ">"
        onActivated: { taskbarListAnim.to = Math.min(taskbarList.contentWidth - taskbarList.width, taskbarList.contentX + 200); taskbarListAnim.start() }
    }
}
