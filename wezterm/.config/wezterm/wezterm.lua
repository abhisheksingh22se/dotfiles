local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
  config.default_prog = { 'bash.exe' } -- Or { 'bash.exe' } if you prefer Git Bash
else
  config.default_prog = { 'zsh' }
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
config.macos_window_background_blur = 38
config.text_background_opacity = 0.90

config.window_decorations = 'RESIZE'
config.window_frame = {
  active_titlebar_bg = 'none',
  inactive_titlebar_bg = 'none',
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
  
  -- Liquid Glass Aesthetic
  local bg_active = '#1E2D23'     -- Raised glossy dark green/slate
  local fg_active = '#6EEB91'     -- Soft glowing sage (bright, not neon)
  
  local bg_inactive = '#111814'   -- Deep, heavy frosted glass
  local fg_inactive = '#85998C'   -- Legible but muted sage-grey
  
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
    mods = 'CMD',
    action = wezterm.action.CloseCurrentPane { confirm = false }
  },
  {
    key = 'd',
    mods = 'CMD',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' }
  },
  {
    key = 'd',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' }
  },
  {
    key = 'Backspace',
    mods = 'CMD',
    action = wezterm.action.SendString 'clear\n'
  },
  {
    key = 'h',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'j',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  {
    key = 'k',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'l',
    mods = 'CMD',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'h',
    mods = 'CMD|ALT',
    action = wezterm.action.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'j',
    mods = 'CMD|ALT',
    action = wezterm.action.AdjustPaneSize { 'Down', 5 },
  },
  {
    key = 'k',
    mods = 'CMD|ALT',
    action = wezterm.action.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'l',
    mods = 'CMD|ALT',
    action = wezterm.action.AdjustPaneSize { 'Right', 5 },
  },
  {
    key = 's',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ShowLauncherArgs { flags = 'WORKSPACES' },
  },
  {
    key = 'n',
    mods = 'CMD|SHIFT',
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
    mods = 'CMD|SHIFT',
    action = wezterm.action.SwitchWorkspaceRelative(-1),
  },
  {
    key = 'p',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SwitchWorkspaceRelative(1),
  },
  {
    key = 'r',
    mods = 'CMD|SHIFT',
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

