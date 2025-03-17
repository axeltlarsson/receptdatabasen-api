local utils = require "utils"

local size = ngx.var.size
local path = ngx.var.path
local ext = ngx.var.ext
local file_upload_path = os.getenv("FILE_UPLOAD_PATH")
local images_dir = file_upload_path .. "/"      -- where original images are stored
local cache_dir = file_upload_path .. "/cache/" -- where resized images are cached

-- Verify size is a reasonable number
local size_num = tonumber(size)
if not size_num or size_num < 1 or size_num > 1200 then
    return utils.return_error("Invalid size parameter", ngx.HTTP_BAD_REQUEST)
end

-- Basic path validation to prevent directory traversal
if path:find("%.%./") or path:find("/../") or path:find("^/") then
    return utils.return_error("Invalid path", ngx.HTTP_BAD_REQUEST)
end

-- Source file path
local source_fname = images_dir .. path

-- Log for debugging
ngx.log(ngx.INFO, "Looking for source file: " .. source_fname)

-- Check if the source file exists
local file = io.open(source_fname, "rb")
if not file then
    ngx.log(ngx.ERR, "Source file not found: " .. source_fname)
    return utils.return_error("File not found", ngx.HTTP_NOT_FOUND)
end
file:close()

-- Generate deterministic cache filename using MD5
local digest = ngx.md5(size .. "/" .. path)
local dest_fname = cache_dir .. digest .. "." .. ext

-- Resize the image using libvips
local vips = require "vips"

-- Log for debugging
ngx.log(ngx.INFO, path .. "not found in cache, resizing image to width " .. size)

-- Use pcall to catch any errors
local ok, err = pcall(function()
    -- Fast thumbnail generator
    local image = vips.Image.thumbnail(source_fname, size_num)
    -- Write the result to cache directory
    image:write_to_file(dest_fname)
end)

if not ok then
    ngx.log(ngx.ERR, "Error resizing image: " .. tostring(err))
    return utils.return_error("Error processing image: " .. tostring(err), ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Log successful resize
ngx.log(ngx.INFO, "Successfully resized image to: " .. dest_fname)

-- set header indicating cache miss
ngx.header['x-image-server'] = 'cache miss'

-- redirect back to same location again, this time try_files will pick up the
-- cached file!
ngx.exec(ngx.var.request_uri)
