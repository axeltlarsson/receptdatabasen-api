local cjson = require 'cjson'
local sha256 = require 'resty.sha256'
local str = require 'resty.string'


local content_type = ngx.var.content_type

if not string.match(content_type, 'image/*') then
  -- ngx.say(cjson.encode({error = 'bad content-type'}))
  ngx.log(ngx.WARN, "Bad content-type")
  ngx.exit(ngx.HTTP_NOT_ALLOWED)
end


local function file_name()
  -- What about file extensions? Calculate from mime type?
  local r = ngx.now() + math.random()
  return ngx.md5(tostring(r)) .. '.jpeg'
end

-- Body is read from memory (true if client_max_body_size == client_body_buffer_size)
ngx.req.read_body()
local body_data = ngx.req.get_body_data()

if body_data then
  local file_name = file_name()
  local file_path = '/uploads/' .. file_name
  local file = io.open(file_path, 'w+b')
  file:write(body_data)
  file:close()
  local response = { image = { url = '/images/' .. file_name } }
  ngx.say(cjson.encode(response))
else
  -- ngx.say(cjson.encode({error = 'Could not read the body data.'}))
  ngx.log(ngx.WARN, "Could not read the body data.")
  ngx.exit(ngx.HTTP_BAD_REQUEST)
end
