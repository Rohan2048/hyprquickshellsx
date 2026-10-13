import QtQuick
import Qt5Compat.GraphicalEffects
import "../../Theme"
import "../../Services"

// Appear/disappear wrapper for bar buttons that only exist while "active".
// This is the music button's musicTrayWrapper from Bar.qml, extracted so the
// timer and stopwatch buttons animate identically: width grows/collapses
// (220ms OutQuint), opacity fades with the slide-blur timing, and a short
// horizontal DirectionalBlur pulse plays whenever `active` flips.
//
// Put exactly the button(s) to reveal inside it. When anchoring a popup to
// the button, pass THIS item (not the inner button) to
// popupTracking.offsetFromRight(): offsetFromRight() assumes the item is a
// direct child of rightRow.
Item {
    id: root

    property bool active: false
    default property alias content: holder.data

    // Wrapped content is sized by its own implicitWidth/Height.
    readonly property real contentWidth: holder.childrenRect.width
    readonly property real contentHeight: holder.childrenRect.height

    implicitWidth: active ? contentWidth : 0
    width: implicitWidth
    height: contentHeight
    visible: width > 0 || opacity > 0
    clip: true
    opacity: active ? 1 : 0

    // Don't let a click land on the button while it is collapsing away.
    enabled: active

    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
    Behavior on opacity {
        NumberAnimation {
            duration: Animations.slideBlurDuration
            easing.type: root.active ? Animations.slideBlurEasingOut : Animations.slideBlurEasingIn
        }
    }

    property real blurLength: 0
    layer.enabled: blurLength > 0
    layer.effect: DirectionalBlur {
        angle: Animations.slideBlurHorizontalAngle
        length: root.blurLength
        samples: Animations.slideBlurSamples
    }

    Item { id: holder }

    onActiveChanged: blurPulse.restart()

    SequentialAnimation {
        id: blurPulse
        NumberAnimation { target: root; property: "blurLength"; to: Animations.slideBlurHorizontalLength * 1.3; duration: Animations.slideBlurDuration * 0.35; easing.type: Animations.slideBlurEasingIn }
        NumberAnimation { target: root; property: "blurLength"; to: 0; duration: Animations.slideBlurDuration * 0.35; easing.type: Animations.slideBlurEasingOut }
    }
}
