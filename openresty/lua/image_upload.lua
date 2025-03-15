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
for key, _ in pairs(mime_type_map) do
  table.insert(supported_mime_types, key)
end

local function file_ext(mime_type)
  return mime_type_map[mime_type]
end

local function file_name()
  local r = ngx.now() + math.random()
  return ngx.md5(tostring(r))
end

-- Check if FILE_UPLOAD_PATH environment variable is set
local upload_path = os.getenv("FILE_UPLOAD_PATH")
if not upload_path then
  ngx.log(ngx.ERR, "FILE_UPLOAD_PATH environment variable is not set")
  utils.return_error("Server configuration error: upload path not set", ngx.HTTP_INTERNAL_SERVER_ERROR)
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
  local file_path = upload_path .. "/" .. name

  -- Log for debugging
  ngx.log(ngx.INFO, "Attempting to save file to: " .. file_path .. file_ext(mime_type))

  -- Try to open the file with error handling
  local file, err = io.open(file_path .. file_ext(mime_type), 'w+b')
  if not file then
    ngx.log(ngx.ERR, "Failed to open file for writing: " .. (err or "unknown error"))
    utils.return_error("Could not create file: " .. (err or "unknown error"), ngx.HTTP_INTERNAL_SERVER_ERROR)
    return
  end

  -- Write data with error handling
  local ok, write_err = file:write(body_data)
  file:close()

  if not ok then
    ngx.log(ngx.ERR, "Failed to write to file: " .. (write_err or "unknown error"))
    utils.return_error("Could not write to file: " .. (write_err or "unknown error"), ngx.HTTP_INTERNAL_SERVER_ERROR)
    return
  end

  -- Convert to jpeg
  local vips = require "vips"

  -- Use pcall to catch any vips errors
  local ok, err = pcall(function()
    local image = vips.Image.new_from_buffer(body_data)
    image:jpegsave(file_path .. ".jpeg")
  end)

  if not ok then
    ngx.log(ngx.ERR, "Failed to convert image with libvips: " .. (err or "unknown error"))
    utils.return_error("Could not process image: " .. (err or "unknown error"), ngx.HTTP_INTERNAL_SERVER_ERROR)
    return
  end

  local response = { image = { url = name .. ".jpeg", originalUrl = name .. file_ext(mime_type) } }
  ngx.say(cjson.encode(response))
else
  utils.return_error("Could not read the image data from POST body")
end
