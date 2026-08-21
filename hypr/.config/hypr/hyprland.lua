-- ~/.config/hypr/hyprland.lua
--
-- Hyprland, configured as the Linux twin of the macOS AeroSpace + SketchyBar setup
-- in this repo. Two rules govern everything below:
--
--   1. Keybindings mirror aerospace/.config/aerospace/aerospace.toml one-for-one.
--      ALT is the modifier there, so ALT is mainMod here — muscle memory ports intact.
--      SUPER is left free for launching things (AeroSpace never used it; macOS did
--      that job with Raycast/CMD, and rofi/SUPER takes over here).
--   2. Colors and geometry mirror wezterm.lua + sketchybarrc: translucent dark glass,
--      10px rounding, 5px gaps, white-at-53% active borders, mint-sage accent.
--
-- Written in Hyprland's Lua config format (the one `Hyprland` generates on a fresh
-- install — see linux-configs/hyprland.lua for the pristine original). If your build
-- predates Lua config support, it will look for hyprland.conf instead and ignore this
-- file entirely; `hyprctl version` tells you which you have.


-- ─────────────────────────────────────────────
-- Palette  (single source of truth; from wezterm.lua + sketchybarrc)
-- ─────────────────────────────────────────────

local c = {
    -- sketchybar's `borders` colors: active 0x88ffffff, inactive 0x20ffffff
    border_active   = "rgba(ffffff88)",
    border_accent   = "rgba(6eeb91cc)",  -- wezterm active-tab foreground
    border_inactive = "rgba(ffffff20)",
    shadow          = 0xee050806,        -- wezterm background, opaque
}


-- ─────────────────────────────────────────────
-- Programs
-- ─────────────────────────────────────────────

local terminal    = "wezterm"
local fileManager = "thunar"
local menu        = "rofi -show drun"
local browser     = "zen-browser"
local lock        = "hyprlock"


-- ─────────────────────────────────────────────
-- Monitors and scaling
-- ─────────────────────────────────────────────
-- This block is why the desktop looks the size it does. If everything is too big or
-- too small, this is the only place to change it — not font sizes in waybar/rofi/
-- wezterm, which are all expressed in *logical* pixels and follow the scale set here.
--
-- This machine: the WQHD panel, 2560x1440 @ 120Hz (confirmed via `hyprctl monitors`).
--
--   panel            native        scale   logical size    logical PPI   vs MacBook
--   ---------------  ------------  ------  --------------  ------------  ----------
--   FHD  144Hz       1920x1080     1.00    1920x1080       157           denser
-- > WQHD 120Hz       2560x1440     1.60    1600x900        131           about equal
--   WQHD 120Hz       2560x1440     1.25    2048x1152       168           denser
--
-- A 14" MacBook Pro renders 1512x982 logical on a 254 PPI panel — roughly 127 logical
-- PPI. Scale 1.6 is the closest match, which is what "make it look like the Mac"
-- actually means: same apparent size, more physical pixels underneath.
--
-- `scale = "auto"` is what the stock config ships, and on this panel it rounds up to
-- 2.0 — 1280x720 logical, fewer usable pixels than a 2010 laptop. That is the reason
-- everything looked oversized.
--
-- If 1600x900 of working space turns out to be too little, 1.25 is the other sane
-- value: sharper and denser than the Mac, at the cost of smaller text. Both divide the
-- panel evenly, which is required — Hyprland rejects a fractional scale that leaves a
-- non-integer logical size and silently falls back to 1.0.
--
--   2560 / 1.60 = 1600      1440 / 1.60 = 900
--   2560 / 1.25 = 2048      1440 / 1.25 = 1152
--
-- Set to "auto" to go back to detecting the panel from the table below instead — worth
-- doing if this config ever lands on a different machine.

local PANEL_SCALE = 1.6

-- Fractional scales must divide the panel evenly or Hyprland rejects them and falls
-- back to 1.0. Both values below are exact: 2560/1.6 = 1600, 1440/1.6 = 900.
local SCALE_FOR_HEIGHT = {
    [1440] = 1.6,   -- WQHD panel (this laptop)
    [1200] = 1.25,
    [1080] = 1.0,   -- FHD panel: native is already the right density
}

