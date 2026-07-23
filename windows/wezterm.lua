local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

-- Tab look. Fancy variants (keep per-tab close buttons): 'fancy-white' |
-- 'fancy-blue' | 'fancy-accent' | 'fancy-accent2' | 'fancy-dot' |
-- 'fancy-index' | 'fancy-tint'. Retro variants (no per-tab close buttons,
-- but real underline/shapes): 'retro-underline' | 'retro-pill' |
-- 'retro-pill-blue' | 'retro-bottom'.
local TAB_STYLE = 'fancy-tint'
-- One flat surface: terminal bg, tab strip, titlebar and inactive tabs all share
-- BG. The Mac uses #202020, but that reads too bright on this display — darker
-- here on purpose.
local BG = '#121212'
local BG_HOVER = '#1F1F1F'
-- Steel-blue fill for the tinted variants; flat BG otherwise.
local TAB_TINT = (TAB_STYLE == 'fancy-accent2' or TAB_STYLE == 'fancy-tint')
    and '#2B3B58' or BG

wezterm.on('format-tab-title', function(tab, tabs, panes, conf, hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title or ''
    -- A bare shell title says nothing; show the folder the shell sits in.
    -- A fresh pwsh tab here reports 'pwsh.exe' (verified via wezterm cli list).
    local bare = title:lower()
    if bare == '' or bare == 'pwsh.exe' or bare == 'pwsh'
        or bare == 'powershell.exe' or bare == 'powershell'
        or bare == 'cmd.exe' or bare == 'cmd' then
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
  -- The fancy bar sizes tabs itself; only retro needs the cell budget honored.
  local cap = TAB_STYLE:sub(1, 5) == 'retro' and max_width - 4 or 24
  title = wezterm.truncate_right(title, cap)
  local idx = tostring(tab.tab_index + 1)
  if not tab.is_active then
    local text = ' ' .. title .. ' '
    if TAB_STYLE == 'fancy-index' then
      text = ' ' .. idx .. '  ' .. title .. ' '
    end
    -- Inactive tabs return TEXT ONLY, no colors, on purpose. Explicit colors
    -- pin the tab and kill wezterm's native hover repaint, and the handler's
    -- `hover` arg can't replace it: with the fancy bar that flag is computed
    -- from character-cell columns while tabs render in the proportional
    -- titlebar font, so it lands on the wrong tab (wezterm#5164, #3481).
    -- Bare text styles via tab_bar.inactive_tab / inactive_tab_hover instead.
    return { { Text = text } }
  end
  if TAB_STYLE == 'fancy-blue' then
    return { { Foreground = { Color = '#5594FA' } }, { Text = ' ' .. title .. ' ' } }
  elseif TAB_STYLE == 'fancy-accent' then
    return {
      { Foreground = { Color = '#5594FA' } },
      { Text = '▎' },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title .. ' ' },
    }
  elseif TAB_STYLE == 'fancy-accent2' then
    return {
      { Background = { Color = '#2B3B58' } },
      { Foreground = { Color = '#7FAEFF' } },
      { Text = '▍' },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title .. ' ' },
    }
  elseif TAB_STYLE == 'fancy-dot' then
    return {
      { Foreground = { Color = '#5594FA' } },
      { Text = ' ● ' },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title .. ' ' },
    }
  elseif TAB_STYLE == 'fancy-index' then
    return {
      { Foreground = { Color = '#5594FA' } },
      { Text = ' ' .. idx .. '  ' },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title .. ' ' },
    }
  elseif TAB_STYLE == 'fancy-tint' then
    return { { Foreground = { Color = '#FFFFFF' } }, { Text = ' ' .. title .. ' ' } }
  elseif TAB_STYLE == 'retro-underline' or TAB_STYLE == 'retro-bottom' then
    return {
      { Background = { Color = BG } },
      { Foreground = { Color = '#FFFFFF' } },
      { Attribute = { Underline = 'Single' } },
      { Text = ' ' .. title .. ' ' },
    }
  elseif TAB_STYLE == 'retro-pill-blue' then
    return {
      { Background = { Color = BG } },
      { Foreground = { Color = '#2B3B58' } },
      { Text = wezterm.nerdfonts.ple_left_half_circle_thick },
      { Background = { Color = '#2B3B58' } },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title },
      { Background = { Color = BG } },
      { Foreground = { Color = '#2B3B58' } },
      { Text = wezterm.nerdfonts.ple_right_half_circle_thick },
    }
  elseif TAB_STYLE == 'retro-pill' then
    return {
      { Background = { Color = BG } },
      { Foreground = { Color = '#3A3A3A' } },
      { Text = wezterm.nerdfonts.ple_left_half_circle_thick },
      { Background = { Color = '#3A3A3A' } },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title },
      { Background = { Color = BG } },
      { Foreground = { Color = '#3A3A3A' } },
      { Text = wezterm.nerdfonts.ple_right_half_circle_thick },
    }
  end
  -- fancy-white
  return { { Foreground = { Color = '#FFFFFF' } }, { Text = ' ' .. title .. ' ' } }
