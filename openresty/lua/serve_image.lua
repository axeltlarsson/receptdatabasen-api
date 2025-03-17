local sig, size, path, ext =
    ngx.var.sig, ngx.var.size, ngx.var.path, ngx.var.ext

local secret = "hello_world"                                 -- signature secret key
local images_dir = os.getenv("FILE_UPLOAD_PATH") .. "/"      -- where images are stored
local cache_dir = os.getenv("FILE_UPLOAD_PATH") .. "/cache/" -- where images are cached
local utils = require "utils"

local function calculate_signature(str)
  return ngx.encode_base64(ngx.hmac_sha1(secret, str))
      :gsub("[+/=]", { ["+"] = "-", ["/"] = "_", ["="] = "," })
      :sub(1, 12)
end

if calculate_signature(size .. "/" .. path) ~= sig then
  print('invalid signature')
  -- return_not_found("invalid signature")
end

local source_fname = images_dir .. path

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
print(path .. " not found in cache, resizing image to width " .. size)
local image = vips.Image.thumbnail(source_fname, tonumber(size))
-- write the result to file (/uploads/cache)
image:write_to_file(dest_fname)

-- set header indicating cache miss
ngx.header['x-image-server'] = 'cache miss'

-- redirect back to same location again, this time try_files will pick up the
-- cached file!
ngx.exec(ngx.var.request_uri)
