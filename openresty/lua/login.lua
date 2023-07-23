local cjson = require 'cjson'
local utils = require 'utils'
local resty_session = require 'resty.session'

-- This little lua module is called from /login, to "capture" a requst
-- to the Postgrest /rest/rpc/login, and then it strips out the jwt token
-- in the response, and instead adds it to a session cookie

-- Tell nginx to read body, in order to pass it onto auth endpoint
ngx.req.read_body()
local request_options = {}
request_options["method"] = ngx.HTTP_POST
request_options["always_forward_body"] = true
-- "Issues a synchronous but still non-blocking Nginx Subrequest using uri"
-- https://openresty-reference.readthedocs.io/en/latest/Lua_Nginx_API/#ngxlocationcapture
local res = ngx.location.capture(
  "/internal/rest/rpc/login",
  request_options
  )

if res.status ~= 200 then
  -- in case of error, just forward it as is
  ngx.status = res.status
  return ngx.say(res.body)
else
  local resp_data = cjson.decode(res.body)
  -- Only keep the "me" key in the resonse, strip jwt
  local response = { me = resp_data.me }
  -- initiate a session
  local session = resty_session.start()
  session.data.jwt = resp_data.token
  session.cookie.samesite = 'Strict'
  session:save()
  return ngx.say(cjson.encode(response))
end
