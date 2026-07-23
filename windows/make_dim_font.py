"""Extract Cascadia Mono's Regular (wght=400) instance as a static font with a
unique family name, so wezterm's dim font_rule can target a family that has no
light weights (required to trigger its synthesize_dim color-halving path)."""
import os
from fontTools import ttLib
from fontTools.varLib.instancer import instantiateVariableFont

SRC = r"C:\Windows\Fonts\CASCADIAMONO.TTF"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(OUT_DIR, "CascadiaMonoDim.ttf")
FAMILY = "Cascadia Mono Dim"

font = ttLib.TTFont(SRC)
instantiateVariableFont(font, {"wght": 400}, inplace=True, updateFontNames=True)

name = font["name"]
# 1=family, 16=typographic family, 3=unique id, 4=full name, 6=postscript name
for rec in name.names:
    if rec.nameID in (1, 16):
        rec.string = FAMILY
    elif rec.nameID == 4:
        rec.string = FAMILY
    elif rec.nameID == 6:
        rec.string = FAMILY.replace(" ", "") + "-Regular"
    elif rec.nameID == 3:
        rec.string = f"{FAMILY} 400 static"
    # 2/17 = subfamily; force Regular so the 600 weight is the family's default style
    elif rec.nameID in (2, 17):
        rec.string = "Regular"

print("usWeightClass:", font["OS/2"].usWeightClass)
os.makedirs(OUT_DIR, exist_ok=True)
font.save(OUT)
print("saved:", OUT)
