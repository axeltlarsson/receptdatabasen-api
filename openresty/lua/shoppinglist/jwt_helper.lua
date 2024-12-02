--- Module for generating JWT tokens.
-- This is used to authenticate requests to the shopping list API.
local jwt = require "resty.jwt"

local M = {}

--- Generate a JWT token for a given user.
-- @param user_name string The user name for which to generate the token.
-- @param secret string The shared secret used to sign the token.
-- @return string The generated JWT token.
function M.generate(user_name, secret)
    return jwt:sign(
        secret,
        {
            header = { typ = "JWT", alg = "HS256" },
            payload = {
                iss = "receptdatabasen",
                aud = "listan",
                sub = user_name,
                scope = "add:ingredients",
                iat = ngx.now(),
                exp = ngx.now() + 600 -- Expires in 10 minutes
            }
        }
    )
end

return M

