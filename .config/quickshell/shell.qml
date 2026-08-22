import QtQml
import Quickshell
import "./Bar"
import "./Popups"
import "./Background"
import "./Services"
import "./Widgets"
import "./Lock"
import "./Screenshot"
import "./OSDPopup"
ShellRoot {
    Component.onCompleted: ScreenshotSession.active
    ScreenshotWindow {}

    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }
    Variants {
        model: {
            const internal = Quickshell.screens.filter(s => /^(eDP|LVDS)-/.test(s.name))
            return internal.length > 0 ? internal : Quickshell.screens
        }
        Bar {}
    }
    ShortcutsWindow {}
    CommandsPopup {}
    WorkspaceOverview {}
    NotificationToast {}
    OSDPopup {}
    LockScreen {}

}
