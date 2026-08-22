pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string status: "Stopped"
    property string title: ""
    property string artist: ""
    property string album: ""
    property string art: ""
    property real duration: 0
    property string durationFmt: "00:00"
    property real position: 0
    property string positionFmt: "00:00"
    property bool seeking: false

    readonly property bool playing: status === "Playing"
    readonly property bool active: status === "Playing" || status === "Paused"

    property string activePlayerName: ""
    property var _players: ({})
    property var _artCache: ({})

    readonly property string _sep: "\x1f"

    function fmt(secs) {
        secs = Math.max(0, Math.floor(secs))
        const m = Math.floor(secs / 60)
        const s = secs % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    function playPause() { if (root.activePlayerName !== "") ctl.run(["playerctl", "--player=" + root.activePlayerName, "play-pause"]) }
    function next()      { if (root.activePlayerName !== "") ctl.run(["playerctl", "--player=" + root.activePlayerName, "next"]) }
    function previous()  { if (root.activePlayerName !== "") ctl.run(["playerctl", "--player=" + root.activePlayerName, "previous"]) }

    function seek(percent) {
        if (duration <= 0 || root.activePlayerName === "") return
            const target = (percent / 100.0) * duration
            root.position = target
            root.positionFmt = fmt(target)
            ctl.run(["playerctl", "--player=" + root.activePlayerName, "position", target.toFixed(2)])
    }

    function _reset() {
        root.status           = "Stopped"
        root.title            = ""
        root.artist           = ""
        root.album            = ""
        root.art              = ""
        root.duration         = 0
        root.durationFmt      = "00:00"
        root.position         = 0
        root.positionFmt      = "00:00"
        root.activePlayerName = ""
    }

    function _pickActivePlayer() {
        let bestName = ""
        let bestTs = -1

        for (const name in root._players) {
            const p = root._players[name]
            if (p.status === "Playing" && p.ts > bestTs) {
                bestName = name
                bestTs = p.ts
            }
        }

        if (bestName === "") {
            for (const name in root._players) {
                const p = root._players[name]
                if (p.status === "Paused" && p.ts > bestTs) {
                    bestName = name
                    bestTs = p.ts
                }
            }
        }

        if (bestName === "") {
            root._reset()
            return
        }

        const p = root._players[bestName]
        // A track change is: switching to a different player, OR the
        // title differing from what's currently shown. Only then do we
        // allow art to go blank — otherwise (same track, just a noisy
        // blank line) we keep showing the art we already have.
        const trackChanged = (root.activePlayerName !== bestName) || (root.title !== p.title)

        root.activePlayerName = bestName
        root.status      = p.status
        root.title       = p.title
        root.artist      = p.artist
        root.album       = p.album

        if (trackChanged) {
            // New track: show whatever art we currently know for it
            // (often "" since the art file is written asynchronously,
            // after the track-change is announced). A follow-up
            // metadata line with the real artUrl will arrive shortly
            // and update this the next time _pickActivePlayer runs.
            root.art = p.art
        } else if (p.art !== "") {
            // Same track: only overwrite with a real value, never blank
            // it out due to a transient empty line.
            root.art = p.art
        }

        root.duration    = p.duration
        root.durationFmt = root.fmt(p.duration)
    }

    Timer {
        id: pickSettleTimer
        interval: 150
        onTriggered: root._pickActivePlayer()
    }

    Process {
        id: ctl
        function run(cmd) {
            ctl.command = cmd
            ctl.running = true
        }
    }

    Process {
        id: metaFollow
        command: ["playerctl", "-a", "--follow", "metadata", "--format",
        "{{playerName}}" + root._sep + "{{status}}" + root._sep + "{{title}}" + root._sep +
        "{{artist}}" + root._sep + "{{album}}" + root._sep + "{{mpris:artUrl}}" + root._sep +
        "{{mpris:length}}"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(root._sep)
                if (parts.length < 7) return

                    const playerName = parts[0]
                    if (playerName.trim() === "") return

                        const status = parts[1]

                        if (parts[2].trim() === "") return

                            const normalizedTitle = parts[2].replace(/\s*-\s*YouTube\s*$/i, "").trim()
                            const cacheKey = playerName + root._sep + normalizedTitle + root._sep + parts[3]
                            const newArt = parts[5]

                            let resolvedArt
                            if (newArt !== "") {
                                root._artCache[cacheKey] = newArt
                                resolvedArt = newArt
                            } else if (root._artCache[cacheKey]) {
                                resolvedArt = root._artCache[cacheKey]
                            } else {
                                // No art known yet for this exact track —
                                // leave blank rather than borrowing the
                                // previous track's art from this or any
                                // other player.
                                resolvedArt = ""
                            }

                            const lenUs = parseFloat(parts[6])
                            const durationSecs = (!isNaN(lenUs) && lenUs > 0) ? lenUs / 1_000_000.0 : 0

                            root._players[playerName] = {
                                status: status,
                                title: parts[2],
                                artist: parts[3],
                                album: parts[4],
                                art: resolvedArt,
                                duration: durationSecs,
                                ts: Date.now()
                            }

                            if (status !== "Playing" && status !== "Paused") {
                                delete root._players[playerName]
                            }

                            pickSettleTimer.restart()
            }
        }

        onExited: (code, status) => metaRestart.start()
    }

    Timer {
        id: metaRestart
        interval: 1500
        onTriggered: metaFollow.running = true
    }

    Process {
        id: playerListProc
        command: ["playerctl", "-l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const live = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                let changed = false
                for (const name in root._players) {
                    if (live.indexOf(name) === -1) {
                        delete root._players[name]
                        changed = true
                    }
                }
                if (changed) pickSettleTimer.restart()
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: playerListProc.running = true
    }

    Timer {
        interval: 1000
        running: root.active
        repeat: true
        onTriggered: if (!root.seeking && root.activePlayerName !== "") posProc.running = true
    }

    Process {
        id: posProc
        command: root.activePlayerName !== "" ? ["playerctl", "--player=" + root.activePlayerName, "position"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseFloat(text)
                if (!isNaN(val) && !root.seeking) {
                    root.position = val
                    root.positionFmt = root.fmt(val)
                }
            }
        }
    }
}
