# wezterm-config

My WezTerm setup. Dark single-surface theme (`#121212` everywhere: terminal, tab strip, titlebar), ANSI palette synced from my IntelliJ color scheme, steel-blue active tab, and tab titles that show the shell's folder name instead of `pwsh.exe`.

Windows config for now; the mac variant lands here later.

## Layout

- `windows/wezterm.lua` goes to `%USERPROFILE%\.wezterm.lua`
- `windows/make_dim_font.py` generates the "Cascadia Mono Dim" font that the dim-text setup needs (see below)

## Install (Windows)

1. Install a WezTerm nightly. The winget nightly manifest is chronically stale (hash mismatch), so grab `WezTerm-nightly-setup.exe` from the GitHub releases and run it.
2. Copy `windows/wezterm.lua` to `%USERPROFILE%\.wezterm.lua`.
3. Generate the dim font:

   ```
   pip install fonttools
   mkdir %USERPROFILE%\.wezterm-fonts
   copy windows\make_dim_font.py %USERPROFILE%\.wezterm-fonts\
   python %USERPROFILE%\.wezterm-fonts\make_dim_font.py
   ```

4. Start WezTerm. `wezterm ls-fonts` should print "Will synthesize dim" under `When Intensity=Half`.

## Why the weird bits exist

The lua file is heavily commented, and the comments are the real documentation. The short version:

- **DemiBold body font, OpenGL front end, LCD render target, no hinting.** WezTerm rasterizes with FreeType and its strokes read thinner than the ClearType text you get in Windows Terminal. These four settings together get the closest match. Subpixel AA silently does nothing on the WebGpu front end, so OpenGL is load-bearing.
- **"Cascadia Mono Dim".** WezTerm only color-dims SGR 2 text when the matched font family has no weight lighter than the one requested. Real Cascadia has Light instances, so wezterm snaps to those and dim text goes spindly instead of darker. The generated font is a static copy of the Regular instance under a unique family name with no other weights, which forces the color-dimming path. Most of a Claude Code session is dim text, so this matters more than it sounds.
- **Tab styles.** `TAB_STYLE` at the top of the file switches between a handful of fancy and retro tab looks. The fancy tab bar ignores underline/bold/italic attributes from `format-tab-title`, colors only, so the active-tab treatment is a background fill rather than an underline.
- **Close confirmations.** Killing them takes three settings, not one: `window_close_confirmation` only covers the window, the default Ctrl+Shift+W binding hardcodes its own confirm, and the per-tab ✕ overlay is governed by `skip_close_confirmation_for_processes_named` (which replaces the defaults when set, so the stock shells are re-listed).
