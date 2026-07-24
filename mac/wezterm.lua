local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Tab look. Fancy variants (keep per-tab close buttons): 'fancy-white' |
-- 'fancy-blue' | 'fancy-accent' | 'fancy-accent2' | 'fancy-dot' |
-- 'fancy-index' | 'fancy-tint'. Retro variants (no per-tab close buttons,
-- but real underline/shapes): 'retro-underline' | 'retro-pill' |
-- 'retro-pill-blue' | 'retro-bottom'.
local TAB_STYLE = 'fancy-tint'
-- Steel-blue fill for the tinted variants; #202020 (flat) otherwise.
local TAB_TINT = (TAB_STYLE == 'fancy-accent2' or TAB_STYLE == 'fancy-tint')
    and '#2B3B58' or '#202020'

wezterm.on('format-tab-title', function(tab, tabs, panes, conf, hover, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title or ''
    -- A bare shell title says nothing; show the folder the shell sits in.
    if title == '' or title == 'z' or title == 'zsh' or title == '-zsh'
        or title == 'bash' or title == 'sh' then
      local url = tab.active_pane.current_working_dir
      if url then
        local path = type(url) == 'string' and url or url.file_path
        local base = path and path:gsub('/+$', ''):match('([^/]+)$')
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
      { Background = { Color = '#202020' } },
      { Foreground = { Color = '#FFFFFF' } },
      { Attribute = { Underline = 'Single' } },
      { Text = ' ' .. title .. ' ' },
    }
  elseif TAB_STYLE == 'retro-pill-blue' then
    return {
      { Background = { Color = '#202020' } },
      { Foreground = { Color = '#2B3B58' } },
      { Text = wezterm.nerdfonts.ple_left_half_circle_thick },
      { Background = { Color = '#2B3B58' } },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title },
      { Background = { Color = '#202020' } },
      { Foreground = { Color = '#2B3B58' } },
      { Text = wezterm.nerdfonts.ple_right_half_circle_thick },
    }
  elseif TAB_STYLE == 'retro-pill' then
    return {
      { Background = { Color = '#202020' } },
      { Foreground = { Color = '#3A3A3A' } },
      { Text = wezterm.nerdfonts.ple_left_half_circle_thick },
      { Background = { Color = '#3A3A3A' } },
      { Foreground = { Color = '#FFFFFF' } },
      { Text = title },
      { Background = { Color = '#202020' } },
      { Foreground = { Color = '#3A3A3A' } },
      { Text = wezterm.nerdfonts.ple_right_half_circle_thick },
    }
  end
  -- fancy-white
  return { { Foreground = { Color = '#FFFFFF' } }, { Text = ' ' .. title .. ' ' } }
end)

config.default_cwd = wezterm.home_dir .. '/IdeaProjects/Fullstack'
config.set_environment_variables = { CLAUDE_CODE_NO_FLICKER = '1' }

config.font = wezterm.font { family = 'Cascadia Mono', weight = 'Regular' }
config.font_size = 14.0
config.font_dirs = { wezterm.home_dir .. '/.wezterm-fonts' }
-- "Cascadia Mono Dim" is a static Regular-only extract of Cascadia Mono
-- (generated by ~/.wezterm-fonts/make-cascadia-dim.py). Requesting Book from a
-- family whose only weight is Regular forces wezterm to synthesize dim via
-- color (50% brightness) instead of picking a real Light instance.
config.font_rules = {
  { intensity = 'Half',
    font = wezterm.font { family = 'Cascadia Mono Dim', weight = 'Book' } },
}
config.freetype_load_flags = 'NO_HINTING'

config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.animation_fps = 1

