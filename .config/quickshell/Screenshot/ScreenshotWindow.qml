pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Services"
import "../SBS"
import "Toolbar"
import "Canvas"
import "Tools"

PanelWindow {
    id: window

    readonly property int barClearance: 96 // reserved band top/bottom for toolbars

    property bool dialogOpen: false

    Process {
        id: hueRingGen
        command: ["bash", "-c",
        "test -f '" + Quickshell.env("HOME") + "/.config/quickshell/assets/hue_ring.png' || python3 '" +
        Quickshell.env("HOME") + "/.config/quickshell/scripts/gen_hue_ring.py'"
        ]
    }

    Component.onCompleted: hueRingGen.running = true

    property var targetScreen: {
        const name = ScreenshotSession.screenName;
        for (const s of Quickshell.screens) {
            if (s.name === name) return s;
        }
        return null;
    }

    screen: targetScreen
    // dialogOpen no longer hides the window — the backdrop stays visible
    // and the file dialog floats on top of it instead of the whole thing
    // vanishing and reappearing.
    visible: ScreenshotSession.active && targetScreen !== null
    // SBS on: fully opaque black -- matches the noblur layerrule (no
    // compositor blur to show through, so transparency would just look
    // like a flat charcoal window instead of a backdrop). SBS off:
    // back to the original translucent dim over the blurred desktop.
    color: SBSState.active ? "black" : Qt.rgba(0,0,0,0.65)

    // Namespace picks which Hyprland layerrule applies. SBS active ->
    // "-noblur" variant, so a `layerrule = noblur, ^(quickshell:screenshot-noblur)$`
    // (or simply no blur rule matching it) leaves this surface unblurred
    // while SBS is on; SBS off -> plain "quickshell:screenshot", which is
    // what the existing `layerrule = blur, ^(quickshell:screenshot)$` rule
    // targets. QML can't apply the blur itself (no compositor-side effect
    // hook here) — Hyprland has to key off the namespace string.
    WlrLayershell.namespace: SBSState.active ? "quickshell:screenshot-noblur" : "quickshell:screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusionMode: ExclusionMode.Ignore



    // Leaves a click-through hole in the top-center strip where toast
    // notifications render (see Widgets/ToastWindow.qml), so swipe/tap
    // gestures on toasts reach their own surface instead of being
    // swallowed by this window's full-screen input region. Sized for the
    // normal collapsed toast stack; the expanded stack (up to 900px) can
    // extend past this — will revisit once toast stack height is exposed
    // as a shared property.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item {
        id: fullMaskArea
        anchors.fill: parent
    }

    Item {
        id: toastCutoutArea
        width: Notifications.activeToasts.count > 0 ? 280 : 0
        height: Notifications.activeToasts.count > 0 ? 320 : 0
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    mask: Region {
        item: fullMaskArea
        Region {
            item: toastCutoutArea
            intersection: Intersection.Subtract
        }
    }
    function requestClose() {
        if (!ScreenshotSession.active) return;
        ScreenshotSession.annotations.clear();
        ScreenshotSession.clearAnnotationSelection();
        imageContainer.letterboxMargin = 0;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 320
        onTriggered: ScreenshotSession.cancel()
    }

    Item {
        id: focusScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                window.requestClose();
                event.accepted = true;
            } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
                && ScreenshotSession.selectedAnnotationId !== -1) {
                ScreenshotSession.annotations.remove(ScreenshotSession.selectedAnnotationId);
            ScreenshotSession.clearAnnotationSelection();
            event.accepted = true;
                }
        }

        Item {
            id: imageContainer
            property real letterboxMargin: 0

            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: imageContainer.letterboxMargin
                bottomMargin: imageContainer.letterboxMargin
            }

            Behavior on letterboxMargin {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }

            Image {
                id: baseImage
                anchors.fill: parent
                source: ScreenshotSession.imagePath ? "file://" + ScreenshotSession.imagePath : ""
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: false
                onPaintedWidthChanged: window._updateScale()
                onStatusChanged: if (status === Image.Ready) {
                    window._updateScale();
                    ScreenshotSession.applyPendingRemap();
                }
            }

            Item {
                id: imageBounds
                x: (imageContainer.width - baseImage.paintedWidth) / 2
                y: (imageContainer.height - baseImage.paintedHeight) / 2
                width: baseImage.paintedWidth
                height: baseImage.paintedHeight

                Image {
                    id: compositeBackground
                    anchors.fill: parent
                    source: baseImage.source
                    fillMode: Image.Stretch
                    cache: false
                    smooth: true
                    visible: false
                }

                SelectionOverlay {}

                ShapeLayer { id: shapeLayer; annotationStack: annotationStack }
                TextLayer { id: textLayer; annotationStack: annotationStack }

                FreehandLayer {
                    id: freehandLayer
                    anchors.fill: parent
                    annotationStack: annotationStack
                }
                DoodleTool {
                    anchors.fill: parent
                    annotationModel: ScreenshotSession.annotations
                    strokeColor: ScreenshotSession.annotationColor
                    strokeWidth: ScreenshotSession.annotationStrokeWidth
                    highlighter: ScreenshotSession.annotationHighlighter
                    dotted: ScreenshotSession.annotationDotted
                    visible: ScreenshotSession.currentTool === "doodle"
                    enabled: visible
                }
                EraserTool {
                    anchors.fill: parent
                    visible: ScreenshotSession.currentTool === "eraser"
                    enabled: visible
                }
                BlurLayer {
                    id: blurLayer
                    anchors.fill: parent
                    annotationModel: ScreenshotSession.annotations
                    annotationStack: annotationStack
                }
                BlurTool {
                    anchors.fill: parent
                    annotationModel: ScreenshotSession.annotations
                    visible: ScreenshotSession.currentTool === "blur"
                    enabled: visible
                }

                AnnotationStack {
                    id: annotationStack
                    anchors.fill: parent
                    shapeLayer: shapeLayer
                    blurLayer: blurLayer
                    sourceItem: baseImage
                    sourceOffset: Qt.point(imageBounds.x, imageBounds.y)
                }


            }
        }

        TopToolbar { screenshotWindow: window }
        BottomToolbar { screenshotWindow: window }
    }

    function _updateScale() {
        if (baseImage.sourceSize.width > 0)
            ScreenshotSession.displayScale = baseImage.paintedWidth / baseImage.sourceSize.width;
    }

    function restoreFocus() {
        focusScope.forceActiveFocus();
    }

    function captureComposite(callback) {
        compositeBackground.visible = true;
        imageBounds.grabToImage(function(result) {
            compositeBackground.visible = false;
            const tmp = "/tmp/quickshot-composite-" + Date.now() + ".png";
            if (result.saveToFile(tmp))
                callback(tmp);
            else
                callback(null);
        });
    }

    onVisibleChanged: {
        if (visible) {
            focusScope.forceActiveFocus();
            imageContainer.letterboxMargin = 0;
            letterboxTimer.restart();
        }
    }

    Timer {
        id: letterboxTimer
        interval: 16
        onTriggered: imageContainer.letterboxMargin = window.barClearance
    }
}
