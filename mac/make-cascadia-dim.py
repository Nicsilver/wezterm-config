#!/usr/bin/env python3
"""Generate "Cascadia Mono Dim" - a static Regular-only copy of Cascadia Mono.

WezTerm renders SGR 2 (dim/half-intensity) text by picking a LIGHTER FONT when
the family has real light instances, instead of darkening the color. Cascadia
Mono is a variable font with real Light weights, so dim text comes out spindly
(very visible in Claude Code, whose UI is mostly dim text).

WezTerm's synthesize_dim path (50% brightness color scaling) only fires when the
Half-intensity font_rule requests a sub-Regular weight (e.g. 'Book') AND the
matched font is Regular or heavier. This script extracts the wght=400 instance
of Cascadia Mono as a static single-weight font under the new family name
"Cascadia Mono Dim". Within that family the 'Book' request can only ever match
Regular, so the color path always fires.

Verify after (re)generating: `wezterm ls-fonts` must print "-- Will synthesize dim"
under "When Intensity=Half".

Usage:
    pip install fonttools
    python3 make-cascadia-dim.py

Output: ~/.wezterm-fonts/CascadiaMonoDim-Regular.ttf
"""
import sys
from pathlib import Path

from fontTools import ttLib
from fontTools.varLib.instancer import instantiateVariableFont

FAMILY = "Cascadia Mono Dim"
PSNAME = "CascadiaMonoDim-Regular"
OUT = Path.home() / ".wezterm-fonts" / "CascadiaMonoDim-Regular.ttf"

SRC_CANDIDATES = [
    Path.home() / "Library/Fonts/CascadiaMono.ttf",
    Path("/Library/Fonts/CascadiaMono.ttf"),
]


def set_name(name_table, name_id: int, value: str) -> None:
    name_table.removeNames(nameID=name_id)
    name_table.setName(value, name_id, 3, 1, 0x409)  # Windows, Unicode BMP, en-US


def main() -> int:
    src = next((p for p in SRC_CANDIDATES if p.exists()), None)
    if src is None:
        print("Cascadia Mono variable font not found. Install it first:")
        print("  brew install --cask font-cascadia-mono")
        return 1

    font = ttLib.TTFont(src)
    # inplace=True matters: the default returns a new font and leaves `font`
    # variable, which would ship a still-variable file under the Dim name.
    instantiateVariableFont(font, {"wght": 400}, inplace=True, updateFontNames=True)
    if "STAT" in font:
        del font["STAT"]

    name = font["name"]
    set_name(name, 1, FAMILY)            # family
    set_name(name, 2, "Regular")         # subfamily
    set_name(name, 3, f"{PSNAME};wezterm-dim")  # unique ID
    set_name(name, 4, f"{FAMILY} Regular")      # full name
    set_name(name, 6, PSNAME)            # postscript name
    set_name(name, 16, FAMILY)           # typographic family
    set_name(name, 17, "Regular")        # typographic subfamily

    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)
    print(f"wrote {OUT} (from {src})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
