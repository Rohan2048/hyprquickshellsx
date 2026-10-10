import QtQml
import QtQuick
import QtQuick.Effects
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
// import "./WinBtn"   // only used by the commented-out WinDecorations loader below; the folder is not part of this tree

ShellRoot {
    id: shellRoot

    // The Bar instance running on the primary screen, so WinDecorations
    // can reuse its toggleMinimize/isMinimizedFake machinery.
    property var primaryBar: {
        var insts = barVariants.instances
        for (var i = 0; i < insts.length; i++) {
            if (insts[i].modelData === Quickshell.screens[0]) return insts[i]
        }
        return null
    }

    Component.onCompleted: {
        ScreenshotSession.active
    }

    // The screenshot editor and the preview stack are only needed while a
    // screenshot is being edited / queued. Building their QML trees (and
    // keeping their windows around) at startup cost RAM and login CPU for
    // something used rarely, so they are created on demand and destroyed
    // when done. Each one's own `visible` already tracked these same
    // conditions, so nothing is shown or hidden any differently.
    Loader {
        id: screenshotLoader
        active: ScreenshotSession.active
        sourceComponent: ScreenshotWindow {}
        // The window used to restore direct scanout from its onVisibleChanged;
        // a destroyed window can't, so do it here.
        onActiveChanged: if (!active) directScanoutRestore.running = true
    }
    Process {
        id: directScanoutRestore
        command: ["hyprctl", "keyword", "render:direct_scanout", "1"]
    }
    Loader {
        active: ScreenshotQueue.store.count > 0
        sourceComponent: PreviewStack {}
    }

    Variants {
        model: SBSState._loaded && !SBSState.active ? Quickshell.screens : []
        Wallpaper {}
    }
    Variants {
        id: barVariants
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

    // Window button decorations — main screen only for now.
    // Off during SBS: one PanelWindow per open window is extra
    // layer-shell surfaces we don't want eating battery in that mode.
    // Loader {
    //     id: winDecorationsLoader
    //     active: SBSState._loaded && !SBSState.active && shellRoot.primaryBar !== null
    //     sourceComponent: WinDecorations { bar: shellRoot.primaryBar }
    // }

    // One-off shader warm-up (DirectionalBlur) so the first real animation
    // doesn't stall on shader compilation. Only needs to exist briefly at
    // startup; keeping a permanent layer-shell surface + render target alive
    // for the whole session just to have compiled it once was wasted RAM.
    Loader {
        id: shaderWarmupLoader
        active: true
        sourceComponent: shaderWarmupComponent
    }
    Timer {
        interval: 6000
        running: true
        onTriggered: shaderWarmupLoader.active = false
    }
    Component {
        id: shaderWarmupComponent
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
            // Also compile the MultiEffect blur used by the lock screen so
            // the first lock of a session doesn't wait on shader compilation.
            Rectangle {
                id: lockWarmSrc
                width: 1; height: 1; color: "black"; visible: false
                layer.enabled: true
            }
            MultiEffect {
                width: 1; height: 1
                source: lockWarmSrc
                autoPaddingEnabled: false
                blurEnabled: true; blur: 1.0; blurMax: 96; blurMultiplier: 1.6
                saturation: -0.08; brightness: -0.06; contrast: 0.05
            }
        }
    }
}
