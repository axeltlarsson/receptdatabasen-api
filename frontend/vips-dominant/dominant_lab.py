#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.pyvips

import sys

#  from gi.repository import Vips
import pyvips

N_BINS = 10
BIN_SIZE = 256 / N_BINS

im = pyvips.Image.new_from_file(sys.argv[1], access="sequential")

# turn to lab
im = im.colourspace("lab")

# turn to 8-bit unsigned so we can make a histogram
# use 0 - 255 to be -128 - +127 for a/b
# and 0 - 255 for 0 - 100 L
im += [0, 128, 128]
im *= [255.0 / 100, 1, 1]
im = im.cast("uchar")

# make a 3D histogram of the 8-bit LAB image
hist = im.hist_find_ndim(bins=N_BINS)

# find the position of the maximum
v, x, y = hist.maxpos()

# get the pixel at (x, y)
pixel = hist(x, y)

# find the index of the max value in the pixel
band = pixel.index(v)

# scale up for the number of bins
x = x * BIN_SIZE + BIN_SIZE / 2
y = y * BIN_SIZE + BIN_SIZE / 2
band = band * BIN_SIZE + BIN_SIZE / 2

# turn the index back into the LAB colour
L = x * (100.0 / 255)
a = y - 128
b = band - 128

print("dominant colour:")
print("   L = ", L)
print("   a = ", a)
print("   b = ", b)

value = [L, a, b]
from_space = "lab"
to_space = "srgb"

# make a 1x1 pixel image, tag as being in the source colourspace
pixel = pyvips.Image.black(1, 1) + value
pixel = pixel.copy(interpretation=from_space)

# transform to dest space
pixel = pixel.colourspace(to_space)

# pull out the pixel from coordinate (0, 0) as an array
new_value = pixel(0, 0)

print(from_space, " ", value)
print(to_space, " ", new_value)


def colored(r, g, b, text):
    return "\033[38;2;{};{};{}m{} \033[38;2;255;255;255m".format(r, g, b, text)


text = "Hello, World"
colored_text = colored(255, 0, 0, text)
print(colored_text)

# or

print(colored(255, 0, 0, "Hello, World"))
