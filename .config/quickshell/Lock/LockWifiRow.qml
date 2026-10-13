import Quickshell
import "../Services"

LockQuickToggleTile {
id: root
signal devicesRequested()

active: Wifi.radioOn
label: "Wifi"
sublabel: Wifi.radioOn ? Wifi.ssid : "Off"
iconSource: "file://" + Quickshell.env("HOME") + "/.config/icons/wifion.svg"

onIconClicked: Wifi.toggleRadio()
onLabelClicked: root.devicesRequested()
}
