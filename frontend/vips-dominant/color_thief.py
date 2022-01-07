#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.colorthief python3Packages.pyvips

import sys
import os
from colorthief import ColorThief
import pyvips

color_thief = ColorThief(sys.argv[1])
# get the dominant color
(r, g, b) = color_thief.get_color(quality=1)
# build a color palette
palette = color_thief.get_palette(color_count=6)

print((r, g, b))

outIm = pyvips.Image.black(20, 20) + [r, g, b]
outIm.write_to_file("test.jpeg")
os.system(f"viu {sys.argv[1]}")
os.system("viu test.jpeg")


print(palette)

for color in palette:
    print(color)
    (r, g, b) = color
    outIm = pyvips.Image.black(10, 10) + [r, g, b]
    outIm.write_to_file("test.jpeg")
    os.system("viu test.jpeg")
