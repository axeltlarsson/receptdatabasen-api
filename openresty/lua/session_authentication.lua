-- to access the PostgREST API we only require that you have a valid session
local resty_session = require 'resty.session'
local session, present = resty_session.open()
local utils = require "utils"
if not present or not session.data.jwt then
  utils.return_error("You need a valid session to access this endpoint", ngx.HTTP_UNAUTHORIZED)
end

ngx.req.set_header('Authorization', 'Bearer ' .. session.data.jwt)
