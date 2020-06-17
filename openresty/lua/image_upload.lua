local cjson = require 'cjson'
local sha256 = require 'resty.sha256'
local str = require 'resty.string'
local mime_sniff = require "lib.mime_sniff"

local content_type = ngx.var.content_type

local function return_error(msg, error_code)
  ngx.status = error_code or ngx.HTTP_BAD_REQUEST
  ngx.log(ngx.WARN, msg)
  ngx.say(cjson.encode({error = msg}))
  ngx.exit(ngx.OK)
end

if not content_type or not string.match(content_type, 'image/*') then
  return_error("Bad Content-type", ngx.HTTP_NOT_ALLOWED)
end

local mime_type_map = {
  ["image/bmp"] = ".bmp",
  ["image/gif"] = ".gif",
  ["image/jpeg"] = ".jpeg",
  ["image/png"] = ".png",
  ["image/svg+xml"] = ".svg",
  ["image/tiff"] = ".tif",
  ["image/webp"] =  ".webp"
}

local supported_mime_types = {}
for key,val in pairs(mime_type_map) do
  table.insert(supported_mime_types, key)
end

local function file_name(mime_type)
  -- What about file extensions? Calculate from mime type?
  local r = ngx.now() + math.random()
  return ngx.md5(tostring(r)) .. mime_type_map[mime_type]
end

-- Body is read from memory (true if client_max_body_size == client_body_buffer_size)
ngx.req.read_body()
local body_data = ngx.req.get_body_data()


if body_data then
  local mime_type = mime_sniff.match_content_type(body_data, table.unpack(supported_mime_types))
  if not mime_type then
    return_error("The server does not support the sniffed mime type", ngx.HTTP_NOT_ALLOWED)
  end

  if mime_type ~= content_type then
    return_error("Content-type does not match sniffed mime type", ngx.HTTP_NOT_ALLOWED)
  end

  local file_name = file_name(mime_type)
  local file_path = '/uploads/' .. file_name
  local file = io.open(file_path, 'w+b')
  file:write(body_data)
  file:close()
  local response = { image = { url = '/images/' .. file_name } }
  ngx.say(cjson.encode(response))
else
  return_error("Could not read the body data")
end
