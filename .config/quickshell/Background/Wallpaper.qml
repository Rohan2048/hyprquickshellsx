import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Theme"
import "../Services"

PanelWindow {
    id: wallpaperWindow

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell:wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0
    color: "transparent"

    anchors { top: true; bottom: true; left: true; right: true }
    visible: true

    property string currentPath: ""
    property real transitionProgress: 1
    property bool transitioning: false

    Component {
        id: imageSlot
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            property string imgPath: ""
            source: imgPath.length > 0 ? ("file://" + imgPath) : ""
            sourceSize.width: wallpaperWindow.width * wallpaperWindow.screen.devicePixelRatio
            sourceSize.height: wallpaperWindow.height * wallpaperWindow.screen.devicePixelRatio
        }
    }

    function reloadImageSlot(loader, path) {
        loader.active = false
        loader.imgPath = path
        loader.active = true
    }

    // FIX (perf): don't eagerly spin up the back-slot Image the instant the
    // front one loads at login.
    Timer {
        id: backWarmTimer
        interval: 350
        repeat: false
        property string pendingPath: ""
        onTriggered: wallpaperWindow.reloadImageSlot(loaderBack, pendingPath)
    }

    Loader {
        id: loaderBack
        anchors.fill: parent
        asynchronous: true
        sourceComponent: imageSlot
        property string imgPath: ""
        active: false
        opacity: 1 - wallpaperWindow.transitionProgress
        layer.enabled: wallpaperWindow.transitioning
        layer.effect: DirectionalBlur {
            angle: Animations.wallpaperBlurAngle
            length: Animations.blurEnvelope(wallpaperWindow.transitionProgress) * Animations.wallpaperBlurLength
            samples: Animations.wallpaperBlurSamples
            transparentBorder: true
        }
        onItemChanged: if (item) item.imgPath = imgPath
    }

    Loader {
        id: loaderFront
        anchors.fill: parent
        asynchronous: true
        sourceComponent: imageSlot
        property string imgPath: ""
        active: false
        opacity: wallpaperWindow.transitionProgress
        layer.enabled: wallpaperWindow.transitioning
        layer.effect: DirectionalBlur {
            angle: Animations.wallpaperBlurAngle
            length: Animations.blurEnvelope(wallpaperWindow.transitionProgress) * Animations.wallpaperBlurLength
            samples: Animations.wallpaperBlurSamples
            transparentBorder: true
        }

        property bool waitingForLoad: false

        onItemChanged: if (item) item.imgPath = imgPath

        Connections {
            target: loaderFront.item
            enabled: loaderFront.item !== null
            function onStatusChanged() {
                if (loaderFront.item.status !== Image.Ready) return

                    if (loaderFront.waitingForLoad && wallpaperWindow.transitionProgress === 0) {
                        loaderFront.waitingForLoad = false
                        crossfadeAnim.restart()
                    }
            }
        }
    }

    NumberAnimation {
        id: crossfadeAnim
        target: wallpaperWindow
        property: "transitionProgress"
        from: 0; to: 1
        duration: Animations.wallpaperCrossfadeDuration
        easing.type: Animations.wallpaperCrossfadeEasing
        running: false
        onStarted: wallpaperWindow.transitioning = true
        onStopped: {
            wallpaperWindow.transitioning = false
            wallpaperWindow.reloadImageSlot(loaderBack, wallpaperWindow.currentPath)
        }
    }

    function setWallpaper(path) {
        currentPath = path
        transitionProgress = 0
        loaderFront.waitingForLoad = true
        reloadImageSlot(loaderFront, path)
    }

    Connections {
        target: WallpaperState
        function onWallpaperUpdated(imagePath, imageChanged) {
            if (imagePath.length === 0) return
                if (imagePath === currentPath) return
                    setWallpaper(imagePath)
        }
    }

    Component.onCompleted: {
        if (WallpaperState.initialized) {
            Qt.callLater(function() {
                setWallpaper(WallpaperState.imagePath)
            })
        }
    }
}
