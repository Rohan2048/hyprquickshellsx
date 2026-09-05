import QtQml
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import "./Bar"
import "./Popups"
import "./Background"
import "./Services"
import "./Widgets"
import "./Lock"
import "./Screenshot"
import "./OSDPopup"
import "./SBS"

ShellRoot {
    Component.onCompleted: {
        ScreenshotSession.active
    }

    ScreenshotWindow {}

    Variants {
        model: SBSState._loaded && !SBSState.active ? Quickshell.screens : []
        Wallpaper {}
    }
    Variants {
        model: {
            if (!SBSState._loaded || SBSState.active) return []
            const internal = Quickshell.screens.filter(s => /^(eDP|LVDS)-/.test(s.name))
            return internal.length > 0 ? internal : Quickshell.screens
        }
        Bar {}
    }
    Variants {
        model: {
            if (!SBSState._loaded || !SBSState.active) return []
            const internal = Quickshell.screens.filter(s => /^(eDP|LVDS)-/.test(s.name))
            return internal.length > 0 ? internal : Quickshell.screens
        }
        SBSShell {}
    }

    Loader {
        id: shortcutsLoader
        active: false
        sourceComponent: ShortcutsWindow {}
    }
    Loader {
        id: commandsLoader
        active: false
        sourceComponent: CommandsPopup {}
    }

    IpcHandler {
        target: "shortcuts"
        function toggle(): void {
            shortcutsLoader.active = true
            shortcutsLoader.item.menuOpen = !shortcutsLoader.item.menuOpen
        }
        function open(): void {
            shortcutsLoader.active = true
            shortcutsLoader.item.menuOpen = true
        }
        function close(): void {
            if (shortcutsLoader.item) shortcutsLoader.item.menuOpen = false
        }
    }
    IpcHandler {
        target: "commands"
        function toggle(): void {
            commandsLoader.active = true
            commandsLoader.item.shown = !commandsLoader.item.shown
        }
    }

    WorkspaceOverview { id: workspaceOverview }
    NotificationToast {}
    Loader {
        id: osdPopupLoader
        active: !SBSState.active
        sourceComponent: OSDPopup {}
    }
    Loader {
        active: true
        sourceComponent: (SBSState._loaded && SBSState.active) ? sbsLockComponent : mainLockComponent
    }
    Component { id: mainLockComponent; LockScreen {} }
    Component { id: sbsLockComponent; SBSLockScreen {} }

    PanelWindow {
        id: shaderWarmup
        visible: true
        color: "transparent"
        implicitWidth: 1
        implicitHeight: 1
        exclusiveZone: -1

        WlrLayershell.namespace: "quickshell:warmup"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; left: true }
        margins { top: -10000; left: -10000 }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: DirectionalBlur { angle: 0; length: 1; samples: 4 }
        }
    }
}
