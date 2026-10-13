pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Services"
import "../Theme"

// Music file picker (grid). Toggle with the "musicPickerToggle" global
// shortcut or:  qs ipc call musicPicker toggle
//
// Keys:  type = filter   arrows = move   Enter = open folder / play file
//        Backspace = parent folder   Ctrl+Enter = play current folder
//        Esc = clear filter / close
PanelWindow {
    id: picker

    property int selected: 0
    readonly property int columns: 5
    property bool shown: false
    readonly property int fadeMs: Animations.panelFadeDuration

    WlrLayershell.namespace: "quickshell:musicPicker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Window is panel-sized plus a 12px margin (room for the spring overshoot)
    // instead of a fullscreen layer surface, so there is far less to composite.
    implicitWidth: 664
    implicitHeight: 524
    color: "transparent"

    // Quickshell tears the whole window down when `visible` goes false, so
    // every open used to rebuild the GL context, all textures, every icon
    // layer and the shader pipelines -- that was the GPU spike. After the
    // startup preload the window therefore stays mapped, fully transparent
    // and input-transparent (empty mask), and open/close only fade the panel.
    // Set keepMapped to false to go back to map-on-open (spiky, but no
    // surface exists while closed).
    property bool keepMapped: true
    property bool _forceMap: false
    visible: shown || _forceMap || (keepMapped && MusicPicker.ready)
    mask: shown ? null : emptyMask
    Region { id: emptyMask }

    function open() {
        hideTimer.stop()
        MusicPicker.start()
        selected = 0
        if (picker.visible) {
            shown = true
        } else {
            // Opened before the preload mapped the window: let the surface
            // commit its first frame before the fade starts.
            _forceMap = true
            showTimer.restart()
        }
    }
    function close() {
        showTimer.stop()
        shown = false
        hideTimer.restart()
    }
    function toggle() { shown ? close() : open() }

    // Device hot-plug monitoring only runs while the picker is open.
    onShownChanged: MusicPicker.watching = shown

    Timer {
        id: showTimer
        interval: 32
        onTriggered: picker.shown = true
    }

    Timer {
        id: hideTimer
        interval: picker.fadeMs + 60
        onTriggered: picker._forceMap = false
    }

    ClickAwayCloser {
        targetWindows: [picker]
        active: picker.shown
        onDismissed: picker.close()
    }

    function activate(i) {
        const r = MusicPicker.rows[i]
        if (!r) return
            if (r.kind === "up") MusicPicker.up()
                else if (r.isDir) MusicPicker.enter(r.path)
                    else { MusicPicker.play(r.path, false); close() }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "musicPickerToggle"
        description: "Toggle music file picker"
        onPressed: picker.toggle()
    }

    IpcHandler {
        target: "musicPicker"
        function toggle() { picker.toggle() }
        function open() { picker.open() }
        function close() { picker.close() }
    }

    Connections {
        target: MusicPicker
        function onRowsChanged() {
            picker.selected = Math.min(picker.selected, Math.max(0, MusicPicker.rows.length - 1))
        }
        function onPathChanged() { picker.selected = 0 }
        function onFilterChanged() { picker.selected = 0 }
    }


    FocusScope {
        anchors.fill: parent
        focus: picker.shown

        Keys.onPressed: (event) => {
            const n = MusicPicker.rows.length
            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
            switch (event.key) {
                case Qt.Key_Escape:
                    if (MusicPicker.filter !== "") MusicPicker.filter = ""
                        else picker.close()
                            break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (ctrl) { MusicPicker.play(MusicPicker.path, true); picker.close() }
                    else picker.activate(picker.selected)
                        break
                case Qt.Key_Right: picker.selected = Math.min(n - 1, picker.selected + 1); break
                case Qt.Key_Left: picker.selected = Math.max(0, picker.selected - 1); break
                case Qt.Key_Down: picker.selected = Math.min(n - 1, picker.selected + picker.columns); break
                case Qt.Key_Up: picker.selected = Math.max(0, picker.selected - picker.columns); break
                case Qt.Key_PageDown: picker.selected = Math.min(n - 1, picker.selected + picker.columns * 3); break
                case Qt.Key_PageUp: picker.selected = Math.max(0, picker.selected - picker.columns * 3); break
                case Qt.Key_Home: picker.selected = 0; break
                case Qt.Key_End: picker.selected = Math.max(0, n - 1); break
                case Qt.Key_Backspace:
                    if (MusicPicker.filter !== "") MusicPicker.filter = MusicPicker.filter.slice(0, -1)
                        else MusicPicker.up()
                            break
                default:
                    if (ctrl && event.key === Qt.Key_S) MusicPicker.stop()
                        else if (!ctrl && event.text.length === 1 && event.text >= " ")
                            MusicPicker.filter += event.text
                            else return
            }
            event.accepted = true
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            anchors.margins: 12
            radius: 18
            color: Theme.effectiveDark ? Qt.rgba(0.08, 0.08, 0.1, 0.58) : Qt.rgba(0.95, 0.95, 0.96, 0.58)
            border.width: 1
            border.color: Theme.color3

            // Same motion as WorkspaceOverview: fade + small spring scale.
            // The panel lives in one permanent texture, so the GPU animates a
            // single quad instead of re-drawing the whole grid every frame, and
            // nothing is allocated or freed per open.
            opacity: picker.shown ? 1 : 0
            scale: picker.shown ? 1 : 0.94
            layer.enabled: true
            layer.smooth: true
            Behavior on opacity { NumberAnimation { id: fadeAnim; duration: picker.fadeMs } }
            Behavior on scale {
                SpringAnimation {
                    id: scaleAnim
                    spring: Animations.panelSlideSpring
                    damping: Animations.panelSlideDamping
                    mass: Animations.panelSlideMass
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                Item {
                    width: parent.width
                    height: 26

                    Text {
                        anchors.left: parent.left
                        anchors.right: playBtn.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: MusicPicker.path === "" ? "..." : MusicPicker.path
                        elide: Text.ElideLeft
                        color: Theme.color3
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    Rectangle {
                        id: playBtn
                        anchors.right: stopBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 104
                        height: 24
                        radius: 12
                        readonly property bool on: MusicPicker.path !== ""
                        color: on ? (playMouse.containsMouse ? Qt.rgba(Theme.color3.r, Theme.color3.g, Theme.color3.b, 0.45)
                        : Qt.rgba(Theme.color3.r, Theme.color3.g, Theme.color3.b, 0.25))
                        : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                        opacity: on ? 1 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: "\u25B6  Play Folder"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            enabled: playBtn.on
                            hoverEnabled: true
                            onClicked: { MusicPicker.play(MusicPicker.path, true); picker.close() }
                        }
                    }

                    Rectangle {
                        id: stopBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72
                        height: 24
                        radius: 12
                        readonly property bool on: MusicPicker.mpvRunning
                        color: on ? (stopMouse.containsMouse ? Qt.rgba(Theme.color3.r, Theme.color3.g, Theme.color3.b, 0.45)
                        : Qt.rgba(Theme.color3.r, Theme.color3.g, Theme.color3.b, 0.25))
                        : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.05)
                        opacity: on ? 1 : 0.4

                        Text {
                            anchors.centerIn: parent
                            text: "\u25A0  Stop"
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                        }

                        MouseArea {
                            id: stopMouse
                            anchors.fill: parent
                            enabled: stopBtn.on
                            hoverEnabled: true
                            onClicked: MusicPicker.stop()
                        }
                    }
                }

                // Shown only while an external device is connected.
                Flow {
                    id: deviceBar
                    width: parent.width
                    spacing: 6
                    visible: MusicPicker.deviceTabs.length > 0

                    Repeater {
                        model: MusicPicker.deviceTabs

                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool isInternal: modelData.kind === "internal"
                            height: 24
                            readonly property bool canEject: !isInternal && modelData.mounted
                            width: chipText.implicitWidth + 24 + (canEject ? 22 : 0)
                            radius: 12
                            color: modelData.active
                            ? Qt.rgba(Theme.color3.r, Theme.color3.g, Theme.color3.b, 0.30)
                            : Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, chipMouse.containsMouse ? 0.12 : 0.06)
                            opacity: isInternal || modelData.mounted ? 1 : 0.6

                            Text {
                                id: chipText
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.isInternal ? "Internal"
                                : (chip.modelData.mounted ? chip.modelData.label : chip.modelData.label + "  \u00B7  mount")
                                color: Theme.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: chip.modelData.active
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: chip.isInternal ? MusicPicker.goInternal() : MusicPicker.openDevice(chip.modelData)
                            }

                            // Eject: only on mounted external devices
                            Item {
                                visible: chip.canEject
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 24

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u23CF"
                                    color: Theme.foreground
                                    opacity: ejectMouse.containsMouse ? 1 : 0.6
                                    font.pixelSize: Theme.fontSize
                                }
                                MouseArea {
                                    id: ejectMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: MusicPicker.eject(chip.modelData)
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "> " + MusicPicker.filter + "▂"
                    elide: Text.ElideRight
                    color: Theme.foreground
                    opacity: MusicPicker.filter === "" ? 0.45 : 1
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Rectangle { width: parent.width; height: 1; color: Theme.foreground; opacity: 0.12 }

                GridView {
                    id: list
                    width: parent.width
                    height: parent.height - 86 - (deviceBar.visible ? deviceBar.height + 8 : 0)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / picker.columns)
                    cellHeight: 112
                    model: MusicPicker.rows
                    currentIndex: picker.selected
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool sel: index === picker.selected
                        width: list.cellWidth
                        height: list.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: 12
                            color: cell.sel ? Qt.rgba(Theme.color3.r, Theme.color3.g, Theme.color3.b, 0.28) : "transparent"
                        }

                        // Same method as Bar.qml: the icon's own layer is tinted with
                        // Theme.iconColor, which follows the light/dark theme. The Bar
                        // already uses this ColorOverlay, so its shader is compiled by
                        // the time the picker opens.
                        Image {
                            id: ico
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 56
                            height: 56
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize: Qt.size(112, 112)
                            source: cell.modelData.isDir ? MusicPicker.folderIcon : MusicPicker.musicIcon

                            layer.enabled: true
                            layer.smooth: true
                            layer.textureSize: Qt.size(112, 112)
                            layer.effect: ColorOverlay { color: Theme.iconColor }
                        }

                        Text {
                            anchors.top: ico.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: cell.modelData.label
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: cell.modelData.isDir
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: picker.selected = cell.index
                            onClicked: { picker.selected = cell.index; picker.activate(cell.index) }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: MusicPicker.mounting ? "Working..." : MusicPicker.loading ? "Loading..." :
                    "Enter Open/Play  ·  Ctrl+Enter: Play folder  ·  Ctrl+S: Stop  ·  Backspace: Back  ·  Esc: Close"
                    elide: Text.ElideRight
                    color: Theme.foreground
                    opacity: 0.4
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
            }
        }
    }
}
