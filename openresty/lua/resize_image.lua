-- serve_image.lua
-- Resize images and save them into the cache directory for future serving
-- the signature comprises the size and path of the image and a secret key
-- it is used to verify the request and prevent DOS attacks trying to resize images wasting CPU
local utils = require "utils"
local vips = require "vips"

local sig, size, path, ext =
    ngx.var.sig, ngx.var.size, ngx.var.path, ngx.var.ext

local secret = os.getenv("IMAGE_SERVER_SECRET")              -- secret key
local images_dir = os.getenv("FILE_UPLOAD_PATH") .. "/"      -- where images are stored
local cache_dir = os.getenv("FILE_UPLOAD_PATH") .. "/cache/" -- where images are cached

-- Verify size is a reasonable number
local size_num = tonumber(size)
if not size_num or size_num < 1 or size_num > 2000 then
  return utils.return_error("Invalid size parameter", ngx.HTTP_BAD_REQUEST)
end

-- Basic path validation to prevent directory traversal
if path:find("%.%./") or path:find("/../") or path:find("^/") then
  return utils.return_error("Invalid path", ngx.HTTP_BAD_REQUEST)
end


if utils.calculate_signature(secret, size, path) ~= sig then
  ngx.log(ngx.WARN, "Invalid signature")
  utils.return_error("Invalid signature", ngx.HTTP_FORBIDDEN)
end

local source_fname = images_dir .. path

-- make sure the file exists
local file, err = io.open(source_fname, "r")

if not file then
  ngx.log(ngx.ERR, "Source could not be opened: " .. err)
  return utils.return_error("File not found", ngx.HTTP_NOT_FOUND)
end
file:close()

-- Generate deterministic cache filename using MD5
local dest_fname = cache_dir .. ngx.md5(size .. "/" .. path) .. "." .. ext

-- Resize the image using libvips and write to cache directory
local ok, err_vips = pcall(function()
  local image = vips.Image.thumbnail(source_fname, size_num)
  image:write_to_file(dest_fname)
end)

if not ok then
  ngx.log(ngx.ERR, "Error resizing image: " .. tostring(err_vips))
  return utils.return_error("Error processing image", ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Set header indicating cache miss
ngx.header['x-image-server'] = 'cache miss'

-- Redirect back to same location again, this time try_files will pick up the
-- cached file!
ngx.exec(ngx.var.request_uri)
