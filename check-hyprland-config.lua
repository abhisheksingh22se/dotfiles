-- check-hyprland-config.lua
--
-- Executes hypr/.config/hypr/hyprland.lua against a stubbed `hl` API so a typo, a
-- nil call or a duplicated keybind surfaces here instead of as a black screen with no
-- working binds on the actual machine. Hyprland has no --check-config equivalent, and
-- a Lua config that throws halfway through leaves you with *half* a config, which is
-- worse than none.
--
--   luajit check-hyprland-config.lua                 # summary + duplicate detection
--   luajit check-hyprland-config.lua --list          # also print the full bind map
--
-- Any Lua 5.1+ interpreter works (luajit, lua, lua5.4). This only proves the file is
-- structurally sound — it cannot tell you whether Hyprland accepts a given option
-- name, so it complements testing on the box rather than replacing it.

local path = "hypr/.config/hypr/hyprland.lua"
local list = false
for _, a in ipairs(arg or {}) do
  if a == "--list" then list = true else path = a end
end

local binds, order = {}, {}
local rules, layers, wsrules = 0, 0, 0
local execs, submaps = 0, {}
local scope = "main"        -- flips while a submap body is being defined
local problems = {}

-- Config keys Hyprland has removed or relocated. A dead key is not fatal — Hyprland
-- logs "unknown config key" and carries on — but it means the setting you wrote is
-- silently doing nothing, which is worse than an error you'd notice. Add to this list
-- whenever an upstream release drops one.
local DEAD_KEYS = {
  ["misc.vfr"] =
    "moved to debug:vfr in 0.55, and marked debug-only. Defaults to on — just drop it.",
  ["misc.new_window_takes_over_fullscreen"] =
    "replaced in 0.53 by misc:on_focus_under_fullscreen (not a like-for-like swap).",
  ["master.inherit_fullscreen"] =
    "replaced in 0.53 by misc:on_focus_under_fullscreen.",
  ["dwindle.pseudotile"] =
    "removed in 0.55 (it wasn't doing anything).",
  ["decoration.shadow.ignore_window"] =
    "removed in 0.55; the behaviour is now always on.",
  ["render.cm_fs_passthrough"] =
    "removed in 0.55; automatic with render:cm_auto_hdr.",
  ["dwindle.no_gaps_when_only"] =
    "removed; use workspace rules (w[tv1] / f[1]) instead.",
  ["master.no_gaps_when_only"] =
    "removed; use workspace rules (w[tv1] / f[1]) instead.",
  ["general.cursor_inactive_timeout"] = "moved to cursor:inactive_timeout.",
  ["general.hide_cursor_on_key_press"] = "moved to cursor:hide_on_key_press.",
  ["general.no_cursor_warps"] = "moved to cursor:no_warps.",
}

-- Keys typed as css_gap: Hyprland's Lua layer takes an integer or a
-- {top=,right=,bottom=,left=} table, and rejects the conf file's "10 5 5 5" string.
local GAP_KEYS = {
  ["general.gaps_in"] = true, ["general.gaps_out"] = true, ["general.gaps_workspaces"] = true,
}

local handle = { set_enabled = function() end }
local function noop() return handle end
local function dispatcher(name)
  return function(a) return { __dispatcher = name, __args = a } end
end

