import QtQuick

QtObject {
    id: tracking

    // ---- Required references, wired up from Bar.qml ----
    required property var bar
    required property var barClip
    required property var barContent
    required property var leftRow
    required property var rightRow

    readonly property real barScreenX: bar.screen
    ? (bar.screen.width - bar.implicitWidth) / 2
    : 0

    function offsetFromRight(item) {
        if (!item || !bar.screen)
            return 0
            const centerX = barClip.x + barContent.x + rightRow.x + item.x + item.width / 2
            return bar.screen.width - (barScreenX + centerX)
    }

    function offsetFromLeft(item) {
        if (!item || !bar.screen)
            return 0
            const centerX = barClip.x + barContent.x + leftRow.x + item.x + item.width / 2
            return barScreenX + centerX
    }

    // Generic version for items nested at arbitrary depth (e.g. AppsTray's
    // ListView delegates, where a plain leftRow.x + item.x chain breaks —
    // item.x is only relative to its immediate parent, and ListView adds
    // its own contentX scroll offset on top). mapToItem walks the real
    // parent chain regardless of depth, so this works for any item as long
    // as it's part of the same window's scene graph.
    function offsetFromLeftItem(item) {
        if (!item || !bar.screen || !bar.contentItem)
            return 0
            const p = item.mapToItem(bar.contentItem, item.width / 2, 0)
            return barScreenX + p.x
    }

    readonly property real barTopEdgeFromBottom: bar.margins.bottom + bar.height

    // ---- Bar's own rendered left/right edges, in absolute screen coords ----
    // barClip.width tracks bar.visualWidth (the animated, content-fit width),
    // not bar.implicitWidth (the full reserved window width) — so these
    // follow the bar's actual visible glass panel, including its width
    // animation, rather than the wider invisible window bounds. Used for
    // clamping popups to overhang the bar itself by a small fixed amount,
    // instead of clamping to the full screen edges.
    //
    // Computed via mapToGlobal rather than barScreenX + mapToItem: mapToGlobal
    // asks the windowing system directly for barClip's real on-screen position,
    // so it's correct regardless of how the PanelWindow itself ends up placed
    // by the compositor. The old barScreenX formula assumed the window is
    // exactly centered via (screen.width - bar.implicitWidth) / 2 — an
    // assumption that doesn't reliably hold and was the actual source of the
    // popup drifting away from the bar's true edge as the bar's width changed.
    readonly property real barLeftEdge: {
        if (!barClip)
            return 0
            // mapToGlobal() does not register as a binding dependency on its
            // own — it reads geometry via internal transforms that bypass the
            // property system's change tracking. Without reading these
            // explicitly first, this binding only ever evaluates once, at
            // creation, and gets stuck at whatever position barClip happened
            // to be in at that instant (reads as "always pinned to screen edge").
            const _dep = barClip.x + barClip.width + barContent.x
            const p = barClip.mapToGlobal(0, 0)
            return p.x
    }

    readonly property real barRightEdge: {
        if (!barClip)
            return 0
            const _dep = barClip.x + barClip.width + barContent.x
            const p = barClip.mapToGlobal(barClip.width, 0)
            return p.x
    }
}
