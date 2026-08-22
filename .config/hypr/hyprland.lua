-- Hyprland 0.55 Lua Configuration
-- https://wiki.hypr.land/Configuring/Start/

--------------------
---- MONITORS ----
--------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "konsole"
local fileManager = "dolphin"
local menu        = "rofi -show drun"
local mainMod     = "SUPER"

--------------------
---- LAYER RULES ----
--------------------

hl.layer_rule({ match = { namespace = "eww"              }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "volume-popup" },  ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "bar" },  ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "gtk-layer-shell"  }, blur = true })
hl.layer_rule({ match = { namespace = "rofi"             }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" },  ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "notifications"    }, blur = true })
hl.layer_rule({ match = { namespace = "volume-popup"     }, blur = true })
hl.layer_rule({ match = { namespace = "brightness-popup" }, blur = true })
hl.layer_rule({ match = { namespace = "bt-popup"         }, blur = true })
hl.layer_rule({ match = { namespace = "wifi-popup"       }, blur = true })
hl.layer_rule({ match = { namespace = "bar-window" }, blur = true, ignore_alpha = 0.05, animation = "false" })
hl.layer_rule({
    match = { namespace = "bar-trigger" },
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:popup:battery" },
    blur = true,
    ignore_alpha = 0.4,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:toast" },
    blur = true,
    ignore_alpha = 0.4,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:screenshot" },
    blur = true,
    ignore_alpha = 0.4,
    animation = "false"
})
hl.layer_rule({
    match = { namespace = "quickshell:screenshot-fontbrowser" },
    blur = true,
    ignore_alpha = 0.4,
})
hl.layer_rule({
    match = { namespace = "osd-popup" },
    blur = true,
    ignore_alpha = 0.2,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:screenshot-saveas" },
    blur = true,
    ignore_alpha = 0.4,
})
hl.layer_rule({
    match = { namespace = "quickshell:popup:wifi" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:wallpaper" },
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:videowallpaper" },
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:popup:battery" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:popup:notifications" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:musicPopup" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "volume-popup" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:popup:bluetooth" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({ match = { namespace = "top-bar-window"   }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "battery-popup"    }, blur = true, ignore_alpha = 0.05 })
hl.layer_rule({ match = { namespace = "shortcuts-window" }, blur = true, ignore_alpha = 0.1  })
hl.layer_rule({ match = { namespace = "commands-window"  }, blur = true, ignore_alpha = 0.1  })
hl.layer_rule({ match = { namespace = "music-popup"      }, blur = true, ignore_alpha = 0.1,
              animation = "slide bottom" })
hl.layer_rule({ match = { namespace = "datetime-popup"   }, blur = true, ignore_alpha = 0.1,
              animation = "slide bottom" })
hl.layer_rule({
    match = { namespace = "datetime-popup" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:popup:applications" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "false",
})
hl.layer_rule({
    match = { namespace = "quickshell:toast" },
    blur = true,
    ignore_alpha = 0.4,   -- was 0.1 - lets the compositor skip blurring once the card's
    -- own opacity/drag-fade has already faded it out most of the way
    animation = "false",
})
hl.layer_rule({ match = { namespace = "selection"        }, no_anim = true })
hl.layer_rule({ match = { namespace = "hyprlock" }, animation = "slide top" })



-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
hl.exec_cmd("~/.config/hypr/shellwrapper.sh")
hl.exec_cmd("~/.config/hypr/volume-osd --daemon &")
-- hl.exec_cmd("dunst")
hl.exec_cmd("~/.config/hypr/autoplay.sh")
-- hl.exec_cmd("pkill cava; rm -f /tmp/cava.fifo; mkfifo /tmp/cava.fifo; cava -p ~/.config/cava/config")
hl.exec_cmd("kdeconnectd")
hl.exec_cmd("kded")
hl.exec_cmd("kglobalaccel6")
hl.exec_cmd("/usr/lib/kdeconnectd")
hl.exec_cmd("kdeconnect-indicator")
hl.exec_cmd("bash ~/.config/hypr/lock-before-suspend.sh &")

-- hl.exec_cmd("playerctld daemon")
-- hl.exec_cmd("bash ~/.config/eww/popup-monitor.sh")
-- hl.exec_cmd("bash ~/.config/eww/player-daemon.sh")
-- hl.exec_cmd("bash ~/.config/eww/player-start.sh")
-- hyprexpo plugin config (set after plugin loads)
-- hl.exec_cmd("hyprctl keyword plugin:hyprexpo:columns 3")
-- hl.exec_cmd("hyprctl keyword plugin:hyprexpo:gap_size 5")
-- hl.exec_cmd("hyprctl keyword plugin:hyprexpo:bg_col 'rgb(111111)'")
-- hl.exec_cmd("hyprctl keyword plugin:hyprexpo:workspace_method 'center current'")
-- hl.exec_cmd("hyprctl keyword plugin:hyprexpo:enable_gesture false")
-- hl.exec_cmd("hyprctl keyword plugin:hyprexpo:gesture_distance 300")
end)

-- ── Cursor ────────────────────────────────────────────────────────────────
hl.env("XCURSOR_SIZE",                        "18")
hl.env("XCURSOR_THEME",                       "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE",                     "18")

-- ── Qt / Electron ─────────────────────────────────────────────────────────
hl.env("QT_QPA_PLATFORM",                     "wayland")
hl.env("QT_QPA_PLATFORMTHEME",                "kde")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT",        "auto")

-- ── Intel rendering ───────────────────────────────────────────────────────
hl.env("__GL_THREADED_OPTIMIZATIONS",         "1")
hl.env("mesa_glthread",                       "true")
hl.env("vblank_mode",                         "0")
hl.env("__GL_SYNC_TO_VBLANK",                 "0")
hl.env("LIBGL_DRI3_DISABLE",                  "0")
hl.env("ANV_QUEUE_THREAD_DISABLE",            "0")
hl.env("vblank_mode",                      "1")
hl.env("__GL_SYNC_TO_VBLANK",              "0")
-- hl.env("WAYLAND_DISABLE_FRACTIONAL_SCALE,      1")
-- ── AMD rendering (swap with Intel block if on AMD) ───────────────────────
-- hl.env("mesa_glthread",                    "true")
-- hl.env("vblank_mode",                      "0")
-- hl.env("__GL_SYNC_TO_VBLANK",              "0")
-- hl.env("RADV_PERFTEST",                    "aco,rt")
-- hl.env("AMD_VULKAN_ICD",                   "RADV")
-- hl.env("WLR_RENDERER",                     "vulkan")  -- test first, may break screenshare

-- ── Wayland / wlroots ─────────────────────────────────────────────────────
hl.env("WLR_DRM_NO_ATOMIC",                   "0")
hl.env("WLR_NO_HARDWARE_CURSORS",             "1")

-----------------------
----- PERMISSIONS -----
-----------------------

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
    cursor = {
        no_warps = true
    },
    misc = {
        force_default_wallpaper = 0,
            disable_hyprland_logo   = true,
    },

    general = {
        gaps_in          = 0,
        gaps_out         = 0,
        border_size      = 2,
        resize_on_border = true,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 10,
        rounding_power   = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.75,

        --        dim_inactive = true,
        --        dim_strength = 0.08,

        shadow = {
            enabled        = true,
            range          = 20,
            render_power   = 4,
            --          color          = "rgba(0,0,0,0.4)",
          --          color_inactive = "rgba(0,0,0,0.2)",
        },

        blur = {
            enabled           = true,
            size              = 6,        -- was 6
            passes            = 3,        -- was 3
            noise             = 0.02,
            contrast          = 0.9,      -- was 0.9 - disabled, one less multiply per pixel per pass
            brightness        = 0.75,      -- was 0.85 - disabled, same reason
            vibrancy          = 0.2,        -- was 0.20 - disabled
            vibrancy_darkness = 0.5,
            special           = true,
            popups            = true,
            new_optimizations = true,
            ignore_opacity    = true,
--             xray              =true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- SOURCE: ~/.cache/wal/hyprland-colours.conf
dofile(os.getenv("HOME") .. "/.cache/wal/hyprland-colours.lua")

----------------------
---- BEZIER CURVES ----
----------------------

-- Snappy deceleration — windows land fast and crisp
hl.curve("snap",          { type = "bezier", points = { {0.13, 0.99}, {0.22, 1.0}  } })
-- Smooth ease for fades and layers
hl.curve("easeOutQuint",  { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
-- Slightly overshooting — the "bouncy" feel
hl.curve("overshot",      { type = "bezier", points = { {0.05, 0.9},  {0.1,  1.05} } })
-- Elastic exit for windows closing/leaving
hl.curve("easeInBack",    { type = "bezier", points = { {0.36, 0},    {0.66, -0.56}} })
-- Quick linear-ish ramp for things that need no personality
hl.curve("linear",        { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",  { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",         { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
-- Smooth cubic for layer transitions
hl.curve("easeInOutCubic",{ type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })

--------------------
---- ANIMATIONS ----
--------------------

-- Global master switch
hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })

-- Borders — snappy colour transitions
hl.animation({ leaf = "border",        enabled = true,  speed = 4.5,  bezier = "snap" })

-- Windows — snappy in, clean out with slight pop
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.0,  bezier = "snap" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 3.8,  bezier = "overshot",  style = "popin 80%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.2,  bezier = "easeInBack",style = "popin 80%" })
--hl.animation({ leaf = "windowsMove",   enabled = true,  speed = 3.5,  bezier = "overshot" })

-- Fades — smooth, not sluggish
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 3.0,  bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 2.0,  bezier = "easeInOutCubic" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 2.5,  bezier = "quick" })
--hl.animation({ leaf = "fadeDim",       enabled = true,  speed = 2.5,  bezier = "quick" })

-- Layers (eww popups etc.) — bouncy slide in, quick out
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 3.2,  bezier = "overshot",      style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 2.2,  bezier = "easeInOutCubic",style = "slide" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 2.0,  bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.4,  bezier = "almostLinear" })

-- Workspaces — fast fade, feels snappy without being jarring
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 2.2,  bezier = "snap",      style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.4,  bezier = "snap",      style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 2.0,  bezier = "almostLinear", style = "fade" })

------------------------
---- WORKSPACE RULES ----
------------------------

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

-----------------------
---- WINDOW RULES ----
-----------------------

-- No borders/rounding on tiled windows in single-window or fullscreen workspaces
hl.window_rule({
    match       = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})
hl.window_rule({
    match       = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

-- Suppress maximize events
hl.window_rule({
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- Ignore phantom xwayland popups
hl.window_rule({
    match    = { class = "^$", title = "^$", xwayland = true,
        float = true, fullscreen = false, pin = false },
        no_focus = true,
})

-- Dunst opacity
hl.window_rule({
    match   = { class = "^dunst$" },
    opacity = "0.45 0.45",
})

-- In hyprland.lua
hl.window_rule({
    match = { class = "eww-calendar" },
    animation = "popin 80%",
    float = true,
})


--------------
-- RULES------
--------------

-- Prevent the popup from stealing focus when it opens.
-- This allows workspace clicks to pass through to the window beneath it.
-- 1. Prevent the popup from stealing focus when it spawns.
hl.window_rule({
    name = "volume-popup-no-focus",
    match = {
        class = "quickshell",       -- IMPORTANT: Run `hyprctl clients` in terminal to get your exact class
        title = "VolumePopup"       -- IMPORTANT: Run `hyprctl clients` to get your exact title
    },
    float = true,
    no_initial_focus = true,        -- CRITICAL: Keeps focus on the background window
})

-- 2. Listen for focus changes. If the popup loses focus, close it.
hl.on("window.active", function(active_win, focus_reason)
-- If the popup itself just gained focus (e.g., you clicked inside it), do nothing.
if active_win and active_win.class == "quickshell" and active_win.title == "VolumePopup" then
    return
    end

    -- Otherwise, the user clicked outside. Find the popup and close it.
    for _, win in ipairs(hl.get_windows()) do
        if win.class == "quickshell" and win.title == "VolumePopup" then
            hl.dsp.closewindow(win.address)
            break
            end
            end
            end)


--------------------
---- PLUGINS ----
--------------------

------------------
---- GESTURES ----
------------------

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       modifiers = "ALT", action = "close" })

--------------------
---- KEYBINDINGS ----
--------------------

-- Bar toggle
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/hypr/toggle-bar.sh"))

-- Touchpad toggle
hl.bind("ALT + M", hl.dsp.exec_cmd("bash ~/.config/hypr/toggle_touchpad.sh"))
-- Toggle the workspace overview: Alt+Tab -> Quickshell global shortcut
hl.bind("ALT + Tab", hl.dsp.global("quickshell:workspaceOverviewToggle"))
hl.bind("ALT_L", hl.dsp.global("quickshell:workspaceOverviewConfirm"), { release = true })
-- Power menu / schedule
hl.bind(mainMod .. " + escape",         hl.dsp.exec_cmd("~/.config/rofi/powermenu.sh"))
hl.bind(mainMod .. " + SHIFT + escape", hl.dsp.exec_cmd("~/.config/hypr/schedule_action.sh"))

-- Monitor layout switches
-- hl.bind("ALT + SHIFT + S", hl.dsp.exec_cmd(
    --     'hyprctl keyword monitor "eDP-1,1920x1080@60.05,0x0,1.5" ; '..
    --     'hyprctl keyword monitor "HDMI-A-1,disable" ; '..
    --     'killall -9 eww 2>/dev/null ; eww daemon ; '..
    --     'eww open bar-window && eww open top-bar-window'
    -- ))

    hl.bind("ALT + S", hl.dsp.exec_cmd("~/.config/hypr/hdmi.sh"))
    hl.bind("ALT" .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/hdmi-refresh.sh"))

    -- Reload eww bar
    -- hl.bind("ALT + R", hl.dsp.exec_cmd(
        --     'killall -9 eww 2>/dev/null ; bash ~/.config/eww/preload.sh & eww daemon && sleep 0.5; eww open bar-window'
        -- ))
        hl.bind("ALT + R", hl.dsp.exec_cmd(
            'bash ~/.config/quickshell/scripts/rofi-animation-scale.sh'
        ))

        -- VNC
        hl.bind("ALT + V", hl.dsp.exec_cmd("~/.config/hypr/vnc.sh"))

        -- Wallpaper
        hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/wallpaper_switcher.sh"))
        hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.config/hypr/video-wallpaper-selector.sh"))
        -- Player controls
        hl.bind("ALT + N", hl.dsp.exec_cmd(
            'playerctl --ignore-player=kdeconnect next'
        ), { locked = true })
        hl.bind("ALT + P", hl.dsp.exec_cmd(
            'playerctl --ignore-player=kdeconnect previous'
        ), { locked = true })

        -- hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("eww open commands-window --toggle"))
        -- hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("eww open shortcuts-window --toggle"))
        hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call commands toggle"))
        hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs ipc call shortcuts toggle"))
        -- Lock / suspend
        -- hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("bash ~/.config/gtklock/lock.sh"))
        hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("qs ipc call lock lock"))
        -- Apps
        hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
        hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
        hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))

        -- Window management
        hl.bind(mainMod .. " + C", hl.dsp.window.close())
        hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
        hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
        hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))
        hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 1 }))

        -- Minimize to special workspace
        hl.bind(mainMod .. " + N",         hl.dsp.window.move({ workspace = "special:minimized" }))
        hl.bind(mainMod .. " + SHIFT + N", hl.dsp.workspace.toggle_special("minimized"))

        -- Screenshot
        -- hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(
            --     'sleep 0.2 && grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png && notify-send "Screenshot saved."'
            -- ))
            hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("qs ipc call screenshot capture"))

            -- Autoplay toggle
            hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.config/hypr/autoplay.sh"))

            -- Clipboard
            hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(
                "cliphist list | rofi -dmenu -config ~/.config/rofi/config-history.rasi | cliphist decode | wl-copy"
            ))

            -- Focus movement
            hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
            hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
            hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
            hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
            -- Workspace switching
            for i = 1, 10 do
                local key = i % 10  -- 10 maps to key 0
                hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
                hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
                end

                -- Mouse window management
                hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
                hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

                ---Volume
                hl.bind(
                    "XF86AudioRaiseVolume",
                    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/volume-osd up"),
                        { repeating = true }
                )

                hl.bind(
                    "XF86AudioLowerVolume",
                    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/volume-osd down"),
                        { repeating = true }
                )

                hl.bind(
                    "XF86AudioMute",
                    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/volume-osd mute")
                )

                hl.bind(
                    "XF86AudioMicMute",
                    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/volume-osd micmute")
                )

                hl.bind(
                    "F4",
                    hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/volume-osd micmute")
                )

                ---BRIGHTNESS
                hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(
                    'brightnessctl -e4 -n2 set 5%+ && qs msg osd show brightness "$(brightnessctl -m | cut -d, -f4 | tr -d %)"'
                ), { repeating = true })
                hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(
                    'brightnessctl -e4 -n2 set 5%- && qs msg osd show brightness "$(brightnessctl -m | cut -d, -f4 | tr -d %)"'
                ), { repeating = true })
                -- Media keys
                hl.bind("XF86AudioNext",  hl.dsp.exec_cmd('playerctl --player="%any,!kdeconnect" next'),       { locked = true })
                hl.bind("XF86AudioPause", hl.dsp.exec_cmd('playerctl --player="%any,!kdeconnect" play-pause'), { locked = true })
                hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd('playerctl --player="%any,!kdeconnect" play-pause'), { locked = true })
                hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd('playerctl --player="%any,!kdeconnect" previous'),   { locked = true })