local internalScale = 1.0
if type(PANEL_SCALE) == "number" then
    internalScale = PANEL_SCALE
else
    -- Guarded: hl.get_monitors() may not be populated this early during the first
    -- config parse, and a hard error here would take the whole config down. Falling
    -- back to 1.0 is the safe direction — native resolution, nothing oversized.
    local ok, detected = pcall(function()
        for _, m in ipairs(hl.get_monitors() or {}) do
            if tostring(m.name):match("^eDP") then
                return SCALE_FOR_HEIGHT[m.height]
            end
        end
        return nil
    end)
    if ok and detected then
        internalScale = detected
    end
    hl.print(("hyprland.lua: internal panel scale = %s%s")
        :format(internalScale, (ok and detected) and " (detected)" or " (fallback)"))
end

-- `highrr` picks the highest refresh rate the panel offers — 120Hz here. Preferred to
-- a literal "2560x1440@120" because the panel reports a fractional rate (119.88 or
-- similar) and an exact-match mode string that misses is rejected outright. The stock
-- `preferred` can settle on 60Hz, and a panel below its native mode is the *other* way
-- a desktop ends up looking oversized and soft.
-- The internal panel is `eDP-1` on this laptop, but that is not guaranteed — it
-- depends on the driver and, on a mux'd machine, on which GPU is driving the display.
-- If the name is wrong the rule matches nothing, the wildcard below applies instead,
-- and you get the oversized desktop this whole block exists to prevent. So: emit a
-- rule for every internal-looking output actually present, and keep the static eDP-1
-- rule as a fallback for when the query isn't answerable yet.
--
-- Confirm the real name with: hyprctl monitors
local internalOutputs = {}
pcall(function()
    for _, m in ipairs(hl.get_monitors() or {}) do
        local name = tostring(m.name)
        if name:match("^eDP") or name:match("^LVDS") or name:match("^DSI") then
            internalOutputs[#internalOutputs + 1] = name
        end
    end
end)

if #internalOutputs == 0 then
    internalOutputs = { "eDP-1" }
end

for _, output in ipairs(internalOutputs) do
    hl.monitor({
        output   = output,
        mode     = "highrr",
        position = "auto",
        scale    = internalScale,
    })
end

-- Everything else (external displays) at native.
--
-- scale = 1 rather than "auto" on purpose: "auto" is what rounds a HiDPI panel up to
-- 2.0 and produces a 1280x720 desktop. If a rule above ever fails to match, falling
-- through to 1 gives a display that is too *small* — visibly wrong but usable and
-- obvious, rather than the silent inflation that sent us round this loop once already.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})


-- ─────────────────────────────────────────────
-- Environment
-- ─────────────────────────────────────────────

hl.env("XCURSOR_SIZE",             "24")
hl.env("HYPRCURSOR_SIZE",          "24")

-- Wayland-native where possible; XWayland only as fallback.
hl.env("MOZ_ENABLE_WAYLAND",       "1")
hl.env("QT_QPA_PLATFORM",          "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME",     "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")   -- VSCode, Antigravity IDE, Brave
hl.env("GDK_BACKEND",              "wayland,x11")
hl.env("SDL_VIDEODRIVER",          "wayland")

-- Scaling: let each toolkit read the compositor's per-output scale instead of being
-- told a global multiplier. GDK_SCALE and QT_SCALE_FACTOR are integer-only overrides —
-- if either is set (some install guides and .desktop files set GDK_SCALE=2), every GTK
-- or Qt window renders at double size regardless of what the monitor block says. This
-- pins them to 1 so a stray value inherited from elsewhere can't win.
--
-- If the desktop still looks oversized after fixing the monitor scale, check for them:
--   env | grep -Ei 'scale|dpi'
hl.env("GDK_SCALE",                    "1")
hl.env("QT_SCALE_FACTOR",              "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",  "1")

