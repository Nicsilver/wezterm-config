local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

-- The Mac uses #202020, but that reads too bright on this display — darker
-- here on purpose.
M.bg = '#121212'
M.bg_hover = '#1F1F1F'

function M.apply(config)
  -- Shell: same as Windows Terminal default profile
  config.default_prog = { 'pwsh.exe' }
  config.default_cwd = 'C:\\Programming'

  -- Weight bumped above Regular: wezterm rasterizes with FreeType (never
  -- ClearType, by design — wezterm/wezterm#2477), whose strokes read thinner
  -- than WT's gamma-boosted ClearType. A heavier instance compensates; bold
  -- (700) stays visibly distinct. 'DemiBold' selects Cascadia's SemiBold (600)
  -- instance — the only step between Regular and Bold in this font; wezterm
  -- can't interpolate variable-font weights.
  config.font = wezterm.font { family = 'Cascadia Mono', weight = 'DemiBold' }
  -- 12 on purpose, NOT IntelliJ's 14: at this machine's DPI, 14pt through
  -- FreeType+DemiBold reads oversized/cursed. 12 was tuned by eye against WT.
  config.font_size = 12.0
  -- ClearType-style subpixel AA needs all three of front_end + load target +
  -- render target: the 20240203 release defaults to the WebGpu front end,
  -- which silently skips subpixel rendering — OpenGL is required for
  -- HorizontalLcd to take effect. Light hinting + LCD render is the combo
  -- that matches Windows Terminal (wezterm/wezterm#3582); applies to the tab
  -- bar text too. Pairs with the shared NO_HINTING load flags.
  config.front_end = 'OpenGL'
  config.freetype_load_target = 'Light'
  config.freetype_render_target = 'HorizontalLcd'

  config.window_frame = {
    -- Semibold for the same reason the terminal font is DemiBold: FreeType
    -- strokes read a step thinner than the ClearType-rendered Segoe UI in
    -- WT's own tabs.
    font = wezterm.font { family = 'Segoe UI', weight = 'DemiBold' },
    font_size = 10.0,
    active_titlebar_bg = M.bg, inactive_titlebar_bg = M.bg,
  }

  config.skip_close_confirmation_for_processes_named = {
    'cmd.exe', 'pwsh.exe', 'powershell.exe',
    'claude.exe', 'node.exe', 'npm.exe',
  }

  table.insert(config.keys,
    { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' })
  -- Split pane (was DuplicatePaneAuto in Windows Terminal)
  table.insert(config.keys,
    { key = 'd', mods = 'ALT|SHIFT',
      action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } })
end

return M
