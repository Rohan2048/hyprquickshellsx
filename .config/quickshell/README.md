# hypr65536 → QuickShell port (work in progress)

## What's in here

```
shell.qml                    entry point (ShellRoot)
Theme/
  Theme.qml                  singleton: pywal palette + glass colors/metrics
  qmldir
Widgets/
  GlassPanel.qml             the translucent rounded container (bar + popups)
  GlassButton.qml            clickable pill button (gov-btn / sink-btn / toggle-btn equivalent)
Services/
  Volume.qml                 wraps scripts/volume-listener.sh (pactl subscribe, event-driven)
  Battery.qml                wraps scripts/battery-listener.sh (10s poll, matches eww defpoll)
  Wifi.qml                   wraps scripts/wifi-history.sh (nmcli monitor, event-driven)
  Bluetooth.qml              wraps scripts/bt-history.sh (dbus PropertiesChanged, event-driven)
  qmldir
Bar/
  Bar.qml                    the top bar (PanelWindow)
  modules/
    ControlIcon.qml          generic right-side icon button
Popups/
  VolumePopup.qml            full port of volume-popup-widget
  BatteryPopup.qml           full port of battery-popup-widget (Turbo/Prioritise/Optimise)
scripts/                     bash scripts copied verbatim from your eww config — unchanged
  volume-listener.sh
  battery-listener.sh
  turbo-state.sh
  turbo-toggle.sh
  wifi-history.sh
  bt-history.sh
```

## Bar status (this pass)

Fixed a bug from the first draft: your `bar-window` is
`(geometry :anchor "bottom center" :height "28px")` — bottom of the screen,
not top. Bar and both popups now anchor `bottom`, matching your eww config
exactly (`Theme.barHeight` is 28px to match).

The bar itself is now fully live:
- Power button → runs your `rofi/powermenu.sh`
- Wifi / Bluetooth icons → real radio-on/off state from `Wifi.qml` / `Bluetooth.qml`
  (dimmed when off). Click currently just logs state to console — `WifiPopup.qml`
  / `BluetoothPopup.qml` (saved networks / paired devices lists) are the next
  logical step, not done yet.
- Volume icon → live mute state, opens the full `VolumePopup`
- Battery icon → live percentage, opens the full `BatteryPopup`; falls back to
  a plug glyph when `Battery.hasBattery` is false
- Clock → live time/date, click is a TODO for `CalendarPopup.qml`
- Bell → placeholder, `NotificationsPopup.qml` not done yet
- Music tray → still just a "port pending" label; needs the MPRIS dbus-next
  daemon wired up as `Services/Mpris.qml` before it can show anything real

Copy this whole folder to `~/.config/quickshell/`, run `quickshell`, done (once quickshell +
qt6 + qt6-declarative are installed).

## Why this structure

Your eww setup was already event-driven at the shell-script layer (deflisten +
pactl/nmcli/dbus watchers). That's the expensive part to get right and it already
works, so **the scripts are untouched**. What changes is only the front end:

- `deflisten VAR` → a long-lived `Process` in a `Services/X.qml` singleton, parsing
  each stdout line as JSON, same as your scripts already emit.
- `defpoll VAR :interval "10s"` → `Process` + `Timer { interval: 10000; repeat: true }`.
- `defwidget` → a `.qml` component.
- `defwindow` → a `PanelWindow` (bar/dock) or a `PanelWindow` with `exclusiveZone: 0`
  used as a popup (no true eww-style popup positioning API needed — anchoring +
  margins gets you the same top-right placement you're using now).

## The blur problem — same fix as before

You already discovered blur has to come from the compositor's layer-rule, not
CSS (`backdrop-filter` never worked in GTK either). Same story here: QuickShell
surfaces are plain wlr-layer-shell surfaces, so give each one a stable
`WlrLayershell.namespace` (already set: `quickshell:bar`, `quickshell:popup:volume`,
`quickshell:popup:battery`) and match it in your compositor config, e.g. for Hyprland:

```
layerrule = blur, ^(quickshell:bar)$
layerrule = ignorezero, ^(quickshell:bar)$
layerrule = blur, ^(quickshell:popup:.*)$
layerrule = ignorezero, ^(quickshell:popup:.*)$
```

niri's `layer-rules` block does the same match-by-namespace thing.

## pywal integration

`Theme.qml` watches `~/.cache/wal/colors.json` directly with `FileView` and
re-parses on change — so `wal -i <wallpaper>` live-updates every panel without
restarting quickshell. No template files needed for the shell itself (you'll
still want your existing kdeglobals pywal template for Qt/KDE apps, that's
unrelated to this).

## What's stubbed / not ported yet

Everything else in your eww config follows the exact same two-file pattern
(`Services/X.qml` + `Popups/XPopup.qml`) as Volume/Battery above:

- **Wifi** — port `wifi-history.sh`/`wifi-scan.sh` unchanged, same nmcli-monitor
  loop, into `Services/Wifi.qml`. Popup = saved-networks list + toggle (screenshot 7).
- **Bluetooth** — same shape as Wifi, paired-devices list with Forget buttons (screenshot 8).
- **Notifications** — `NOTIF_LIST` deflisten → `Services/Notifications.qml`, list of
  WhatsApp-style entries with delete buttons (screenshot 6).
- **Calendar** — `CAL_DATA` deflisten + `cal-detail.sh` → `Services/Calendar.qml`,
  grid built with a `GridLayout`/`Repeater` over day cells, event/holiday dots
  (screenshot 9). This one's the most layout work since it's a full month grid.
- **Music tray / player popup** — the dbus-next MPRIS daemon (`player-daemon.py`)
  slots in as a `Process` the same way; UI is a GTK4/Adwaita popup in your version,
  straightforward `RowLayout` port.
- **Shortcuts dock, command palette, powermenu, lazy-mode prompt** — same pattern again.

`set-governor.sh`, `set-tuned.sh`, `set-sink.sh` weren't in the dump you pasted
(only referenced) — drop your existing copies into `scripts/` and the calls in
`Battery.qml`/`Volume.qml` will work as-is.

## Next step

Tell me which one to port next (wifi, bluetooth, notifications, calendar, or
music) and I'll build it out fully the same way as Volume/Battery — real
Service + real Popup, not a stub.
