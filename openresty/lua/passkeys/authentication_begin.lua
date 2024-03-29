local resty_session = require "resty.session"
local utils = require "utils"

-- passkey_authentication_begin lua code to relay POST request to PostgREST
-- but to capture and store the challenge in the session

-- read the body so we can forward it
ngx.req.read_body()

ngx.req.set_header("Prefer", "params=single-object")
local res = ngx.location.capture(
    "/internal/rest/rpc/passkey_authentication_begin",
    { method = ngx.HTTP_POST, always_forward_body  = true }
    )

-- read the response from PostgREST
if res.status ~= 200 then
    -- in case of error, just forward it as is
    ngx.status = res.status
    return ngx.say(res.body)
else
    -- read the challenge from the body 
    local b = cjson.decode(res.body)
    local challenge = b['challenge']
    if challenge then
        -- and store it in session
        local session = resty_session.open()

        session:set('challenge', challenge)
        local ok, err = session:save()
        if not ok then
            utils.return_error("Could not store passkey challenge in session cookie", ngx.HTTP_BAD_REQUEST)
        end
    end
    ngx.status = 200
    return ngx.say(res.body)
end