end)

-- Shell: same as Windows Terminal default profile
config.default_prog = { 'pwsh.exe' }
config.default_cwd = 'C:\\Programming'

-- Claude Code's documented anti-flicker mode, scoped to WezTerm sessions only
config.set_environment_variables = { CLAUDE_CODE_NO_FLICKER = '1' }

-- Font: matches Windows Terminal. Swap to 'Cascadia Code' if you want ligatures.
-- Weight bumped above Regular: wezterm rasterizes with FreeType (never ClearType, by
-- design — wezterm/wezterm#2477), whose strokes read thinner than WT's gamma-boosted
-- ClearType. A heavier instance compensates; bold (700) stays visibly distinct.
-- 'DemiBold' selects Cascadia's SemiBold (600) instance — the only step between
-- Regular and Bold in this font; wezterm can't interpolate variable-font weights.
config.font = wezterm.font { family = 'Cascadia Mono', weight = 'DemiBold' }
-- 12 on purpose, NOT IntelliJ's 14: at this machine's DPI, 14pt through
-- FreeType+DemiBold reads oversized/cursed. 12 was tuned by eye against WT.
config.font_size = 12.0
-- Dim (SGR 2) like Windows Terminal: darker color, same stroke weight. wezterm only
-- darkens dim text (synthesize_dim, 50% brightness) when the rule asks for a
-- sub-Regular weight and the matched font is Regular-or-heavier — impossible within
-- the real Cascadia family, which has Light instances to snap to. "Cascadia Mono Dim"
-- is a generated static copy of the Regular (400) instance with no other weights
-- (make_dim_font.py, lives in ~/.wezterm-fonts), so asking it for 'Book' (380) lands
-- on the 400 face and triggers the color-dimming path. Regular rather than SemiBold
-- on purpose: WT's dim is regular-weight + darker, and the thinner strokes are part
-- of why WT's dim reads dimmer. Don't swap this
-- rule to a real light weight — that kills the dimming and Claude Code's UI (which is
-- largely dim text) goes spindly.
config.font_dirs = { wezterm.home_dir .. '\\.wezterm-fonts' }
config.font_rules = {
  {
    intensity = 'Half',
    font = wezterm.font { family = 'Cascadia Mono Dim', weight = 'Book' },
  },
}
-- ClearType-style subpixel AA needs all three of these: the 20240203 release defaults
-- to the WebGpu front end, which silently skips subpixel rendering — OpenGL is required
-- for HorizontalLcd to take effect. Light hinting + LCD render is the combo that
-- matches Windows Terminal (wezterm/wezterm#3582); applies to the tab bar text too.
config.front_end = 'OpenGL'
config.freetype_load_target = 'Light'
config.freetype_render_target = 'HorizontalLcd'
-- Unhinted outlines: Light hinting snaps x/cap-height to whole pixels, which rounds
-- Cascadia a pixel taller than WT's DirectWrite rendering at 12pt. No hinting scales
-- the true outlines like DirectWrite natural mode, matching WT's glyph heights.
config.freetype_load_flags = 'NO_HINTING'

-- Clean on/off cursor blink like WT. The defaults fade the cursor in/out via an eased
-- animation, which reads as rapid flicker when a TUI (Claude Code) redraws per keystroke.
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.animation_fps = 1

-- ANSI palette synced from the IntelliJ scheme; flat BG everywhere so the
-- terminal, tab strip and titlebar read as one surface.
config.colors = {
  foreground = '#CCCCCC',
  background = BG,
  cursor_bg = '#FFFFFF',
  cursor_border = '#FFFFFF',
  cursor_fg = '#0C0C0C',
  selection_bg = '#FFFFFF',
  selection_fg = '#0C0C0C',
  ansi = {
    '#000000', '#F27481', '#6BCC62', '#E0CE70',
    '#5594FA', '#C092FA', '#47CCBD', '#CED0D6',
  },
  brights = {
    '#4E5157', '#FF6B7A', '#67FF59', '#FFEC1A',
    '#3399FF', '#D970FF', '#40FFE9', '#FFFFFF',
  },
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
-- This list is THE mechanism behind the tab ✕ button's "Really kill this tab"
-- overlay — NeverPrompt doesn't cover it. Setting it REPLACES the defaults, so
-- the stock shells are re-listed. Claude Code runs as claude.exe here (tasklist).
config.skip_close_confirmation_for_processes_named = {
  'cmd.exe', 'pwsh.exe', 'powershell.exe',
  'claude.exe', 'node.exe', 'npm.exe',
}
-- Bigger, padded new-tab button; the fancy bar does honor tab_bar_style for this.
config.tab_bar_style = {
  new_tab = wezterm.format {
    { Foreground = { Color = '#8A8A90' } }, { Text = '  ＋  ' },
  },
  new_tab_hover = wezterm.format {
    { Foreground = { Color = '#CCCCCC' } }, { Text = '  ＋  ' },
  },
}
config.use_fancy_tab_bar = TAB_STYLE:sub(1, 5) ~= 'retro'
config.tab_bar_at_bottom = TAB_STYLE == 'retro-bottom'
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.hide_tab_bar_if_only_one_tab = false -- the bar hosts the window buttons now
config.tab_max_width = 32 -- default 16 truncates Claude session titles
config.window_frame = {
  -- Semibold for the same reason the terminal font is DemiBold: FreeType strokes
  -- read a step thinner than the ClearType-rendered Segoe UI in WT's own tabs.
  font = wezterm.font { family = 'Segoe UI', weight = 'DemiBold' },
  font_size = 10.0,
  active_titlebar_bg = BG,
  inactive_titlebar_bg = BG,
}

config.window_padding = { left = 8, right = 8, top = 0, bottom = 0 }
config.initial_cols = 120
config.initial_rows = 30
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

config.keys = {
  -- Claude Code multiline input (same as the sendInput binding in Windows Terminal)
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\n' },

  -- Ctrl+C copies when text is selected, otherwise passes through as interrupt (Windows Terminal behavior)
  {
    key = 'c',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      if window:get_selection_text_for_pane(pane) ~= '' then
        window:perform_action(act.CopyTo 'ClipboardAndPrimarySelection', pane)
        window:perform_action(act.ClearSelection, pane)
      else
        window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
      end
    end),
  },
  { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },

  -- Split pane (was DuplicatePaneAuto in Windows Terminal)
  { key = 'd', mods = 'ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },

  -- The default Ctrl+Shift+W hardcodes confirm=true and ignores NeverPrompt
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },

  -- Browser-style tab keys. These shadow the control chars in every pane:
  -- Ctrl+T never reaches terminal apps (Claude Code's todo toggle, bash
  -- transpose) and Ctrl+W won't delete-word in shells.
  { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL', action = act.CloseCurrentTab { confirm = false } },

  { key = 'LeftArrow', mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivateTabRelative(1) },
}

return config
