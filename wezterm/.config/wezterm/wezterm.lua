local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

local target = wezterm.target_triple
local is_windows = target:find('windows') ~= nil
local is_macos = target:find('apple') ~= nil
local is_linux = target:find('linux') ~= nil

-- CMD maps to Super/Win on non-macOS, which isn't the muscle memory a Windows/Linux
-- user expects — use CTRL there instead. One variable, reused by every binding below.
local super = is_macos and 'CMD' or 'CTRL'

if is_windows then
  config.default_prog = { 'bash.exe' }
end

if is_linux then
  -- zsh is the login shell on the Arch box (the whole ~/.zshrc lives there); bash
  -- would silently drop p10k, the plugins and every alias. Fall back to bash only if
  -- zsh genuinely isn't installed yet.
  local zsh = io.open('/usr/bin/zsh', 'r')
  if zsh then
    zsh:close()
    config.default_prog = { '/usr/bin/zsh', '-l' }
  else
    config.default_prog = { '/bin/bash', '-l' }
  end

  -- Wayland-native. Under XWayland the window is neither blurred nor correctly
  -- scaled on a HiDPI panel, so this is not optional under Hyprland.
  config.enable_wayland = true
end

-- ─────────────────────────────────────────────
-- Font
-- ─────────────────────────────────────────────

config.font = wezterm.font('Hack Nerd Font', {
  weight = 'Regular',
})

config.font_size = 13.0
config.line_height = 1.08

-- ─────────────────────────────────────────────
-- Dark Frosted Hacker Glass
-- ─────────────────────────────────────────────

config.colors = {
  background = '#050806',
  foreground = '#A8E6B0',
  cursor_bg = '#39FF88',
  cursor_fg = '#041007',
  cursor_border = '#39FF88',
  selection_bg = '#163D27',
  selection_fg = '#D8FFE5',
  split = '#1A4D2E',

  ansi = {
    '#07100A', '#D05C65', '#37D67A', '#C9B458',
    '#609ED8', '#A879C8', '#56B6A9', '#B7C5BA',
  },
  brights = {
    '#435048', '#FF6978', '#50FA9B', '#E6D267',
    '#7CB7F0', '#C792EA', '#73DACA', '#E5F2E8',
  },

  -- Setting this to pure rgba(0,0,0,0) removes the black strip entirely
  tab_bar = {
    background = 'rgba(0, 0, 0, 0)',
    active_tab = { bg_color = 'rgba(0, 0, 0, 0)', fg_color = 'rgba(0, 0, 0, 0)' },
    inactive_tab = { bg_color = 'rgba(0, 0, 0, 0)', fg_color = 'rgba(0, 0, 0, 0)' },
    new_tab = { bg_color = 'rgba(0, 0, 0, 0)', fg_color = 'rgba(0, 0, 0, 0)' },
  },
}


-- ─────────────────────────────────────────────
-- Frosted / Liquid Glass Window
-- ─────────────────────────────────────────────

config.window_background_opacity = 0.80
if is_macos then
  config.macos_window_background_blur = 38
end
-- On Linux there is no equivalent setting: WezTerm just renders translucent and the
-- *compositor* blurs what shows through. Hyprland's `decoration.blur` block in
-- hypr/.config/hypr/hyprland.lua is what supplies the frost, so the 0.80 above is
-- doing the same job on both OSes through two different mechanisms.
config.text_background_opacity = 0.90

config.window_decorations = 'RESIZE'

-- 'none' is not a color WezTerm can parse — it goes through a CSS colour parser that
-- knows names, #rrggbb and rgba(), and nothing else. An unparsable value here doesn't
-- disable the titlebar, it falls back to the built-in opaque slate, which is what the
-- solid strip along the frame was. rgba(0,0,0,0) is the same intent, spelled in
-- something the parser accepts.
--
-- (window_frame only governs the *fancy* tab bar, which is off below — but leaving a
-- broken value here is a trap for the next person who flips use_fancy_tab_bar back on.)
config.window_frame = {
  active_titlebar_bg   = 'rgba(0, 0, 0, 0)',
  inactive_titlebar_bg = 'rgba(0, 0, 0, 0)',
  active_titlebar_fg   = '#A8E6B0',
  inactive_titlebar_fg = '#85998C',
}

config.window_padding = {
  left = 18,
  right = 18,
  top = 16,
  bottom = 16,
}


-- ─────────────────────────────────────────────
-- Tabs (Invisible Bar, Right-Aligned Floating Pills)
-- ─────────────────────────────────────────────

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false 
config.show_new_tab_button_in_tab_bar = false 
config.show_tab_index_in_tab_bar = false 
config.tab_max_width = 28

-- 1. Erase the actual tabs from the left side so they are invisible
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  return '' 
end)

