local cjson = require 'cjson'
local utils = require "utils"
local resty_session = require "resty.session"

-- passkey_authentication_complete lua code to relay POST request to PostgREST
-- but to read the expected challange from the session and relay it in the body

local session, err, exists = resty_session.open()

-- Read the challenge from the session and inject into request for the Postgrest endpoint
if session and session:get("challenge") then
    -- read the request body
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    -- ...and inject the challenge into it from session
    local new_body = cjson.encode({
        expected_challenge = session:get("challenge"),
        raw_credential = cjson.decode(body)
    })

    -- make the request to Postgrest with the new_body
    ngx.req.set_header("Prefer", "params=single-object")
    local res = ngx.location.capture(
        "/internal/rest/rpc/passkey_authentication_complete",
            { method = ngx.HTTP_POST, body = new_body }
        )

    if res.status ~= 200 then
        -- in case of error, just forward it as is with http status from postgrest
        ngx.status = res.status
        return ngx.say(res.body)
    else
        -- decode response and strip token and save into session
        local resp_data = cjson.decode(res.body)
        -- Only keep the "me" and "authentication" keys in the resonse, strip jwt
        local response = { me = resp_data.me, authentication = resp_data.authentication }
        session:set("jwt", resp_data.token)
        session:save()
        return ngx.say(cjson.encode(response))
    end
else
    utils.return_error("Could not forward challenge from session, make sure to call /rest/rpc/passkey_authentication_begin to get the challenge first.", ngx.HTTP_BAD_REQUEST)
end