-- Walk everything passed to hl.config() and flag keys that no longer exist, plus the
-- string-vs-table mistake that css_gap values invite.
local function checkConfig(tbl, prefix)
  for k, v in pairs(tbl) do
    local path = (prefix == "" and tostring(k)) or (prefix .. "." .. tostring(k))
    if DEAD_KEYS[path] then
      problems[#problems + 1] = ("dead config key `%s` — %s"):format(path, DEAD_KEYS[path])
    end
    if GAP_KEYS[path] and type(v) == "string" then
      problems[#problems + 1] =
        ("`%s` is a string; css_gap wants an integer or {top=,right=,bottom=,left=}"):format(path)
    end
    if type(v) == "table" then checkConfig(v, path) end
  end
end

hl = {
  monitor = noop, env = noop, curve = noop, animation = noop,
  config = function(t) checkConfig(t, "") return handle end,
  gesture = noop, device = noop, permission = noop, load_plugin = noop,
  exec_cmd = function() execs = execs + 1 return handle end,
  print = function(...) print("  hl.print:", ...) end,
  on = function(_, fn) fn() return handle end,
  -- Pretend to be the WQHD G14 panel so the scale-detection path is exercised, not
  -- just its fallback. Change height to 1080 to check the FHD branch.
  get_monitors = function() return { { name = "eDP-1", width = 2560, height = 1440 } } end,
  get_active_monitor = function() return { name = "eDP-1", width = 2560, height = 1440 } end,
  window_rule = function() rules = rules + 1 return handle end,
  layer_rule = function() layers = layers + 1 return handle end,
  workspace_rule = function() wsrules = wsrules + 1 return handle end,
}

hl.define_submap = function(name, fn)
  submaps[#submaps + 1] = name
  local prev = scope
  scope = "submap:" .. name
  fn()
  scope = prev
  return handle
end

hl.bind = function(keys, action, opts)
  -- Submap binds live in their own namespace, so only collide within one scope.
  local id = scope .. "  " .. keys
  if binds[id] then
    problems[#problems + 1] = ("duplicate bind in %s: %s"):format(scope, keys)
  else
    order[#order + 1] = id
  end
  binds[id] = action
  if type(action) ~= "table" and type(action) ~= "function" then
    problems[#problems + 1] = ("bind %s has a %s action, expected a dispatcher"):format(keys, type(action))
  end
  return handle
end
hl.unbind = noop

hl.dsp = {
  exec_cmd = dispatcher("exec_cmd"), exec_raw = dispatcher("exec_raw"),
  submap = dispatcher("submap"), layout = dispatcher("layout"),
  exit = dispatcher("exit"), no_op = dispatcher("no_op"),
  focus = dispatcher("focus"),
  window = {
    close = dispatcher("window.close"), kill = dispatcher("window.kill"),
    float = dispatcher("window.float"), fullscreen = dispatcher("window.fullscreen"),
    pseudo = dispatcher("window.pseudo"), center = dispatcher("window.center"),
    pin = dispatcher("window.pin"), move = dispatcher("window.move"),
    resize = dispatcher("window.resize"), swap = dispatcher("window.swap"),
    drag = dispatcher("window.drag"), tag = dispatcher("window.tag"),
    bring_to_top = dispatcher("window.bring_to_top"),
  },
  workspace = {
    toggle_special = dispatcher("workspace.toggle_special"),
    move = dispatcher("workspace.move"), rename = dispatcher("workspace.rename"),
  },
  group = {
    toggle = dispatcher("group.toggle"), next = dispatcher("group.next"),
    prev = dispatcher("group.prev"), lock = dispatcher("group.lock"),
  },
  cursor = { move = dispatcher("cursor.move"), move_to_corner = dispatcher("cursor.move_to_corner") },
  dpms = dispatcher("dpms"),
}

local ok, err = pcall(dofile, path)
if not ok then
  io.stderr:write("FAIL  " .. path .. "\n      " .. tostring(err) .. "\n")
  os.exit(1)
end

print(("%s parsed and executed cleanly"):format(path))
print(("  binds            %d"):format(#order))
print(("  window rules     %d"):format(rules))
print(("  layer rules      %d"):format(layers))
print(("  workspace rules  %d"):format(wsrules))
print(("  autostart execs  %d"):format(execs))
print(("  submaps          %s"):format(#submaps > 0 and table.concat(submaps, ", ") or "none"))

if list then
  print("")
  table.sort(order)
  for _, id in ipairs(order) do
    local a = binds[id]
    print(("  %-40s %s"):format(id, type(a) == "table" and a.__dispatcher or type(a)))
  end
end

if #problems > 0 then
  print("")
  for _, p in ipairs(problems) do print("  WARN  " .. p) end
  os.exit(1)
end
