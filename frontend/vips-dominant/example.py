#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 python3Packages.pyvips

import pyvips

image = pyvips.Image.new_from_file("some-image.jpg", access="sequential")
image *= [1, 2, 1]
mask = pyvips.Image.new_from_array([[-1, -1, -1], [-1, 16, -1], [-1, -1, -1]], scale=8)
image = image.conv(mask, precision="integer")
image.write_to_file("x.jpg")
