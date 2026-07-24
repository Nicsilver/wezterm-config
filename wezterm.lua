local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- ~/.wezterm.lua is a stub that loads this entry straight from the clone via
-- loadfile(path)(path) — see README. The path arrives as our vararg because
-- wezterm's Lua sandbox has no debug library (the usual self-location trick).
-- From it we load the platform module and register both files for auto-reload;
-- files loaded this way aren't watched automatically.
local entry_path = ...
assert(entry_path, 'load via the stub: return assert(loadfile(entry))(entry)')
local here = entry_path:gsub('[/\\][^/\\]*$', '')
local platform_file = wezterm.target_triple:find('windows')
    and '/windows.lua' or '/mac.lua'
local platform = dofile(here .. platform_file)
wezterm.add_to_config_reload_watch_list(here .. '/wezterm.lua')
wezterm.add_to_config_reload_watch_list(here .. platform_file)

-- One flat surface: terminal bg, tab strip, titlebar and inactive tabs all
-- share BG; each platform picks the shade that suits its display.
local BG = platform.bg
local BG_HOVER = platform.bg_hover

-- Tab look — every style runs on the FANCY bar (native tab height + per-tab
-- ✕ buttons). The shaped retro pack is parked in git history (2ce5458) until
-- the wezterm fork adds retro bar height (upstream said not-planned, #3077).
-- The fancy bar renders colors from format-tab-title but ignores
-- bold/italic/underline. Ctrl+Shift+S cycles styles live; the pick sticks
-- across config reloads via wezterm.GLOBAL and falls back to the default
-- below on app restart.
local STYLE_ORDER = {
  'steel', 'slate', 'mauve', 'amber', 'green', 'crimson',
  'accent', 'index', 'circled', 'iconid', 'hash', 'gradient',
}
local TAB_STYLE = 'steel'
-- GLOBAL can hold a style name from an older roster (e.g. the retro pack);
-- only honor it if it still exists.
for _, name in ipairs(STYLE_ORDER) do
  if name == wezterm.GLOBAL.tab_style then
    TAB_STYLE = name
  end
end

-- Solid-fill styles recolor the native active chip via colors.tab_bar below;
-- glyph/dynamic styles leave the chip on BG and paint inside the title.
local FILLS = {
  steel   = { bg = '#2B3B58', fg = '#FFFFFF' },
  slate   = { bg = '#3A3A42', fg = '#FFFFFF' },
  mauve   = { bg = '#C6A0F6', fg = '#181926' },
  amber   = { bg = '#D97706', fg = '#141414' },
  green   = { bg = '#39D353', fg = '#0D1117' },
  crimson = { bg = '#7D2A35', fg = '#FFFFFF' },
  accent  = { bg = '#2B3B58', fg = '#FFFFFF' },
}
local ACTIVE = FILLS[TAB_STYLE] or { bg = BG, fg = '#FFFFFF' }

-- Bare shell titles say nothing; the tab shows the shell's folder instead.
-- One combined set for both platforms — a fresh pwsh tab reports 'pwsh.exe'
-- (verified via wezterm cli list).
local BARE_SHELLS = {
  [''] = true, ['z'] = true, ['zsh'] = true, ['-zsh'] = true,
  ['bash'] = true, ['sh'] = true,
  ['pwsh.exe'] = true, ['pwsh'] = true,
  ['powershell.exe'] = true, ['powershell'] = true,
  ['cmd.exe'] = true, ['cmd'] = true,
}

local function compute_title(tab)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title or ''
    if BARE_SHELLS[title:lower()] then
      local url = tab.active_pane.current_working_dir
      if url then
        local path = type(url) == 'string' and url or url.file_path
        -- Windows paths mix separators and end drive roots in '/', so strip
        -- trailing slashes of both kinds when taking the basename.
        local base = path and path:match('([^/\\]+)[/\\]*$')
        if base and #base > 0 then
          title = base
        end
      end
    end
  end
  return title
end

local function has_unseen(tab)
  for _, p in ipairs(tab.panes) do
    if p.has_unseen_output then
      return true
    end
  end
  return false
end

local function contrast_fg(color)
  local lightness = color:laba()
  return lightness > 55 and '#000000' or '#FFFFFF'
end

-- Style renderers. Each takes (tab, tabs, hover, title) and returns format
-- items; title arrives pre-truncated (with the unseen-output dot already
-- prefixed on background tabs). Inactive tabs return bare text wherever
-- possible: explicit colors pin the tab and kill wezterm's native hover
-- repaint (wezterm#5164, #3481) — iconid/hash/gradient knowingly trade that.
local STYLES = {}

-- Solid chip recolors: the native chip fill comes from colors.tab_bar (see
-- FILLS); the handler only needs to keep the text legible on it.
local function fill_style(tab, _, _, title)
  if not tab.is_active then
    return { { Text = ' ' .. title .. ' ' } }
  end
  return { { Foreground = { Color = ACTIVE.fg } }, { Text = ' ' .. title .. ' ' } }
end
for name in pairs(FILLS) do
  STYLES[name] = fill_style
end

-- Steel chip plus a bright edge bar at the start of the active tab.
STYLES['accent'] = function(tab, _, _, title)
  if not tab.is_active then
    return { { Text = ' ' .. title .. ' ' } }
  end
  return {
    { Foreground = { Color = '#7FAEFF' } },
    { Text = '▍' },
    { Foreground = { Color = '#FFFFFF' } },
    { Text = title .. ' ' },
  }
end

-- No fill at all; the active tab is marked by an accent-blue index number.
STYLES['index'] = function(tab, _, _, title)
  local n = tostring(tab.tab_index + 1)
  if not tab.is_active then
    return { { Text = ' ' .. n .. '  ' .. title .. ' ' } }
  end
  return {
    { Foreground = { Color = '#5594FA' } },
    { Text = ' ' .. n .. '  ' },
    { Foreground = { Color = '#FFFFFF' } },
    { Text = title .. ' ' },
  }
end

-- Circled index badges, magenta on the active tab. Unicode (not nerd-font)
-- so it renders in the fancy bar's proportional font.
local CIRCLED = { '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩' }
STYLES['circled'] = function(tab, _, _, title)
  local badge = CIRCLED[tab.tab_index + 1] or tostring(tab.tab_index + 1)
  if not tab.is_active then
    return { { Text = ' ' .. badge .. ' ' .. title .. ' ' } }
  end
  return {
    { Foreground = { Color = '#C092FA' } },
    { Text = ' ' .. badge .. ' ' },
    { Foreground = { Color = '#FFFFFF' } },
    { Text = title .. ' ' },
  }
end

-- rashil2000: tab fills sampled from one gradient across the whole strip;
-- inactive tabs get the muted version of their own stop. Painting inactive
-- tabs costs native hover repaint — accepted for this style.
STYLES['gradient'] = function(tab, tabs, _, title)
  local stops = wezterm.color.gradient(
    { orientation = 'Horizontal', colors = { '#4C2A85', '#C1436D' } },
    math.max(#tabs, 2)
  )
  local bg = stops[tab.tab_index + 1]
  if not tab.is_active then
    bg = bg:desaturate(0.35):darken(0.35)
  end
  return {
    { Background = { Color = bg } },
    { Foreground = { Color = contrast_fg(bg) } },
    { Text = ' ' .. title .. ' ' },
  }
end

-- wezterm discussion #4945: tab color is a hash of its cwd, so the same
-- project always lands on the same hue; fg picked by LAB lightness. Same
-- hover trade as gradient.
STYLES['hash'] = function(tab, _, _, title)
  local url = tab.active_pane and tab.active_pane.current_working_dir
  local path = url and (type(url) == 'string' and url or url.file_path) or title
  local h = 0
  for i = 1, #path do
    h = (string.byte(path, i) + (h << 5) - h) & 0xFFFFFF
  end
  local bg = wezterm.color.parse(string.format('#%06X', h))
  if not tab.is_active then
    bg = bg:desaturate(0.4):darken(0.3)
  end
  return {
    { Background = { Color = bg } },
    { Foreground = { Color = contrast_fg(bg) } },
    { Text = ' ' .. title .. ' ' },
  }
end

-- metafates-inspired: no titles — each tab keeps a random colored glyph for
-- the life of the process, plus its index. Unicode so it renders in the
-- proportional bar font; colored inactive tabs cost hover repaint — accepted.
local ICON_IDS = {}
local ICON_CHOICES = {
  { '✦', '#47CCBD' },
  { '☾', '#CED0D6' },
  { '⚑', '#F27481' },
  { '♜', '#6BCC62' },
  { '❖', '#5594FA' },
  { '♠', '#E0CE70' },
  { '☘', '#C092FA' },
}
STYLES['iconid'] = function(tab)
  local pick = ICON_IDS[tab.tab_id]
  if not pick then
    pick = ICON_CHOICES[math.random(#ICON_CHOICES)]
    ICON_IDS[tab.tab_id] = pick
  end
  local items = {
    { Foreground = { Color = pick[2] } },
    { Text = '  ' .. pick[1] .. ' ' },
  }
  if tab.is_active then
    items[#items + 1] = { Foreground = { Color = '#FFFFFF' } }
  else
    items[#items + 1] = { Foreground = { Color = '#6A6A72' } }
  end
  items[#items + 1] = { Text = (tab.tab_index + 1) .. '  ' }
  return items
end

wezterm.on('format-tab-title', function(tab, tabs, panes, conf, hover, max_width)
  -- The fancy bar sizes tabs itself; the cap just bounds runaway titles.
  local title = wezterm.truncate_right(compute_title(tab), 24)
  -- Universal unseen-output marker on background tabs. Deliberately uncolored:
  -- plain text keeps the native hover repaint alive (explicit colors pin the
  -- tab, and `hover` can't replace it on the fancy bar — wezterm#5164, #3481).
  if not tab.is_active and has_unseen(tab) then
    title = '● ' .. title
  end
  return (STYLES[TAB_STYLE] or STYLES.steel)(tab, tabs, hover, title)
end)

-- Experiment aid while style-shopping: name the current style bottom-right.
wezterm.on('update-status', function(window, _)
  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#6A6A72' } },
    { Text = TAB_STYLE .. '  ' },
  })
end)

-- Claude Code's documented anti-flicker mode, scoped to WezTerm sessions only
config.set_environment_variables = { CLAUDE_CODE_NO_FLICKER = '1' }

-- Dim (SGR 2) like Windows Terminal: darker color, same stroke weight. wezterm
-- only darkens dim text (synthesize_dim, 50% brightness) when the rule asks
-- for a sub-Regular weight and the matched font is Regular-or-heavier —
-- impossible within the real Cascadia family, which has Light instances to
-- snap to. "Cascadia Mono Dim" is a generated static copy of the Regular (400)
-- instance with no other weights (the make-dim script in this repo, installed
-- to ~/.wezterm-fonts), so asking it for 'Book' (380) lands on the 400 face
-- and triggers the color-dimming path. Don't swap this rule to a real light
-- weight — that kills the dimming and Claude Code's UI (largely dim text)
-- goes spindly.
config.font_dirs = { wezterm.home_dir .. '/.wezterm-fonts' }
config.font_rules = {
  { intensity = 'Half',
    font = wezterm.font { family = 'Cascadia Mono Dim', weight = 'Book' } },
}
-- Unhinted outlines scale the true glyph shapes like DirectWrite's natural
-- mode; hinting snaps x/cap-height to whole pixels and rounds Cascadia a
-- pixel taller than Windows Terminal at small sizes.
config.freetype_load_flags = 'NO_HINTING'

-- Clean on/off cursor blink like WT. The defaults fade the cursor in/out via
-- an eased animation, which reads as rapid flicker when a TUI (Claude Code)
-- redraws per keystroke.
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.animation_fps = 1

config.colors = {
  foreground = '#CCCCCC',
  background = BG,
  cursor_bg = '#FFFFFF', cursor_border = '#FFFFFF', cursor_fg = '#0C0C0C',
  selection_bg = '#FFFFFF', selection_fg = '#0C0C0C',
  -- ANSI palette synced from the IntelliJ scheme's Console Colors
  -- (_@user_Visual Studio Code Dark Plus.icls), not Campbell.
  ansi = { '#000000', '#F27481', '#6BCC62', '#E0CE70',
           '#5594FA', '#C092FA', '#47CCBD', '#CED0D6' },
  brights = { '#4E5157', '#FF6B7A', '#67FF59', '#FFEC1A',
              '#3399FF', '#D970FF', '#40FFE9', '#FFFFFF' },
  -- IntelliJ-style: strip == terminal bg, tabs flat on it; the active-tab
  -- marking comes from the selected style's chip fill + format-tab-title.
  tab_bar = {
    background = BG,
    -- If the fill ever stops painting, emit it as the FIRST item from the
    -- format-tab-title handler instead — bg_color here can silently lose to
    -- a registered handler for some styles.
    active_tab = { bg_color = ACTIVE.bg, fg_color = ACTIVE.fg },
    inactive_tab = { bg_color = BG, fg_color = '#8A8A90' },
    inactive_tab_hover = { bg_color = BG_HOVER, fg_color = '#CCCCCC' },
    new_tab = { bg_color = BG, fg_color = '#8A8A90' },
    new_tab_hover = { bg_color = BG_HOVER, fg_color = '#CCCCCC' },
    inactive_tab_edge = BG, -- no divider lines
  },
}

config.window_close_confirmation = 'NeverPrompt'
-- The tab ✕'s "Really kill this tab" overlay is governed ONLY by the
-- skip_close_confirmation list (set per platform) — NeverPrompt doesn't cover
-- it, and setting the list REPLACES wezterm's defaults, so each platform
-- re-lists its stock shells plus what actually runs in these tabs (Claude
-- Code runs as a node binary / claude.exe).

-- Bigger, padded new-tab button; the fancy bar does honor tab_bar_style for
-- this, and fullwidth ＋ reads noticeably larger than the stock + at the same
-- font size.
config.tab_bar_style = {
  new_tab = wezterm.format {
    { Foreground = { Color = '#8A8A90' } }, { Text = '  ＋  ' },
  },
  new_tab_hover = wezterm.format {
    { Foreground = { Color = '#CCCCCC' } }, { Text = '  ＋  ' },
  },
}
config.use_fancy_tab_bar = true
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.hide_tab_bar_if_only_one_tab = false -- the bar hosts the window buttons
config.tab_max_width = 32 -- default 16 truncates Claude session titles

config.window_padding = { left = 8, right = 8, top = 0, bottom = 0 }
config.initial_cols = 120
config.initial_rows = 30
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

config.keys = {
  -- Claude Code multiline input
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\n' },

  -- Windows Terminal behaviour: Ctrl+C copies when there is a selection,
  -- otherwise sends a real ^C (so e.g. double Ctrl+C exits Claude Code).
  { key = 'c', mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local sel = window:get_selection_text_for_pane(pane)
      if sel and sel ~= '' then
        window:perform_action(act.CopyTo 'Clipboard', pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end) },

  -- The default Ctrl+Shift+W hardcodes confirm=true and ignores NeverPrompt
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },

  -- Browser-style tab keys. These shadow the control chars in every pane:
  -- Ctrl+T never reaches terminal apps (Claude Code's todo toggle, bash
  -- transpose) and Ctrl+W won't delete-word in shells.
  { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL', action = act.CloseCurrentTab { confirm = false } },

  { key = 'LeftArrow', mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivateTabRelative(1) },

  -- Cycle tab styles live while style-shopping. wezterm.GLOBAL survives the
  -- reload, so the pick holds until the app restarts; make one permanent by
  -- changing the TAB_STYLE default.
  { key = 's', mods = 'CTRL|SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local cur = wezterm.GLOBAL.tab_style or TAB_STYLE
      local idx = 1
      for i, name in ipairs(STYLE_ORDER) do
        if name == cur then
          idx = i
          break
        end
      end
      wezterm.GLOBAL.tab_style = STYLE_ORDER[idx % #STYLE_ORDER + 1]
      wezterm.reload_configuration()
    end) },

  -- Detach the current tab into its own window (no mouse tear-off upstream:
  -- wezterm#549). Moves the focused PANE, which equals the tab as long as the
  -- tab isn't split.
  { key = 'UpArrow', mods = 'ALT',
    action = wezterm.action_callback(function(window, pane)
      pane:move_to_new_window()
    end) },
}

platform.apply(config)

return config
