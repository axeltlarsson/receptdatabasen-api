-- serve_public_image.lua
-- Based on serve_image.lua but without signature verification and with additional checks for public images.

local size, path, ext = ngx.var.size, ngx.var.path, ngx.var.ext
local images_dir = os.getenv("FILE_UPLOAD_PATH") or "/uploads" -- where images are stored
local cache_dir = (os.getenv("FILE_UPLOAD_PATH") or "/uploads") .. "/cache/" -- where images are cached
local utils = require "utils"

-- Verify size is a reasonable number (additional check for public images)
local size_num = tonumber(size)
if not size_num or size_num < 1 or size_num > 1200 then -- limit max size for public images
    return utils.return_error("Invalid size parameter", ngx.HTTP_BAD_REQUEST)
end

-- Basic path validation to prevent directory traversal (additional check for public images)
if path:find("%.%./") or path:find("/../") or path:find("^/") then
    return utils.return_error("Invalid path", ngx.HTTP_BAD_REQUEST)
end

local source_fname = images_dir .. "/" .. path

-- make sure the file exists
local file = io.open(source_fname)
if not file then
  utils.return_error("File not found", ngx.HTTP_NOT_FOUND)
end
file:close()

local dest_fname = cache_dir .. ngx.md5(size .. "/" .. path) .. "." .. ext

-- resize the image
local vips = require "vips"

-- fast thumbnail generator
ngx.log(ngx.INFO, path .. " not found in cache, resizing image to width " .. size)
local image = vips.Image.thumbnail(source_fname, size_num)
-- write the result to file
image:write_to_file(dest_fname)

-- set header indicating cache miss and add cache control for public images
ngx.header['x-image-server'] = 'cache miss'
ngx.header['Cache-Control'] = 'public, max-age=2592000' -- 30 days

-- redirect back to same location again, this time try_files will pick up the
-- cached file!
ngx.exec(ngx.var.request_uri)
