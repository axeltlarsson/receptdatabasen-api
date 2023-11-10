local resty_session = require "resty.session"
local utils = require "utils"

-- make the request to Postgrest 
ngx.req.read_body()
local request_options = {}
request_options["always_forward_body"] = true

local res = ngx.location.capture(
    "/internal/rest/rpc/passkey_registration_begin",
    request_options
    )

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

        session.data.challenge = challenge
        local ok, err = session:save()
        if not ok then
            utils.return_error("Could not store passkey challenge in session cookie", ngx.HTTP_BAD_REQUEST)
        end
    end
    ngx.status = 200
    return ngx.say(res.body)
end
