pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    property bool isDark: true
    function toggleMode() { isDark = !isDark }

    function adaptColor(c) {
        var l = c.hslLightness
        if (isDark) {
            if (l < 0.45) l = 0.45
        } else {
            if (l > 0.5) l = 0.5
        }
        return Qt.hsla(c.hslHue, c.hslSaturation, l, c.a)
    }

    property var palette: ({
        background: "#0d0b16",
        foreground: "#e6e1f0",
            color0: "#0d0b16", color1: "#7c3aed", color2: "#a855f7", color3: "#c026d3",
            color4: "#6366f1", color5: "#8b5cf6", color6: "#d946ef", color7: "#e6e1f0",
            color8: "#4c1d95", color9: "#7c3aed", color10: "#a855f7", color11: "#c026d3",
            color12: "#818cf8", color13: "#a78bfa", color14: "#e879f9", color15: "#f5f3ff"
    })

    readonly property color color0: palette.color0
    readonly property color color1: palette.color1
    readonly property color color2: palette.color2
    readonly property color color3: palette.color3
    readonly property color color4: palette.color4
    readonly property color color5: palette.color5
    readonly property color color6: palette.color6
    readonly property color color7: palette.color7
    readonly property color color8: palette.color8

    readonly property color accentActive: adaptColor(color3)
    readonly property color accentHover: adaptColor(color1)

    readonly property color foreground: isDark ? palette.foreground : "#1a1625"
    readonly property color background: isDark ? palette.background : "#f5f3fa"
    readonly property color borderMuted: isDark ? color8 : Qt.rgba(0, 0, 0, 0.12)
    readonly property color textMuted: isDark ? color7 : "#4a4458"
    readonly property color textDim: isDark ? color8 : "#8a8298"
    readonly property color textOnAccent: "#000000"

    readonly property color barBg: isDark
    ? Qt.rgba(theme.palette.color0.r, theme.palette.color0.g, theme.palette.color0.b, 0.25)
    : Qt.rgba(1, 1, 1, 0.55)
    readonly property color barBorderTop: isDark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.15)
    readonly property color popupBg: isDark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.55)

    readonly property color hoverBg: isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color hoverBgSoft: isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.045)
    readonly property color hoverBgStrong: isDark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color pillOffBg: isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)

    readonly property color iconColor: foreground

    readonly property int radiusSm: 6
    readonly property int radiusMd: 12
    readonly property int radiusPill: 20
    readonly property int barHeight: 28
    readonly property int gapSm: 6
    readonly property int gapMd: 10

    readonly property string fontFamily: "Satoshi Variable"
    readonly property int fontSize: 13
    readonly property int fontSizeSm: 10
    readonly property int fontSizeXs: 9
    readonly property int fontSizeLg: 17
    readonly property int fontSizeXl: 27

    // ---- rofi color export ----
    // Separate process from quickshell, so it can't read isDark/palette
    // directly — this writes a rasi file on every change; rofi's config
    // imports it. Uses execDetached (same mechanism as power-btn.svg's
    // handler) instead of FileView, since FileView write API was unverified.
    readonly property string rofiColorsPath: Quickshell.env("HOME") + "/.cache/rofi/colors.rasi"
    function _rgba(c) {
        return `rgba(${Math.round(c.r*255)}, ${Math.round(c.g*255)}, ${Math.round(c.b*255)}, ${c.a.toFixed(2)})`
    }

    // Strips hue/saturation to produce a neutral gray at a given lightness —
    // used for scrollbar/placeholder so they never carry an accent tint.
    function _neutralGray(l) {
        return Qt.hsla(0, 0, l, 1)
    }

    function _rofiVariant(dark) {
        const bg = adaptColorFor(color0, dark)
        const fg =  dark ? Qt.color(palette.foreground) : Qt.color("#1a1625")
        const tMuted = adaptColorFor(color8, dark)
        const aActive = adaptColorFor(color3, dark)
        const aHover = adaptColorFor(color7, dark)

       const pBg = dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.55)

        // Unselected element background: subtle glass tint, same direction
        // as the bar's hoverBg (lighten in dark mode, darken in light mode)
        const elementBg = dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.045)

        // Selected element: solid accent color, not a tinted overlay
       const selectedBg = Qt.rgba(255,255,255,0.15)

        const grayMuted = _neutralGray(0.55)
        const onAccent = Qt.color("#000000")

        return "* {\\n" +
        "    background: " + _rgba(bg) + ";\\n" +
        "    popup-bg: " + _rgba(pBg) + ";\\n" +
        "    foreground: " + _rgba(fg) + ";\\n" +
        "    accent-active: " + _rgba(aActive) + ";\\n" +
        "    accent-hover: " + _rgba(aHover) + ";\\n" +
        "    border-muted: " + _rgba(grayMuted) + ";\\n" +
        "    text-muted: " + _rgba(tMuted) + ";\\n" +
        "    text-dim: " + _rgba(grayMuted) + ";\\n" +
        "    element-bg: " + _rgba(elementBg) + ";\\n" +
        "    selected-bg: " + _rgba(selectedBg) + ";\\n" +
        "    text-on-accent: " + _rgba(onAccent) + ";\\n" +
        "}\\n"
    }
    // Same clamp as adaptColor but takes an explicit mode instead of reading
    // the live isDark, so _rofiVariant can compute both variants at once.
    function adaptColorFor(c, dark) {
        var l = c.hslLightness
        if (dark) {
            if (l < 0.45) l = 0.45
        } else {
            if (l > 0.5) l = 0.5
        }
        return Qt.hsla(c.hslHue, c.hslSaturation, l, c.a)
    }

    function _writeRofiColors() {
        const darkContent = _rofiVariant(true)
        const lightContent = _rofiVariant(false)
        const target = isDark ? "colors-dark.rasi" : "colors-light.rasi"

        Quickshell.execDetached(["bash", "-c",
                                "mkdir -p ~/.cache/rofi && " +
                                "printf '%b' \"" + darkContent.replace(/"/g, '\\"') + "\" > ~/.cache/rofi/colors-dark.rasi && " +
                                "printf '%b' \"" + lightContent.replace(/"/g, '\\"') + "\" > ~/.cache/rofi/colors-light.rasi && " +
                                "ln -sf ~/.cache/rofi/" + target + " ~/.cache/rofi/colors.rasi"])
    }

    onIsDarkChanged: {
        theme._writeRofiColors()
        theme._writeSystemTheme()
    }
    onPaletteChanged: theme._writeRofiColors()
    Component.onCompleted: {
        theme._writeRofiColors()
        theme._writeSystemTheme()
    }

    // ---- KDE/GTK/Kate system theme ----
    // Same idea as the rofi writer above: drop the current mode to a file
    // apply-theme.sh can read, then run it detached so kdeglobals/GTK/Kate
    // pick up light or dark immediately on toggle, not just after wal runs.
    function _writeSystemTheme() {
        const mode = isDark ? "dark" : "light"
        Quickshell.execDetached(["bash", "-c",
                                "mkdir -p ~/.cache/quickshell && printf '%s' '" + mode + "' > ~/.cache/quickshell/theme_mode && " +
                                "~/.config/hypr/apply-theme.sh " + mode])
    }

    property string walPath: Quickshell.env("HOME") + "/.cache/wal/colors.json"

    property FileView _walFile: FileView {
        id: walFileView
        path: theme.walPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme._applyWal(text())
        onLoadFailed: (error) => {
            console.warn("Theme: no pywal cache yet at", theme.walPath, "- using fallback palette")
        }
    }

    property FileView _themeTrigger: FileView {
        path: Quickshell.env("HOME") + "/.cache/quickshell/theme_trigger"
        watchChanges: true
        onFileChanged: walFileView.reload()
    }

    function _applyWal(raw) {
        try {
            const data = JSON.parse(raw)

            const special = data.special || {}
            const colors = data.colors || {}
            const p = {}

            p.background = special.background || palette.background
            p.foreground = special.foreground || palette.foreground

            for (let i = 0; i <= 15; i++) {
                const key = "color" + i
                p[key] = colors[key] || palette[key]
            }

            if (JSON.stringify(p) === JSON.stringify(palette))
                return

                palette = p
        } catch (e) {
            console.warn("Theme: failed to parse pywal colors.json:", e)
        }
    }
}
