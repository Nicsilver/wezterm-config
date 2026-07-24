local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

-- #202020 = the IntelliJ scheme's editor/terminal background.
M.bg = '#202020'
M.bg_hover = '#2A2A2A'

function M.apply(config)
  config.default_cwd = wezterm.home_dir .. '/IdeaProjects/Fullstack'

  config.font = wezterm.font { family = 'Cascadia Mono', weight = 'Regular' }
  config.font_size = 14.0

  config.window_frame = {
    -- San Francisco. WezTerm's CoreText locator can't select hidden system
    -- fonts by name, so ~/.wezterm-fonts holds a copy of
    -- /System/Library/Fonts/SFNS.ttf (family "System Font") that the FontDirs
    -- locator picks up.
    -- Medium + 14pt: slightly bolder tab labels, and the fancy bar's height
    -- follows this font size (wezterm#3789), so this is also the height knob.
    font = wezterm.font { family = 'System Font', weight = 'Medium' },
    font_size = 14.0,
    active_titlebar_bg = M.bg, inactive_titlebar_bg = M.bg,
  }

  config.skip_close_confirmation_for_processes_named = {
    'bash', 'sh', 'zsh', 'fish', 'tmux', 'nu',
    'claude', 'node', 'npm',
  }

  -- The default Cmd+W passes confirm=true regardless of window_close_confirmation.
  table.insert(config.keys,
    { key = 'w', mods = 'CMD', action = act.CloseCurrentTab { confirm = false } })
  table.insert(config.keys,
    { key = 'd', mods = 'CMD|SHIFT',
      action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } })
  -- Ctrl+V is deliberately NOT bound here: paste is handled outside wezterm
  -- (Karabiner exempts wezterm; the Hammerspoon smart-paste tap sends Cmd+V
  -- for text and passes raw ^V through for images so Claude Code's image
  -- paste works).
end

return M