-- 2. Draw the sleek floating pills on the right side
wezterm.on('update-status', function(window, pane)
  local stat_elements = {}
  local mux_window = window:mux_window()
  local tabs = mux_window:tabs_with_info()
  
  -- Liquid Glass Aesthetic.
  --
  -- These were opaque hex (#1E2D23 / #111814). Opaque is the wrong choice for a pill
  -- that floats on a window already at window_background_opacity = 0.80: the rest of
  -- the surface shows the blurred desktop through it and the pill doesn't, so the tab
  -- strip reads as a solid bar glued across the frame instead of part of the glass.
  --
  -- rgba() here composites against the *translucent* window background, so the pills
  -- pick up the same frost as everything else. The alphas are deliberately low — this
  -- is the same 0.14 mint / 0.06 white vocabulary the waybar capsules use for their
  -- active and inactive workspace chips, so the terminal's tabs and the bar's
  -- workspaces look like the same design language.
  --
  -- Deliberately NOT behind `if is_linux`. This file is stowed on both platforms
  -- (bootstrap.sh's ALL_PKGS), and both run window_background_opacity = 0.80 — macOS
  -- frosting it with macos_window_background_blur, Hyprland with decoration.blur. Same
  -- problem, same fix, so the tabs should look identical on the Mac and the G14.
  local bg_active = 'rgba(110, 235, 145, 0.14)'   -- mint wash, matches waybar .active
  local fg_active = '#6EEB91'                     -- soft glowing sage (bright, not neon)

  local bg_inactive = 'rgba(255, 255, 255, 0.06)' -- barely-there frosted chip
  local fg_inactive = '#85998C'                   -- legible but muted sage-grey
  
  local transparent = 'rgba(0, 0, 0, 0)' -- Pure window transparency

  -- Iterate over all open tabs to draw them
  for _, tab_info in ipairs(tabs) do
    local is_active = tab_info.is_active
    local index = tab_info.index + 1
    local tab = tab_info.tab
    
    local title = tab:get_title()
    if not title or title == '' then title = tab:active_pane():get_title() end
    if title and #title > 15 then title = title:sub(1, 12) .. "..." end
    
    local tab_text = string.format(" %d: %s ", index, title)
    local bg = is_active and bg_active or bg_inactive
    local fg = is_active and fg_active or fg_inactive

    -- A. Transparent gap + Left pill edge
    table.insert(stat_elements, { Background = { Color = transparent } })
    table.insert(stat_elements, { Text = '   ' }) -- Spacing between pills
    table.insert(stat_elements, { Foreground = { Color = bg } })
    table.insert(stat_elements, { Text = '' })
    
    -- B. Pill body
    table.insert(stat_elements, { Background = { Color = bg } })
    table.insert(stat_elements, { Foreground = { Color = fg } })
    if is_active then
      table.insert(stat_elements, { Attribute = { Intensity = 'Bold' } })
    end
    table.insert(stat_elements, { Text = tab_text })
    if is_active then
      table.insert(stat_elements, { Attribute = { Intensity = 'Normal' } })
    end
    
    -- C. Right pill edge
    table.insert(stat_elements, { Background = { Color = transparent } })
    table.insert(stat_elements, { Foreground = { Color = bg } })
    table.insert(stat_elements, { Text = '' })
  end

  window:set_right_status(wezterm.format(stat_elements))
end)


-- ─────────────────────────────────────────────
-- Key Bindings
-- ─────────────────────────────────────────────

config.keys = {
  {
    key = 'w',
    mods = super,
    action = wezterm.action.CloseCurrentPane { confirm = false }
  },
  {
    key = 'd',
    mods = super,
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' }
  },
  {
    key = 'd',
    mods = super .. '|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' }
  },
  {
    key = 'Backspace',
    mods = super,
    action = wezterm.action.SendString 'clear\n'
  },
  {
    key = 'h',
    mods = super,
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'j',
    mods = super,
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  {
    key = 'k',
    mods = super,
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'l',
    mods = super,
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'h',
    mods = super .. '|ALT',
    action = wezterm.action.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'j',
    mods = super .. '|ALT',
    action = wezterm.action.AdjustPaneSize { 'Down', 5 },
  },
  {
    key = 'k',
    mods = super .. '|ALT',
    action = wezterm.action.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'l',
    mods = super .. '|ALT',
    action = wezterm.action.AdjustPaneSize { 'Right', 5 },
  },
  {
    key = 's',
    mods = super .. '|SHIFT',
    action = wezterm.action.ShowLauncherArgs { flags = 'WORKSPACES' },
  },
  {
    key = 'n',
    mods = super .. '|SHIFT',
    action = wezterm.action.PromptInputLine {
      description = wezterm.format {
        { Attribute = { Intensity = 'Bold' } },
        { Foreground = { AnsiColor = 'Fuchsia' } },
        { Text = 'Enter workspace name:' },
      },
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:perform_action(
            wezterm.action.SwitchToWorkspace {
              name = line,
            },
            pane
          )
        end
      end),
    },
  },
  {
    key = 'o',
    mods = super .. '|SHIFT',
    action = wezterm.action.SwitchWorkspaceRelative(-1),
  },
  {
    key = 'p',
    mods = super .. '|SHIFT',
    action = wezterm.action.SwitchWorkspaceRelative(1),
  },
  {
    key = 'r',
    mods = super .. '|SHIFT',
    action = wezterm.action.PromptInputLine {
      description = wezterm.format {
        { Attribute = { Intensity = 'Bold' } },
        { Foreground = { AnsiColor = 'Aqua' } },
        { Text = 'Rename current workspace to:' },
      },
      action = wezterm.action_callback(function(window, pane, line)
        if line and line ~= '' then
          local mux = wezterm.mux
          local current_workspace = mux.get_active_workspace()
          mux.rename_workspace(current_workspace, line)
        end
      end),
    },
  },
}

-- ─────────────────────────────────────────────
-- Cursor
-- ─────────────────────────────────────────────

config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 650


-- ─────────────────────────────────────────────
-- Inactive Panes
-- ─────────────────────────────────────────────

config.inactive_pane_hsb = {
  saturation = 0.75,
  brightness = 0.55,
}

return config

