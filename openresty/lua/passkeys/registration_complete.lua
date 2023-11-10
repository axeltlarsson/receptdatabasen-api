local cjson = require 'cjson'
local utils = require "utils"
local resty_session = require "resty.session"

local session, present, reason = resty_session.open()

-- Read the challenge from the session and inject into request for the Postgrest endpoint
if present and session.data.challenge then
    -- read the request body
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    -- ...and inject the challenge into it from session
    local new_body = cjson.encode({
        challenge = session.data.challenge,
        raw_credential = cjson.decode(body)
    })

    -- make the request to Postgrest with the new_body
    ngx.req.set_header("Prefer", "params=single-object")
    local res = ngx.location.capture(
        "/internal/rest/rpc/passkey_registration_complete",
            { method = ngx.HTTP_POST, body = new_body }
        )

    if res.status ~= 200 then
        -- in case of error, just forward it as is with http status from postgrest
        ngx.status = res.status
        return ngx.say(res.body)
    else
        -- also just forward as is
        return ngx.say(res.body)
    end
else
    utils.return_error("Could not forward challenge from session, make sure to call /rest/rpc/passkey_registration_begin to get the challenge first.", ngx.HTTP_BAD_REQUEST)
end



