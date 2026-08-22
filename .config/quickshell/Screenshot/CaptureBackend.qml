pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    signal captured(string path)
    signal failed(string reason)
    signal cropped(string path)
    signal cropFailed(string reason)

    property string _pendingPath: ""
    property string _pendingCropPath: ""

    function capture(outputName) {
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        const path = "/tmp/qs-screenshot-" + ts + ".png";
        root._pendingPath = path;

        grimProcess.command = outputName
        ? ["grim", "-o", outputName, "-t", "png", path]
        : ["grim", "-t", "png", path];
        grimProcess.running = true;
    }

    function cropImage(sourcePath, x, y, w, h) {
        const ts = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        const path = "/tmp/qs-screenshot-crop-" + ts + ".png";
        root._pendingCropPath = path;

        cropProcess.command = ["convert", sourcePath, "-crop", w + "x" + h + "+" + x + "+" + y, "+repage", path];
        cropProcess.running = true;
    }

    Process {
        id: grimProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.captured(root._pendingPath);
            else
                root.failed("grim exited with code " + exitCode);
        }
    }

    Process {
        id: cropProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.cropped(root._pendingCropPath);
            else
                root.cropFailed("convert exited with code " + exitCode);
        }
    }
}