config.colors = {
  -- #202020 = the IntelliJ scheme's editor/terminal background.
  foreground = '#CCCCCC', background = '#202020',
  cursor_bg = '#FFFFFF', cursor_border = '#FFFFFF', cursor_fg = '#0C0C0C',
  selection_bg = '#FFFFFF', selection_fg = '#0C0C0C',
  -- ANSI palette synced from the IntelliJ scheme's Console Colors
  -- (_@user_Visual Studio Code Dark Plus.icls), not Campbell.
  ansi = { '#000000', '#F27481', '#6BCC62', '#E0CE70',
           '#5594FA', '#C092FA', '#47CCBD', '#CED0D6' },
  brights = { '#4E5157', '#FF6B7A', '#67FF59', '#FFEC1A',
              '#3399FF', '#D970FF', '#40FFE9', '#FFFFFF' },
  -- IntelliJ-style: strip == terminal bg, tabs flat on it; the active-tab
  -- marking comes from format-tab-title above (see TAB_STYLE).
  tab_bar = {
    background = '#202020',
    active_tab = { bg_color = TAB_TINT, fg_color = '#FFFFFF', underline = 'Single' },
    inactive_tab = { bg_color = '#202020', fg_color = '#8A8A90' },
    inactive_tab_hover = { bg_color = '#2A2A2A', fg_color = '#CCCCCC' },
    new_tab = { bg_color = '#202020', fg_color = '#8A8A90' },
    new_tab_hover = { bg_color = '#2A2A2A', fg_color = '#CCCCCC' },
    inactive_tab_edge = '#202020',
  },
}

config.window_close_confirmation = 'NeverPrompt'
-- The tab ×'s "Really kill this tab" overlay only skips processes on this
-- list; NeverPrompt above doesn't cover it. Includes wezterm's defaults plus
-- what actually runs in these tabs (claude is a node binary).
config.skip_close_confirmation_for_processes_named = {
  'bash', 'sh', 'zsh', 'fish', 'tmux', 'nu',
  'claude', 'node', 'npm',
}
-- Fullwidth ＋ reads noticeably larger than the stock + at the same font size.
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
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.window_frame = {
  -- San Francisco. WezTerm's CoreText locator can't select hidden system fonts
  -- by name, so ~/.wezterm-fonts holds a copy of /System/Library/Fonts/SFNS.ttf
  -- (family "System Font") that the FontDirs locator picks up.
  font = wezterm.font { family = 'System Font', weight = 'Regular' },
  font_size = 13.0,
  active_titlebar_bg = '#202020', inactive_titlebar_bg = '#202020',
}

config.window_padding = { left = 8, right = 8, top = 0, bottom = 0 }
config.initial_cols = 120
config.initial_rows = 30
config.scrollback_lines = 10000
config.audible_bell = 'Disabled'

config.keys = {
  { key = 'Enter', mods = 'SHIFT', action = act.SendString '\n' },
  { key = 'd', mods = 'CMD|SHIFT',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  -- The default Cmd+W passes confirm=true regardless of window_close_confirmation.
  { key = 'w', mods = 'CMD', action = act.CloseCurrentTab { confirm = false } },
  -- Browser-style tab keys. These shadow the control chars in every pane:
  -- Ctrl+T never reaches terminal apps (Claude Code's todo toggle, bash
  -- transpose) and Ctrl+W won't delete-word in shells.
  { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL', action = act.CloseCurrentTab { confirm = false } },

  { key = 'LeftArrow', mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivateTabRelative(1) },

  -- Detach the current tab into its own window (no mouse tear-off upstream:
  -- wezterm#549). Moves the focused PANE, which equals the tab as long as the
  -- tab isn't split.
  { key = 'UpArrow', mods = 'ALT',
    action = wezterm.action_callback(function(window, pane)
      pane:move_to_new_window()
    end) },
  -- Windows Terminal behaviour: Ctrl+C copies when there is a selection,
  -- otherwise sends a real ^C (so e.g. double Ctrl+C exits Claude Code).
  -- Ctrl+V is handled outside wezterm (Karabiner exempts wezterm; the
  -- Hammerspoon smart-paste tap sends Cmd+V for text and passes raw ^V
  -- through for images so Claude Code's image paste works).
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
}

return config
