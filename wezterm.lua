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

-- Tab look: slate — flat one-surface strip, graphite active chip on the fancy
-- bar (native height + per-tab ✕). Needs two visible steps above BG: #3A3A42
-- disappears on a real #202020 strip. The 12-style experiment pack lives at
-- git 031c35a, the shaped retro pack at 2ce5458 (parked until the wezterm
-- fork adds retro bar height — upstream said not-planned, #3077).
local TAB_FILL = { bg = '#46464F', fg = '#FFFFFF' }

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

wezterm.on('format-tab-title', function(tab, tabs, panes, conf, hover, max_width)
  -- The fancy bar sizes tabs itself; the cap just bounds runaway titles.
  local title = wezterm.truncate_right(compute_title(tab), 24)
  if not tab.is_active then
    -- '•' marks a background tab with unseen output ('●' renders huge in the
    -- 13pt SF bar font and fights the ✳ Claude-busy marker). Deliberately
    -- uncolored, and inactive tabs return TEXT ONLY: explicit colors pin the
    -- tab and kill wezterm's native hover repaint, and the handler's `hover`
    -- arg can't replace it — with the fancy bar that flag is computed from
    -- character-cell columns while tabs render in the proportional titlebar
    -- font, so it lands on the wrong tab (wezterm#5164, #3481). Bare text
    -- styles via tab_bar.inactive_tab / inactive_tab_hover instead.
    if has_unseen(tab) then
      title = '• ' .. title
    end
    return { { Text = ' ' .. title .. ' ' } }
  end
  -- Wider padding on the active chip only — reads as emphasis, like Chrome.
  return { { Foreground = { Color = TAB_FILL.fg } }, { Text = '  ' .. title .. '  ' } }
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
    active_tab = { bg_color = TAB_FILL.bg, fg_color = TAB_FILL.fg },
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
