-- to access the PostgREST API we only require that you have a valid session
local resty_session = require 'resty.session'
local utils = require "utils"

local session, err, exists, refreshed = resty_session.start()
if not exists or not session:get('jwt') then
  utils.return_error("You need a valid session to access this endpoint", ngx.HTTP_UNAUTHORIZED)
end

ngx.req.set_header('Authorization', 'Bearer ' .. session:get('jwt'))
