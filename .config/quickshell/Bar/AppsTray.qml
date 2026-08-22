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

    property int maxTaskbarWidth: barScreen.width - leftRowWidth - rightRowWidth - Theme.gapMd * 4
    implicitWidth: visible ? Math.max(0, Math.min(taskbarList.contentWidth, maxTaskbarWidth)) : 0
    width: implicitWidth
    height: Theme.barHeight
    visible: ToplevelManager.toplevels.values.length > 0

    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutQuint }
    }

    ControlIcon {
        id: navLeft
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: taskbarList.contentWidth > appsTray.maxTaskbarWidth
        width: visible ? implicitWidth : 0
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
        clip: true
        glyph: "<"
        onActivated: {
            let target = Math.max(0, taskbarList.contentX - 200);
            taskbarListAnim.to = target;
            taskbarListAnim.start();
        }
    }

    ListView {
        id: taskbarList
        anchors.left: navLeft.right
        anchors.right: navRight.left
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.barHeight
        orientation: ListView.Horizontal
        clip: true
        spacing: 4

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutQuart }
            NumberAnimation { property: "scale"; from: 0.6; to: 1; duration: 160; easing.type: Easing.OutQuart }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuart }
            NumberAnimation { property: "scale"; to: 0.6; duration: 120; easing.type: Easing.InQuart }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutQuint }
        }

        property var appOrder: []
        property var groupedApps: []

        function syncGroupedApps() {
            const vals = ToplevelManager.toplevels.values

            const byAppId = {}
            for (let i = 0; i < vals.length; i++) {
                const tl = vals[i]
                const appId = tl.appId ?? ""
                if (!byAppId[appId]) {
                    byAppId[appId] = []
                }
                byAppId[appId].push(tl)
            }

            taskbarList.appOrder = taskbarList.appOrder.filter(id => byAppId[id] !== undefined)
            for (const appId in byAppId) {
                if (taskbarList.appOrder.indexOf(appId) === -1)
                    taskbarList.appOrder.push(appId)
            }

            taskbarList.groupedApps = taskbarList.appOrder.map(id => ({ appId: id, windows: byAppId[id] }))
        }

        Connections {
            target: ToplevelManager.toplevels
            function onValuesChanged() { taskbarList.syncGroupedApps() }
        }

        Component.onCompleted: taskbarList.syncGroupedApps()

        model: ScriptModel {
            values: taskbarList.groupedApps
            objectProp: "appId"
        }

        property var iconCache: ({})

        property var hoveredEntry: null
        property var pendingHoverEntry: null
        property var contextMenuEntry: null

        Timer {
            id: hoverDelay
            interval: 200
            onTriggered: taskbarList.hoveredEntry = taskbarList.pendingHoverEntry
        }

        Timer {
            id: hideDelay
            interval: 250
            property var pendingHideEntry: null
            onTriggered: {
                if (taskbarList.hoveredEntry === hideDelay.pendingHideEntry)
                    taskbarList.hoveredEntry = null
            }
        }

        Timer {
            id: contextMenuHideDelay
            interval: 250
            property var pendingHideEntry: null
            onTriggered: {
                if (taskbarList.contextMenuEntry === contextMenuHideDelay.pendingHideEntry)
                    taskbarList.contextMenuEntry = null
            }
        }

        // Builds an ordered list of icon sources to try for a given appId,
        // widest-match first. Covers the cases that used to fall through to
        // a broken-image glyph:
        //  - reverse-DNS appIds (org.kde.dolphin) whose .desktop file is
        //    only keyed on the trailing segment ("dolphin")
        //  - Icon= values that are absolute file paths rather than
        //    icon-theme names (fed in as file:// instead of through
        //    Quickshell.iconPath, which expects theme names)
        //  - appId casing mismatches against the theme's icon names
        // Result is cached per appId, same as the old iconCache.
        function resolveIconCandidates(appId) {
            if (appId in taskbarList.iconCache)
                return taskbarList.iconCache[appId]

                const lower = appId.toLowerCase()
                const tail = appId.includes(".") ? appId.split(".").pop() : ""
                const tailLower = tail.toLowerCase()

                const entries = [
                    DesktopEntries.heuristicLookup(appId),
                    DesktopEntries.heuristicLookup(lower),
                    tail ? DesktopEntries.heuristicLookup(tail) : null,
                    tailLower && tailLower !== lower ? DesktopEntries.heuristicLookup(tailLower) : null
                ]

                const names = []
                const pushName = (n) => { if (n && names.indexOf(n) === -1) names.push(n) }

                for (const e of entries) pushName(e?.icon)
                    pushName(appId)
                    pushName(lower)
                    pushName(tail)
                    pushName(tailLower)

                    const candidates = []
                    for (const n of names) {
                        const src = n.startsWith("/") ? ("file://" + n) : Quickshell.iconPath(n, "")
                        if (src && candidates.indexOf(src) === -1) candidates.push(src)
                    }

                    taskbarList.iconCache[appId] = candidates
                    return candidates
        }

        NumberAnimation {
            id: taskbarListAnim
            target: taskbarList
            property: "contentX"
            duration: 300
            easing.type: Easing.OutQuart
        }

        WheelHandler {
            id: taskbarWheel
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                taskbarListAnim.stop()
                const delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                const maxX = Math.max(0, taskbarList.contentWidth - taskbarList.width)
                taskbarList.contentX = Math.max(0, Math.min(maxX, taskbarList.contentX - delta))
            }
        }

        delegate: Item {
            id: taskDelegate
            required property var modelData

            readonly property bool groupActivated: modelData.windows.some(w => w.activated)
            readonly property var targetWindow: modelData.windows.find(w => w.activated) ?? modelData.windows[0]

            implicitWidth: Theme.barHeight
            implicitHeight: Theme.barHeight

            Component.onDestruction: {
                hoverDelay.stop()
                hideDelay.stop()
                contextMenuHideDelay.stop()
                if (taskbarList.pendingHoverEntry === taskDelegate) {
                    taskbarList.pendingHoverEntry = null
                }
                if (taskbarList.hoveredEntry === taskDelegate) {
                    taskbarList.hoveredEntry = null
                }
                if (taskbarList.contextMenuEntry === taskDelegate) {
                    taskbarList.contextMenuEntry = null
                }
                if (hideDelay.pendingHideEntry === taskDelegate) {
                    hideDelay.pendingHideEntry = null
                }
                if (contextMenuHideDelay.pendingHideEntry === taskDelegate) {
                    contextMenuHideDelay.pendingHideEntry = null
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: taskMouse.containsMouse
                ? Qt.rgba(Theme.hoverBg.r, Theme.hoverBg.g, Theme.hoverBg.b, 0.35)
                : (taskDelegate.groupActivated ? Qt.rgba(Theme.hoverBg.r, Theme.hoverBg.g, Theme.hoverBg.b, 0.18) : "transparent")
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            Loader {
                id: taskIconLoader
                anchors.centerIn: parent
                width: 16
                height: 16
                active: true

                // Breeze icons are palette-recolored at decode time, and
                // per apply-theme.sh's own notes, already-running processes
                // never get that pushed live. Closing/reopening an app works
                // because it destroys and recreates this ListView delegate,
                // forcing a fresh IconImage decode against the new colors.
                // This reproduces that same destroy/recreate trigger on
                // every theme change instead, without needing the app itself
                // restarted.
                property var themeKey: Theme.palette
                onThemeKeyChanged: {
                    active = false
                    active = true
                }

                sourceComponent: Component {
                    Item {
                        id: iconRoot
                        anchors.fill: parent

                        property var candidates: taskbarList.resolveIconCandidates(taskDelegate.modelData.appId ?? "")
                        property int candidateIndex: 0
                        readonly property bool exhausted: candidateIndex >= candidates.length

                        IconImage {
                            id: taskIcon
                            anchors.fill: parent
                            asynchronous: false   // was: true
                            visible: !iconRoot.exhausted
                            source: iconRoot.exhausted ? "" : iconRoot.candidates[iconRoot.candidateIndex]
                            onStatusChanged: {
                                if (status === Image.Error)
                                    iconRoot.candidateIndex++
                            }
                        }

                        // Last-resort fallback once every candidate has
                        // failed: an initial-letter avatar instead of Qt's
                        // broken-image glyph, so nothing ever renders as a
                        // visibly-missing icon.
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            visible: iconRoot.exhausted
                            color: Theme.hoverBg
                            Text {
                                anchors.centerIn: parent
                                text: (taskDelegate.modelData.appId ?? "?").charAt(0).toUpperCase() || "?"
                                color: Theme.foreground
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }
                }
            }

            Row {
                id: windowDots
                visible: modelData.windows.length > 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                spacing: 2

                Repeater {
                    model: Math.min(modelData.windows.length, 5)
                    delegate: Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Theme.foreground
                    }
                }
            }

            Rectangle {
                id: overflowBadge
                visible: modelData.windows.length > 5
                width: 11
                height: 11
                radius: 3
                color: Theme.color1
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 0
                anchors.rightMargin: 0

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: "white"
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            MouseArea {
                id: taskMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        hoverDelay.stop()
                        hideDelay.stop()
                        taskbarList.pendingHoverEntry = null
                        taskbarList.hoveredEntry = null
                        contextMenuHideDelay.stop()
                        taskbarList.contextMenuEntry =
                        (taskbarList.contextMenuEntry === taskDelegate) ? null : taskDelegate
                    } else {
                        if (appsTray.bar.isMinimizedFake(taskDelegate.targetWindow)) {
                            appsTray.bar.toggleMinimize(taskDelegate.targetWindow)
                        } else {
                            taskDelegate.targetWindow.minimized = false
                            taskDelegate.targetWindow.activate()
                        }
                    }
                }
            }

            HoverHandler {
                id: iconHover
                onHoveredChanged: {
                    if (hovered) {
                        hideDelay.stop()
                        taskbarList.pendingHoverEntry = taskDelegate
                        hoverDelay.restart()
                        if (taskbarList.contextMenuEntry === taskDelegate)
                            contextMenuHideDelay.stop()
                    } else {
                        hoverDelay.stop()
                        if (taskbarList.hoveredEntry === taskDelegate) {
                            hideDelay.pendingHideEntry = taskDelegate
                            hideDelay.restart()
                        }
                        if (taskbarList.contextMenuEntry === taskDelegate) {
                            contextMenuHideDelay.pendingHideEntry = taskDelegate
                            contextMenuHideDelay.restart()
                        }
                    }
                }
            }

            // PanelWindow (not PopupWindow) — real layer-shell surface, so
            // Hyprland's layer_rule (namespace, blur, ignore_alpha) can
            // actually attach to it. Positioning uses PopupTracking's
            // offsetFromLeftItem (mapToItem-based, handles the ListView
            // delegate's nested/scrolled position correctly), same as
            // every other popup in Bar.qml uses offsetFromLeft/Right.
            Loader {
                id: thumbLoader
                active: taskbarList.hoveredEntry === taskDelegate
                asynchronous: false
                sourceComponent: Component {
                    PanelWindow {
                        id: thumbPopup
                        screen: barScreen
                        visible: false

                        WlrLayershell.namespace: "quickshell:taskbar-thumb"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                        color: "transparent"
                        exclusiveZone: 0

                        readonly property int thumbW: 200
                        readonly property int thumbH: 120
                        readonly property int thumbSpacing: 6
                        readonly property int thumbColumns: Math.min(3, taskDelegate.modelData.windows.length)

                        readonly property var thumbRowsList: {
                            const rows = []
                            const windows = taskDelegate.modelData.windows
                            for (let i = 0; i < windows.length; i += thumbColumns)
                                rows.push(windows.slice(i, i + thumbColumns))
                                return rows.reverse()
                        }

                        implicitWidth: thumbColumns * thumbW + (thumbColumns - 1) * thumbSpacing + 8
                        implicitHeight: thumbRowsList.length * thumbH + Math.max(0, thumbRowsList.length - 1) * thumbSpacing + 8

                        anchors { bottom: true; left: true }
                        margins {
                            bottom: appsTray.tracking.barTopEdgeFromBottom
                            left: Math.max(0, appsTray.tracking.offsetFromLeftItem(taskDelegate) - implicitWidth / 2)
                        }

                        Component.onCompleted: thumbPopup.visible = true

                        GlassPanel {
                            id: thumbGlass
                            anchors.fill: parent
                            radius: Theme.radiusSm

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: thumbPopup.thumbSpacing

                                Repeater {
                                    model: thumbPopup.thumbRowsList
                                    delegate: Row {
                                        id: thumbRow
                                        required property var modelData
                                        spacing: thumbPopup.thumbSpacing

                                        Repeater {
                                            model: thumbRow.modelData
                                            delegate: Rectangle {
                                                id: thumbCell
                                                required property var modelData
                                                width: thumbPopup.thumbW
                                                height: thumbPopup.thumbH
                                                color: Theme.background
                                                radius: Theme.radiusSm
                                                border.color: Theme.hoverBg
                                                border.width: 1
                                                clip: true

                                                HoverHandler {
                                                    id: thumbCellHover
                                                    onHoveredChanged: {
                                                        if (hovered) {
                                                            hideDelay.stop()
                                                        } else {
                                                            if (taskbarList.hoveredEntry === taskDelegate) {
                                                                hideDelay.pendingHideEntry = taskDelegate
                                                                hideDelay.restart()
                                                            }
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: parent.radius
                                                    color: Qt.rgba(1, 1, 1, 0.06)
                                                    visible: thumbCellHover.hovered
                                                }

                                                QtObject {
                                                    id: thumbRefreshPulse
                                                    property bool pulsing: false
                                                }

                                                Timer {
                                                    id: thumbInitialCapture
                                                    interval: 500
                                                    running: true
                                                    onTriggered: thumbRefreshPulse.pulsing = true
                                                }

                                                ScreencopyView {
                                                    id: screencopyView
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    live: thumbRefreshPulse.pulsing
                                                    captureSource: thumbCell.modelData
                                                }

                                                Timer {
                                                    id: thumbRefreshTimer
                                                    interval: 7000
                                                    repeat: true
                                                    running: true
                                                    onTriggered: thumbRefreshPulse.pulsing = true
                                                }

                                                Timer {
                                                    id: thumbRefreshOff
                                                    interval: 400
                                                    running: thumbRefreshPulse.pulsing
                                                    onTriggered: thumbRefreshPulse.pulsing = false
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        if (appsTray.bar.isMinimizedFake(thumbCell.modelData)) {
                                                            appsTray.bar.toggleMinimize(thumbCell.modelData)
                                                        } else {
                                                            thumbCell.modelData.minimized = false
                                                            thumbCell.modelData.activate()
                                                        }
                                                        taskbarList.hoveredEntry = null
                                                    }
                                                }

                                                Rectangle {
                                                    width: 18
                                                    height: 18
                                                    radius: 4
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.topMargin: 0
                                                    anchors.rightMargin: 0
                                                    color: closeMouse.containsMouse ? Theme.color1 : Qt.rgba(0, 0, 0, 0.4)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "×"
                                                        color: "white"
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        id: closeMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: {
                                                            thumbCell.modelData.close()
                                                            taskbarList.hoveredEntry = null
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
                }
            }

            // Same PanelWindow + tracking.offsetFromLeftItem pattern for the context menu.
            Loader {
                id: contextMenuLoader
                active: taskbarList.contextMenuEntry === taskDelegate
                asynchronous: false
                sourceComponent: Component {
                    PanelWindow {
                        id: contextMenuPopup
                        screen: barScreen
                        visible: false

                        WlrLayershell.namespace: "quickshell:taskbar-menu"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                        color: "transparent"
                        exclusiveZone: 0

                        implicitWidth: 130
                        implicitHeight: menuColumn.implicitHeight + 8

                        anchors { bottom: true; left: true }
                        margins {
                            bottom: appsTray.tracking.barTopEdgeFromBottom
                            left: Math.max(0, appsTray.tracking.offsetFromLeftItem(taskDelegate) - implicitWidth / 2)
                        }

                        Component.onCompleted: contextMenuPopup.visible = true

                        GlassPanel {
                            id: contextMenuGlass
                            anchors.fill: parent
                            radius: Theme.radiusSm
                            clip: true

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered) {
                                        contextMenuHideDelay.stop()
                                    } else {
                                        if (taskbarList.contextMenuEntry === taskDelegate) {
                                            contextMenuHideDelay.pendingHideEntry = taskDelegate
                                            contextMenuHideDelay.restart()
                                        }
                                    }
                                }
                            }

                            Column {
                                id: menuColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                spacing: 2

                                Rectangle {
                                    width: parent.width
                                    height: 28
                                    radius: Theme.radiusSm
                                    color: minimizeMouse.containsMouse ? Theme.hoverBg : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: appsTray.bar.isMinimizedFake(taskDelegate.targetWindow) ? "Show" : "Minimize"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }

                                    MouseArea {
                                        id: minimizeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            appsTray.bar.toggleMinimize(taskDelegate.targetWindow)
                                            taskbarList.contextMenuEntry = null
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 28
                                    radius: Theme.radiusSm
                                    color: closeMenuMouse.containsMouse ? Theme.hoverBg : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Close All"
                                        color: Theme.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                    }

                                    MouseArea {
                                        id: closeMenuMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            taskbarList.contextMenuEntry = null
                                            appsTray.bar.closeAll(taskDelegate.modelData.windows)
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

    ControlIcon {
        id: navRight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: taskbarList.contentWidth > appsTray.maxTaskbarWidth
        width: visible ? implicitWidth : 0
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
        clip: true
        glyph: ">"
        onActivated: {
            let target = Math.min(taskbarList.contentWidth - taskbarList.width, taskbarList.contentX + 200);
            taskbarListAnim.to = target;
            taskbarListAnim.start();
        }
    }
}