-- NVIDIA: only uncomment these while running `supergfxctl -m Hybrid`. On the
-- Integrated mode you daily-drive (per upc-plans/linux-setup.md §8) they point
-- hardware video decode at a GPU that isn't in the pipeline and break VA-API.
-- hl.env("LIBVA_DRIVER_NAME",           "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME",   "nvidia")
-- hl.env("NVD_BACKEND",                 "direct")


-- ─────────────────────────────────────────────
-- Autostart
-- ─────────────────────────────────────────────

hl.on("hyprland.start", function()
    -- Portals and anything launched by systemd/dbus need the Wayland env exported
    -- first, or screensharing and GTK file pickers come up blank. This must run
    -- before the rest.
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")

    -- hl.exec_cmd("waybar")                                   -- SketchyBar's counterpart
    hl.exec_cmd("hyprpaper")                                -- wallpaper
    hl.exec_cmd("mako")                                     -- notifications
    hl.exec_cmd("hypridle")                                 -- idle -> lock -> dpms
    hl.exec_cmd("systemctl --user start hyprpolkitagent")   -- GUI sudo prompts
    hl.exec_cmd("swayosd-server")                           -- volume/brightness OSD
    hl.exec_cmd("nm-applet --indicator")                    -- tray: wifi
    hl.exec_cmd("blueman-applet")                           -- tray: bluetooth

    -- Clipboard history, the cliphist half of what Raycast's clipboard did on macOS.
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)


-- ─────────────────────────────────────────────
-- Look and feel
-- ─────────────────────────────────────────────

hl.config({
    general = {
        -- Target: a 5px gutter everywhere — screen edges, between windows, and
        -- between the bar and the topmost window.
        --
        -- gaps_in is per-window-edge, so two adjacent windows each contribute one:
        -- the gap you actually see between them is gaps_in * 2. 2 -> ~4px, which is
        -- the closest an integer gets to 5 without the seam reading as 10.
        --
        -- gaps_out.top stacks on top of waybar's exclusive zone, not on the screen
        -- edge. waybar/style.css ends its capsule flush with the bottom of that zone
        -- (bottom margin 0), so top = 5 is exactly 5px of visible space between the
        -- capsule and the window under it. If you re-introduce a bottom margin in
        -- style.css, subtract it here or the gap grows by that much.
        --
        -- The conf-file form ("5 5 5 5") is not accepted here: the Lua layer types
        -- this as a css_gap, which wants either a plain integer or this table.
        gaps_in  = 2,
        gaps_out = { top = 5, right = 5, bottom = 5, left = 5 },

        -- `borders` on macOS drew 4px outside the window; Hyprland draws inside, so
        -- 3px reads at about the same weight.
        border_size = 3,

        col = {
            active_border   = { colors = { c.border_active, c.border_accent }, angle = 45 },
            inactive_border = c.border_inactive,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        -- macOS window corners are a touch rounder than the 10px sketchybar capsule,
        -- and they are squircles rather than quarter-circles. rounding_power > 2
        -- flattens the middle of the arc, which is what reads as "Mac" rather than
        -- "rounded rectangle"; 2 is a plain circular corner.
        rounding       = 12,
        rounding_power = 2.2,

        active_opacity   = 1.0,
        inactive_opacity = 0.97,

        shadow = {
            enabled      = true,
            range        = 18,
            render_power = 3,
            color        = c.shadow,
        },

        -- This is what makes the whole thing read as glass: wezterm sits at 0.80
        -- opacity and Hyprland blurs whatever is behind it, which is the Wayland
        -- equivalent of macos_window_background_blur = 38.
        blur = {
            enabled     = true,
            size        = 8,
            passes      = 3,
            vibrancy    = 0.1696,
            noise       = 0.008,
            brightness  = 0.85,
            contrast    = 1.05,
            popups      = true,
            special     = true,
        },
    },

    animations = { enabled = true },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
        smart_resizing = true,
    },

    master = { new_status = "master" },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            -- macOS trackpad muscle memory. Everything about this laptop's touchpad
            -- should feel like the MacBook's, not like stock Linux.
            natural_scroll         = true,
            disable_while_typing   = true,
            tap_to_click           = true,
            drag_lock              = true,
            scroll_factor          = 0.6,
        },
    },

    binds = {
        -- AeroSpace's alt-tab is a true toggle between the last two workspaces.
        allow_workspace_cycles = true,
        workspace_back_and_forth = false,
    },

    misc = {
        force_default_wallpaper  = 0,     -- no anime mascot; hyprpaper owns the background
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        focus_on_activate        = true,

        -- Two keys deliberately absent, both removed out from under this config:
        --
        --   vfr  — moved to `debug:` in 0.55 and explicitly marked as a debug variable
        --          not to be set in production. It defaults to on, so the laptop still
        --          gets the battery saving; there is simply nothing to declare.
        --
        --   new_window_takes_over_fullscreen — replaced in 0.53 by
        --          `misc:on_focus_under_fullscreen`, which is not a like-for-like
        --          swap (upstream discussion #12877: the old behaviour isn't
        --          reachable any more). Left unset rather than guessing at a value
        --          that would change focus behaviour in a way I can't predict.
    },

    cursor = {
        inactive_timeout   = 5,
        hide_on_key_press  = true,
    },

    xwayland = {
        -- Without this, X11 apps on a fractionally-scaled display are rendered at 1x
        -- and then bitmap-upscaled by the compositor: oversized *and* blurry, while
        -- native Wayland windows next to them look correct. force_zero_scaling makes
        -- XWayland render at 1x and leaves the toolkit to scale, which is sharp.
        -- Pair it with GDK_SCALE / QT_SCALE_FACTOR left unset (see the env block).
        force_zero_scaling = true,
    },
})


