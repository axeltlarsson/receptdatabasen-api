local cjson = require 'cjson'
local mime_sniff = require "lib.mime_sniff"
local utils = require "utils"

local content_type = ngx.var.content_type

if not content_type or not string.match(content_type, 'image/*') then
  utils.return_error("Unsupported content-type", ngx.HTTP_NOT_ALLOWED)
end

local mime_type_map = {
  ["image/bmp"] = ".bmp",
  ["image/gif"] = ".gif",
  ["image/jpeg"] = ".jpeg",
  ["image/png"] = ".png",
  ["image/svg+xml"] = ".svg",
  ["image/tiff"] = ".tif",
  ["image/webp"] = ".webp"
}

local supported_mime_types = {}
for key, val in pairs(mime_type_map) do
  table.insert(supported_mime_types, key)
end

local function file_ext(mime_type)
  return mime_type_map[mime_type]
end

local function file_name()
  local r = ngx.now() + math.random()
  return ngx.md5(tostring(r))
end

-- Body is read from memory (true if client_max_body_size == client_body_buffer_size)
ngx.req.read_body()
local body_data = ngx.req.get_body_data()


if body_data then
  local mime_type = mime_sniff.match_content_type(body_data, table.unpack(supported_mime_types))
  if not mime_type then
    utils.return_error("The server does not support the sniffed mime type", ngx.HTTP_NOT_ALLOWED)
  end

  if mime_type ~= content_type then
    utils.return_error("Content-type does not match sniffed mime type", ngx.HTTP_NOT_ALLOWED)
  end

  local name = file_name()
  -- Save original
  local file_path = os.getenv("FILE_UPLOAD_PATH") .. "/" .. name

  local file = io.open(file_path .. file_ext(mime_type), 'w+b')
  local f, write_err = file:write(body_data)
  file:close()

  if write_err then
    ngx.log(ngx.ERR, write_err)
    utils.return_error("Could not write to file: ", ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  -- Convert to jpeg
  local vips = require "vips"
  local image = vips.Image.new_from_buffer(body_data)
  image.jpegsave(image, file_path .. ".jpeg")

  local response = { image = { url = name .. ".jpeg", originalUrl = name .. file_ext(mime_type) } }
  ngx.say(cjson.encode(response))
else
  utils.return_error("Could not read the image data from POST body")
end
