pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../SBS"

QtObject {
    id: theme

    property bool isDark: true
    function toggleMode() { isDark = !isDark }

    // SBS forces the lock screen (the only Theme consumer still mounted
    // while SBS is active) into dark, without touching the persisted
    // isDark toggle or firing onIsDarkChanged's rofi/system writes.
    readonly property bool effectiveDark: SBSState.active ? true : isDark

    function adaptColor(c) {
        var l = c.hslLightness
        if (effectiveDark) {
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

    readonly property color foreground: effectiveDark ? palette.foreground : "#1a1625"
    readonly property color background: effectiveDark ? palette.background : "#f5f3fa"
    readonly property color borderMuted: effectiveDark ? color8 : Qt.rgba(0, 0, 0, 0.12)
    readonly property color textMuted: effectiveDark ? color7 : "#4a4458"
    readonly property color textDim: effectiveDark ? color8 : "#8a8298"
    readonly property color textOnAccent: "#000000"

    readonly property color barBg: effectiveDark
    ? Qt.rgba(theme.palette.color0.r, theme.palette.color0.g, theme.palette.color0.b, 0.25)
    : Qt.rgba(1, 1, 1, 0.55)
    readonly property color barBorderTop: effectiveDark ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.15)
    readonly property color popupBg: effectiveDark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.55)

    readonly property color hoverBg: effectiveDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color hoverBgSoft: effectiveDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.045)
    readonly property color hoverBgStrong: effectiveDark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color pillOffBg: effectiveDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)

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

    readonly property string rofiColorsPath: Quickshell.env("HOME") + "/.cache/rofi/colors.rasi"
    function _rgba(c) {
        return `rgba(${Math.round(c.r*255)}, ${Math.round(c.g*255)}, ${Math.round(c.b*255)}, ${c.a.toFixed(2)})`
    }

    function _neutralGray(l) {
        return Qt.hsla(0, 0, l, 1)
    }

    // While SBS is active, rofi's background is forced fully opaque black
    // instead of the usual semi-transparent dark palette color -- SBS's
    // own shell is flat black/white with no blur anywhere, and an opaque
    // window has nothing for a compositor blur rule to show through, so
    // this makes the rofi blur windowrule a non-issue without needing to
    // touch hyprland.lua.
    function _rofiVariant(dark) {
        const forceBlack = dark && SBSState.active

        const bg = forceBlack ? Qt.rgba(0, 0, 0, 1) : adaptColorFor(color0, dark)
        const fg =  dark ? Qt.color(palette.foreground) : Qt.color("#1a1625")
        const tMuted = adaptColorFor(color8, dark)
        const aActive = adaptColorFor(color3, dark)
        const aHover = adaptColorFor(color7, dark)

        const pBg = forceBlack
        ? Qt.rgba(0, 0, 0, 1)
        : (dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.55))

        const elementBg = dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.045)
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
        // Symlink by effectiveDark, not raw isDark -- SBS forces dark
        // regardless of the persisted isDark toggle, so colors.rasi must
        // follow effectiveDark or it can point at the light variant while
        // the shell itself is rendering dark.
        const target = effectiveDark ? "colors-dark.rasi" : "colors-light.rasi"

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
    // Catches SBS enabling/disabling (SBSState.active flips this even
    // when isDark itself never changes) as well as ordinary isDark
    // changes -- either way rofi's colors need regenerating.
    onEffectiveDarkChanged: theme._writeRofiColors()
    onPaletteChanged: theme._writeRofiColors()

    // effectiveDark only re-derives a boolean (dark/light); it does NOT
    // change value when SBS turns off while isDark was already true, or
    // turns on while isDark was already true. But _rofiVariant()'s output
    // still depends directly on SBSState.active via forceBlack (opaque
    // black vs. normal semi-transparent dark bg) -- so effectiveDark
    // alone isn't a sufficient trigger. This watches SBSState.active
    // itself so the SBS<->main-shell transition regenerates colors.rasi
    // even when effectiveDark's value doesn't move, instead of only
    // resolving on the next Quickshell restart's Component.onCompleted.
    readonly property bool sbsActive: SBSState.active
    onSbsActiveChanged: theme._writeRofiColors()

    Component.onCompleted: {
        theme._writeRofiColors()
        theme._writeSystemTheme()
    }

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