-- ─────────────────────────────────────────────
-- Animation curves
-- ─────────────────────────────────────────────
-- Kept from the Hyprland defaults — they are already close to macOS's spring feel,
-- which is the point of the exercise.

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })


-- ─────────────────────────────────────────────
-- Gestures
-- ─────────────────────────────────────────────
-- Replaces the SwipeAeroSpace cask from the Brewfile. Same gesture, natively.

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up",         action = "special", workspace_name = "magic" })


-- ═════════════════════════════════════════════
-- KEYBINDINGS — direct port of aerospace.toml
-- ═════════════════════════════════════════════

local mod = "ALT"          -- AeroSpace's modifier. Do not change; the whole map hangs off it.
local sup = "SUPER"        -- Launching and system actions.

-- ── Layout (aerospace: alt-slash / alt-comma / alt-shift-f) ──
-- `layout tiles horizontal vertical` toggles the split axis  -> togglesplit
-- `layout accordion ...` stacks windows in place             -> Hyprland groups (tabbed)
-- `layout floating tiling`                                   -> togglefloating
hl.bind(mod .. " + slash",     hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + comma",     hl.dsp.group.toggle())
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- ── Focus (aerospace: alt-h/j/k/l) ──
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left"  }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down"  }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up"    }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))

-- ── Move (aerospace: alt-shift-h/j/k/l) ──
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left"  }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down"  }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up"    }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- ── Resize (aerospace: alt-minus / alt-equal, `resize smart ∓50`) ──
-- "smart" resizes along the parent container's orientation; dwindle's smart_resizing
-- above gets us the same behaviour from a symmetric delta.
hl.bind(mod .. " + minus", hl.dsp.window.resize({ x = -50, y = -50 }), { repeating = true })
hl.bind(mod .. " + equal", hl.dsp.window.resize({ x =  50, y =  50 }), { repeating = true })

-- ── Numbered workspaces (aerospace: alt-1..9 / alt-shift-1..9) ──
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    -- AeroSpace's move-node-to-workspace does not follow the window. follow=false matches.
    hl.bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i, follow = false }))
end

-- ── Letter workspaces (aerospace: alt-a .. alt-z) ──
-- h/j/k/l are focus keys and f is the float toggle, so those are excluded exactly as
-- they are in aerospace.toml. Hyprland has no lettered workspaces natively, but named
-- ones are equivalent — "name:A" is the same thing AeroSpace calls workspace A.
local letters      = { "a","b","c","d","e","f","g","i","m","n","o","p","q","r","s","t","u","v","w","x","y","z" }
local moveLetters  = { "a","b","c","d","e",    "g","i","m","n","o","p","q","r","s","t","u","v","w","x","y","z" }

