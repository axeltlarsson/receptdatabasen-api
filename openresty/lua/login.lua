local cjson = require 'cjson'
local utils = require 'utils'
local resty_session = require 'resty.session'

-- This little lua module is called from /login, to "capture" a requst
-- to the Postgrest /rest/rpc/login, and then it strips out the jwt token
-- in the response, and instead adds it to a session cookie

-- Tell nginx to read body, in order to pass it onto auth endpoint
ngx.req.read_body()
-- "Issues a synchronous but still non-blocking Nginx Subrequest using uri"
-- https://openresty-reference.readthedocs.io/en/latest/Lua_Nginx_API/#ngxlocationcapture
local res = ngx.location.capture(
  "/internal/rest/rpc/login",
  { method = ngx.HTTP_POST, always_forward_body = true }
  )

if res.status ~= 200 then
  -- in case of error, just forward it as is
  ngx.status = res.status
  return ngx.say(res.body)
else
  local resp_data = cjson.decode(res.body)
  -- Only keep the "me" key in the resonse, strip jwt
  local response = { me = resp_data.me }

  -- initiate a session and save the jwt token
  local session = resty_session.new()
  session:set("jwt", resp_data.token)
  local ok, err = session:save()
  if not ok then
    utils.return_error("Could not save session cookie")
  end

  return ngx.say(cjson.encode(response))
end
