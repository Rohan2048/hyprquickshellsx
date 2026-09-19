import Quickshell
import "../Theme"

LockQuickToggleTile {
    id: root

    active: Theme.isDark
    label: "Theme"
    labelIsButton: false
    sublabel: Theme.isDark ? "Dark" : "Light"
    iconSource: "file://" + Quickshell.env("HOME") + "/.config/icons/light-dark.svg"

    onIconClicked: Theme.toggleMode()
    onLabelClicked: Theme.toggleMode()
}