for _, ch in ipairs(letters) do
    hl.bind(mod .. " + " .. ch, hl.dsp.focus({ workspace = "name:" .. ch:upper() }))
end
for _, ch in ipairs(moveLetters) do
    hl.bind(mod .. " + SHIFT + " .. ch,
            hl.dsp.window.move({ workspace = "name:" .. ch:upper(), follow = false }))
end

-- ── Workspace / monitor navigation (aerospace: alt-tab, alt-shift-tab) ──
hl.bind(mod .. " + tab",         hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + SHIFT + tab", hl.dsp.workspace.move({ monitor = "+1" }))

-- Scroll through workspaces (aerospace had no equivalent; the generated config did)
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Drag/resize with the mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Scratchpad ──
-- AeroSpace has no scratchpad; this is the one addition to the movement map, because
-- Hyprland gives it away for free and it covers the "float a terminal over anything"
-- case that Warp's quick-access window handled on macOS.
hl.bind(sup .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(sup .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = false }))


-- ── Launching (SUPER — the half AeroSpace left to macOS/Raycast) ──
hl.bind(sup .. " + return",       hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + return",       hl.dsp.exec_cmd(terminal))            -- i3 muscle memory
hl.bind(sup .. " + space",        hl.dsp.exec_cmd(menu))                -- Raycast
hl.bind(sup .. " + E",            hl.dsp.exec_cmd(fileManager))
hl.bind(sup .. " + B",            hl.dsp.exec_cmd(browser))
hl.bind(sup .. " + W",            hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q",    hl.dsp.window.close())
hl.bind(sup .. " + F",            hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(sup .. " + SHIFT + F",    hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(sup .. " + P",            hl.dsp.window.pin({ action = "toggle" }))
hl.bind(sup .. " + L",            hl.dsp.exec_cmd(lock))

-- Clipboard history (Raycast's clipboard manager)
hl.bind(sup .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p clipboard | cliphist decode | wl-copy"))

-- Emoji picker (macOS ctrl-cmd-space)
hl.bind(sup .. " + period", hl.dsp.exec_cmd("rofi -show emoji"))

-- Screenshots. macOS cmd-shift-4 / cmd-shift-3 -> region / full screen.
hl.bind("SUPER + SHIFT + 4", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind("SUPER + SHIFT + 3", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind("SUPER + SHIFT + 5", hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"))
hl.bind("Print",             hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- Colour picker
hl.bind(sup .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Power menu / logout
hl.bind(sup .. " + SHIFT + E", hl.dsp.exec_cmd("wlogout -b 4"))


-- ── Idle, display sleep and the lid ──────────────────────────────────────────────
-- Hyprland does none of this itself. It has no idle timer, no screen blanking and no
-- lid handling — that is `hypridle`'s job (autostarted above; config in hypridle.conf),
-- and it will not happen at all if hypridle isn't installed and running. Check with
-- `pgrep hypridle` if the display never sleeps.

-- Put the display to sleep now, without locking. macOS: ctrl-shift-power.
hl.bind(sup .. " + SHIFT + L", hl.dsp.exec_cmd("hyprctl dispatch dpms off"))

-- Suspend the machine now.
hl.bind(sup .. " + SHIFT + Z", hl.dsp.exec_cmd("systemctl suspend"))

-- Lid switch. Guarded because `switch:` bind targets are parsed differently from key
-- names, and an unrecognised one here would abort the rest of the config.
--
-- This only turns the internal panel off so an external display keeps working with the
-- lid shut. Whether closing the lid *suspends* is systemd's decision, not Hyprland's —
-- set HandleLidSwitch / HandleLidSwitchExternalPower in /etc/systemd/logind.conf.
pcall(function()
    hl.bind("switch:on:Lid Switch",
            hl.dsp.exec_cmd("hyprctl keyword monitor \"eDP-1, disable\""), { locked = true })
    hl.bind("switch:off:Lid Switch",
            hl.dsp.exec_cmd("hyprctl keyword monitor \"eDP-1, highrr, auto, " .. internalScale .. "\""), { locked = true })
end)


-- ── Media and hardware keys ──
-- swayosd draws the macOS-style overlay; without it these still work, just silently.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"),  { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"),  { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ASUS-specific keys on the G14
hl.bind("XF86Launch1", hl.dsp.exec_cmd("rog-control-center"))                    -- ROG key
hl.bind("XF86Launch3", hl.dsp.exec_cmd("asusctl led-mode -n"))                   -- Aura key
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d asus::kbd_backlight set +1"), { locked = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d asus::kbd_backlight set 1-"), { locked = true })


-- ── Service mode (aerospace: alt-shift-semicolon -> [mode.service]) ──
-- Hyprland's submaps are the same idea. Guarded: hl.define_submap is newer than the
-- rest of the Lua API, and a missing function here would otherwise take the whole
-- config down and leave you at a black screen with no binds at all.
local ok, err = pcall(function()
    hl.define_submap("service", function()
        hl.bind("escape",     hl.dsp.submap("default"))
        hl.bind("R",          hl.dsp.layout("togglesplit"))          -- reset-ish: flatten split
        hl.bind("F",          hl.dsp.window.float({ action = "toggle" }))
        hl.bind("backspace",  hl.dsp.exec_cmd("hyprctl dispatch killactive"))

        -- aerospace `join-with <dir>` -> Hyprland `swapwindow <dir>`
        hl.bind("ALT + SHIFT + H", hl.dsp.window.swap({ direction = "left"  }))
        hl.bind("ALT + SHIFT + J", hl.dsp.window.swap({ direction = "down"  }))
        hl.bind("ALT + SHIFT + K", hl.dsp.window.swap({ direction = "up"    }))
        hl.bind("ALT + SHIFT + L", hl.dsp.window.swap({ direction = "right" }))

        hl.bind("down",         hl.dsp.exec_cmd("swayosd-client --output-volume lower"))
        hl.bind("up",           hl.dsp.exec_cmd("swayosd-client --output-volume raise"))
        hl.bind("SHIFT + down", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"))
    end)
    hl.bind(mod .. " + SHIFT + semicolon", hl.dsp.submap("service"))
end)

if not ok then
    -- Fall back to a flat set of binds so the functionality still exists, just without
    -- the modal wrapper.
    hl.print("hyprland.lua: submap API unavailable (" .. tostring(err) .. "), using flat binds")
    hl.bind(mod .. " + CTRL + H", hl.dsp.window.swap({ direction = "left"  }))
    hl.bind(mod .. " + CTRL + J", hl.dsp.window.swap({ direction = "down"  }))
    hl.bind(mod .. " + CTRL + K", hl.dsp.window.swap({ direction = "up"    }))
    hl.bind(mod .. " + CTRL + L", hl.dsp.window.swap({ direction = "right" }))
end


-- ═════════════════════════════════════════════
-- WINDOW RULES
-- ═════════════════════════════════════════════

-- Ignore app-initiated maximize requests, same as the stock config recommends.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix XWayland drag-and-drop ghost windows stealing focus.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Terminals get the frosted treatment; everything else stays opaque so text in
-- browsers and IDEs is never washed out. This is exactly the split wezterm.lua makes
-- on macOS (only the terminal sets window_background_opacity).
hl.window_rule({
    name  = "glass-terminals",
    match = { class = "^(org\\.wezfurlong\\.wezterm|wezterm|kitty|foot|Alacritty)$" },
    opacity = "0.92 0.88",
})

-- ── Workspace auto-routing ──
-- Port of aerospace.toml's [[on-window-detected]] blocks. Same destinations:
--   1 = terminals + editors, 3 = browsers, 5 = media.
-- `silent` keeps the window from yanking focus off what you're doing, which is how
-- AeroSpace's move-node-to-workspace behaves.

hl.window_rule({
    name  = "route-terminals-and-editors",
    match = { class = "^(org\\.wezfurlong\\.wezterm|wezterm|Code|code-oss|VSCodium|Antigravity|antigravity|dev\\.warp\\.Warp)$" },
    workspace = "1 silent",
})

hl.window_rule({
    name  = "route-browsers",
    match = { class = "^(zen|zen-browser|zen-alpha|Brave-browser|brave-browser|firefox)$" },
    workspace = "3 silent",
})

-- The two Brave PWAs pinned to workspace 5 on macOS (YouTube Music, YouTube) show up
-- on Linux as `brave-<app-id>-Default`. Same app IDs as in aerospace.toml.
hl.window_rule({
    name  = "route-media",
    match = { class = "^(brave-agimnkijcaahngcdmfeangaknmldooml-Default|brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default|Spotify|spotify|YouTube Music|com\\.github\\.th_ch\\.youtube_music)$" },
    workspace = "5 silent",
})

-- ── Floating dialogs ──
-- Sizes are percentages, not pixels, and that is the whole point. A literal
-- "900 600" is 56% x 67% of this panel's 1600x900 *logical* space (2560x1440 at
-- scale 1.6, see the monitor block above) — a settings dialog opening two-thirds of
-- the screen wide is what "the window is huge" was. Percentages stay proportionate
-- if the scale or the panel ever changes.
--
-- Anything not matched here tiles, and a lone tiled window fills the workspace — so
-- an unlisted utility (waypaper, nwg-look, a GTK "About" box) looks enormous for a
-- different reason. Add new ones to this list rather than to the picker list below.
hl.window_rule({
    name  = "float-dialogs",
    match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor|rog-control-center|org\\.pulseaudio\\.pavucontrol|xdg-desktop-portal-gtk|Thunar|thunar|nm-applet|blueman-applet|file-roller|org\\.gnome\\.FileRoller|Gpick|qalculate-gtk)$" },
    float = true,
    size  = "45% 55%",
    center = true,
})

-- Wallpaper and theme pickers are grids of thumbnails; they need width more than the
-- 45% a settings dialog gets, but still nothing close to fullscreen.
hl.window_rule({
    name  = "float-pickers-wide",
    match = { class = "^(waypaper|Waypaper|nwg-look|nwg-displays)$" },
    float = true,
    size  = "60% 65%",
    center = true,
})

hl.window_rule({
    name  = "float-picker-dialogs",
    match = { title = "^(Open File|Open Folder|Save File|Save As|Choose Files|File Upload|Open|Save)$" },
    float = true,
    size  = "55% 60%",
    center = true,
})

-- Picture-in-picture follows you across workspaces, like macOS PiP.
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float = true,
    pin   = true,
    size  = "480 270",
    move  = "100%-500 100%-320",
})


-- ═════════════════════════════════════════════
-- LAYER RULES
-- ═════════════════════════════════════════════
-- Waybar, rofi and mako are layer surfaces, not windows — their glass comes from here,
-- not from the decoration block above. This is what makes the bar look like SketchyBar
-- rather than a flat strip.

hl.layer_rule({ name = "blur-bar",       match = { namespace = "^waybar$" },   blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "blur-launcher",  match = { namespace = "^rofi$" },     blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "blur-notifs",    match = { namespace = "^notifications$" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "blur-osd",       match = { namespace = "^swayosd$" },  blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "blur-logout",    match = { namespace = "^wlogout$" },  blur = true })


-- ═════════════════════════════════════════════
-- WORKSPACE RULES
-- ═════════════════════════════════════════════

-- There is deliberately no "no gaps when only" rule here any more.
--
-- The usual pair — workspace_rule gaps_out = 0 plus a window_rule with rounding = 0
-- for w[tv1]/f[1] — made a lone window on a workspace go edge to edge with square
-- corners. Two visible consequences, both of which read as bugs rather than design:
--
--   * gaps_out = 0 puts the window's top edge flush against the bottom of waybar's
--     exclusive zone, ~3px under the capsule, so the bar looked like it was sitting
--     on the window. It showed up "only in WezTerm" because WezTerm is routed to
--     workspace 1 and is usually the single window there — the rule only fires when
--     a workspace holds exactly one tiled window.
--   * rounding = 0 squared off exactly the window you look at most.
--
-- Dropping both means every window keeps the 5px gutter and the 12px corner. Real
-- fullscreen (SUPER+F) still goes edge to edge; that path ignores gaps entirely.
