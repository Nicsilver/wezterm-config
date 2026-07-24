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

-- Tab look. 'fancy-steel' is the original native-bar steel-blue (keeps per-tab
-- ✕ buttons); every other style renders on the retro bar, where there are no
-- ✕ buttons — middle-click a tab to close it. Ctrl+Shift+S cycles styles live;
-- the pick sticks across config reloads via wezterm.GLOBAL and falls back to
-- the default below on app restart.
local STYLE_ORDER = {
  'powerline', 'pill', 'capsules', 'slant', 'gradient', 'hash',
  'circled', 'iconid', 'chevron', 'underline', 'block', 'matrix',
  'fancy-steel',
}
local TAB_STYLE = wezterm.GLOBAL.tab_style or 'powerline'
-- Steel-blue fill for the fancy-steel active tab.
local TAB_TINT = '#2B3B58'

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

local nf = wezterm.nerdfonts

-- Retro style renderers. Each takes (tab, tabs, hover, title) and returns
-- format items; title arrives pre-truncated.
local STYLES = {}

-- folke/dot: one continuous strip, solid powerline arrows hugging the active
-- tab, thin dividers between inactive neighbors.
STYLES['powerline'] = function(tab, tabs, _, title)
  local active_bg, inactive_bg = '#2B3B58', '#2A2A30'
  local bg = tab.is_active and active_bg or inactive_bg
  local fg = tab.is_active and '#FFFFFF' or '#9A9AA2'
  local next_tab = tabs[tab.tab_index + 2]
  local is_last = tab.tab_index == #tabs - 1
  local items = {}
  if tab.is_active then
    items[#items + 1] = { Attribute = { Intensity = 'Bold' } }
    items[#items + 1] = { Attribute = { Italic = true } }
  end
  items[#items + 1] = { Background = { Color = bg } }
  items[#items + 1] = { Foreground = { Color = fg } }
  items[#items + 1] = { Text = ' ' .. title .. ' ' }
  if tab.is_active or is_last or (next_tab and next_tab.is_active) then
    local right_bg = BG
    if not is_last then
      right_bg = next_tab.is_active and active_bg or inactive_bg
    end
    items[#items + 1] = { Background = { Color = right_bg } }
    items[#items + 1] = { Foreground = { Color = bg } }
    items[#items + 1] = { Text = nf.pl_left_hard_divider }
  else
    items[#items + 1] = { Background = { Color = inactive_bg } }
    items[#items + 1] = { Foreground = { Color = '#4A4A52' } }
    items[#items + 1] = { Text = nf.pl_left_soft_divider }
  end
  return items
end

-- dragonlobster: only the active tab becomes a rounded mauve chip.
STYLES['pill'] = function(tab, _, hover, title)
  local label = (tab.tab_index + 1) .. ': ' .. title
  if not tab.is_active then
    return {
      { Foreground = { Color = hover and '#CCCCCC' or '#8A8A90' } },
      { Text = '  ' .. label .. '  ' },
    }
  end
  local fill = '#C6A0F6'
  return {
    { Background = { Color = BG } },
    { Foreground = { Color = fill } },
    { Text = ' ' .. nf.ple_left_half_circle_thick },
    { Background = { Color = fill } },
    { Foreground = { Color = '#181926' } },
    { Text = label },
    { Background = { Color = BG } },
    { Foreground = { Color = fill } },
    { Text = nf.ple_right_half_circle_thick .. ' ' },
  }
end

-- KevinSilvester: every tab a detached capsule; unseen output shows as an
-- orange count badge inside the pill.
STYLES['capsules'] = function(tab, _, _, title)
  local fill = tab.is_active and '#89B4FA' or '#45475A'
  local fg = tab.is_active and '#11111B' or '#CDD6F4'
  local items = {
    { Background = { Color = BG } },
    { Foreground = { Color = fill } },
    { Text = ' ' .. nf.ple_left_half_circle_thick },
    { Background = { Color = fill } },
    { Foreground = { Color = fg } },
    { Text = title },
  }
  local n = 0
  for _, p in ipairs(tab.panes) do
    if p.has_unseen_output then
      n = n + 1
    end
  end
  if n > 0 then
    items[#items + 1] = { Foreground = { Color = '#FFA066' } }
    items[#items + 1] =
      { Text = ' ' .. (nf['md_numeric_' .. math.min(n, 10) .. '_circle'] or tostring(n)) }
  end
  items[#items + 1] = { Background = { Color = BG } }
  items[#items + 1] = { Foreground = { Color = fill } }
  items[#items + 1] = { Text = nf.ple_right_half_circle_thick .. ' ' }
  return items
end

-- mozumasu (Zenn): floating trapezoid chips, gold active on slate.
STYLES['slant'] = function(tab, _, _, title)
  local fill = tab.is_active and '#AE8B2D' or '#5C6D74'
  return {
    { Background = { Color = BG } },
    { Foreground = { Color = fill } },
    { Text = ' ' .. nf.ple_lower_right_triangle },
    { Background = { Color = fill } },
    { Foreground = { Color = '#FFFFFF' } },
    { Text = ' ' .. title .. ' ' },
    { Background = { Color = BG } },
    { Foreground = { Color = fill } },
    { Text = nf.ple_upper_left_triangle .. ' ' },
  }
end

-- rashil2000: tab fills sampled from one gradient across the whole strip;
-- inactive tabs get the muted version of their own stop.
STYLES['gradient'] = function(tab, tabs, _, title)
  local stops = wezterm.color.gradient(
    { orientation = 'Horizontal', colors = { '#4C2A85', '#C1436D' } },
    math.max(#tabs, 2)
  )
  local bg = stops[tab.tab_index + 1]
  if not tab.is_active then
    bg = bg:desaturate(0.35):darken(0.35)
  end
  local items = {}
  if tab.is_active then
    items[#items + 1] = { Attribute = { Intensity = 'Bold' } }
  end
  items[#items + 1] = { Background = { Color = bg } }
  items[#items + 1] = { Foreground = { Color = contrast_fg(bg) } }
  items[#items + 1] = { Text = ' ' .. title .. ' ' }
  return items
end

-- wezterm discussion #4945: tab color is a hash of its cwd, so the same
-- project always lands on the same hue; fg picked by LAB lightness.
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
  local items = {}
  if tab.is_active then
    items[#items + 1] = { Attribute = { Intensity = 'Bold' } }
  end
  items[#items + 1] = { Background = { Color = bg } }
  items[#items + 1] = { Foreground = { Color = contrast_fg(bg) } }
  items[#items + 1] = { Text = ' ' .. title .. ' ' }
  return items
end

-- sravioli: circled index numbers that swap to a bell when a background pane
-- has unseen output.
STYLES['circled'] = function(tab, _, _, title)
  local i = tab.tab_index + 1
  local unseen = not tab.is_active and has_unseen(tab)
  local badge = unseen and nf.md_bell_badge
    or nf['md_numeric_' .. i .. '_circle']
    or tostring(i)
  local badge_fg = unseen and '#E0A06A' or (tab.is_active and '#C092FA' or '#5A5A62')
  local items = {
    { Foreground = { Color = badge_fg } },
    { Text = ' ' .. badge .. ' ' },
  }
  if tab.is_active then
    items[#items + 1] = { Attribute = { Intensity = 'Bold' } }
    items[#items + 1] = { Foreground = { Color = '#FFFFFF' } }
  else
    items[#items + 1] = { Foreground = { Color = '#8A8A90' } }
  end
  items[#items + 1] = { Text = title .. ' ' }
  return items
end

-- metafates: no titles at all — each tab gets a random colored icon pinned to
-- its tab_id for the life of the process, plus its index.
local ICON_IDS = {}
local ICON_CHOICES = {
  { nf.cod_telescope, '#47CCBD' },
  { nf.md_ghost, '#CED0D6' },
  { nf.md_rocket, '#F27481' },
  { nf.md_flask, '#6BCC62' },
  { nf.md_earth, '#5594FA' },
  { nf.md_cat, '#E0CE70' },
  { nf.md_skull, '#C092FA' },
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
    items[#items + 1] = { Attribute = { Intensity = 'Bold' } }
    items[#items + 1] = { Foreground = { Color = '#FFFFFF' } }
  else
    items[#items + 1] = { Foreground = { Color = '#6A6A72' } }
  end
  items[#items + 1] = { Text = (tab.tab_index + 1) .. '  ' }
  return items
end

-- The official-docs classic: purple chevron wedges with a hover shade (hover
-- is reliable on the retro bar — cells are real character columns there).
STYLES['chevron'] = function(tab, _, hover, title)
  local bg, fg = '#1B1032', '#808080'
  if tab.is_active then
    bg, fg = '#2B2042', '#C0C0C0'
  elseif hover then
    bg, fg = '#3B3052', '#909090'
  end
  return {
    { Background = { Color = BG } },
    { Foreground = { Color = bg } },
    { Text = nf.pl_right_hard_divider },
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = ' ' .. title .. ' ' },
    { Background = { Color = BG } },
    { Foreground = { Color = bg } },
    { Text = nf.pl_left_hard_divider },
  }
end

-- Minimal: flat text, the active tab is just brighter and underlined (real
-- underline — the retro bar honors attributes, unlike fancy).
STYLES['underline'] = function(tab, _, hover, title)
  if tab.is_active then
    return {
      { Attribute = { Underline = 'Single' } },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = ' ' .. title .. ' ' },
    }
  end
  return {
    { Foreground = { Color = hover and '#CCCCCC' or '#7A7A82' } },
    { Text = ' ' .. title .. ' ' },
  }
end

-- Loud amber block on the active tab, everything else stays quiet.
STYLES['block'] = function(tab, _, hover, title)
  if tab.is_active then
    return {
      { Background = { Color = '#D97706' } },
      { Foreground = { Color = '#141414' } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = ' ' .. title .. ' ' },
    }
  end
  return {
    { Foreground = { Color = hover and '#CCCCCC' or '#8A8A90' } },
    { Text = ' ' .. title .. ' ' },
  }
end

-- Terminal-green on near-black; active tab is inverse video with brackets.
STYLES['matrix'] = function(tab, _, _, title)
  if tab.is_active then
    return {
      { Background = { Color = '#39D353' } },
      { Foreground = { Color = '#0D1117' } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = ' [' .. title .. '] ' },
    }
  end
  return {
    { Background = { Color = '#0D1117' } },
    { Foreground = { Color = '#2E9E44' } },
    { Text = '  ' .. title .. '  ' },
  }
end

wezterm.on('format-tab-title', function(tab, tabs, panes, conf, hover, max_width)
  local title = compute_title(tab)
  if TAB_STYLE == 'fancy-steel' then
    -- The fancy bar sizes tabs itself; the cap just bounds runaway titles.
    title = wezterm.truncate_right(title, 24)
    if not tab.is_active then
      -- Inactive tabs return TEXT ONLY, no colors, on purpose. Explicit colors
      -- pin the tab and kill wezterm's native hover repaint, and the handler's
      -- `hover` arg can't replace it: with the fancy bar that flag is computed
      -- from character-cell columns while tabs render in the proportional
      -- titlebar font, so it lands on the wrong tab (wezterm#5164, #3481).
      -- Bare text styles via tab_bar.inactive_tab / inactive_tab_hover instead.
      return { { Text = ' ' .. title .. ' ' } }
    end
    return { { Foreground = { Color = '#FFFFFF' } }, { Text = ' ' .. title .. ' ' } }
  end
  title = wezterm.truncate_right(title, max_width - 6)
  return (STYLES[TAB_STYLE] or STYLES.powerline)(tab, tabs, hover, title)
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
  -- marking comes from the steel-blue TAB_TINT fill + format-tab-title above.
  tab_bar = {
    background = BG,
    -- If the fill ever stops painting, emit it as the FIRST item from the
    -- format-tab-title handler instead — bg_color here can silently lose to
    -- a registered handler for some styles.
    active_tab = { bg_color = TAB_TINT, fg_color = '#FFFFFF', underline = 'Single' },
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
config.use_fancy_tab_bar = TAB_STYLE == 'fancy-steel'
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
