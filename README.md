# wezterm-config

My WezTerm setup. Dark single-surface theme (terminal, tab strip and titlebar all one color: `#121212` on Windows, `#202020` on the Mac to match IntelliJ), ANSI palette synced from my IntelliJ color scheme, steel-blue active tab, and tab titles that show the shell's folder name instead of `pwsh.exe`.

## Layout

- `wezterm.lua` — the shared config; almost everything lives here. It detects the OS via `wezterm.target_triple` and loads the matching platform module.
- `mac.lua` / `windows.lua` — what genuinely differs per platform: shell, fonts/rendering, background shade, close-confirmation process lists, and a few keys.
- `windows/make_dim_font.py` / `mac/make-cascadia-dim.py` — generate the "Cascadia Mono Dim" font that the dim-text setup needs (see below).

## Install (both platforms)

`~/.wezterm.lua` (`%USERPROFILE%\.wezterm.lua` on Windows) is a stub that loads the entry file straight from the clone, so `git pull` is the deploy and repo edits hot-reload:

```lua
local wezterm = require 'wezterm'
local entry = wezterm.home_dir .. '/IdeaProjects/wezterm-config/wezterm.lua'
return assert(loadfile(entry))(entry)
```

Adjust the clone path per machine. It's `loadfile(entry)(entry)` rather than `dofile` because the entry file needs its own path to find the platform modules — wezterm's Lua sandbox has no `debug` library to self-locate with.

## Install (Windows)

1. Install a WezTerm nightly. The winget nightly manifest is chronically stale (hash mismatch), so grab `WezTerm-nightly-setup.exe` from the GitHub releases and run it.
2. Create the stub above at `%USERPROFILE%\.wezterm.lua`.
3. Generate the dim font:

   ```
   pip install fonttools
   mkdir %USERPROFILE%\.wezterm-fonts
   copy windows\make_dim_font.py %USERPROFILE%\.wezterm-fonts\
   python %USERPROFILE%\.wezterm-fonts\make_dim_font.py
   ```

4. Start WezTerm. `wezterm ls-fonts` should print "Will synthesize dim" under `When Intensity=Half`.

## Install (macOS)

1. Install a WezTerm nightly. The upstream `wezterm@nightly` cask can fail its install step on APFS; if it does, install from a locally patched copy of the cask.
2. Create the stub above at `~/.wezterm.lua`.
3. Generate the dim font:

   ```
   pip install fonttools
   mkdir -p ~/.wezterm-fonts
   cp mac/make-cascadia-dim.py ~/.wezterm-fonts/
   python3 ~/.wezterm-fonts/make-cascadia-dim.py
   ```

4. Copy the titlebar font: `cp /System/Library/Fonts/SFNS.ttf ~/.wezterm-fonts/`. WezTerm's CoreText locator can't select hidden system fonts by name, so the config picks up this copy (family "System Font") via `font_dirs` instead.
5. Start WezTerm. `wezterm ls-fonts` should print "Will synthesize dim" under `When Intensity=Half`.

Note the mac config binds no Ctrl+V: paste is handled outside wezterm (a Hammerspoon smart-paste tap sends Cmd+V for text and passes raw ^V through for images, which is what keeps Claude Code's image paste working).

## Why the weird bits exist

The lua files are heavily commented, and the comments are the real documentation. The short version:

- **DemiBold body font, OpenGL front end, LCD render target, no hinting.** WezTerm rasterizes with FreeType and its strokes read thinner than the ClearType text you get in Windows Terminal. These four settings together get the closest match. Subpixel AA silently does nothing on the WebGpu front end, so OpenGL is load-bearing.
- **"Cascadia Mono Dim".** WezTerm only color-dims SGR 2 text when the matched font family has no weight lighter than the one requested. Real Cascadia has Light instances, so wezterm snaps to those and dim text goes spindly instead of darker. The generated font is a static copy of the Regular instance under a unique family name with no other weights, which forces the color-dimming path. Most of a Claude Code session is dim text, so this matters more than it sounds.
- **Tab styles.** `TAB_STYLE` at the top of the file switches between a handful of fancy and retro tab looks. The fancy tab bar ignores underline/bold/italic attributes from `format-tab-title`, colors only, so the active-tab treatment is a background fill rather than an underline.
- **Close confirmations.** Killing them takes three settings, not one: `window_close_confirmation` only covers the window, the default Ctrl+Shift+W binding hardcodes its own confirm, and the per-tab ✕ overlay is governed by `skip_close_confirmation_for_processes_named` (which replaces the defaults when set, so the stock shells are re-listed).
