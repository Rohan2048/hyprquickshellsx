import QtQuick
import "../Theme"
import "../Services"
// GlassPanel — direct port of .popup-box:
//   background-color: rgba(0,0,0,0.35); border: 1px solid $color8; border-radius: 12px;
// The actual frosted blur is compositor-side (Hyprland/niri layerrule on this
// surface's namespace) — same as your eww setup, this just draws the fill/border.
Rectangle {
    radius: Theme.radiusMd
    color: Theme.popupBg
    border.width: 1
    border.color: Theme.borderMuted
}
