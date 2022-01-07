#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.pyvips

import sys
import os

#  from gi.repository import Vips
import pyvips

#  im = Vips.Image.new_from_file(sys.argv[1], access=Vips.Access.SEQUENTIAL)
im = pyvips.Image.new_from_file(sys.argv[1], access="sequential")

N_BINS = 10
BIN_SIZE = 256 / N_BINS

# make a 3D histogram of the RGB image ... 10 bins in each axis
hist = im.hist_find_ndim(bins=N_BINS)

# find the position of the maximum
v, x, y = hist.maxpos()

# get the pixel at (x, y)
pixel = hist(x, y)

# find the index of the max value in the pixel
band = pixel.index(v)

print("dominant colour:")
r = round(x * BIN_SIZE + BIN_SIZE / 2)
g = round(y * BIN_SIZE + BIN_SIZE / 2)
b = round(band * BIN_SIZE + BIN_SIZE / 2)
print(f"\tR = {r}")
print(f"\tG = {g}")
print(f"\tB = {b}")


def colored(r, g, b, text):
    return "\033[38;2;{};{};{}m{} \033[38;2;255;255;255m".format(r, g, b, text)


text = "Hello, World"
colored_text = colored(r, g, b, text)
#  print(colored_text)


outIm = pyvips.Image.black(20, 20) + [r, g, b]
outIm.write_to_file("test.jpeg")
os.system(f"viu {sys.argv[1]}")
os.system("viu test.jpeg")
